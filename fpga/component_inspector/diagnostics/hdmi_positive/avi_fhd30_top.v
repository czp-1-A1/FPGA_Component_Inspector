// D: C raster/sync/clocks/PHY, adding HDMI preambles/guards and AVI VIC34.
// Standalone video format comparison; no camera, DDR, audio or classification.
module avi_fhd30_top(input wire I_sys_clk,I_rst_n,
 output wire O_tmds_ch0_p,O_tmds_ch1_p,O_tmds_ch2_p,O_tmds_clk_p);
 wire pixel,serial,locked;
 HDMI_PLL u_pll(I_sys_clk,pixel,serial,locked,!I_rst_n);
 wire release_n=I_rst_n && locked;
 reg [2:0] release_sync;
 always @(posedge pixel or negedge release_n)
  if(!release_n)release_sync<=0;else release_sync<={release_sync[1:0],1'b1};
 wire rst=!release_sync[2];
 reg [11:0] x;reg [10:0] y;
 always @(posedge pixel or posedge rst)
  if(rst)begin x<=0;y<=0;end
  else if(x==12'd2199)begin x<=0;y<=(y==11'd1124)?0:y+1'b1;end
  else x<=x+1'b1;
 wire de=x<12'd1920 && y<11'd1080;
 wire hs=x>=12'd2008 && x<12'd2052;
 wire vs=(y==11'd1083)?(x>=12'd2008):(y==11'd1088)?(x<12'd2008):(y>=11'd1084 && y<11'd1089);
 reg [23:0] rgb;
 always @* begin
  if(x<12'd240)rgb=24'hffffff;
  else if(x<12'd480)rgb=24'hffff00;
  else if(x<12'd720)rgb=24'h00ffff;
  else if(x<12'd960)rgb=24'h00ff00;
  else if(x<12'd1200)rgb=24'hff00ff;
  else if(x<12'd1440)rgb=24'hff0000;
  else if(x<12'd1680)rgb=24'h0000ff;
  else rgb=24'h000000;
 end
 wire [9:0] video_b,video_g,video_r,blue,green,red;
 dvi_encoder u_blue(pixel,rst,de,rgb[7:0],{vs,hs},video_b);
 dvi_encoder u_green(pixel,rst,de,rgb[15:8],2'b00,video_g);
 dvi_encoder u_red(pixel,rst,de,rgb[23:16],2'b00,video_r);
 hdmi_avi_insert u_packet(pixel,rst,x,y,hs,vs,video_b,video_g,video_r,blue,green,red);
 hdmi_phy_wrapper #(.DEVICE("PH1P")) u_phy(
  .I_pixel_clk(pixel),.I_serial_clk(serial),.I_rst(rst),
  .I_tmds_channel_0(blue),.I_tmds_channel_1(green),.I_tmds_channel_2(red),
  .I_tmds_channel_clk(10'b1111100000),
  .O_tmds_ch0_p(O_tmds_ch0_p),.O_tmds_ch1_p(O_tmds_ch1_p),
  .O_tmds_ch2_p(O_tmds_ch2_p),.O_tmds_clk_p(O_tmds_clk_p));
endmodule
