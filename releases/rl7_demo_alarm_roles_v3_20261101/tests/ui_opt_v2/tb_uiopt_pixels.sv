`timescale 1ns/1ps
module tb_uiopt_pixels;
 reg clk=0;always #5 clk=~clk;
 reg rst_n=0,vs=0,hs=0,de=0,page=0,eligible=1,latency_new=0,latency_valid=1;
 reg[23:0]rgb=0;reg[15:0]latency_ms10=414,latency_frame_lag=1;reg[39:0]latency_source_bcd=40'h0000001720;
 reg[303:0]objects=0;reg[255:0]live=0,record=0;reg[63:0]relay=0;reg[2:0]mode=1;
 wire[1:0]base_vs,base_hs,base_de,label_vs,label_hs,label_de,final_vs,final_hs,final_de;
 wire[23:0]base_rgb[0:1],label_rgb[0:1],final_rgb[0:1];
 genvar g;generate for(g=0;g<2;g=g+1)begin:variants
compact_inspector_osd_v1_ref #(.DEMO_UI(g),.FIVE_EMPTY_V7(1),.ADJACENT_V6(1),.RELAY_CLEAN_UI(1),.RELAY_KEYS_V3(1),.RELAY_LEFT_LAYOUT(1),.AUTO_RELAY(1),.RELAY_TARGET_X(152),.RELAY_ADVANCE_PX(32),.RELAY_TOL_PX(80),.BUILD_R22(1),.WIDTH(1280),.HEIGHT(720),.REPORT_NUMBER_GAPS(1)) base_dut(
 .clk(clk),.rst_n(rst_n),.vs(vs),.hs(hs),.de(de),.rgb(rgb),.page(page),
 .latency_new(latency_new),.latency_valid(latency_valid),.latency_ms10(latency_ms10),.latency_frame_lag(latency_frame_lag),.latency_source_bcd(latency_source_bcd),
 .exposure(16'd1092),.gain(16'd40),.fps(16'd27),.width(16'd1920),.height(16'd1080),
 .wb_r(8'd100),.wb_b(8'd100),.roi_mean(8'd0),.roi_min(8'd0),.roi_max(8'd0),.wb_tune(1'b0),.wb_pending(1'b0),.roi_valid(1'b1),.cfg_done(1'b1),.view_mode(2'd0),.edge_count(13'd12),
 .lane_errors(16'd0),.format_errors(16'd0),.i2c_errors(16'd0),.gaps(16'd0),.overflow_frames(16'd0),.lost_frames(16'd0),.underflow_frames(16'd0),
 .frames(32'd1720),.diagnostics(36'habcdef123),.publish_diagnostic(27'h7654321),.objects(objects),.calibration_record(128'd0),.calibration_valid(1'b0),.local_wait_reason(4'd0),
 .relay_status(relay),.relay_diagnostic(96'h1234567890abcdef12345678),.relay_control_mode(mode),.live_record(live),.frame_record(record),.eligible(eligible),
 .out_vs(base_vs[g]),.out_hs(base_hs[g]),.out_de(base_de[g]),.out_rgb(base_rgb[g]));
compact_inspector_osd_label_only #(.DEMO_UI(g),.FIVE_EMPTY_V7(1),.ADJACENT_V6(1),.RELAY_CLEAN_UI(1),.RELAY_KEYS_V3(1),.RELAY_LEFT_LAYOUT(1),.AUTO_RELAY(1),.RELAY_TARGET_X(152),.RELAY_ADVANCE_PX(32),.RELAY_TOL_PX(80),.BUILD_R22(1),.WIDTH(1280),.HEIGHT(720),.REPORT_NUMBER_GAPS(1)) label_dut(
 .clk(clk),.rst_n(rst_n),.vs(vs),.hs(hs),.de(de),.rgb(rgb),.page(page),
 .latency_new(latency_new),.latency_valid(latency_valid),.latency_ms10(latency_ms10),.latency_frame_lag(latency_frame_lag),.latency_source_bcd(latency_source_bcd),
 .exposure(16'd1092),.gain(16'd40),.fps(16'd27),.width(16'd1920),.height(16'd1080),
 .wb_r(8'd100),.wb_b(8'd100),.roi_mean(8'd0),.roi_min(8'd0),.roi_max(8'd0),.wb_tune(1'b0),.wb_pending(1'b0),.roi_valid(1'b1),.cfg_done(1'b1),.view_mode(2'd0),.edge_count(13'd12),
 .lane_errors(16'd0),.format_errors(16'd0),.i2c_errors(16'd0),.gaps(16'd0),.overflow_frames(16'd0),.lost_frames(16'd0),.underflow_frames(16'd0),
 .frames(32'd1720),.diagnostics(36'habcdef123),.publish_diagnostic(27'h7654321),.objects(objects),.calibration_record(128'd0),.calibration_valid(1'b0),.local_wait_reason(4'd0),
 .relay_status(relay),.relay_diagnostic(96'h1234567890abcdef12345678),.relay_control_mode(mode),.live_record(live),.frame_record(record),.eligible(eligible),
 .out_vs(label_vs[g]),.out_hs(label_hs[g]),.out_de(label_de[g]),.out_rgb(label_rgb[g]));
compact_inspector_osd #(.DEMO_UI(g),.FIVE_EMPTY_V7(1),.ADJACENT_V6(1),.RELAY_CLEAN_UI(1),.RELAY_KEYS_V3(1),.RELAY_LEFT_LAYOUT(1),.AUTO_RELAY(1),.RELAY_TARGET_X(152),.RELAY_ADVANCE_PX(32),.RELAY_TOL_PX(80),.BUILD_R22(1),.WIDTH(1280),.HEIGHT(720),.REPORT_NUMBER_GAPS(1)) final_dut(
 .clk(clk),.rst_n(rst_n),.vs(vs),.hs(hs),.de(de),.rgb(rgb),.page(page),
 .latency_new(latency_new),.latency_valid(latency_valid),.latency_ms10(latency_ms10),.latency_frame_lag(latency_frame_lag),.latency_source_bcd(latency_source_bcd),
 .exposure(16'd1092),.gain(16'd40),.fps(16'd27),.width(16'd1920),.height(16'd1080),
 .wb_r(8'd100),.wb_b(8'd100),.roi_mean(8'd0),.roi_min(8'd0),.roi_max(8'd0),.wb_tune(1'b0),.wb_pending(1'b0),.roi_valid(1'b1),.cfg_done(1'b1),.view_mode(2'd0),.edge_count(13'd12),
 .lane_errors(16'd0),.format_errors(16'd0),.i2c_errors(16'd0),.gaps(16'd0),.overflow_frames(16'd0),.lost_frames(16'd0),.underflow_frames(16'd0),
 .frames(32'd1720),.diagnostics(36'habcdef123),.publish_diagnostic(27'h7654321),.objects(objects),.calibration_record(128'd0),.calibration_valid(1'b0),.local_wait_reason(4'd0),
 .relay_status(relay),.relay_diagnostic(96'h1234567890abcdef12345678),.relay_control_mode(mode),.live_record(live),.frame_record(record),.eligible(eligible),
 .out_vs(final_vs[g]),.out_hs(final_hs[g]),.out_de(final_de[g]),.out_rgb(final_rgb[g]));
end endgenerate
 integer scene=0,which_page=0,xx,yy,i,pixels=0,comparisons=0;
 always @(posedge clk)begin #1;if(rst_n)begin
  for(integer k=0;k<2;k=k+1)begin
   if({base_vs[k],base_hs[k],base_de[k],base_rgb[k]}!=={label_vs[k],label_hs[k],label_de[k],label_rgb[k]})
    $fatal(1,"label-sharing mismatch scene%0d page%0d demo%0d xy%0d/%0d",scene,page,k,xx,yy);
   if({base_vs[k],base_hs[k],base_de[k],base_rgb[k]}!=={final_vs[k],final_hs[k],final_de[k],final_rgb[k]})
    $fatal(1,"shared-font mismatch scene%0d page%0d demo%0d xy%0d/%0d base%h new%h",scene,page,k,xx,yy,base_rgb[k],final_rgb[k]);
   if(base_de[k])comparisons=comparisons+2;
  end
  if(base_de[0])pixels=pixels+1;
 end end
 function[75:0]obj(input[1:0]kind,input[3:0]why,input[10:0]x0,x1,input[9:0]y0,y1);
  obj={1'b1,kind,why,13'd180,7'd32,7'd28,x0,x1,y0,y1};
 endfunction
 task ticks(input integer n);repeat(n)@(negedge clk);endtask
 task setup_scene;begin
  objects=0;live=0;record=0;relay=0;eligible=1;mode=1;latency_valid=1;
  latency_ms10=414+scene;latency_frame_lag=scene;latency_source_bcd=40'h0000001720+scene;
  live[47:32]=7;record[47:32]=7;live[50:48]=2;record[50:48]=2;
  live[66:58]=13;live[75:67]=11;live[84:76]=2;live[93:85]=3;live[210:202]=13;
  record[57]=scene[0];relay[31:29]=1;relay[0]=1;
  for(i=0;i<4;i=i+1)record[94+i*9+:9]=10+i;
  objects[75:0]=obj(2,0,200,240,250,290);objects[151:76]=obj(3,0,550,562,280,292);
  objects[227:152]=obj(2,3,650,690,310,350);objects[303:228]=obj(1,1,900,940,400,440);
  case(scene)
   0:objects=0;
   2:begin
    objects[75:0]=obj(2,0,300,340,300,340);objects[151:76]=obj(3,0,300,340,300,340);
    objects[227:152]=obj(2,7,300,340,300,340);objects[303:228]=obj(1,1,300,340,300,340);
   end
   3:begin
    objects[75:0]=obj(2,0,1250,1270,95,115);objects[151:76]=obj(3,0,1240,1260,580,620);
    objects[227:152]=obj(2,5,0,30,80,100);objects[303:228]=obj(1,1,5,25,580,623);
   end
   4:for(i=0;i<4;i=i+1)record[94+i*9+:9]=0;
   5:begin for(i=0;i<4;i=i+1)record[94+i*9+:9]=511-i;latency_ms10=65535;latency_frame_lag=65535;latency_source_bcd=40'h4294967295;end
   6:begin eligible=0;record[47:32]=8;latency_valid=0;end
   7:begin relay[31:29]=4;relay[28:25]=15;mode=2;end
  endcase
 end endtask
 task picture;begin
  vs=1;de=0;ticks(5);vs=0;ticks(20);
  for(yy=0;yy<720;yy=yy+1)begin
   de=1;hs=0;
   for(xx=0;xx<1280;xx=xx+1)begin
    rgb={xx[7:0],yy[7:0],(xx[7:0]^yy[7:0])};
    latency_new=(yy==0 && xx==40);
    if(yy==120 && xx==300)begin live[66:58]=99;record[47:32]=9;end
    ticks(1);
   end
   de=0;latency_new=0;hs=1;ticks(12+scene%3);hs=0;ticks(12);
  end
  ticks(12);
 end endtask
 initial begin
  ticks(5);rst_n=1;ticks(5);
  for(scene=0;scene<8;scene=scene+1)begin
   for(which_page=0;which_page<2;which_page=which_page+1)begin page=which_page;setup_scene;picture;end
   $display("UIOPT_SCENE %0d two pages compared",scene);
  end
  if(pixels!=14745600 || comparisons!=58982400)$fatal(1,"coverage mismatch pixels%0d pairs%0d",pixels,comparisons);
  $display("PASS UIOPT_PIXELS: 16 complete720p rasters14745600pixels;58982400 label-only/final vs immutableV1 pair comparisons across legacy/demo modes;four labels,overlap,edge/IDs/missing/invalid/alarm;exactRGB/DE/HS/VS");$finish;
 end
 initial begin #400000000;$fatal(1,"pixel equivalence timeout");end
endmodule
