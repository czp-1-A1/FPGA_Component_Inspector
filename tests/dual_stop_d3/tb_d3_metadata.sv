`timescale 1ns/1ps
module tb_d3_metadata;
 reg [1142:0] raw;reg [511:0] live_raw;
 wire [1142:0] result;wire [511:0] live;
 wire [511:0] expected,expected_live;
 extracted_d3_metadata dut(raw,live_raw,result,live);
 count_record_view view0(raw[631+:256],expected[255:0]);
 count_record_view view1(raw[887+:256],expected[511:256]);
 count_record_view live0(live_raw[255:0],expected_live[255:0]);
 count_record_view live1(live_raw[511:256],expected_live[511:256]);
 integer n,w,checks=0;
 initial begin
  for(n=0;n<1024;n++)begin
   for(w=0;w<1143;w++)raw[w]=$urandom_range(0,1);
   for(w=0;w<512;w++)live_raw[w]=$urandom_range(0,1);
   // Two real lane-local boxes in the unchanged original metadata segment.
   raw[198+:76]={1'b1,2'd2,4'd0,13'd1600,7'd40,7'd40,11'd680,11'd720,10'd300,10'd340};
   raw[350+:76]={1'b1,2'd2,4'd0,13'd1600,7'd40,7'd40,11'd680,11'd720,10'd480,10'd520};
   #1;
   if($isunknown(result))$fatal(1,"metadata has undriven fields");
   if(result[630:0]!==raw[630:0] || result[1142:631]!==expected || live!==expected_live)$fatal(1,"metadata bank offset mismatch");
   if(result[360+:10]!==10'd480 || result[350+:10]!==10'd520)$fatal(1,"lower bbox moved out of its lane");
   checks++;
  end
  $display("PASS D3 ACTUAL TOP METADATA: %0d random bundles, all1143bits driven, two count banks, live normalization, lower bbox stays y480..520",checks);$finish;
 end
endmodule
