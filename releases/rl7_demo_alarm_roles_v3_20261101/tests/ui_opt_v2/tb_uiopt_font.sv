`timescale 1ns/1ps
module tb_uiopt_font;
 reg clk=0;always #5 clk=~clk;
 reg[10:0]aa=0;reg[7:0]ca=0;reg cm=0;
 wire[7:0]a0,a1;wire[23:0]c0,c1;
 compact_ascii_rom ar(clk,aa,a0);compact_cjk_rom cr(clk,ca,c0);
 rl7_shared_font_rom packed_font(clk,aa,ca,cm,a1,c1);
 integer i,n=0;reg[31:0]rng=32'h20261101;
 task check(input[10:0]a,input[7:0]c,input m);begin
  @(negedge clk);aa=a;ca=c;cm=m;@(posedge clk);#1;
  if((!cm && a0!==a1)||(cm && c0!==c1))$fatal(1,"font mismatch mode%b ascii%h cjk%h old%h/%h new%h/%h",cm,aa,ca,a0,c0,a1,c1);
  n=n+1;
 end endtask
 initial begin
  for(i=0;i<2048;i=i+1)check(i,i,0);
  for(i=0;i<256;i=i+1)check(i,i,1);
  for(i=0;i<65536;i=i+1)begin
   rng={rng[30:0],rng[31]^rng[21]^rng[1]^rng[0]};check(rng[10:0],rng[23:16],rng[29]);
  end
  $display("PASS UIOPT_FONT: %0d synchronous selections; all2048 ASCII/all256 CJK addresses, full95 printable ASCII and7 Chinese glyphs,65536 interleaved reads, original byte/row/latency exact",n);$finish;
 end
endmodule
