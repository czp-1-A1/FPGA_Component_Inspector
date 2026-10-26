`timescale 1ns/1ps
module tb_simple_recovery_ui;
reg clk=0,rst_n=0,vs=0,hs=0,de=0,page_switch=1,eligible=1;
always #5 clk=~clk;
reg [255:0] live=0,packet=0;reg [303:0] objects=0;reg [127:0] cal=0;
wire nv,nh,nd;wire [23:0] nrgb;
integer f=0,fd,px=0,n=0,xx,yy;reg [2:0] vp=0,hp=0,dp=0;
classified_dual_page_osd #(.REPORT_NUMBER_GAPS(0),.COMPACT_UI(1),.CLASSIFIED_COUNT(1),.RESULT_RECORDER(1),.LOCAL_RECOVERY(1),.MULTITHRESHOLD_EMPTY(1),.WIDTH(1280),.HEIGHT(720),.DIAG_BITS(27),.RESOLUTION_V11(1),.REGIONS(1),.CALIBRATION(1),.LOCAL_SEARCH(1),.SHAPE_MODEL(1),.DIRECT_DETECTION(1),.FRAME_OBJECTS(1)) dut(
.clk(clk),
.rst_n(rst_n),
.vs(vs),
.hs(hs),
.de(de),
.rgb(24'h556677),
.exposure(16'd1092),
.gain(16'd40),
.wb_r(8'd100),
.wb_b(8'd100),
.wb_tune(1'b0),
.wb_pending(1'b0),
.view_mode(2'd3),
.edge_count(13'd0),
.edge_sum(24'd0),
.local_box_valid(1'b1),
.local_x0(11'd550),
.local_x1(11'd720),
.local_y0(10'd290),
.local_y1(10'd350),
.roi_valid(1'b1),
.roi_mean(8'd149),
.roi_min(8'd124),
.roi_max(8'd176),
.roi_state(2'd2),
.width(16'd1920),
.height(16'd1080),
.fps(16'd27),
.lane_errors(16'd0),
.format_errors(16'd0),
.i2c_errors(16'd0),
.gaps(16'd0),
.frames(32'd17),
.uptime(32'd42),
.cfg_done(1'b1),
.overflow_frames(16'd0),
.lost_frames(16'd0),
.underflow_frames(16'd0),
.diagnostics(36'd0),
.publish_diagnostic(27'd0),
.pocket_records(340'd0),
.pocket_enable(1'b0),
.track_valid(1'b0),
.track_x0(11'd0),
.track_x1(11'd0),
.track_reason(4'd0),
.track_rows(3'd0),
.frame_objects(objects),
.calibration_record(cal),
.calibration_valid(1'b1),
.local_wait_reason(4'd0),
.out_vs(nv),
.out_hs(nh),
.out_de(nd),
.out_rgb(nrgb),
.count_page_switch(page_switch),
.count_live_record(live),
.count_frame_record(packet),
.count_eligible(eligible));

always @(posedge clk)begin
 vp<={vp[1:0],vs};hp<={hp[1:0],hs};dp<={dp[1:0],de};
 #1;
 if(rst_n)begin
  if({nv,nh,nd}!=={vp[2],hp[2],dp[2]})$fatal(1,"three-clock video/control alignment");
  if(nd)begin
   $fwrite(fd,"%06x\n",nrgb);px=px+1;
   if(^nrgb===1'bx)$fatal(1,"unknown output pixel");
  end
 end
end
task tick;input integer count;integer i;begin for(i=0;i<count;i=i+1)@(negedge clk);end endtask
function [75:0] object;
 input [1:0] kind;input [3:0] reason;input [10:0] x0,x1;input [9:0] y0,y1;
 begin object={1'b1,kind,reason,13'd956,7'd32,7'd32,x0,x1,y0,y1};end
endfunction
task picture;
 input integer index;reg [255:0] saved;reg [303:0] saved_objects;
 begin
  f=index;px=0;
  case(index)
   0:fd=$fopen("compact_0.hex","w");1:fd=$fopen("compact_1.hex","w");
   2:fd=$fopen("compact_2.hex","w");default:fd=$fopen("compact_3.hex","w");
  endcase
  vs=1;tick(4);vs=0;tick(10);
  saved=live;saved_objects=objects;
  for(yy=0;yy<720;yy=yy+1)begin
   hs=1;tick(2);hs=0;de=1;
   for(xx=0;xx<1280;xx=xx+1)tick(1);
   de=0;tick(10);
   if(yy==300)begin live=~saved;objects=~saved_objects;end
  end
  tick(8);live=saved;objects=saved_objects;
  if(px!=921600)$fatal(1,"pixel count %d",px);
  $fclose(fd);
 end
endtask
initial begin
 tick(10);rst_n=1;tick(8);
 live[47:32]=7;live[50:48]=2;live[55]=1;live[56]=1;
 live[66:58]=27;live[75:67]=20;live[84:76]=7;live[93:85]=2;live[239:224]=65535;
 live[210:202]=27;live[212:211]=3;live[255:240]=16'h4021;
 live[130+:9]=1;live[139+:9]=9;live[148+:9]=13;live[157+:9]=14;
 live[166+:9]=15;live[175+:9]=20;live[184+:9]=24;
 packet=live;packet[31:0]=32'h89abcdef;packet[94+:9]=8;packet[103+:9]=9;
 objects[75:0]=object(2,0,550,581,300,331);
 objects[151:76]=object(3,0,650,659,310,319);
 objects[227:152]=object(2,1,550,581,470,501);
 objects[303:228]=object(1,2,690,711,480,497);
 cal[63:0]={1'b1,1'b1,2'd3,8'd148,8'd124,8'd176,9'd0,13'd956,7'd32,7'd32};
 cal[127:64]=cal[63:0];
 picture(0);
 page_switch=0;tick(742520);
 live[112+:9]=9;packet[112+:9]=9;packet[31:0]=32'h12345678;
 picture(1);
 live=0;eligible=0;picture(2);
 live[47:32]=8;live[50:48]=2;eligible=1;picture(3);
 $display("PASS simple_recovery_ui: four full HD rasters, metadata frozen midframe, page switch, clear and generation guard; independent pixel reference pending");
 $finish;
end
initial begin #200000000;$fatal(1,"timeout");end
endmodule
