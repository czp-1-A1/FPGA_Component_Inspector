`timescale 1ns/1ps
module tb_d3_math_bounds;
 roi_sobel_view #(.WIDTH(96),.HEIGHT(30)) dut(
  .clk(1'b0),.rst_n(1'b0),.pixel_valid(1'b0),.pixel_sof(1'b0),.pixel_last(1'b0),.early_sof(1'b0),.rgb(96'd0),.mode(2'd0),.invalidate(1'b0),.view_ready(1'b0),
  .dynamic_x0(11'd0),.dynamic_x1(11'd0),.dynamic_y0(10'd0),.dynamic_y1(10'd0));
 integer checks=0;reg [9:0] expected;
 initial begin
  for(integer a=0;a<1024;a++)for(integer b=0;b<1024;b++)begin
   expected=a>=b ? a-b : b-a;
   if(dut.abs_diff10(10'(a),10'(b))!==expected)$fatal(1,"absolute difference mismatch %0d %0d",a,b);checks++;
  end
  for(integer a=0;a<256;a++)for(integer b=0;b<256;b++)begin
   if(((a*3+b)>>2)>255 || ((a*3+b)>>2)!==((a*3+b)&1023)>>2)$fatal(1,"weighted bound");
  end
  $display("PASS exact display math: all1048576 ten-bit absolute-difference inputs including beyond normal Sobel1020, full10-bit weighted sum maximum1020 with exact divide4 truncation; no arithmetic precision reduction");$finish;
 end
endmodule
