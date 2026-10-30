`timescale 1ns/1ps
module tb_d3_shared_font;
 reg clk=0;always #5 clk=~clk;
 reg cjk=0;reg [10:0] a=0;reg [7:0] c=0;reg [4:0] col=0;
 wire p;wire [7:0] ascii;wire [23:0] chinese;
 compact_shared_font_rom dut(clk,cjk,a,c,col,p);
 compact_ascii_rom original_ascii(clk,a,ascii);
 compact_cjk_rom original_chinese(clk,c,chinese);
 integer checks=0;
 initial begin
  for(integer k=0;k<2;k++)for(integer i=0;i<(k ? 256 : 2048);i++)for(integer j=0;j<32;j++)begin
   @(negedge clk);cjk=k;a=i;c=i;col=j;
   @(posedge clk);#1;
   if(p!==(k ? j<24 && chinese[23-j] : j<8 && ascii[7-j]))
    $fatal(1,"font differs type%0d address%0d column%0d new%b ascii%h cjk%h",k,i,j,p,ascii,chinese);
   checks++;
  end
  if(checks!=73728)$fatal(1,"font coverage");
  $display("PASS shared immutable font: all 73728 type/address/column combinations, all ASCII and CJK glyphs and every zero padding/border, exact original read clock");$finish;
 end
endmodule
