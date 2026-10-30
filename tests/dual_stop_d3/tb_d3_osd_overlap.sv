`timescale 1ns/1ps
module tb_d3_osd_overlap;
 reg clk=0,rst_n=0,vs=0,hs=0,de=0;
 always #5 clk=~clk;
 reg page=0,eligible=1;reg [127:0] relay_status=0;reg [2:0] relay_mode=2;reg relay_motor=0;
 reg [511:0] live=0,packet=0;reg [303:0] objects=0;
 wire ov,oh,od;wire [23:0] pixel;
 reg [2:0] vp=0,hp=0,dp=0;
 integer fd,xx,yy,frame_no=0,pixels=0;
 compact_inspector_osd #(.AUTO_RELAY(1),.DUAL_REGION_COUNT(1),.PRESENT_TRACE(1),.BUILD_R22(1),.EMPTY_TRACE(1),.BUILD_R20(1),.REPORT_NUMBER_GAPS(0)) dut(
  .relay_status(relay_status),.relay_mode(relay_mode),.relay_motor(relay_motor),
  .clk(clk),.rst_n(rst_n),.vs(vs),.hs(hs),.de(de),.rgb(24'h556677),.page(page),
  .exposure(16'd1092),.gain(16'd40),.fps(16'd27),.width(16'd1920),.height(16'd1080),
  .wb_r(8'd100),.wb_b(8'd100),.roi_mean(8'd149),.roi_min(8'd124),.roi_max(8'd176),
  .wb_tune(1'b0),.wb_pending(1'b0),.roi_valid(1'b1),.cfg_done(1'b1),.view_mode(2'd3),.edge_count(13'd0),
  .lane_errors(16'd0),.format_errors(16'd0),.i2c_errors(16'd0),.gaps(16'd0),
  .overflow_frames(16'd0),.lost_frames(16'd0),.underflow_frames(16'd0),.frames(32'd17),
  .diagnostics(36'd0),.publish_diagnostic(27'd0),.objects(objects),.calibration_record(128'd0),
  .calibration_valid(1'b0),.local_wait_reason(4'd0),.live_record(live),.frame_record(packet),.eligible(eligible),
  .out_vs(ov),.out_hs(oh),.out_de(od),.out_rgb(pixel));
 wire rv,rh,rd;wire [23:0] ref_pixel;
 always @(posedge clk)begin
  #2;if(rst_n && ({ov,oh,od}!=={rv,rh,rd} || od && pixel!==ref_pixel))
   $fatal(1,"OSD previous-renderer pixel mismatch x%0d y%0d new%h ref%h",dut.x,dut.y,pixel,ref_pixel);
 end
 r11_reference_compact_inspector_osd #(.AUTO_RELAY(1),.DUAL_REGION_COUNT(1),.PRESENT_TRACE(1),.BUILD_R22(1),.EMPTY_TRACE(1),.BUILD_R20(1),.REPORT_NUMBER_GAPS(0)) baseline(
  .relay_status(relay_status),.relay_mode(relay_mode),.relay_motor(relay_motor),
  .clk(clk),.rst_n(rst_n),.vs(vs),.hs(hs),.de(de),.rgb(24'h556677),.page(page),
  .exposure(16'd1092),.gain(16'd40),.fps(16'd27),.width(16'd1920),.height(16'd1080),
  .wb_r(8'd100),.wb_b(8'd100),.roi_mean(8'd149),.roi_min(8'd124),.roi_max(8'd176),
  .wb_tune(1'b0),.wb_pending(1'b0),.roi_valid(1'b1),.cfg_done(1'b1),.view_mode(2'd3),.edge_count(13'd0),
  .lane_errors(16'd0),.format_errors(16'd0),.i2c_errors(16'd0),.gaps(16'd0),
  .overflow_frames(16'd0),.lost_frames(16'd0),.underflow_frames(16'd0),.frames(32'd17),
  .diagnostics(36'd0),.publish_diagnostic(27'd0),.objects(objects),.calibration_record(128'd0),
  .calibration_valid(1'b0),.local_wait_reason(4'd0),.live_record(live),.frame_record(packet),.eligible(eligible),
  .out_vs(rv),.out_hs(rh),.out_de(rd),.out_rgb(ref_pixel));
 function [75:0] object_at(input integer cx,cy,kind,mask);
  begin object_at={1'b1,2'(kind),4'(mask),13'd956,7'd32,7'd32,11'(cx),11'(cx+31),10'(cy),10'(cy+31)};end
 endfunction

 integer scene,seed=32'h41acd25f,compared=0;
 always @(posedge clk)begin #3;if(rst_n && od)compared++;end
 initial begin
  repeat(10)@(negedge clk);rst_n=1;
  for(scene=0;scene<8;scene++)begin
   page=scene[0];eligible=scene!=6;
   for(integer k=0;k<16;k++)begin live[k*32+:32]=$random(seed);packet[k*32+:32]=$random(seed);end
   for(integer b=0;b<2;b++)begin
    live[b*256+47-:16]=7;packet[b*256+47-:16]=7+(scene==7 && b==1);
    live[b*256+50-:3]=2;packet[b*256+50-:3]=2;packet[b*256+223]=1;
    packet[b*256+57]=scene[1];live[b*256+57]=scene[1];
   end
   case(scene/2)
    0:begin
     objects[75:0]=object_at(550,300,2,0);objects[151:76]=object_at(554,240,3,0);
     objects[227:152]=object_at(558,310,2,1);objects[303:228]=object_at(560,250,1,15);
    end
    1:begin
     objects[75:0]=object_at(1240,100,2,0);objects[151:76]=object_at(1200,590,3,0);
     objects[227:152]=object_at(1230,96,2,1);objects[303:228]=object_at(1220,620,1,7);
    end
    2:begin
     objects[75:0]=object_at(6,106,3,0);objects[151:76]=object_at(20,80,1,5);
     objects[227:152]=object_at(50,108,2,0);objects[303:228]=object_at(35,92,2,1);
     objects[151]=0;
    end
    3:begin
     objects[75:0]=object_at(800,432,2,0);objects[151:76]=object_at(820,472,3,0);
     objects[227:152]=object_at(808,435,1,7);objects[303:228]=object_at(824,476,2,1);
    end
   endcase
   vs=1;repeat(4)@(negedge clk);vs=0;repeat(10)@(negedge clk);
   for(yy=0;yy<720;yy++)begin
    hs=1;repeat(2)@(negedge clk);hs=0;de=1;
    for(xx=0;xx<1280;xx++)@(negedge clk);
    de=0;repeat(10)@(negedge clk);
    if(yy==350)begin live=~live;packet=~packet;objects=~objects;relay_status=~relay_status;end
   end
   repeat(8)@(negedge clk);
  end
  if(compared!=8*1280*720)$fatal(1,"incomplete raster oracle");
  $display("PASS shared OSD exact previous-renderer equivalence: 8 complete rasters %0d pixels, both pages, overlap last-slot priority, all P/E/review/unknown classes, clamp and top/bottom boundaries, invalid slots, generation/eligibility guards and atomic mid-frame changes",compared);$finish;
 end
 initial begin #100000000;$fatal(1,"OSD oracle watchdog");end
endmodule
