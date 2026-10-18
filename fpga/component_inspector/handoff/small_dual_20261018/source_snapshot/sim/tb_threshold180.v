`timescale 1ns/1ps
// Geometry/state fixtures chosen before RTL evaluation from the documented
// half-cell tolerance changes. Not native camera photos or accuracy metrics.
module tb_threshold180;
reg clk=0,rst=0,fs=0,sof=0,accept=0,cancel=0;
reg [10:0] x=0;reg [9:0] y=0;reg [95:0] rgb=0;
always #5 clk=~clk;
wire ready;wire [303:0] objects;
frame_shape_search #(.WIDTH(1280),.HEIGHT(720),.REGIONS(1)) dut(
 .clk(clk),.rst_n(rst),.frame_start(fs),.pixel_sof(sof),.pixel_accept(accept),.invalidate(cancel),
 .pixel_x(x),.pixel_y(y),.rgb(rgb),.ready(ready),.region_objects(objects));
integer pattern=0,shift=0,cases=0,checks=0,failures=0,cycles,px,py,l,v;
function automatic integer circle(input integer xx,yy,n);
 begin circle=xx>=0 && xx<n && yy>=0 && yy<n && (2*xx+1-n)*(2*xx+1-n)+(2*yy+1-n)*(2*yy+1-n)<=n*n;end
endfunction
function automatic integer image(input integer xx,yy);
 integer dx,dy,base,localx,localy;begin
 image=30;
 for(integer zone=0;zone<2;zone++)begin
  base=(zone==0 ? 300 : 500)+shift;
  // Main real pocket: small normal, fill-sensitive body, standing projection,
  // broad standing projection, or low-gray flipped synthetic fixture.
  if(pattern==0 || pattern==3 || pattern==5 || pattern==6 || pattern==7 || pattern==8)begin
   if(pattern==0)begin
    if(xx>=546+shift && xx<576+shift && yy>=base+2 && yy<base+40)image=180;
   end else if(pattern==6)begin
    if(xx>=550+shift && xx<574+shift && yy>=base-2 && yy<base+42)image=180;
   end else if(pattern==7)begin
    if(xx>=542+shift && xx<580+shift && yy>=base+6 && yy<base+34)image=180;
   end else if(xx>=544+shift && xx<578+shift && yy>=base && yy<base+42)begin
    image=pattern==8 ? 90 : 180;
    if(pattern==3 && xx>=556+shift && xx<564+shift && yy>=base+6 && yy<base+34)image=30;
    if(pattern==8 && (yy<base+6 || yy>=base+36))image=180;
   end
  end
  if(pattern==1 || pattern==4 || pattern==5)begin
   dx=xx-((pattern==5 ? 714 : 554)+shift);dy=yy-(base+14);
   if(dx>=0 && dy>=0 && circle(dx/2,dy/2,6))image=pattern==4 ? 110 : 90;
  end
  //20px locating hole with a connected T100 inner fragment. It must be
  // removed before a small/uncertain inspection candidate can use its slot.
  if(pattern==2 || pattern==5)begin
   dx=xx-(630+shift);dy=yy-(base-28);
   if(dx>=0 && dy>=0 && circle(dx/2,dy/2,10))begin
    image=90;if(dx>=6 && dx<12 && dy>=6 && dy<12)image=110;
   end
  end
  if(pattern==9 && xx>=560+shift && xx<562+shift && yy>=base+20 && yy<base+22)image=110;
 end
 end
endfunction
task ticks(input integer n);repeat(n)@(negedge clk);endtask
task frame(input integer p,offset);
 reg [75:0] rec;integer count,want,expected;begin
 cases++;pattern=p;shift=offset;fs=1;ticks(1);fs=0;ticks(3);
 for(py=0;py<720;py++)begin
  for(px=0;px<1280;px+=4)begin
   x=px;y=py;accept=1;sof=px==0 && py==0;
   for(l=0;l<4;l++)begin v=image(px+l,py);rgb[95-l*24-:24]={3{8'(v)}};end
   ticks(1);accept=0;sof=0;if(px%128==0)ticks(1);
  end
  ticks(2);
 end
 ticks(5);cycles=0;while(!ready && cycles<240000)begin ticks(1);cycles++;end
 want=(p==2 || p==9) ? 0 : p==5 ? 4 : 2;count=0;
 for(integer k=0;k<4;k++)begin
  rec=objects[k*76+:76];
  if(rec[75])begin
   count++;checks++;expected=(p==1 || (p==5 && k%2==1)) ? 3 : p==4 ? 1 : 2;
   if(rec[74:73]!==expected)begin failures++;$display("FAIL threshold class p%0d shift%0d slot%0d got%0d expected%0d",p,offset,k,rec[74:73],expected);end
   if(p==0 && rec[72:69]!=0)begin failures++;$display("FAIL threshold small normal wrongly reviewed p%0d slot%0d reason%h",p,k,rec[72:69]);end
   if(p==3 && !rec[71])begin failures++;$display("FAIL threshold 84percent fill not reviewed slot%0d reason%h",k,rec[72:69]);end
   if((p==6 || p==7 || p==8) && rec[72:69]==0)begin failures++;$display("FAIL threshold standing/flipped review absent p%0d slot%0d",p,k);end
   if(p==2 || p==9)begin failures++;$display("FAIL threshold locating/tiny occupied inspection slot p%0d",p);end
  end
 end
 if(!ready || count!=want)begin failures++;$display("FAIL threshold count/deadline p%0d shift%0d count%0d expected%0d ready%b",p,offset,count,want,ready);end
 $display("REF threshold pattern%0d shift%0d records%h cycles%0d",p,offset,objects,cycles);
 cancel=1;ticks(1);cancel=0;ticks(2);if(ready || objects!==0)$fatal(1,"threshold cancel kept stale objects");
 end endtask
initial begin
 ticks(5);rst=1;ticks(5);
 for(integer p=0;p<10;p++)frame(p,0);
 frame(0,1);frame(1,1);frame(2,1);frame(5,1);
 if(failures)$fatal(1,"threshold regression failed %0d",failures);
 $display("PASS threshold180: %0d full frames/%0d independent records; small normal/no false review,6-cell empty,10-cell locating+T100 fragment suppression,mixed P/E,85percent fill,standing/broad standing/low-gray flip kept PRESENT+review,bright/tiny not EMPTY,2x2 phase,cancel",cases,checks);$finish;
end
initial begin #180000000;$fatal(1,"threshold watchdog");end
endmodule
