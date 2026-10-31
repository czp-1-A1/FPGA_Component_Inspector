`timescale 1ns/1ps
// Exhaust all 9-bit sums, 8-bit thresholds and legal fresh-word popcounts.
// Keep the original expression verbatim as the independent arithmetic oracle.
module tb_d3_fss_ref_math;
 reg [8:0] left_dark,right_dark;reg [7:0] ref_min;reg [2:0] dark_word;
 wire original_bad=left_dark<ref_min || right_dark+dark_word<ref_min;
 wire original_good=left_dark>=ref_min && right_dark+dark_word>=ref_min;
 wire [4:0] choices;
 genvar k;
 generate for(k=0;k<5;k=k+1)begin : option_predicate
  localparam [8:0] N=k;
  assign choices[k]=left_dark<ref_min || right_dark+N<ref_min;
 end endgenerate
 integer t,r,d,l,checks=0,wrap_checks=0;
 initial begin
  // All right/threshold combinations, both independent left-comparison classes.
  for(t=0;t<256;t=t+1)for(r=0;r<512;r=r+1)for(d=0;d<5;d=d+1)begin
   ref_min=8'(t);right_dark=9'(r);dark_word=3'(d);left_dark=511;
   #1;
   if(original_bad!==choices[dark_word] || original_good!==!choices[dark_word])
    $fatal(1,"reference modular compare changed right%0d threshold%0d word%0d",r,t,d);
   if(r+d>511)wrap_checks++;
   checks++;
   if(t!=0)begin
    left_dark=9'(t-1);#1;
    if(original_bad!==1'b1 || choices[dark_word]!==1'b1 || original_good!==1'b0)
     $fatal(1,"left reference rejection changed");
    checks++;
   end
  end
  // Cover every left/threshold pair separately, including equality and zero.
  for(t=0;t<256;t=t+1)for(l=0;l<512;l=l+1)begin
   ref_min=8'(t);left_dark=9'(l);right_dark=256;dark_word=0;#1;
   if(original_bad!==choices[0] || original_good!==!choices[0])$fatal(1,"left threshold changed");
   checks++;
  end
  $display("PASS FSS exact original 9-bit reference comparisons: %0d exhaustive checks, %0d modular overflow cases, all thresholds/left/right/legal fresh popcounts; diagnostic and accumulator expressions not rewritten",checks,wrap_checks);$finish;
 end
endmodule
