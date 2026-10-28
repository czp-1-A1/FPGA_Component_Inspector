`timescale 1ns/1ps
// Newly widened display packet crosses asynchronous processing/display clocks.
// Every observed 163-bit word must be one complete, previously offered word.
module tb_v6_display_mailbox;
 reg sc=0,dc=0,rst=0;always #5 sc=~sc;always #17 dc=~dc;
 reg [162:0] offered=0;wire [162:0] received;
 reg [162:0] words[0:256];integer n,j,found,last=0,observed=0;
 status_cdc #(.WIDTH(163)) dut(sc,dc,rst,offered,received);
 always @(negedge dc)if(rst && received!=0)begin
  found=0;
  for(integer k=1;k<=256;k++)if(received===words[k])found=k;
  if(found==0 || found<last)$fatal(1,"torn or reordered mode/diagnostic/status packet");
  if(found!=last)observed++;
  last=found;
 end
 initial begin
  words[0]=0;words[1]={3'b101,32'hfedcba98,32'h76543210,32'h13579bdf,32'h2468ace0,32'ha55ac33c};
  for(n=2;n<=256;n++)begin
   words[n]=words[n-1];
   for(j=0;j<167;j++)words[n]={words[n][161:0],words[n][162]^words[n][80]^words[n][46]^words[n][2]};
  end
  repeat(5)@(negedge sc);rst=1;
  for(n=1;n<=256;n++)begin offered=words[n];repeat(n%5+1)@(negedge sc);end
  repeat(100)@(negedge dc);
  if(received!==words[256] || observed<20)$fatal(1,"mailbox not exercised through final packet");
  $display("PASS V6 DISPLAY MAILBOX: 256 asynchronous 163-bit offers, %0d coherent monotonic delivered words, final mode/diagnostic/status packet exact",observed);$finish;
 end
endmodule
