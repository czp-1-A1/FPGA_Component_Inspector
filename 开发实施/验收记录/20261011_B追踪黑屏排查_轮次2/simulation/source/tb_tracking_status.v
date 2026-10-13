`timescale 1ns/1ps
module tb_tracking_status;
reg [7:0] gates=0;reg cw=0;reg [3:0] hr=2;
wire valid;wire [3:0] reason;
tracking_display_status dut(gates[7],gates[6],gates[5],gates[4],gates[3],gates[2],gates[1],gates[0],cw,hr,valid,reason);
integer n,h,c,expected;
initial begin
 for(n=0;n<256;n=n+1) for(h=0;h<8;h=h+1) for(c=0;c<2;c=c+1) begin
  gates=n;hr=h;cw=c;#1;
  expected=!gates[7] || !gates[6] ? 8 : !gates[5] ? 9 : !gates[4] ? 10 : !gates[3] ? 11 :
   !gates[2] ? 12 : !gates[1] ? (h==0 ? 5 : h) : !gates[0] ? 13 : c ? 14 : 0;
  if(reason!==expected || valid!==(&gates)) $fatal(1,"display gates=%h reason=%0d expected=%0d",gates,reason,expected);
 end
 $display("PASS tracking status: all 4096 gate/reason/class combinations, valid and invalid priorities");$finish;
end
endmodule
