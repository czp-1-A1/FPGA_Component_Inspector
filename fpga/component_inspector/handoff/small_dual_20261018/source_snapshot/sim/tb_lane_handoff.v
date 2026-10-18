`timescale 1ns/1ps
module tb_lane_handoff;
reg clk=0,rst=0,fs=0,sof=0,accept=0,cancel=0;reg [10:0] x=0;reg [9:0] y=0;reg [95:0] rgb=0;
always #5 clk=~clk;
wire ready;wire [303:0] objects;
frame_shape_search #(.WIDTH(1280),.HEIGHT(720),.REGIONS(1),.LANE_SINGLE(1)) dut(
 .clk(clk),.rst_n(rst),.frame_start(fs),.pixel_sof(sof),.pixel_accept(accept),.invalidate(cancel),.pixel_x(x),.pixel_y(y),.rgb(rgb),.ready(ready),.region_objects(objects));
integer shift=0,px,py,k,cy,c,v,cycles,frames=0,checks=0;
function automatic integer image(input integer xx,yy);
 begin image=30;
 for(integer lane=0;lane<2;lane++)begin
  for(integer id=0;id<2;id++)begin
   if(xx>=608+id*64+shift-18 && xx<608+id*64+shift+18 &&
     yy>=(lane==0 ? 300 : 420)-22 && yy<(lane==0 ? 300 : 420)+22)image=180;
  end
 end
 end
endfunction
task ticks(input integer n);repeat(n)@(negedge clk);endtask
task frame(input integer delta,want,clear);
 reg [75:0] rec;integer center;begin
 if(clear)begin cancel=1;ticks(1);cancel=0;ticks(2);if(objects!==0 || ready)$fatal(1,"handoff invalidate retained result");end
 frames++;shift=delta;fs=1;ticks(1);fs=0;ticks(3);
 for(py=0;py<720;py++)begin
  for(px=0;px<1280;px+=4)begin
   x=px;y=py;accept=1;sof=px==0 && py==0;
   for(k=0;k<4;k++)begin v=image(px+k,py);rgb[95-k*24-:24]={3{8'(v)}};end
   ticks(1);accept=0;sof=0;
  end ticks(2);
 end
 ticks(5);cycles=0;while(!ready && cycles<120000)begin ticks(1);cycles++;end
 if(!ready || objects[151:76]!==0 || objects[303:228]!==0)$fatal(1,"handoff deadline/single slot");
 for(integer lane=0;lane<2;lane++)begin
  rec=objects[lane*152+:76];center=(rec[41:31]+rec[30:20])/2;checks++;
  if(!rec[75] || rec[74:73]!=2 || center!=want)$fatal(1,"handoff switched identity frame%0d lane%0d center%0d expected%0d",frames,lane,center,want);
 end
 end endtask
initial begin
 ticks(5);rst=1;ticks(5);
 frame(0,672,0);frame(4,676,0);frame(0,672,0);
 frame(32,640,0);frame(36,644,0);
 frame(4,612,1);frame(0,608,0);
 $display("PASS lane handoff: %0d frames/%0d records,4px back/forth identity stable,central handoff to next part,invalidate forces fresh acquisition,both lanes,current boxes only",frames,checks);$finish;
end
initial begin #70000000;$fatal(1,"handoff watchdog");end
endmodule
