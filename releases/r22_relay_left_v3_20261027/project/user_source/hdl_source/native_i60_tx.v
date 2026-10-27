// Same encoder/AVI/PHY as the G display candidate; coordinates arrive aligned
// with the camera/OSD pixels and sync. No secondary raster generator or audio.
module native_i60_tx #(parameter INTERLACED=1)(input wire pixel_clk,serial_clk,rst,vs,hs,de,
 input wire [23:0] rgb,input wire [11:0] x,input wire [10:0] y,
 output wire O_tmds_ch0_p,O_tmds_ch1_p,O_tmds_ch2_p,O_tmds_clk_p);
 wire [9:0] vb,vg,vr,b,g,r;
 dvi_encoder u_blue(pixel_clk,rst,de,rgb[7:0],{vs,hs},vb);
 dvi_encoder u_green(pixel_clk,rst,de,rgb[15:8],2'b00,vg);
 dvi_encoder u_red(pixel_clk,rst,de,rgb[23:16],2'b00,vr);
 wide_view_avi u_avi(pixel_clk,rst,(INTERLACED!=0),x,y,hs,vs,vb,vg,vr,b,g,r);
 // ODDR reset is sampled at the five-times-faster serial clock. Assert with
 // the pixel reset, then release through a local two-stage serial pipeline.
 // Keep pixel-to-serial data/toggle paths normally timed.
 (* async_reg="true" *) reg [1:0] phy_reset_sync;
 always @(posedge serial_clk or posedge rst)
  if(rst)phy_reset_sync<=2'b11;
  else phy_reset_sync<={phy_reset_sync[0],1'b0};
 hdmi_phy_wrapper #(.DEVICE("PH1P"),.LOCAL_ODDR_RESET(1)) u_phy(
  .I_pixel_clk(pixel_clk),.I_serial_clk(serial_clk),.I_rst(phy_reset_sync[1]),
  .I_tmds_channel_0(b),.I_tmds_channel_1(g),.I_tmds_channel_2(r),
  .I_tmds_channel_clk(10'b1111100000),
  .O_tmds_ch0_p(O_tmds_ch0_p),.O_tmds_ch1_p(O_tmds_ch1_p),
  .O_tmds_ch2_p(O_tmds_ch2_p),.O_tmds_clk_p(O_tmds_clk_p));
endmodule
