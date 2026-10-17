`timescale 1ns/1ps
// Independent state fixtures for the user-labeled P01..P21 scenes.
// Synthetic RGB/layouts exercise the proposed tolerance; not native photo pixels.
module tb_pose180;
reg clk=0,rst=0,fs=0,sof=0,accept=0,cancel=0;
reg [10:0] x=0;reg [9:0] y=0;reg [95:0] rgb=0;
always #5 clk=~clk;
wire ready;wire [303:0] objects;
frame_shape_search #(.WIDTH(1280),.HEIGHT(720),.REGIONS(1)) dut(
 .clk(clk),.rst_n(rst),.frame_start(fs),.pixel_sof(sof),.pixel_accept(accept),.invalidate(cancel),
 .pixel_x(x),.pixel_y(y),.rgb(rgb),.ready(ready),.region_objects(objects));
integer pattern=0,cases=0,checks=0,failures=0,cycles,px,py,l,v;
function integer disk(input integer xx,yy,n);
 begin disk=xx>=0 && xx<n && yy>=0 && yy<n &&
  !((xx==0 || xx==n-1) && (yy==0 || yy==n-1));end
endfunction
function integer image(input integer xx,yy);
 integer dx,dy,u,w,base,cx;
 begin
 image=30;
 for(integer z=0;z<2;z++)begin
  base=z==0 ? 320 : 520;
  for(integer k=0;k<(pattern==10 ? 5 : 1);k++)begin
   cx=pattern==10 ? 512+k*56 : 560;dx=xx-cx;dy=yy-base;
   if(pattern==0 || pattern==10)begin
    if(dx>=-17 && dx<17 && dy>=-21 && dy<21)image=180;
   end else if(pattern==1 || pattern==8)begin
    if(dx>=-6 && dx<6 && dy>=-20 && dy<20)image=180;
   end else if(pattern==2 || pattern==9)begin
    if(dx>=-17 && dx<17 && dy>=-20 && dy<20)begin
     image=90;if(dy<-16 || dy>=16)image=180;
    end
   end else if(pattern==3)begin
    u=(dx*866+dy*500)/1000;w=(-dx*500+dy*866)/1000;
    if(u>=-18 && u<18 && w>=-22 && w<22)image=180;
   end else if(pattern==4)begin
    if(dx>=-17 && dx<17 && dy>=-21 && dy<21)image=90;
   end else if(pattern==5)begin
    if(disk((dx+5)/2,(dy+5)/2,5) && dx>=-5 && dy>=-5)image=90;
   end else if(pattern==6)begin
    if(dx>=-5 && dx<5 && dy>=-5 && dy<5)image=110;
   end else if(pattern==7)begin
    if(dx>=-6 && dx<6 && dy>=-6 && dy<6 && !((dx<-4 || dx>=4) && (dy<-4 || dy>=4)))image=90;
   end
  end
  // The large feed hole must never become PRESENT, including its bright core.
  dx=xx-640;dy=yy-(base-40);
  if(dx>=-8 && dy>=-8 && disk((dx+8)/2,(dy+8)/2,8))begin
   image=90;if(dx>=-2 && dx<4 && dy>=-2 && dy<4)image=110;
  end
  if(pattern==8 || pattern==9)begin
   dx=xx-720;dy=yy-base;
   if(dx>=-5 && dy>=-5 && disk((dx+5)/2,(dy+5)/2,5))image=90;
  end
 end
 end
endfunction
task ticks(input integer n);begin repeat(n)@(negedge clk);end endtask
task frame(input integer p);
 integer count,want,pc,ec;reg [75:0] rec;
 begin
 cases++;pattern=p;fs=1;ticks(1);fs=0;ticks(3);
 for(py=0;py<720;py++)begin
  for(px=0;px<1280;px+=4)begin
   x=px;y=py;accept=1;sof=px==0 && py==0;
   for(l=0;l<4;l++)begin v=image(px+l,py);rgb[95-l*24-:24]={3{8'(v)}};end
   ticks(1);accept=0;sof=0;
  end
  ticks(2);
 end
 ticks(5);cycles=0;while(!ready && cycles<800000)begin ticks(1);cycles++;end
 count=0;pc=0;ec=0;want=(p==8 || p==9 || p==10) ? 4 : 2;
 for(integer k=0;k<4;k++)begin
  rec=objects[k*76+:76];
  if(rec[75])begin
   count++;checks++;if(rec[74:73]==2)pc++;if(rec[74:73]==3)ec++;
   if(p==6 || p==7)begin
    if(rec[74:73]>=2)begin failures++;$display("FAIL pose gap/tiny-bright accepted pattern%0d slot%0d",p,k);end
   end else if(p==5)begin
    if(rec[74:73]!=3)begin failures++;$display("FAIL pose empty pattern%0d slot%0d",p,k);end
   end else if(p==8 || p==9)begin
    if(rec[74:73]!=(k%2==0 ? 2 : 3))begin failures++;$display("FAIL pose mixed pattern%0d slot%0d",p,k);end
   end else if(rec[74:73]!=2)begin failures++;$display("FAIL pose present pattern%0d slot%0d",p,k);end
   if(rec[74:73]==2 && (p==1 || p==2 || p==3 || p==4 || p==8 || p==9) && rec[72:69]==0)begin
    failures++;$display("FAIL pose review absent pattern%0d slot%0d",p,k);
   end
   if((rec[19:10]+rec[9:0])/2 < (k<2 ? 300 : 500))begin failures++;$display("FAIL pose feed occupied slot%0d",k);end
  end
 end
 if(!ready || count!=want)begin failures++;$display("FAIL pose count pattern%0d got%0d expected%0d ready%b",p,count,want,ready);end
 if(cycles>240000)begin failures++;$display("FAIL pose frame budget pattern%0d cycles%0d",p,cycles);end
 $display("REF pose pattern=%0d count=%0d present=%0d empty=%0d cycles=%0d records=%h",p,count,pc,ec,cycles,objects);
 cancel=1;ticks(1);cancel=0;ticks(2);if(ready || objects!==0)$fatal(1,"pose stale results after cancel");
 end
endtask
initial begin
 ticks(5);rst=1;ticks(5);for(integer p=0;p<11;p++)frame(p);
 if(failures)$fatal(1,"pose regressions failed: %0d",failures);
 $display("PASS pose180: %0d frames, %0d independent state checks, smaller normal, standing, low-gray flipped, whole-tape rotation, mixed P/E, feed/gap/tiny rejection, ten-body population, cancel",cases,checks);$finish;
end
initial begin #220000000;$fatal(1,"pose watchdog");end
endmodule
