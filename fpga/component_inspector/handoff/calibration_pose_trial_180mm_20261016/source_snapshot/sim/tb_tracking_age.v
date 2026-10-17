`timescale 1ns/1ps
module tb_tracking_age;
reg clk=0,rst=0,valid=0;reg [1:0] slot=0;wire fresh;
always #5 clk=~clk;
tracking_frame_age #(.LIMIT(8)) dut(clk,rst,valid,slot,fresh);
initial begin
 repeat(3) @(negedge clk);rst=1;valid=1;
 repeat(3) @(negedge clk);if(!fresh) $fatal(1,"new image not live");
 repeat(8) @(negedge clk);if(fresh) $fatal(1,"stalled camera retained live classification");
 slot=2;@(negedge clk);if(!fresh) $fatal(1,"new complete slot did not revive");
 valid=0;@(negedge clk);if(fresh) $fatal(1,"invalid image is fresh");
 valid=1;@(negedge clk);if(!fresh) $fatal(1,"valid slot recovery failed");
 $display("PASS tracking age: new slot, repeated-frame timeout, invalidation and recovery");$finish;
end
endmodule
