`timescale 1fs/1fs
// Test environment only. Never included in the diagnostic TD project.
// The actual vendor PLL is verified separately; this model isolates the
// full-frame encrypted HDMI/ODDR raster from analog/VCO simulation cost.
module HDMI_PLL(input refclk,output reg clk0_out,clk1_out,output lock,input reset);
 initial begin clk0_out=0;clk1_out=0;end
 // Integer femtosecond ticks guarantee exactly 5:1. Independently rounding
 // the nominal fractional periods causes a 2 fs difference per half-pixel
 // and a serializer boundary slip at ~9 ms. Frequency error here is 1 ppm.
 localparam integer SERIAL_HALF_FS=1346800;
 always #(5*SERIAL_HALF_FS) clk0_out=~clk0_out;
 always #SERIAL_HALF_FS clk1_out=~clk1_out;
 assign lock=!reset;
endmodule
