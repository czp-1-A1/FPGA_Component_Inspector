`timescale 1ns/1ps
// Independent 80x80 reference; bright pixels elsewhere in the viewing ROI are excluded.
module tb_roi_core;
reg clk=0,rst=0,accept=0,sof=0,commit=0,invalid=0,fs=0;
reg [10:0] x=0;
reg [9:0] y=0;
reg [95:0] rgb=0;
always #5 clk=~clk;
wire valid,fresh;
wire [7:0] mean,lo,hi;
wire [19:0] count;
wire [27:0] sum;
roi_statistics #(.X0(472),.X1(552),.Y0(260),.Y1(340)) dut(
 clk,rst,accept,sof,x,y,rgb,commit,invalid,valid,mean,lo,hi,count,sum,fresh,fs);
integer px,py,lane,row,beat,r,g,b,gray,refsum=0,reflo=255,refhi=0,pulses=0;
always @(posedge clk) if(rst && fresh) pulses=pulses+1;
task ticks;input integer n;begin repeat(n) @(negedge clk);end endtask
task frame;input integer background,flat_white;
begin
 fs=1;ticks(1);fs=0;pulses=0;
 for(row=0;row<600;row=row+1) for(beat=0;beat<256;beat=beat+1) begin
  x=beat*4;y=row;
  for(lane=0;lane<4;lane=lane+1) begin
   px=x+lane-472;py=row-260;
   if(px>=0 && px<80 && py>=0 && py<80) begin
    r=flat_white ? 255 : px+20;
    g=flat_white ? 255 : py+40;
    b=flat_white ? 255 : (px+py)%100+10;
   end else begin r=background;g=background;b=background;end
   rgb[95-lane*24-:24]={8'(r),8'(g),8'(b)};
  end
  accept=1;sof=(row==0 && beat==0);ticks(1);accept=0;sof=0;
  if(beat%7==0) ticks(1);
 end
 ticks(3);commit=1;ticks(1);commit=0;ticks(40);
 if(!valid || pulses!=1 || count!=6400) $fatal(1,"core count/fresh valid=%b count=%0d pulses=%0d",valid,count,pulses);
 if(flat_white) begin
  if(sum!=1632000 || mean!=255 || lo!=255 || hi!=255) $fatal(1,"core full-scale accumulation/division");
 end else if(sum!=refsum || mean!=refsum/6400 || lo!=reflo || hi!=refhi)
  $fatal(1,"core reference/outside exclusion sum=%0d mean=%0d min=%0d max=%0d",sum,mean,lo,hi);
end endtask
initial begin
 // Only local core pixels contribute to this reference, never stream/DUT internals.
 for(py=0;py<80;py=py+1) for(px=0;px<80;px=px+1) begin
  gray=((px+20)+2*(py+40)+((px+py)%100+10))/4;
  refsum=refsum+gray;if(gray<reflo) reflo=gray;if(gray>refhi) refhi=gray;
 end
 ticks(4);rst=1;ticks(4);
 frame(0,0);frame(255,0);frame(0,1);
 $display("PASS core ROI: 6400 pixels, independent sum/mean/min/max, outside black/white unchanged, full-scale and bubbles");
 $finish;
end
initial begin #10000000;$fatal(1,"core watchdog");end
endmodule
