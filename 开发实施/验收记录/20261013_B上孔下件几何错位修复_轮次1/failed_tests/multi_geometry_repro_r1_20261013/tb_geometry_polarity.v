`timescale 1ns/1ps
// Independent counterexample: upper sprocket circles, lower pitched LED bodies.
// Source geometry is synthetic; it tests the observed orientation, not photo luma.
module tb_geometry_polarity;
reg clk=0,rst=0,fs=0,sof=0,accept=0,commit=0,done=0;
reg [10:0] x=0;reg [9:0] y=0;reg [95:0] rgb=0;
always #5 clk=~clk;
wire [43:0] bx;wire [39:0] by;wire [3:0] mask,verified;
wire located;wire [7:0] diagnostic;wire [339:0] records;wire ready;
multi_pocket_tracker tracker(clk,rst,fs,sof,accept,done,1'b0,x,y,rgb,bx,by,mask,verified,located,diagnostic);
multi_pocket_statistics statistics(clk,rst,fs,sof,accept,commit,1'b0,x,y,rgb,bx,by,mask,verified,
 1'b0,11'd0,10'd0,44'd0,4'd0,2'd1,1'b1,1'b1,8'd58,records,ready);
function integer pixel(input integer xx,yy);
 integer value,c;
 begin
  value=30;
  for(integer h=0;h<6;h++) begin
   c=200+96*h;
   if((xx-c)*(xx-c)+(yy-300)*(yy-300)<=24*24) value=200;
   // These lower bodies satisfy the old bright-run/pitch tests, but are not holes.
   if(xx>=c-48 && xx<c && yy>=344 && yy<416) value=200;
  end
  pixel=value;
 end
endfunction
task ticks(input integer n);begin repeat(n) @(negedge clk);end endtask
task frame;
 integer g;
 begin
  fs=1;ticks(1);fs=0;ticks(8);
  for(integer row=0;row<600;row++) begin
   y=row;
   for(integer beat=0;beat<256;beat++) begin
    x=beat*4;accept=1;sof=row==0 && beat==0;commit=row==456 && beat==0;
    for(integer lane=0;lane<4;lane++) begin g=pixel(beat*4+lane,row);rgb[95-lane*24-:24]={g[7:0],g[7:0],g[7:0]};end
    ticks(1);accept=0;sof=0;commit=0;ticks(1);
   end
   ticks(8);
  end
  ticks(80);done=1;ticks(1);done=0;ticks(8);
 end
endtask
integer wrong=0;
initial begin
 ticks(8);rst=1;frame();frame();
 for(integer p=0;p<4;p++) begin
  $display("OBS upper-hole geometry bank=%0d ROI=(%0d,%0d) valid=%b state=%0d mean=%0d",p,bx[p*11+:11],by[p*10+:10],records[p*85+63],records[p*85+61+:2],records[p*85+53+:8]);
  // The actual LED row is [344,416). A valid PRESENT box on y260 is unsafe.
  if(records[p*85+63] && records[p*85+61+:2]==2 && by[p*10+:10]+80<=344) wrong++;
 end
 if(wrong) $fatal(1,"pitched lower parts were mistaken for hole anchors; %0d PRESENT boxes landed on upper sprocket circles",wrong);
 $display("PASS geometry polarity: upper-hole orientation never classifies sprocket circles as parts");$finish;
end
initial begin #10000000;$fatal(1,"geometry polarity watchdog");end
endmodule
