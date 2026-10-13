`timescale 1ns/1ps
module tb_pack_boundary;
reg clk=0, rst=1, valid=0, sof=0;
reg [95:0] data=0;
wire out_valid, out_sof;
wire [127:0] out_data;
always #5 clk=~clk;
data_96bit_to_128bit dut(clk,rst,sof,valid,data,out_sof,out_valid,out_data);
reg [383:0] collected=0;
integer outputs=0;
localparam [95:0] W0=96'h00112233445566778899aabb;
localparam [95:0] W1=96'h102132435465768798a9bacb;
localparam [95:0] W2=96'h2031425364758697a8b9cadb;
localparam [95:0] W3=96'h30415263748596a7b8c9daeb;
always @(posedge clk) begin
    #1;
    if(out_valid) begin collected={collected[255:0],out_data}; outputs=outputs+1; end
end
task send; input [95:0] word_value;
begin data=word_value; valid=1; @(negedge clk); end endtask
initial begin
    repeat(3) @(negedge clk);
    send(W0); send(W1);
    rst=0; send(W2);
    if(!out_valid) $fatal(1,"existing packer is expected to ignore reset during valid data");
    rst=1; sof=1; send(W3); sof=0;
    if(!out_sof || !out_valid || outputs!=3 || collected!=={W0,W1,W2,W3})
        $fatal(1,"frame-start pulse unexpectedly reset the pack phase or changed byte stream");
    $display("OBS packer: reset and frame_start during continuous valid do not restart packing");
    valid=0; @(negedge clk); outputs=0; collected=0;
    send(W0); send(W1); valid=0; @(negedge clk);
    if(outputs!=1 || out_valid) $fatal(1,"partial group characterization mismatch");
    $display("OBS packer: two input beats emit one 128-bit word; remaining 64 bits are discarded by valid gap");
    outputs=0; collected=0;
    send(W0); send(W1); send(W2); send(W3); valid=0; @(negedge clk);
    if(outputs!=3 || collected!=={W0,W1,W2,W3}) $fatal(1,"complete group after gap did not restart");
    $display("PASS pack boundary characterization: valid gap restarts phase; reset/SOF are not phase guards");
    $finish;
end
initial begin #1000; $fatal(1,"packing watchdog"); end
endmodule
