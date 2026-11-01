`timescale 1ns/1ps
module tb_pack_boundary;
reg clk=0,rst=0,valid=0,sof=0;
reg [95:0] data=0;
wire ov,os;wire [127:0] packed_word;
always #5 clk=~clk;
data_96bit_to_128bit dut(clk,rst,sof,valid,data,os,ov,packed_word);
localparam [95:0] W0=96'h00112233445566778899aabb,W1=96'h102132435465768798a9bacb,
 W2=96'h2031425364758697a8b9cadb,W3=96'h30415263748596a7b8c9daeb;
reg [383:0] collected=0;integer outputs=0;
always @(posedge clk) begin #1;if(ov) begin collected={collected[255:0],packed_word};outputs=outputs+1;end end
task send;input [95:0] v;begin data=v;valid=1;@(negedge clk);end endtask
task idle;begin valid=0;repeat(3) @(negedge clk);end endtask
initial begin
 repeat(3) @(negedge clk);rst=1;
 send(W0);idle;send(W1);idle;send(W2);idle;send(W3);idle;
 if(outputs!=3 || collected!=={W0,W1,W2,W3}) $fatal(1,"valid gap lost partial word");
 outputs=0;collected=0;send(W0);idle;
 sof=1;valid=1;data=W3;@(negedge clk);sof=0;valid=0;
 if(!os || ov || dut.S_cnt!=0) $fatal(1,"FS did not discard old partial phase");
 send(W0);send(W1);send(W2);send(W3);idle;
 if(outputs!=3 || collected!=={W0,W1,W2,W3}) $fatal(1,"clean FS byte order");
 outputs=0;send(W0);rst=0;send(W1);idle;
 if(ov || dut.S_cnt!=0) $fatal(1,"reset retained partial phase");
 rst=1;collected=0;send(W0);send(W1);send(W2);send(W3);idle;
 if(outputs!=3 || collected!=={W0,W1,W2,W3}) $fatal(1,"reset recovery byte order");
 $display("PASS pack boundary characterization: valid gaps preserve bytes; reset and early FS discard partial groups");$finish;
end
initial begin #2000;$fatal(1,"packer watchdog");end
endmodule
