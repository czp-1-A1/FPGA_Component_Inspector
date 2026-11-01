`timescale 1ns/1ps
module tb_d3_essential_fields;
 reg clk=0,rst_n=0,vs=0,hs=0,de=0;
 always #5 clk=~clk;
 reg [127:0] relay_status=0;reg [2:0] relay_mode=0;reg relay_motor=0;
 reg [511:0] live=0,packet=0;reg [303:0] objects=0;
 wire ov,oh,od;wire [23:0] pixel;
 reg [2:0] vp=0,hp=0,dp=0;
 integer fd,xx,yy,frame_no=0,pixels=0;
 compact_inspector_osd #(.ESSENTIAL_UI(1),.AUTO_RELAY(1),.DUAL_REGION_COUNT(1),.PRESENT_TRACE(1),.BUILD_R22(1),.EMPTY_TRACE(1),.BUILD_R20(1),.REPORT_NUMBER_GAPS(0)) dut(
  .relay_status(relay_status),.relay_mode(relay_mode),.relay_motor(relay_motor),
  .clk(clk),.rst_n(rst_n),.vs(vs),.hs(hs),.de(de),.rgb(24'h556677),.page(1'b1),
  .exposure(16'd1092),.gain(16'd40),.fps(16'd27),.width(16'd1920),.height(16'd1080),
  .wb_r(8'd100),.wb_b(8'd100),.roi_mean(8'd149),.roi_min(8'd124),.roi_max(8'd176),
  .wb_tune(1'b0),.wb_pending(1'b0),.roi_valid(1'b1),.cfg_done(1'b1),.view_mode(2'd3),.edge_count(13'd0),
  .lane_errors(16'd0),.format_errors(16'd0),.i2c_errors(16'd0),.gaps(16'd0),
  .overflow_frames(16'd0),.lost_frames(16'd0),.underflow_frames(16'd0),.frames(32'd17),
  .diagnostics(36'd0),.publish_diagnostic(27'd0),.objects(objects),.calibration_record(128'd0),
  .calibration_valid(1'b0),.local_wait_reason(4'd0),.live_record(live),.frame_record(packet),.eligible(1'b1),
  .out_vs(ov),.out_hs(oh),.out_de(od),.out_rgb(pixel));
 function [75:0] object_at(input integer cx,cy,kind,mask);
  begin object_at={1'b1,2'(kind),4'(mask),13'd956,7'd32,7'd32,11'(cx),11'(cx+31),10'(cy),10'(cy+31)};end
 endfunction
 task text_at(input integer row,cell_no,input string value);
  begin
   for(integer i=0;i<value.len();i++)if(dut.plane[row*128+cell_no+i][7:0]!==value[i])
    $fatal(1,"text row%0d col%0d got%h expected%h",row,cell_no+i,dut.plane[row*128+cell_no+i][7:0],value[i]);
  end
 endtask

 task snapshot;
  begin
   de=0;vs=1;repeat(4)@(negedge clk);vs=0;repeat(5)@(negedge clk);
   de=1;repeat(32)@(negedge clk);de=0;
   repeat(2200)@(negedge clk);
   if(!dut.ready)$fatal(1,"essential prepare never ready");
  end
 endtask
 initial begin
  repeat(10)@(negedge clk);rst_n=1;
  live[66:58]=300;live[75:67]=298;live[84:76]=2;live[93:85]=0;live[210:202]=300;live[222:217]=63;
  live[322:314]=511;live[331:323]=510;live[340:332]=1;live[349:341]=0;live[466:458]=511;live[478:473]=62;
  live[130+:9]=299;live[139+:9]=300;live[386+:9]=300;live[395+:9]=511;
  live[50:48]=2;live[306:304]=2;live[47:32]=7;live[303:288]=7;
  packet=live;packet[223]=1;packet[479]=1;packet[94+:9]=511;packet[103+:9]=300;packet[368+:9]=256;packet[377+:9]=1;
  for(integer scene=0;scene<5;scene++)begin
   relay_status=0;relay_mode=0;relay_motor=0;
   case(scene)
    1:relay_mode=2;
    2:begin relay_mode=1;relay_motor=1;end
    3:relay_status[28:25]=4;
    4:relay_status[92:89]=15;
   endcase
   snapshot();
   text_at(1,9,"300");text_at(1,23,"298");text_at(1,37,"002");text_at(1,54,"000");text_at(1,66,"300");
   text_at(2,9,"511");text_at(2,23,"510");text_at(2,37,"001");text_at(2,54,"000");text_at(2,66,"511");
   text_at(3,18,"064");text_at(4,18,"063");text_at(3,26,"299  300");text_at(4,26,"300  511");
   if(dut.label_bcd0!==20'h00511 || dut.label_bcd1!==20'h00300 || dut.label_bcd2!==20'h00256 || dut.label_bcd3!==20'h00001)$fatal(1,"full-width label decimal");
   case(scene)
    0:text_at(6,0,"READY K1 START  ");
    1:text_at(6,0,"PAUSED K2 RESUME");
    2:text_at(6,0,"MOTOR RUNNING   ");
    3:text_at(6,0,"ALARM K3 CLEAR  ");
    4:text_at(6,0,"ALARM FIVE EMPTY");
   endcase
   live[210:202]=12;live[466:458]=13;relay_status=~relay_status;
   repeat(50)@(negedge clk);text_at(1,66,"300");text_at(2,66,"511");
   live[210:202]=300;live[466:458]=511;
  end
  rst_n=0;repeat(3)@(negedge clk);if(dut.ready || ov || oh || od || pixel!==0)$fatal(1,"reset-visible state");
  $display("PASS ESSENTIAL fields: 5 snapshot epochs, nonzero LAST, full IDs256/300/511, pages63/64, both lanes, ready/pause/motor/fault/five-empty, midframe immutable text, reset");$finish;
 end
 initial begin #200000;$fatal(1,"essential fields watchdog");end
endmodule
