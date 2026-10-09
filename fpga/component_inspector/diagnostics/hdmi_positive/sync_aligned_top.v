// C: one change from A, VS leading/trailing edges aligned with leading HS.
// Same active raster, clock/PLL, colors, DVI encoding, PHY, and board pins.
// No AVI/audio, camera or DDR; no physical acceptance implied.
module sync_aligned_fhd30_top(input wire I_sys_clk,I_rst_n,
 output wire O_tmds_ch0_p,O_tmds_ch1_p,O_tmds_ch2_p,O_tmds_clk_p);
 positive_top #(.MODE_HD60(0),.ALIGN_VSYNC(1)) u_video(I_sys_clk,I_rst_n,
  O_tmds_ch0_p,O_tmds_ch1_p,O_tmds_ch2_p,O_tmds_clk_p);
endmodule
