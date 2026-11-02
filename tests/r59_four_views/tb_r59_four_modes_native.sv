`timescale 1ns/1ps
// Real RAW10, vendor demosaic/WB RAM, continuous processing and native proof.
// No forced internal producer signals and no synthetic frame_commit.
module tb_r59_four_modes_native;
 reg clk=0,run_clk=1;always #4.444 if(run_clk)clk=~clk;
 reg procclk=0;always #5 procclk=~procclk;
 reg rst=0,fs=0,fe=0,hs=0,rv=0;reg [39:0] raw=0;
 wire av,asof,alast,cav,casof,calast;wire [39:0] adata,cadata;
 reg packet_open=0;
 always @(posedge clk or negedge rst)
  if(!rst)packet_open<=0;else if(fs)packet_open<=1;else if(fe)packet_open<=0;
 uial2axis #(.IMG_WIDTH(1920),.IMG_HEIGHT(1080),.INPUT_DATA_WIDTH(40)) bridge(clk,rst,raw,rv && packet_open && !fe,fs,fe,av,adata,asof,alast);
 image_correction correction(.I_clk(clk),.I_rst_n(rst),.I_raw_data(adata),.I_raw_valid(av),.I_raw_frame_start(asof),.I_raw_frame_end(alast),
  .O_raw_tdata(cadata),.O_raw_tlast(calast),.O_raw_tvalid(cav),.O_raw_tuser(casof),.O_raw_tready(1'b1));
 wire [31:0] us_gray,capture_us,latest_source;wire capture_valid;wire [64:0] capture_info;
 wire [127:0] vdata;wire vlast,writer_ready;
 wire complete;wire [1:0] completed_slot;wire [64:0] completed_capture;wire [1142:0] completed_metadata;
 integer source=0;reg [31:0] expected_us[0:5];
 contest_latency_clock timer(procclk,rst,us_gray);
 contest_latency_capture capture_clock(clk,rst,us_gray,capture_us,capture_valid);
 always @(posedge clk)if(rst && fs)begin
  if(!capture_valid)$fatal(1,"decoded RAW SOF did not follow enough resumed receive clocks");
  expected_us[source]=capture_us;
 end
 reg [16:0] command=0;reg [17:0] observation=0;
 wire [511:0] live;wire [1142:0] metadata;wire mready,good,bad,vv,vs;
 wire [1:0] events;
 isp_top #(.RAW_EDGE_ONLY(0),.MEASURE_LATENCY(1),.AUTO_RELAY(1),.DUAL_REGION_COUNT(1),.PRESENT_TRACE(1),.LOCAL_EDGE_ASSIST(1),.EMPTY_TRACE(1),.ROBUST_EMPTY_CONTEXT(1),.ROBUST_SMALL_EMPTY(1),.STANDING_REVIEW(1),.SURFACE_REVIEW(1),.LOCAL_RECOVERY(1),.MULTITHRESHOLD_EMPTY(1),.CLASSIFIED_COUNT(1),.RESULT_RECORDER(1),.INPUT_WIDTH(1920),.INPUT_HEIGHT(1080),.WIDTH(1280),.HEIGHT(720),.SCALE_DISPLAY(1),.ROI_X0(600),.ROI_X1(680),.ROI_Y0(320),.ROI_Y1(400),.ASYNC_PROCESSING(1),.DIRECT_DETECTION(1),.SHAPE_MODEL(1),.LOCAL_SEARCH(1),.REGIONS(1),.CALIBRATION(1)) dut(
  .capture_time_us(capture_us),.capture_time_valid(capture_valid),.capture_info(capture_info),.latest_source_frame(latest_source),
  .relay_permit(1'b0),.relay_pause(1'b0),.actual_motor_running(1'b1),.count_command(command),.count_live(live),.count_event_valid(events),.processing_clk(procclk),.axi4s_video_aclk(clk),.I_rst_n(rst),
  .I_tlast(calast),.I_tuser(casof),.I_tdata(cadata),.I_tvalid(cav),.I_tdest(10'd0),.O_tready(1'b1),.view_ready(writer_ready),
  .O_tdata(vdata),.O_tlast(vlast),.O_tvalid(vv),.O_tuser(vs),.video_frame_good(good),.video_frame_bad(bad),
  .raw_start(fs),.raw_end(fe),.hs_valid(hs),.raw_valid(rv),.config_ok(1'b1),.lane_error(2'd0),
  .calibration_ok(1'b1),.present_high(1'b1),.threshold(8'd58),.observation_request(observation),.wb_request(32'h00006464),.image_config(32'h04440028),
  .frame_metadata(metadata),.frame_metadata_ready(mready));
 video_in #(.MEASURE_LATENCY(1),.WIDTH(1280),.HEIGHT(720),.METADATA(1),.META_WIDTH(1143),.METADATA_REQUIRED(0),.VIDEO_FIRST(1)) writer(
  .I_rst_n(rst),.I_camera_clk(procclk),.I_camera_frame_start(vs),.I_camera_valid(vv),.I_camera_data(vdata),.I_mipi_rx_error(1'b0),
  .I_frame_good(good),.I_frame_bad(bad),.O_camera_ready(writer_ready),.I_ddr_clk(procclk),.I_display_pause(1'b0),.I_video_out_rd_busy(1'b0),
  .I_active_valid(1'b0),.I_active_rp(2'd0),.O_completed_valid(complete),.O_completed_rp(completed_slot),.I_ddr_user_ready(1'b1),
  .I_frame_metadata(metadata),.I_frame_metadata_ready(mready),.O_completed_metadata(completed_metadata),
  .I_capture_info(capture_info),.O_completed_capture(completed_capture));
 integer scene=0;
 integer row,b,l,proofs=0,samples=0,accepts=0,pixels=0;
 real detector_time=0,proof_time=0,accept_time=0;
 always @(posedge procclk)if(rst)begin
  if(vv)pixels=pixels+1;
  if(dut.post_commit)begin proofs++;proof_time=$realtime;$display("DENSE_NATIVE_PROOF source=%0d ns=%0f",source,$realtime);end
  if(dut.search_new)begin samples++;detector_time=$realtime;$display("DENSE_NATIVE_DETECT source=%0d ns=%0f state=%0d",source,$realtime,dut.search_state);end
  if(dut.classified_counting.dual_regions.pipeline.regions[0].pipeline.accept)begin
   accepts++;accept_time=$realtime;$display("DENSE_NATIVE_ACCEPT source=%0d ns=%0f",source,$realtime);
  end
  if(events!=0)$fatal(1,"static dense RAW generated event");
 end
 function integer scene_raw(input integer xx,yy);
  integer px,py,lane,k,cx,cy,dx,dy;
  begin
   px=(xx*2)/3;py=(yy*2)/3;scene_raw=80;
   for(lane=0;lane<2;lane++)if(scene==1 || lane==0)begin
    cy=lane==0 ? 320 : 516;
    for(k=0;k<18;k++)begin
     cx=k<10 ? 430+k*46 : 90+(k-10)*44;dx=px-cx;dy=py-cy;
     if(dx>=-18 && dx<18 && dy>=-22 && dy<22 && !((dx< -14 || dx>=14)&&(dy< -14 || dy>=14)))scene_raw=720;
     if(dx*dx+(dy+36)*(dy+36)<=49)scene_raw=720;
    end
   end
  end
 endfunction
 task ticks(input integer n);repeat(n)@(negedge clk);endtask
 task frame(input integer raw_value,frame_end_delay);
  real start_time;
  begin
   source++;proofs=0;samples=0;accepts=0;pixels=0;
   @(negedge clk);start_time=$realtime;fs=1;ticks(1);fs=0;ticks(48);
   for(row=0;row<1080;row++)begin
    hs=1;ticks(3);
    for(b=0;b<480;b++)begin
     rv=1;for(l=0;l<4;l++)raw[l*10+:10]=10'(scene_raw(b*4+l,row));ticks(1);rv=0;ticks(b%4==3 ? 3 : 1);
    end
    hs=0;ticks(98);
    if(row!=1079)begin run_clk=0;#21550.0;run_clk=1;end
   end
   ticks(frame_end_delay);fe=1;ticks(1);fe=0;ticks(200);run_clk=0;
   if($realtime<start_time+37035000)#(start_time+37035000-$realtime);
   if(proofs!=1 || samples!=1 || accepts!=1 || !mready || !good || bad || pixels!=172800)
    $fatal(1,"dense native deadline failed source=%0d proof=%0d result=%0d accepted=%0d meta=%b good=%b bad=%b pixels=%0d",source,proofs,samples,accepts,mready,good,bad,pixels);
   if($realtime-accept_time>2000000)$fatal(1,"accept timestamp did not belong to current frame");
   if(!dut.region_search_objects[75] || (scene==1 && !dut.region_search_objects[227]))$fatal(1,"dense two-lane detection missing scene=%0d objects=%h",scene,dut.region_search_objects);
   for(l=0;l<2;l++)begin
    if(live[l*256+48+:3]!=1 || live[l*256+51+:4]!=1 || live[l*256+58+:36]!=0)$fatal(1,"static dense native must remain LOCKING/zero totals");
    if(metadata[631+l*256+:32]!=source || !metadata[631+l*256+223])$fatal(1,"dense native source binding");
   end
   if(!complete || completed_capture!=={1'b1,32'(source),expected_us[source]})$fatal(1,"RAW->ISP->DDR timestamp/source mismatch source%0d got%h expected_us%0d",source,completed_capture,expected_us[source]);
   if(latest_source!=source || completed_metadata[631+:32]!=source || !completed_metadata[631+223])$fatal(1,"video publication or late classification source mismatch");
   $display("DENSE_NATIVE_DONE source=%0d raw=%0d proof_minus_detector_ns=%0f accept_minus_proof_ns=%0f",source,raw_value,proof_time-detector_time,accept_time-proof_time);
   if($realtime<start_time+37037000)#(start_time+37037000-$realtime);
   run_clk=1;ticks(20);
  end
 endtask
 initial begin
  ticks(8);rst=1;ticks(20);command=2;
  scene=1;for(integer view=0;view<4;view++)begin observation={16'(view+1),2'(view)};frame(120,0);end
  fs=1;ticks(1);fs=0;repeat(200)@(negedge procclk);
  if(live[50:48]==3 || live[306:304]==3)$fatal(1,"next FS falsely lost completed empty frame");
  $display("PASS R59_FOUR_MODES_NATIVE: four full 1920x1080 RAW frames, all four views with both dense main+parking lanes, original vendor RAM, native/scaled proof, exact same-frame metadata before 27FPS next FS, zero static events, next-FS continuity");$finish;
 end
 initial begin #160000000;$fatal(1,"empty native watchdog");end
endmodule
