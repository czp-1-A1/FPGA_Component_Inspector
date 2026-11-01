`timescale 1ns/1ps
module tb_d3_resize_equivalence;
 reg clk=0;always #5 clk=~clk;
 reg rst=0,fs=0,valid=0,last=0;reg [95:0] rgb=0;
 wire fs0,v0,l0,b0,fs1,v1,l1,b1;wire [95:0] rgb0,rgb1;
 rgb_resize_2_3 #(.WIDTH(96),.HEIGHT(24)) dut(clk,rst,fs,valid,last,rgb,fs0,v0,l0,rgb0,b0);
 r11_reference_rgb_resize_2_3 #(.WIDTH(96),.HEIGHT(24)) baseline(clk,rst,fs,valid,last,rgb,fs1,v1,l1,rgb1,b1);
 integer checks=0,outputs=0,seed=32'h6a9c3251,blend_checks=0;
 always @(posedge clk)begin #1;
  if(rst)begin
   if({fs0,v0,l0,b0,rgb0}!=={fs1,v1,l1,b1,rgb1})$fatal(1,"resample differs cycle%0d",checks);
   checks++;if(v0)outputs++;
  end
 end
 initial begin
  for(integer a=0;a<256;a++)for(integer b=0;b<256;b++)for(integer h=0;h<2;h++)begin
   if(dut.blend(8'(a),8'(b),1'(h))!==baseline.blend(8'(a),8'(b),1'(h)))$fatal(1,"full precision blend differs");blend_checks++;
  end
  repeat(5)@(negedge clk);rst=1;
  for(integer f=0;f<36;f++)begin
   fs=1;valid=0;last=0;@(negedge clk);fs=0;
   for(integer y=0;y<24;y++)begin
    for(integer x=0;x<24;x++)begin
     if(f==34 && y==12 && x==10)begin fs=1;valid=0;@(negedge clk);fs=0;end
     valid=1;last=x==23 || f==35 && y==8 && x==11;
     rgb={$random(seed),$random(seed),$random(seed)};
     @(negedge clk);valid=0;last=0;
     repeat(f%3==0 ? 0 : $unsigned($random(seed))%5)@(negedge clk);
    end
    repeat(f%4==0 ? 0 : f%13)@(negedge clk);
   end
   repeat(12)@(negedge clk);
  end
  if(blend_checks!=131072 || outputs<8000)$fatal(1,"resampler coverage");
  $display("PASS shared blend: all131072 operand/weight combinations; 36 actual 96x24 RGB streams, dense/random gaps, FS cancel, bad last, reset, same every-clock output data/valid/last/FS/fault, %0d cycles %0d outputs",checks,outputs);$finish;
 end
 initial begin #10000000;$fatal(1,"resize watchdog");end
endmodule
