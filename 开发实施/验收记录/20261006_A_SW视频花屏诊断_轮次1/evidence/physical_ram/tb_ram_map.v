`timescale 1ns/1ps
module tb_ram_map;
reg clk=0;
always #4.444 clk=~clk;
reg [3:0] bank_enable=0;
reg [7:0] write_address=0,read_address=0;
reg [95:0] rgb=0;
wire [95:0] row_q [0:3];
mapped_rgb_ram dut(clk,bank_enable,write_address,read_address,rgb,row_q);
reg [95:0] reference [0:3][0:255];
integer checks=0,errors=0,b,a,iteration,j;
reg [95:0] expected [0:3];
reg [7:0] sampled_address;
reg check_enabled=0;
reg [31:0] seed=32'h58494c4c;
function [31:0] random32;
 input dummy;
 begin seed=(seed ^ (seed << 13));seed=(seed ^ (seed >> 17));seed=(seed ^ (seed << 5));random32=seed;end
endfunction
always @(posedge clk) begin
 sampled_address=read_address;
 for(j=0;j<4;j=j+1) expected[j]=reference[j][read_address];
 for(j=0;j<4;j=j+1) if(bank_enable[j]) reference[j][write_address]=rgb;
 #1;
 if(check_enabled) for(j=0;j<4;j=j+1) begin
  if(!(bank_enable[j] && write_address==sampled_address)) begin
   checks=checks+1;
   if(row_q[j] !== expected[j]) begin
    errors=errors+1;
    if(errors<=12) $display("FAIL cycle=%0t bank=%0d address=%0d got=%024h expected=%024h",$time,j,sampled_address,row_q[j],expected[j]);
   end
  end
 end
end
initial begin
 // Global GSR releases at 5 us in the installed vendor model.
 #10000;
 for(b=0;b<4;b=b+1) for(a=0;a<256;a=a+1) begin
  @(negedge clk); bank_enable=(1<<b);write_address=a;
  rgb={random32(0),random32(0),random32(0)};read_address=0;
 end
 @(negedge clk);bank_enable=0;check_enabled=1;
 // Every bank/address, consecutive synchronous reads.
 for(a=0;a<256;a=a+1) begin @(negedge clk);read_address=a;end
 // Random read addresses, clock bubbles in write enable, all four write banks.
 for(iteration=0;iteration<8192;iteration=iteration+1) begin
  @(negedge clk);read_address=random32(0);write_address=random32(0);
  bank_enable=(iteration%5==0) ? 0 : (1<<(iteration%4));
  rgb={random32(0),random32(0),random32(0)};
 end
 @(negedge clk);bank_enable=0;
 // Repeated reads and disabled-bank contents after random overwrites.
 for(a=255;a>=0;a=a-1) begin @(negedge clk);read_address=a;end
 @(negedge clk);check_enabled=0;
 if(errors) $fatal(1,"RAM mapping mismatch errors=%0d checks=%0d",errors,checks);
 $display("PASS mapped physical RGB RAM: 12 exact ERAM instances, four 256x96 banks, %0d comparisons, 1-cycle synchronous read; read/write same-bank same-address excluded",checks);
 $finish;
end
initial begin #1000000;$fatal(1,"timeout");end
endmodule
