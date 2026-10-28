`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Create Date:    01:32:02 06/12/2023 
// Module Name:    SC500GainTbl 
//////////////////////////////////////////////////////////////////////////////////
module SC500GainTbl(
	input 			I_clk,
	input 			I_rstn,
	input 	[6:0] 	I,
	output reg	[15:0] 	O
);

    // Preserve the original one-clock lookup and all 74 codes. In the full
    // auto-relay design TD 6.2 folded the constant-address synchronous ROM
    // to 0000 (GAIN40 must produce 0338). Decode the three ranges directly
    // so no ROM inference/constant-ROM folding is needed. I_rstn remains
    // unused, as in the original lookup; camera startup waits 128 clocks.
    always @(posedge I_clk) begin
        if (I < 7'd32)
            O <= {8'h03, 3'b001, I[4:0]};
        else if (I < 7'd64)
            O <= {8'h07, 3'b001, I[4:0]};
        else if (I < 7'd74)
            O <= {8'h0f, 3'b001, I[4:0]};
        else
            O <= 16'h0000;
    end

endmodule
