`timescale 1ns/1ps
module tb_demo_osd;
reg clk=0;always #5 clk=~clk;
reg rst_n=0,vs=0,hs=0,de=0,latency_new=0,latency_valid=1;
reg [15:0] latency_ms10=414,latency_frame_lag=1;
reg [39:0] latency_source_bcd=40'h0000001720;
reg [255:0] live=0;reg [63:0] relay=0;reg [2:0] mode=1;
wire out_vs,out_hs,out_de;wire [23:0] out_rgb;
compact_inspector_osd #(.DEMO_UI(1),.FIVE_EMPTY_V7(1),.ADJACENT_V6(1),.RELAY_CLEAN_UI(1),.RELAY_KEYS_V3(1),.RELAY_LEFT_LAYOUT(1),.AUTO_RELAY(1),.RELAY_TARGET_X(152),.RELAY_ADVANCE_PX(32),.RELAY_TOL_PX(80),.BUILD_R22(1),.WIDTH(1280),.HEIGHT(720),.REPORT_NUMBER_GAPS(0)) dut(
 .clk(clk),.rst_n(rst_n),.vs(vs),.hs(hs),.de(de),.rgb(24'h556677),.page(1'b1),
 .latency_new(latency_new),.latency_valid(latency_valid),.latency_ms10(latency_ms10),
 .latency_frame_lag(latency_frame_lag),.latency_source_bcd(latency_source_bcd),
 .exposure(16'd1092),.gain(16'd40),.fps(16'd27),.width(16'd1920),.height(16'd1080),
 .wb_r(8'd100),.wb_b(8'd100),.roi_mean(8'd0),.roi_min(8'd0),.roi_max(8'd0),
 .wb_tune(1'b0),.wb_pending(1'b0),.roi_valid(1'b0),.cfg_done(1'b1),.view_mode(2'd0),.edge_count(13'd0),
 .lane_errors(16'd0),.format_errors(16'd0),.i2c_errors(16'd0),.gaps(16'd0),
 .overflow_frames(16'd0),.lost_frames(16'd0),.underflow_frames(16'd0),.frames(32'd1720),
 .diagnostics(36'hfffff),.publish_diagnostic(27'h7ffffff),.objects(304'd0),.calibration_record(128'd0),
 .calibration_valid(1'b0),.local_wait_reason(4'hf),.relay_status(relay),.relay_diagnostic(96'hffffffffffffffffffffffff),.relay_control_mode(mode),
 .live_record(live),.frame_record(live),.eligible(1'b1),.out_vs(out_vs),.out_hs(out_hs),.out_de(out_de),.out_rgb(out_rgb));
integer frame=0,xx,yy,fd,pixels=0,chars=0,yellow=0,red=0,blank=0;
reg [2:0] vp=0,hp=0,dp=0;
reg [127:0] title="INSPECT RL7 DEMO";
reg [135:0] lat="LATENCY 0041.4 ms";
reg [231:0] lag_text="FRAME LAG 001  SRC 0000001720";
reg [295:0] alarm_text="ALARM 5 EMPTY - MOTOR STOP - K3 CLEAR";
reg [23:0] total_text="012",normal_text="008",two_text="002";
integer ci;
always @(posedge clk)begin
 vp<={vp[1:0],vs};hp<={hp[1:0],hs};dp<={dp[1:0],de};#1;
 if(rst_n)begin
  if(out_vs!==vp[2] || out_hs!==hp[2] || out_de!==dp[2])$fatal(1,"three-clock RGB/control timing changed");
  if(out_de)begin pixels++;if(frame==0)$fwrite(fd,"%06h\n",out_rgb);end
  if(out_de && out_rgb==24'hffd060)yellow++;
  if(out_de && out_rgb==24'hff5050)red++;
  if(de && dut.ready && dut.x>=136 && dut.x<1160 && dut.x[2:0]==0)begin
   ci=(dut.x-136)/8;
   if(dut.y==8 && ci<16)begin
    if(dut.code!==title[127-ci*8-:8])$fatal(1,"demo title mismatch index%0d code%h",ci,dut.code);chars++;
   end
   if(dut.y==8 && ci>=78 && ci<95)begin
    if(dut.code!==lat[135-(ci-78)*8-:8])$fatal(1,"latency text mismatch index%0d code%h",ci,dut.code);chars++;
   end
   if(dut.y==32 && ci>=78 && ci<107)begin
    if(dut.code!==lag_text[231-(ci-78)*8-:8])$fatal(1,"frame binding text mismatch index%0d code%h",ci,dut.code);chars++;
   end
   if(dut.y==32 && frame==0)begin
    if(ci>=6 && ci<9 && dut.code!==total_text[23-(ci-6)*8-:8])$fatal(1,"total changed");
    if(ci>=24 && ci<27 && dut.code!==normal_text[23-(ci-24)*8-:8])$fatal(1,"normal count is not PRESENT minus REVIEW");
    if(ci>=42 && ci<45 && dut.code!==two_text[23-(ci-42)*8-:8])$fatal(1,"empty count changed");
    if(ci>=63 && ci<66 && dut.code!==two_text[23-(ci-63)*8-:8])$fatal(1,"review count changed");
   end
   if(dut.y==56 && frame==1 && ci<37)begin
    if(dut.code!==alarm_text[295-ci*8-:8] || dut.ink!==24'hff5050)$fatal(1,"red alarm lost");chars++;
   end
   if((dut.y==656 || dut.y==704) && frame==0)begin
    if(dut.y==656 && dut.code!=32)$fatal(1,"debug row not blank");blank++;
   end
  end
 end
end
task ticks(input integer n);repeat(n)@(negedge clk);endtask
task picture;
 begin
  vs=1;ticks(5);vs=0;ticks(20);
  for(yy=0;yy<720;yy++)begin
   de=1;hs=0;
   for(xx=0;xx<1280;xx++)begin
    if(yy==0 && xx==40)latency_new=1;
    if(yy==0 && xx==41)latency_new=0;
    if(frame==0 && yy==120 && xx==300)begin
     relay={6'd5,1'b0,9'd5,16'd0,3'd4,4'd15,4'd5,9'd2,11'd0,1'b0};mode=2;
     latency_ms10=999;latency_source_bcd=40'h9999999999;latency_new=1;
    end
    if(yy==120 && xx==301)latency_new=0;
    ticks(1);
   end
   de=0;hs=1;ticks(12);hs=0;ticks(12);
  end
  ticks(20);
 end
endtask
initial begin
 fd=$fopen("demo_rgb.hex","w");
 live[66:58]=12;live[75:67]=10;live[84:76]=2;live[93:85]=2;live[210:202]=12;live[50:48]=2;
 relay[31:29]=1;relay[0]=1;
 ticks(5);rst_n=1;ticks(5);picture();$fclose(fd);
 frame=1;latency_ms10=527;latency_frame_lag=2;latency_source_bcd=40'h0000001721;
 lat="LATENCY 0052.7 ms";lag_text="FRAME LAG 002  SRC 0000001721";picture();
 if(pixels!=1843200 || chars!=161 || yellow<100 || red<40 || blank<100)$fatal(1,"incomplete demo proof pixels%0d chars%0d yellow%0d red%0d blank%0d",pixels,chars,yellow,red,blank);
 $display("PASS DEMO OSD: two complete720p rasters, current-frame measured latency/source, disjoint display counts, red5-empty alarm, frozen snapshots, debug hidden, unchanged3-clock stream");$finish;
end
initial begin #30000000;$fatal(1,"OSD timeout");end
endmodule
