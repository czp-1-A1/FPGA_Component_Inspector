`timescale 1ns/1ps
// CAL-panel geometry fixtures, not native camera frames or accuracy estimates.
module tb_cal180_holes;
reg clk=0,rst=0,fs=0,sof=0,accept=0,cancel=0;
reg [10:0] x=0;reg [9:0] y=0;reg [95:0] rgb=0;
always #5 clk=~clk;
wire ready;wire [303:0] objects;
frame_shape_search #(.WIDTH(1280),.HEIGHT(720),.REGIONS(1)) dut(
 .clk(clk),.rst_n(rst),.frame_start(fs),.pixel_sof(sof),.pixel_accept(accept),.invalidate(cancel),
 .pixel_x(x),.pixel_y(y),.rgb(rgb),.ready(ready),.region_objects(objects));
integer pattern=0,cases=0,checks=0,cycles,px,py,l,v;
integer centers[0:3];integer rows[0:3];
function integer empty_cell(input integer xx,yy,n);
 begin
 empty_cell=xx>=0 && xx<n && yy>=0 && yy<n;
 if(n==4 && ((xx==0 && yy==0) || (xx==3 && yy==0) || (xx==0 && yy==3)))empty_cell=0;
 if(n==5 && (xx==0 || xx==4) && (yy==0 || yy==4))empty_cell=0;
 end
endfunction
function integer feed_cell(input integer xx,yy,n);
 begin
 feed_cell=xx>=0 && xx<n && yy>=0 && yy<8;
 if(n==8 && ((xx<2 && yy<2) || (xx>=6 && yy<2) || (xx<2 && yy>=6) ||
   (xx>=6 && yy>=6 && !(xx==6 && yy==6))))feed_cell=0;
 if(n==7 && (((xx==0 || xx==6) && (yy==0 || yy==7)) ||
   (yy==0 && (xx==1 || xx==5)) || (yy==7 && (xx==1 || xx==5)) || (xx==0 && yy==1)))feed_cell=0;
 end
endfunction
function integer image(input integer xx,yy);
 integer dx,dy,n,b,ux,uy;
 begin
 image=pattern==4 && !((yy>=250 && yy<370) || (yy>=450 && yy<590)) ? 240 : 30;
 for(integer k=0;k<4;k++)begin
  dx=xx-centers[k];dy=yy-rows[k];n=k%2==0 ? 4 : 5;
  b=pattern==1 || ((pattern==2 || pattern==4) && (k==0 || k==3));
  if(pattern!=3 && pattern!=5)begin
   if(b)begin
    if(dx>=-20 && dx<20 && dy>=-24 && dy<24)image=90;
    if(dx>=-18 && dx<18 && dy>=-22 && dy<22)begin
     ux=(dx+18)/2;uy=(dy+22)/2;
     if(!((ux<2 || ux>=16) && (uy<4 || uy>=18)))image=180;
    end
   end else if(dx>=-n && dy>=-n && empty_cell((dx+n)/2,(dy+n)/2,n))image=pattern==8 ? 110 : 90;
  end
 end
 if(pattern<=4)for(integer k=0;k<2;k++)begin
  n=k==0 ? 8 : 7;dx=xx-640;dy=yy-(k==0 ? 280 : 480);
  if(dx>=-8 && dy>=-8 && feed_cell((dx+8)/2,(dy+8)/2,n))begin
   image=90;
   if(pattern==3 && dx>=-2 && dx<4 && dy>=-2 && dy<4)image=110;
  end
 end
 if(pattern==5)for(integer k=0;k<2;k++)begin
  dx=xx-640;dy=yy-(k==0 ? 320 : 520);
  if(dx>=-6 && dx<6 && dy>=-6 && dy<6 && !((dx<-4 || dx>=4) && (dy<-4 || dy>=4)))image=90;
 end
 end
endfunction
task ticks(input integer n);begin repeat(n)@(negedge clk);end endtask
task frame(input integer p);
 reg [75:0] rec;integer count,want,n,b;
 begin
 cases++;pattern=p;centers[0]=p==6 ? 402 : p==7 ? 398 : 520;
 // Odd-sized mask fixtures still start on even source rows/columns.
 centers[1]=p==1 ? 760 : 761;centers[2]=520;centers[3]=(p==1 || p==2 || p==4) ? 760 : 761;
 rows[0]=320;rows[1]=p==1 ? 320 : 321;rows[2]=520;rows[3]=(p==1 || p==2 || p==4) ? 520 : 521;
 fs=1;ticks(1);fs=0;ticks(3);
 for(py=0;py<720;py++)begin
  for(px=0;px<1280;px+=4)begin
   x=px;y=py;accept=1;sof=px==0 && py==0;
   for(l=0;l<4;l++)begin v=image(px+l,py);rgb[95-l*24-:24]={3{8'(v)}};end
   ticks(1);accept=0;sof=0;
  end
  ticks(2);
 end
 ticks(5);cycles=0;while(!ready && cycles<2300000)begin ticks(1);cycles++;end
 if(!ready)$fatal(1,"CAL80 hole timeout pattern%0d",p);
 want=p==3 ? 0 : p==5 ? 2 : p==7 ? 3 : 4;count=0;
 for(integer k=0;k<4;k++)begin
  rec=objects[k*76+:76];
  if(rec[75])begin
   count++;checks++;b=p==1 || ((p==2 || p==4) && (k==0 || k==3));n=p==5 ? 6 : k%2==0 ? 4 : 5;
   if(rec[74:73]!== (p==8 ? 2'd1 : b ? 2'd2 : 2'd3))$fatal(1,"CAL80 class pattern%0d slot%0d got%0d",p,k,rec[74:73]);
   if(p!=7 && (rec[55:49]!== (b ? 36 : n*2) || rec[48:42]!== (b ? 44 : n*2) ||
     rec[68:56]!== (b ? 1456 : p==5 ? 128 : n==4 ? 52 : 84)))$fatal(1,"CAL80 feature pattern%0d slot%0d FG%0d W%0d H%0d",p,k,rec[68:56],rec[55:49],rec[48:42]);
   if(p==6 && k==0 && rec[41:31]!=396)$fatal(1,"small hole contour cropped at zone boundary");
  end
 end
 if(count!=want)$fatal(1,"CAL80 count pattern%0d got%0d expected%0d",p,count,want);
 $display("REF CAL80 pattern=%0d records=%h cycles=%0d",p,objects,cycles);
 cancel=1;ticks(1);cancel=0;ticks(2);if(ready || objects!==0)$fatal(1,"CAL80 stale metadata after cancel");
 end
endtask
initial begin
 ticks(5);rst=1;ticks(5);for(integer p=0;p<9;p++)frame(p);
 $display("PASS cal180 holes: %0d full frames, %0d records, exact CAL80 W/H/A, CAL100 bodies unchanged with low fringe, feed rejection and high-fragment removal, mixed zones, bright border, extended6-cell empty, zone-edge and outside-center, small bright object not EMPTY, cancel",cases,checks);$finish;
end
endmodule
