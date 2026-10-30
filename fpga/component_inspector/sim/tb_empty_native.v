`timescale 1ns/1ps
// Real RAW10, vendor demosaic/WB RAM, continuous processing and native proof.
// No forced internal producer signals and no synthetic frame_commit.
module tb_empty_native;
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
 reg [16:0] command=0;
 wire [511:0] live;wire [1142:0] metadata;wire mready,good,bad,vv,vs;
 wire [1:0] events;
 isp_top #(.DUAL_REGION_COUNT(1),.PRESENT_TRACE(1),.LOCAL_EDGE_ASSIST(1),.EMPTY_TRACE(1),.ROBUST_EMPTY_CONTEXT(1),.ROBUST_SMALL_EMPTY(1),.STANDING_REVIEW(1),.SURFACE_REVIEW(1),.LOCAL_RECOVERY(1),.MULTITHRESHOLD_EMPTY(1),.CLASSIFIED_COUNT(1),.RESULT_RECORDER(1),.INPUT_WIDTH(1920),.INPUT_HEIGHT(1080),.WIDTH(1280),.HEIGHT(720),.SCALE_DISPLAY(1),.ROI_X0(600),.ROI_X1(680),.ROI_Y0(320),.ROI_Y1(400),.ASYNC_PROCESSING(1),.DIRECT_DETECTION(1),.SHAPE_MODEL(1),.LOCAL_SEARCH(1),.REGIONS(1),.CALIBRATION(1)) dut(
  .count_command(command),.count_live(live),.count_event_valid(events),.processing_clk(procclk),.axi4s_video_aclk(clk),.I_rst_n(rst),
  .I_tlast(calast),.I_tuser(casof),.I_tdata(cadata),.I_tvalid(cav),.I_tdest(10'd0),.O_tready(1'b1),.view_ready(1'b1),
  .O_tvalid(vv),.O_tuser(vs),.video_frame_good(good),.video_frame_bad(bad),
  .raw_start(fs),.raw_end(fe),.hs_valid(hs),.raw_valid(rv),.config_ok(1'b1),.lane_error(2'd0),
  .calibration_ok(1'b1),.present_high(1'b1),.threshold(8'd58),.observation_request(18'd1),.wb_request(32'h00006464),.image_config(32'h04440028),
  .frame_metadata(metadata),.frame_metadata_ready(mready));
 integer source=0,row,b,l,proofs=0,samples=0,accepts=0,pixels=0;
 real detector_time=0,proof_time=0,accept_time=0;
 always @(posedge procclk)if(rst)begin
  if(vv)pixels=pixels+1;
  if(dut.post_commit)begin proofs++;proof_time=$realtime;$display("EMPTY_NATIVE_PROOF source=%0d ns=%0f",source,$realtime);end
  if(dut.search_new)begin samples++;detector_time=$realtime;$display("EMPTY_NATIVE_DETECT source=%0d ns=%0f state=%0d",source,$realtime,dut.search_state);end
  if(dut.classified_counting.dual_regions.pipeline.regions[0].pipeline.accept)begin
   accepts++;accept_time=$realtime;$display("EMPTY_NATIVE_ACCEPT source=%0d ns=%0f",source,$realtime);
  end
  if(events!=0)$fatal(1,"empty RAW generated event");
 end
 task ticks(input integer n);repeat(n)@(negedge clk);endtask
 task frame(input integer raw_value,frame_end_delay);
  real start_time;
  begin
   source++;proofs=0;samples=0;accepts=0;pixels=0;
   @(negedge clk);start_time=$realtime;fs=1;ticks(1);fs=0;ticks(48);
   for(row=0;row<1080;row++)begin
    hs=1;ticks(3);
    for(b=0;b<480;b++)begin
     rv=1;raw={4{10'(raw_value)}};ticks(1);rv=0;ticks(b%4==3 ? 3 : 1);
    end
    hs=0;ticks(98);
    if(row!=1079)begin run_clk=0;#21550.0;run_clk=1;end
   end
   ticks(frame_end_delay);fe=1;ticks(1);fe=0;ticks(200);run_clk=0;
   if($realtime<start_time+37035000)#(start_time+37035000-$realtime);
   if(proofs!=1 || samples!=1 || accepts!=1 || !mready || !good || bad || pixels!=172800)
    $fatal(1,"empty native chain failed source=%0d proof=%0d result=%0d accepted=%0d meta=%b good=%b bad=%b pixels=%0d",source,proofs,samples,accepts,mready,good,bad,pixels);
   for(l=0;l<2;l++)begin
    if(live[l*256+48+:3]!=1 || live[l*256+51+:4]!=1 || live[l*256+58+:36]!=0)$fatal(1,"empty native must remain LOCKING/zero totals");
    if(metadata[631+l*256+:32]!=source || !metadata[631+l*256+223])$fatal(1,"empty native source binding");
   end
   $display("EMPTY_NATIVE_DONE source=%0d raw=%0d proof_minus_detector_ns=%0f accept_minus_proof_ns=%0f",source,raw_value,proof_time-detector_time,accept_time-proof_time);
   if($realtime<start_time+37037000)#(start_time+37037000-$realtime);
   run_clk=1;ticks(20);
  end
 endtask
 initial begin
  ticks(8);rst=1;ticks(20);command=2;
  frame(120,0);frame(880,1200);
  fs=1;ticks(1);fs=0;repeat(200)@(negedge procclk);
  if(live[50:48]==3 || live[306:304]==3)$fatal(1,"next FS falsely lost completed empty frame");
  $display("PASS EMPTY_NATIVE: two full 1920x1080 RAW frames, original vendor RAM, native and scaled proof, empty dark/bright, both banks LOCKING, exact source binding, zero count/events, next-FS continuity");$finish;
 end
 initial begin #80000000;$fatal(1,"empty native watchdog");end
endmodule
