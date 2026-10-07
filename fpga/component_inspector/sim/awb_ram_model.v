`timescale 1ns/1ps
// Simulation only. The selected IP has 96x2048 dual-port RAM, REGMODE_B=NOREG.
// Model one synchronous read edge and read-before-write; no memory reset.
// This does not verify the vendor's encrypted ERAM implementation or timing.
module blk_mem_gen_awb_delay_signal(
    input clka, input wea, input [10:0] addra, input [95:0] dia,
    input clkb, input [10:0] addrb, output reg [95:0] dob,
    input web, input [95:0] dib);
// The DUT explicitly disables B-port writes; these match its unused IP inputs.
reg [95:0] memory[0:2047];
always @(posedge clka) if(wea) memory[addra] <= dia;
always @(posedge clkb) dob <= memory[addrb];
endmodule
