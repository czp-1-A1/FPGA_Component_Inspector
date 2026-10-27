`timescale 1ns/1ps
module tb_simple_record_view;
reg [255:0] raw;wire [255:0] plain,legacy;reg [255:0] expected;reg [31:0] rng=32'h159357ab;
count_record_view #(.REPORT_NUMBER_GAPS(0)) a(raw,plain);
count_record_view #(.REPORT_NUMBER_GAPS(1)) b(raw,legacy);
integer i,j;
initial begin
 for(i=0;i<4096;i++)begin
  for(j=0;j<8;j++)begin rng=rng*32'd1664525+32'd1013904223;raw[j*32+:32]=rng;end
  raw[57]=i[0];expected=raw;
  if(i[0])expected[111:94]=0;else expected[129:112]=0;
  #1;if(plain!==expected || legacy!==raw)$fatal(1,"unexpected event/active-ID/metadata field changed");
 end
 $display("PASS simple_record_view:4096 records both ROI selections, all256 bits checked, legacy passthrough exact");$finish;
end
endmodule
