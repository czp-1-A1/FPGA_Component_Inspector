// F: E raster/PLL/PHY plus old-style independent 50MHz measurement.
// SW1 down720p60/up1080p30. No camera/DDR; no Flash operation.
module clock_probe_top #(parameter WINDOW_CYCLES=50000000)(input wire I_sys_clk,I_rst_n,I_mode_select,
 output wire O_tmds_ch0_p,O_tmds_ch1_p,O_tmds_ch2_p,O_tmds_clk_p);
 wire pixel,serial,locked;
 HDMI_PLL u_pll(I_sys_clk,pixel,serial,locked,!I_rst_n);
 wire release_n=I_rst_n && locked;
 reg [2:0] release_sync;
 always @(posedge pixel or negedge release_n)
  if(!release_n)release_sync<=0;else release_sync<={release_sync[1:0],1'b1};
 wire rst=!release_sync[2];
 (* async_reg="true" *) reg mode_s0,mode_s1;
 reg candidate,mode_request;
 reg [20:0] stable_cycles;
 always @(posedge pixel or posedge rst)
  if(rst)begin mode_s0<=0;mode_s1<=0;candidate<=0;mode_request<=0;stable_cycles<=0;end
  else begin
   mode_s0<=I_mode_select;mode_s1<=mode_s0;
   if(mode_s1!=candidate)begin candidate<=mode_s1;stable_cycles<=0;end
   else if(stable_cycles<21'd1484999)stable_cycles<=stable_cycles+1'b1;
   else mode_request<=candidate;
  end
 reg frame_mode;
 reg [11:0] x;reg [10:0] y;
 wire [11:0] ha=frame_mode?12'd1920:12'd1280,ht=frame_mode?12'd2200:12'd1650;
 wire [11:0] hs0=frame_mode?12'd2008:12'd1390,hs1=frame_mode?12'd2052:12'd1430;
 wire [10:0] va=frame_mode?11'd1080:11'd720,vt=frame_mode?11'd1125:11'd750;
 wire [11:0] bar=frame_mode?12'd240:12'd160;
 always @(posedge pixel or posedge rst)
  if(rst)begin x<=0;y<=0;frame_mode<=0;end
  else if(x==ht-1'b1)begin
   x<=0;
   if(y==vt-1'b1)begin y<=0;frame_mode<=mode_request;end
   else y<=y+1'b1;
  end else x<=x+1'b1;
 wire de=x<ha && y<va;
 wire hs=x>=hs0 && x<hs1;
 wire vs=frame_mode?
  ((y==11'd1083)?(x>=12'd2008):(y==11'd1088)?(x<12'd2008):(y>=11'd1084 && y<11'd1089)):
  (y>=11'd725 && y<11'd730);
 reg [23:0] rgb;
 always @* begin
  if(x<bar)rgb=24'hffffff;
  else if(x<2*bar)rgb=24'hffff00;
  else if(x<3*bar)rgb=24'h00ffff;
  else if(x<4*bar)rgb=24'h00ff00;
  else if(x<5*bar)rgb=24'hff00ff;
  else if(x<6*bar)rgb=24'hff0000;
  else if(x<7*bar)rgb=24'h0000ff;
  else rgb=24'h000000;
 end
 // Continuous event counters survive raster mode changes. Clear on PLL loss.
 wire line_end=x==ht-1'b1;
 wire frame_end=line_end && y==vt-1'b1;
 wire [31:0] p_gray,h_gray,v_gray;
 clock_probe_counter u_count(pixel,rst,line_end,frame_end,p_gray,h_gray,v_gray);
 wire [193:0] sys_snapshot,pixel_snapshot;
 clock_probe_measure #(.WINDOW_CYCLES(WINDOW_CYCLES)) u_measure(
  I_sys_clk,I_rst_n,locked,frame_mode,p_gray,h_gray,v_gray,sys_snapshot);
 // Shared global assertion; a stopped pixel clock cannot deadlock source counting.
 status_cdc #(.WIDTH(194)) u_status(I_sys_clk,pixel,I_rst_n,sys_snapshot,pixel_snapshot);
 reg [193:0] frame_snapshot;
 always @(posedge pixel or posedge rst)
  if(rst)frame_snapshot<=0;else if(frame_end)frame_snapshot<=pixel_snapshot;
 wire [23:0] display_rgb;wire display_de,display_hs,display_vs;
 clock_probe_osd u_osd(pixel,rst,x,y,rgb,de,hs,vs,frame_snapshot,
  display_rgb,display_de,display_hs,display_vs);
 wire [9:0] blue,green,red;
 dvi_encoder u_blue(pixel,rst,display_de,display_rgb[7:0],{display_vs,display_hs},blue);
 dvi_encoder u_green(pixel,rst,display_de,display_rgb[15:8],2'b00,green);
 dvi_encoder u_red(pixel,rst,display_de,display_rgb[23:16],2'b00,red);
 hdmi_phy_wrapper #(.DEVICE("PH1P")) u_phy(
  .I_pixel_clk(pixel),.I_serial_clk(serial),.I_rst(rst),
  .I_tmds_channel_0(blue),.I_tmds_channel_1(green),.I_tmds_channel_2(red),
  .I_tmds_channel_clk(10'b1111100000),
  .O_tmds_ch0_p(O_tmds_ch0_p),.O_tmds_ch1_p(O_tmds_ch1_p),
  .O_tmds_ch2_p(O_tmds_ch2_p),.O_tmds_clk_p(O_tmds_clk_p));
endmodule
