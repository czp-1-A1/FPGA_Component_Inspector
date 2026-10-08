// Standalone diagnostic, not a camera/DDR image or an accepted release.
// Same native HDMI PLL ratios, encrypted core, serializer and board TMDS pins.
module hdmi_tpg_top(
 input wire I_sys_clk,I_rst_n,
 output wire O_tmds_ch0_p,O_tmds_ch1_p,O_tmds_ch2_p,O_tmds_clk_p
);
 wire pixel,serial,locked;
 HDMI_PLL u_hdmi_pll(.refclk(I_sys_clk),.reset(!I_rst_n),
  .clk0_out(pixel),.clk1_out(serial),.lock(locked));
 wire reset_n=I_rst_n && locked;
 reg [2:0] reset_sync;
 always @(posedge pixel or negedge reset_n)
  if(!reset_n)reset_sync<=0;
  else reset_sync<={reset_sync[1:0],1'b1};
 wire rst=!reset_sync[2];
 wire [9:0] blue,green,red,clock_data;
 wire video_locked;
 hdmi_1_4b_transmitter_core_wrapper #(
  .DEVICE("PH1P"),.HTOTAL(2200),.HSA(44),.HFP(88),.HBP(148),.HACTIVE(1920),
  .VTOTAL(1125),.VSA(5),.VFP(4),.VBP(36),.VACTIVE(1080),
  .VIDEO_TPG("Enable"),.VIDEO_FORMAT("RGB"),.VIDEO_VIC(34),
  .AUDIO_SAMPLE_RATE("48K"),.IIC_SCL_DIV(125)
 ) u_core(
  .I_pixel_clk(pixel),.I_rst(rst),.I_edid_read_trig(1'b0),
  .O_edid_read_valid(),.O_edid_read_data(),
  .I_axis_s_user(1'b0),.I_axis_s_valid(1'b0),.I_axis_s_last(1'b0),
  .I_axis_s_data(24'd0),.O_axis_s_ready(),
  .I_audio_valid(1'b0),.I_audio_left_data(24'd0),.I_audio_right_data(24'd0),
  .I_acr_valid(1'b0),.I_acr_cts(20'd0),.I_acr_n(20'd6144),
  .O_video_locked(video_locked),.O_ddc_scl(),.IO_ddc_sda(),
  .O_ch0_tmds_data(blue),.O_ch1_tmds_data(green),.O_ch2_tmds_data(red),.O_clk_tmds_data(clock_data)
 );
 hdmi_phy_wrapper #(.DEVICE("PH1P")) u_phy(
  .I_pixel_clk(pixel),.I_serial_clk(serial),.I_rst(rst),
  .I_tmds_channel_0(blue),.I_tmds_channel_1(green),.I_tmds_channel_2(red),.I_tmds_channel_clk(clock_data),
  .O_tmds_ch0_p(O_tmds_ch0_p),.O_tmds_ch1_p(O_tmds_ch1_p),
  .O_tmds_ch2_p(O_tmds_ch2_p),.O_tmds_clk_p(O_tmds_clk_p)
 );
endmodule
