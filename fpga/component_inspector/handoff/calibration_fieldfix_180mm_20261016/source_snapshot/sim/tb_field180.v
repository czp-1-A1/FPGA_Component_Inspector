`timescale 1ns/1ps
// Field failure regressions constructed from CAL extents and photographed layouts.
// Synthetic RGB fixtures are not native sensor recordings or accuracy statistics.
module tb_field180;
reg clk=0,rst=0,fs=0,sof=0,accept=0,cancel=0;
reg [10:0] x=0;reg [9:0] y=0;reg [95:0] rgb=0;
always #5 clk=~clk;
wire ready;wire [303:0] objects;
frame_shape_search #(.WIDTH(1280),.HEIGHT(720),.REGIONS(1)) dut(
 .clk(clk),.rst_n(rst),.frame_start(fs),.pixel_sof(sof),.pixel_accept(accept),.invalidate(cancel),
 .pixel_x(x),.pixel_y(y),.rgb(rgb),.ready(ready),.region_objects(objects));
integer pattern=0,px,py,l,v,cycles,cases=0,failures=0,checks=0,shift=0;
function integer circle(input integer xx,yy,n);
 begin
 circle=xx>=0 && xx<n && yy>=0 && yy<n;
 if(n==4 && ((xx==0 && yy==0) || (xx==3 && yy==0) || (xx==0 && yy==3)))circle=0;
 if(n==5 && (xx==0 || xx==4) && (yy==0 || yy==4))circle=0;
 if(n==7 && (((xx==0 || xx==6) && (yy<2 || yy>=5)) || ((xx==1 || xx==5) && (yy==0 || yy==6))))circle=0;
 end
endfunction
function integer image(input integer xx,yy);
 integer dx,dy,ux,uy,slope,base,body,n;
 begin
 image=(pattern==3 || pattern==5) ? 240 : 30;
 for(integer z=0;z<2;z++)begin
  slope=(pattern==3 ? -1 : pattern==5 ? 1 : 0)*((xx-640)/8);
  base=z==0 ? 320 : 520;
  if((pattern==3 || pattern==5) && xx>=180 && xx<1120 && yy>=base+slope-58 && yy<base+slope+35)image=30;
  for(integer k=0;k<2;k++)begin
   dx=xx-(616+48*k+shift);dy=yy-(base+slope+shift);
   body=pattern==1 || pattern==3 || pattern==5;
   if(pattern!=2)begin
    if(body && k==0)begin
     if(dx>=-18 && dx<18 && dy>=-22 && dy<22)begin
      ux=(dx+18)/2;uy=(dy+22)/2;
      if(!((ux<2 || ux>=16) && (uy<4 || uy>=18)))image=180;
     end
    end else begin
     n=pattern==6 ? 4 : 5;ux=(dx+n)/2;uy=(dy+n)/2;
     if(dx>=-n && dy>=-n && circle(ux,uy,n))begin
      image=90;
      // Five moderately bright cells: new RAW A20, while T80 A84 remains.
      if((pattern==0 || pattern==4) && ux>=1 && ux<=2 && uy>=1 && uy<=3 && !(ux==2 && uy==3))image=110;
     end
    end
   end
   // Feed-hole row, with a T100 core whose fragments must not occupy pockets.
   dx=xx-(616+48*k+shift);dy=yy-(base+slope-40+shift);
   ux=(dx+7)/2;uy=(dy+7)/2;
   if(dx>=-7 && dy>=-7 && circle(ux,uy,7))begin
    image=90;
    if(ux>=2 && ux<5 && uy>=2 && uy<5)image=110;
   end
  end
 end
 end
endfunction
task ticks(input integer n);begin repeat(n)@(negedge clk);end endtask
task frame(input integer p,offset);
 integer count,want,expected;reg [75:0] rec;
 begin
 pattern=p;shift=offset;cases++;fs=1;ticks(1);fs=0;ticks(3);
 for(py=0;py<720;py++)begin
  for(px=0;px<1280;px+=4)begin
   x=px;y=py;accept=1;sof=px==0 && py==0;
   for(l=0;l<4;l++)begin v=image(px+l,py);rgb[95-l*24-:24]={3{8'(v)}};end
   ticks(1);accept=0;sof=0;
  end
  ticks(2);
 end
 ticks(5);cycles=0;while(!ready && cycles<800000)begin ticks(1);cycles++;end
 count=0;want=p==2 ? 0 : 4;
 for(integer k=0;k<4;k++)begin
  rec=objects[k*76+:76];
  if(rec[75])begin
   count++;checks++;expected=(p==1 || p==3 || p==5) && k%2==0 ? 2 : 3;
   if(rec[74:73]!=expected)begin $display("FAIL field class pattern%0d offset%0d slot%0d class%0d wanted%0d",p,offset,k,rec[74:73],expected);failures++;end
   if(rec[19:10]+rec[9:0] < 2*(k<2 ? 300 : 500))begin $display("FAIL field feed became target pattern%0d slot%0d",p,k);failures++;end
  end
 end
 if((p==3 || p==5) && cycles>120000)begin $display("FAIL field27FPS margin pattern%0d cycles%0d",p,cycles);failures++;end
 if(!ready || count!=want || cycles>240000)begin $display("FAIL field count/deadline pattern%0d offset%0d count%0d want%0d cycles%0d ready%b",p,offset,count,want,cycles,ready);failures++;end
 $display("REF field pattern=%0d offset=%0d records=%h cycles=%0d",p,offset,objects,cycles);
 cancel=1;ticks(1);cancel=0;ticks(2);if(ready || objects!==0)$fatal(1,"field cancel retained old results");
 end
endtask
initial begin
 ticks(5);rst=1;ticks(5);
 frame(0,1);frame(1,1);frame(2,1);frame(3,1);frame(5,1);
 frame(4,0);frame(4,1);frame(4,2);
 frame(6,0);frame(6,1);frame(6,2);
 if(failures)$fatal(1,"field regressions failed: %0d",failures);
 $display("PASS field180: %0d frames, %0d checked results, five bright cells, adjacent mixed pockets, feed-only rejection, +/-slope bright background under1.2ms, subpixel translation of both CAL80 sizes, cancel",cases,checks);$finish;
end
initial begin #200000000;$fatal(1,"field watchdog");end
endmodule
