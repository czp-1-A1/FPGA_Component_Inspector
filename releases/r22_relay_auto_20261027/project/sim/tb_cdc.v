`timescale 1ns/1ps
module tb_cdc;
reg s=0,d=0,rst=0,s_run=1,d_run=1;
always #5 if(s_run) s=~s;
always #7 if(d_run) d=~d;
reg [15:0] seq_value=1;
wire [31:0] sample;
status_cdc dut(s,d,rst,{seq_value,~seq_value},sample);
always @(posedge s) if(rst) seq_value<=seq_value+1'b1;
integer captures=0;
always @(negedge d) if(rst && sample!=0) begin
 if(sample[15:0]!=~sample[31:16]) $fatal(1,"torn mailbox payload %h",sample);
 captures=captures+1;
end
reg [31:0] held;
initial begin
 #22;rst=1;#3000;
 s_run=0;#100;held=sample;#500;if(sample!=held) $fatal(1,"paused source changed settled output");
 s_run=1;#1000;d_run=0;#500;d_run=1;#3000;
 if(captures<50) $fatal(1,"too few transfers");
 rst=0;#30;if(sample!=0) $fatal(1,"mailbox reset");rst=1;#500;
 $display("PASS CDC: asynchronous changing payload, atomic pairs, stopped clocks, reset");$finish;
end
endmodule

