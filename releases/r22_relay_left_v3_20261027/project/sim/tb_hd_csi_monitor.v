`timescale 1ns/1ps
// Exercise the production CSI and RAW10 decoder at the actual native dimensions.
module tb_hd_csi_monitor;
tb_csi_monitor #(.WIDTH(1920),.HEIGHT(1080)) native_hd();
initial begin #30000000;$fatal(1,"HD CSI monitor timeout");end
endmodule
