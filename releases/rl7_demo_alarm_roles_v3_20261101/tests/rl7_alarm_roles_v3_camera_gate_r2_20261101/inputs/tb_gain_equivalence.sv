`timescale 1ns/1ps
module tb_gain_equivalence;
 reg clk=0,rstn=0; reg [6:0] index=0;
 always #5 clk=~clk;
 wire [15:0] actual,reference,fixed_gain;
 SC500GainTbl dut(clk,rstn,index,actual);
 SC500GainTbl_reference original(clk,rstn,index,reference);
 SC500GainTbl fixed_address(clk,rstn,7'd24,fixed_gain);
 integer k,pass;
 initial begin
  // Both reset pin levels, both address orders, every valid/invalid address.
  for(pass=0;pass<2;pass=pass+1) begin
   rstn=pass;
   for(k=0;k<128;k=k+1) begin
    @(negedge clk);index=pass ? 127-k:k;
    @(posedge clk);#1;
    if(actual!==reference)$fatal(1,"gain map differs at index %0d: %h/%h",index,actual,reference);
    if(fixed_gain!==16'h0338)$fatal(1,"constant GAIN40 must encode 0338");
   end
  end
  $display("PASS GAIN EQUIVALENCE: all128 addresses x2 reset levels/orders, original registered lookup and constant0338");
  $finish;
 end
endmodule
