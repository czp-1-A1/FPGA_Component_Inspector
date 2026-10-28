`timescale 1ns/1ps
module tb_relay_clean_osd;
 reg clk=0;always #5 clk=~clk;
 reg rst_n=0,vs=0,hs=0,de=0;wire out_vs,out_hs,out_de;wire [23:0] out_rgb;
 function [75:0] shape(input [10:0] left_x,right_x,input [1:0] kind);
  shape={1'b1,kind,4'd0,13'd64,7'd8,7'd8,left_x,right_x,10'd312,10'd328};
 endfunction
 reg [63:0] relay_status={6'd18,1'b1,9'd27,16'd4321,3'd3,4'd9,4'd2,9'd27,11'd160,1'b0};
 compact_inspector_osd #(.RELAY_CLEAN_UI(1),.EMPTY_TRACE(1),.RELAY_KEYS_V3(1),.RELAY_LEFT_LAYOUT(1),.RELAY_TARGET_X(160),.RELAY_ADVANCE_PX(32),.RELAY_TOL_PX(80),.AUTO_RELAY(1),.BUILD_R22(1),.WIDTH(1280),.HEIGHT(720)) dut(
 .clk(clk),.rst_n(rst_n),.vs(vs),.hs(hs),.de(de),.rgb(24'h556677),.page(1'b0),
 .exposure(16'd1092),.gain(16'd40),.fps(16'd27),.width(16'd1920),.height(16'd1080),
 .wb_r(8'd100),.wb_b(8'd100),.roi_mean(8'd0),.roi_min(8'd0),.roi_max(8'd0),
 .wb_tune(1'b0),.wb_pending(1'b0),.roi_valid(1'b0),.cfg_done(1'b1),.view_mode(2'd0),.edge_count(13'd0),
 .lane_errors(16'd0),.format_errors(16'd0),.i2c_errors(16'd0),.gaps(16'd0),
 .overflow_frames(16'd0),.lost_frames(16'd0),.underflow_frames(16'd0),.frames(32'd17),
 .diagnostics(36'd0),.publish_diagnostic(27'd0),.objects({152'd0,shape(11'd500,11'd520,2'd2),shape(11'd110,11'd118,2'd3)}),.calibration_record({1'b1,11'd400,10'd300,42'd0,1'b1,11'd300,10'd300,42'd0}),
 .calibration_valid(1'b1),.local_wait_reason(4'd0),.relay_status(relay_status),
 .live_record(256'd0),.frame_record(256'd0),.eligible(1'b1),
 .out_vs(out_vs),.out_hs(out_hs),.out_de(out_de),.out_rgb(out_rgb));
 reg [2:0] amber_delay=0;
 always @(posedge clk)begin
  amber_delay<={amber_delay[1:0],rst_n && de && dut.repair_border};#1;
  if(out_de && amber_delay[2] && out_rgb!==24'hffd060)$fatal(1,"wide border output color or pipeline changed");
 end
 reg [2:0] vp=0,hp=0,dp=0;integer xx,yy,frame=0,checks=0,chars=0,pixels=0,fd;
 reg [375:0] expected="RL5 S3 F9 Q12 N01B X0A0 L01B V1 T0A0 A020 W10E1";
 // The literal reference deliberately uses human-readable hex values.
 always @(posedge clk)begin
  vp<={vp[1:0],vs};hp<={hp[1:0],hs};dp<={dp[1:0],de};#1;
  if(rst_n)begin
   if({out_vs,out_hs,out_de}!=={vp[2],hp[2],dp[2]})$fatal(1,"video alignment changed");
   if(out_de)begin
    if(^out_rgb===1'bx)$fatal(1,"unknown active RGB");
    if(frame==0)$fwrite(fd,"%06x\n",out_rgb);
    pixels++;
   end
   if(de && dut.y==56 && dut.x>=712 && dut.x<1088 && dut.x[2:0]==0)begin
    if(dut.code!==expected[375-((dut.x-712)/8)*8-:8])$fatal(1,"relay text mismatch x%0d code%h",dut.x,dut.code);
    chars++;
   end
   if(de && dut.y==300 && (dut.x==64 || dut.x==447 || dut.x==160 || dut.x==192 || dut.x==256 || dut.x==640 || dut.x==300 || dut.x==400) && dut.guide)$fatal(1,"hidden auxiliary line/cross still visible x%0d",dut.x);
   if(de && dut.y==300 && (dut.x==448 || dut.x==831) && !dut.guide)$fatal(1,"count ROI side missing");
   if(de && dut.y==240 && dut.x>=448 && dut.x<832 && dut.x[3] && !dut.guide)$fatal(1,"count ROI top missing");
   if(de && dut.y>120 && frame==0 && dut.relay_snapshot!=={6'd18,1'b1,9'd27,16'd4321,3'd3,4'd9,4'd2,9'd27,11'd160,1'b0})$fatal(1,"midframe status tore");
   if(de && dut.y==300 && (dut.x==80 || dut.x==240) && !dut.repair_border)$fatal(1,"wide amber edge missing");
   if(de && dut.y==320 && (dut.x==110 || dut.x==118 || dut.x==500 || dut.x==520) && !dut.guide)$fatal(1,"live result box hidden");
   checks++;
  end
 end
 task ticks(input integer n);repeat(n)@(negedge clk);endtask
 task picture;
  begin
   vs=1;ticks(5);vs=0;ticks(20);
   for(yy=0;yy<720;yy++)begin
    de=1;hs=0;
    for(xx=0;xx<1280;xx++)begin
     if(frame==0 && yy==120 && xx==300)relay_status=0;
     ticks(1);
    end
    de=0;hs=1;ticks(12);hs=0;ticks(12);
   end
   ticks(20);
  end
 endtask
 initial begin
  fd=$fopen("relay_clean_osd.hex","w");ticks(5);rst_n=1;ticks(5);picture();$fclose(fd);
  frame=1;expected="RL5 S0 F0 Q00 N000 X--- L000 V0 T0A0 A020 W0000";picture();
  if(chars!=94 || pixels!=1843200)$fatal(1,"incomplete rasters chars%0d pixels%0d",chars,pixels);
  $display("PASS CLEAN OSD: two complete rasters, 94 literal status characters, exact 3-clock stream, frame-held status, count ROI + amber window; auxiliary lines/crosses hidden");$finish;
 end
 initial begin #30000000;$fatal(1,"OSD timeout");end
endmodule
