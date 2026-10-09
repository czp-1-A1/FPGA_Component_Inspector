// Standalone positive-sync DVI-compatible colorbars. No camera/DDR or AVI.
// A:1080p30. B:720p60 comparison. Same74.25/371.25MHz PLL and PHY.
module positive_top #(parameter MODE_HD60=0,parameter ALIGN_VSYNC=0)(input wire I_sys_clk,I_rst_n,
 output wire O_tmds_ch0_p,O_tmds_ch1_p,O_tmds_ch2_p,O_tmds_clk_p);
 wire pixel,serial,locked;
 HDMI_PLL u_pll(I_sys_clk,pixel,serial,locked,!I_rst_n);
 localparam HA=MODE_HD60?1280:1920,HT=MODE_HD60?1650:2200;
 localparam HS0=MODE_HD60?1390:2008,HS1=MODE_HD60?1430:2052;
 localparam VA=MODE_HD60?720:1080,VT=MODE_HD60?750:1125;
 localparam VS0=MODE_HD60?725:1084,VS1=MODE_HD60?730:1089,BAR=MODE_HD60?160:240;
 wire release_n=I_rst_n && locked;
 reg [2:0] release_sync;
 always @(posedge pixel or negedge release_n)
  if(!release_n)release_sync<=0;else release_sync<={release_sync[1:0],1'b1};
 wire rst=!release_sync[2];
 reg [11:0] x;
 reg [10:0] y;
 always @(posedge pixel or posedge rst)
  if(rst)begin x<=0;y<=0;end
  else if(x==HT-1)begin x<=0;y<=(y==VT-1)?0:y+1'b1;end
  else x<=x+1'b1;
 wire de=x<HA && y<VA;
 wire hs=x>=HS0 && x<HS1;
 // Legacy A/B retains VS at active-coordinate x=0. The C diagnostic aligns
 // both VS edges with leading HS, measuring vertical porches in HS lines.
 // These partial active-coordinate rows belong to whole HS-defined lines.
 wire vs=ALIGN_VSYNC ?
  ((y==VS0-1) ? (x>=HS0) : (y==VS1-1) ? (x<HS0) : (y>=VS0 && y<VS1)) :
  (y>=VS0 && y<VS1);
 reg [23:0] rgb;
 always @* begin
  if(x<BAR)rgb=24'hffffff;
  else if(x<2*BAR)rgb=24'hffff00;
  else if(x<3*BAR)rgb=24'h00ffff;
  else if(x<4*BAR)rgb=24'h00ff00;
  else if(x<5*BAR)rgb=24'hff00ff;
  else if(x<6*BAR)rgb=24'hff0000;
  else if(x<7*BAR)rgb=24'h0000ff;
  else rgb=24'h000000;
 end
 wire [9:0] blue,green,red;
 dvi_encoder u_blue(pixel,rst,de,rgb[7:0],{vs,hs},blue);
 dvi_encoder u_green(pixel,rst,de,rgb[15:8],2'b00,green);
 dvi_encoder u_red(pixel,rst,de,rgb[23:16],2'b00,red);
 hdmi_phy_wrapper #(.DEVICE("PH1P")) u_phy(
  .I_pixel_clk(pixel),.I_serial_clk(serial),.I_rst(rst),
  .I_tmds_channel_0(blue),.I_tmds_channel_1(green),.I_tmds_channel_2(red),
  .I_tmds_channel_clk(10'b1111100000),
  .O_tmds_ch0_p(O_tmds_ch0_p),.O_tmds_ch1_p(O_tmds_ch1_p),
  .O_tmds_ch2_p(O_tmds_ch2_p),.O_tmds_clk_p(O_tmds_clk_p));
endmodule

// Separate fixed top modules prevent a GUI rebuild from losing mode defines.
module positive_fhd30_top(input wire I_sys_clk,I_rst_n,
 output wire O_tmds_ch0_p,O_tmds_ch1_p,O_tmds_ch2_p,O_tmds_clk_p);
 positive_top #(.MODE_HD60(0)) u_video(I_sys_clk,I_rst_n,
  O_tmds_ch0_p,O_tmds_ch1_p,O_tmds_ch2_p,O_tmds_clk_p);
endmodule
module positive_hd60_top(input wire I_sys_clk,I_rst_n,
 output wire O_tmds_ch0_p,O_tmds_ch1_p,O_tmds_ch2_p,O_tmds_clk_p);
 positive_top #(.MODE_HD60(1)) u_video(I_sys_clk,I_rst_n,
  O_tmds_ch0_p,O_tmds_ch1_p,O_tmds_ch2_p,O_tmds_clk_p);
endmodule
