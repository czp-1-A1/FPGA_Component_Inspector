`timescale 1ns/1ps
module tb_lane_search;
reg clk=0,rst=0,fs=0,sof=0,accept=0,cancel=0;reg [10:0] x=0;reg [9:0] y=0;reg [95:0] rgb=0;
always #5 clk=~clk;
wire ready;wire [303:0] objects;
frame_shape_search #(.WIDTH(1280),.HEIGHT(720),.REGIONS(1),.LANE_SINGLE(1)) dut(
 .clk(clk),.rst_n(rst),.frame_start(fs),.pixel_sof(sof),.pixel_accept(accept),.invalidate(cancel),.pixel_x(x),.pixel_y(y),.rgb(rgb),.ready(ready),.region_objects(objects));
integer pattern=0,offset=0,cases=0,checks=0,px,py,l,v,cycles,maxcycles=0;
integer seen0=0,seen1=0,expected_id,expected_center,actual_center,expected_state,dist,best;
function automatic integer circle(input integer a,b,n);
 circle=a>=0 && a<n && b>=0 && b<n && (2*a+1-n)*(2*a+1-n)+(2*b+1-n)*(2*b+1-n)<=n*n;
endfunction
function automatic integer image(input integer xx,yy);
 integer c,cy,dx,dy,k,sh;begin
 image=30;
 for(integer lane=0;lane<2;lane++)begin
  cy=lane==0 ? 300 : 420;sh=lane==0 ? offset : -offset;
  if(pattern==0)begin
   for(k=0;k<3;k++)begin
    c=576+k*64+sh;
    if(k==1)begin dx=xx-(c-6);dy=yy-(cy-6);if(dx>=0 && dy>=0 && circle(dx/2,dy/2,6))image=90;end
    else if(xx>=c-18 && xx<c+18 && yy>=cy-22 && yy<cy+22)image=180;
   end
  end else if(pattern==1)begin
   dx=xx-630;dy=yy-(cy-10);if(dx>=0 && dy>=0 && circle(dx/2,dy/2,10))begin image=90;if(dx>=6 && dx<12 && dy>=6 && dy<12)image=110;end
  end else if(pattern==2 || pattern==3)begin
   c=640;if(xx>=c-12 && xx<c+12 && yy>=cy-22 && yy<cy+22)image=pattern==2 ? 180 : 90;
  end else if(pattern==4)begin
   // Centers just inside/outside the new left boundary. Complete contour
   // extends outside dashed ROI; only the inside center may produce a record.
   c=offset;if(xx>=c-18 && xx<c+18 && yy>=cy-22 && yy<cy+22)image=180;
  end
 end
 end
endfunction
task ticks(input integer n);repeat(n)@(negedge clk);endtask
task frame(input integer p,sh);
 reg [75:0] rec;integer count,c,delta;begin
 cases++;pattern=p;offset=sh;fs=1;ticks(1);fs=0;ticks(3);
 for(py=0;py<720;py++)begin
  for(px=0;px<1280;px+=4)begin
   x=px;y=py;accept=1;sof=px==0 && py==0;
   for(l=0;l<4;l++)begin v=image(px+l,py);rgb[95-l*24-:24]={3{8'(v)}};end
   ticks(1);accept=0;sof=0;if(px%128==0)ticks(1);
  end ticks(2);
 end
 ticks(5);cycles=0;while(!ready && cycles<120000)begin ticks(1);cycles++;end
 if(!ready)$fatal(1,"lane search deadline");if(cycles>maxcycles)maxcycles=cycles;
 if(objects[151:76]!==0 || objects[303:228]!==0)$fatal(1,"second lane slot survived");
 count=0;
 for(integer lane=0;lane<2;lane++)begin
  rec=objects[lane*152+:76];
  if(rec[75])begin
   count++;checks++;actual_center=(rec[41:31]+rec[30:20])/2;
   if(pattern==0)begin
    best=999;expected_id=-1;
    for(integer k=0;k<3;k++)begin
     c=576+k*64+(lane==0 ? sh : -sh);delta=c-641;if(delta<0)delta=-delta;
     if(c>=560 && c<720 && delta<best)begin best=delta;expected_id=k;expected_center=c;end
    end
    expected_state=expected_id==1 ? 3 : 2;
    if(actual_center!=expected_center || rec[74:73]!=expected_state)$fatal(1,"lane moving truth p%0d sh%0d lane%0d center%0d expected%0d state%0d expected%0d",p,sh,lane,actual_center,expected_center,rec[74:73],expected_state);
    if(lane==0)seen0=seen0|(1<<expected_id);else seen1=seen1|(1<<expected_id);
   end else if(pattern==2 || pattern==3)begin
    if(rec[74:73]!=2 || rec[72:69]==0)$fatal(1,"lane standing/weak body lost PRESENT+review");
   end else if(pattern==4 && rec[74:73]!=2)$fatal(1,"lane boundary body class");
  end
 end
 if(count!=((p==1 || p==5 || (p==4 && sh==556)) ? 0 : 2))$fatal(1,"lane count p%0d offset%0d got%0d",p,sh,count);
 $display("REF lane p%0d shift%0d cycles%0d",p,sh,cycles);
 cancel=1;ticks(1);cancel=0;ticks(2);if(ready || objects!==0)$fatal(1,"lane cancel stale tuple");
 end endtask
initial begin
 ticks(5);rst=1;ticks(5);
 for(integer sh=-64;sh<=64;sh+=16)frame(0,sh);
 for(integer sh=64;sh>=-64;sh-=16)frame(0,sh);
 frame(1,0);frame(2,0);frame(3,0);frame(4,562);frame(4,556);frame(5,0);
 if(seen0!=7 || seen1!=7)$fatal(1,"lane moving population omitted");
 $display("PASS lane search: %0d full frames/%0d current records,all3 pockets both lanes both directions,one slot/nearest center,standing/low gray/feed exclusion,complete contour boundary,outside rejects,cancel,max_cycles%0d",cases,checks,maxcycles);$finish;
end
initial begin #200000000;$fatal(1,"lane search watchdog");end
endmodule
