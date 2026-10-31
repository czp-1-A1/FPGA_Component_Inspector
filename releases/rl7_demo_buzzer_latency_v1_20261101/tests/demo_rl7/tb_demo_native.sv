`timescale 1ns/1ps
// Real RAW10 bridge, demosaic, vendor ERAM, manual WB, Sobel and divider.
// Positive control fixture: RAW360 apertures survive the unchanged T80/T100
// shape proof. RAW280 mirrored weak shapes are a separately retained R22
// baseline classification boundary (native_r1 / weak_replay_r1), not a pass.
module tb_demo_native #(parameter APERTURE_RAW=360);
reg clk=0,rst=0,fs=0,fe=0,hs=0,rv=0;reg [39:0] raw=0;
reg [64:0] selected_capture;real capture_started[0:15];
wire av,asof,alast;wire [39:0] adata;
reg run_clk=1;always #4.444 if(run_clk)clk=~clk;reg dclk=0;always #7.5 dclk=~dclk;
wire cav,casof,calast;wire [39:0] cadata;
image_correction correction(.I_clk(clk),.I_rst_n(rst),.I_raw_data(adata),.I_raw_valid(av),
 .I_raw_frame_start(asof),.I_raw_frame_end(alast),.O_raw_tdata(cadata),.O_raw_tlast(calast),
 .O_raw_tvalid(cav),.O_raw_tuser(casof),.O_raw_tready(1'b1));

// Same native packet window as the production wrapper; guard receives raw rv.
reg native_packet_open=0;
always @(posedge clk or negedge rst)begin
 if(!rst)native_packet_open<=0;else if(fs)native_packet_open<=1;else if(fe)native_packet_open<=0;
end
uial2axis #(.IMG_WIDTH(1920),.IMG_HEIGHT(1080),.INPUT_DATA_WIDTH(40)) bridge(clk,rst,raw,rv && native_packet_open && !fe,fs,fe,av,adata,asof,alast);
wire read_busy,write_busy,active_valid,completed_valid,wen,ren;
wire [1:0] active_slot,completed_slot;wire [24:0] waddr,raddr;
wire [127:0] wdata;wire [886:0] active_meta;wire [15:0] overflows,underflows;
reg procclk=0;always #5 procclk=~procclk;
wire sv,mready,good,bad;wire [7:0] mean;wire [886:0] meta;wire [114:0] obs;
reg [31:0] image_config=32'h04440028;
reg [17:0] request=1;reg [31:0] wb_request=32'h00006464;
wire [127:0] video;wire vv,vsof,view_ready,cap;wire [886:0] completed_meta;
wire [31:0] gray_us,capture_us,latest_source;wire capture_time_valid;
wire [64:0] camera_capture,completed_capture,active_capture;
contest_latency_clock clocker(procclk,rst,gray_us);
contest_latency_capture timer_capture(clk,rst,gray_us,capture_us,capture_time_valid);

video_in #(.MEASURE_LATENCY(1),.WIDTH(1280),.HEIGHT(720),.METADATA(1),.META_WIDTH(887),.METADATA_REQUIRED(0),.VIDEO_FIRST(1)) writer(
 .I_capture_info(camera_capture),.O_completed_capture(completed_capture),
 .I_rst_n(rst),.I_camera_clk(procclk),.I_camera_frame_start(vsof),.I_camera_valid(vv),.I_camera_data(video),.I_mipi_rx_error(1'b0),
 .I_frame_good(good),.I_frame_bad(bad),.O_camera_ready(view_ready),.I_ddr_clk(dclk),.I_display_pause(1'b0),.I_video_out_rd_busy(read_busy),
 .I_active_valid(active_valid),.I_active_rp(active_slot),.I_ddr_user_ready(1'b1),.I_frame_metadata(meta),.I_frame_metadata_ready(mready),
  .O_completed_valid(completed_valid),.O_completed_rp(completed_slot),.O_video_in_wr_busy(write_busy),
 .O_ddr_user_wr_en(wen),.O_ddr_user_addr(waddr),.O_ddr_user_wr_data(wdata),.O_overflow_frames(overflows),
 .O_completed_metadata(completed_meta),.O_capture_ok(cap));
wire relay_feed;wire [63:0] relay_status;
isp_top #(.MEASURE_LATENCY(1),.FIVE_EMPTY_V7(1),.ADJACENT_V6(1),.RELAY_TOL_PX(80),.RELAY_KEYS_V3(1),.AUTO_RELAY(1),.RELAY_LEFT_LAYOUT(1),.RELAY_TARGET_X(152),.RELAY_ADVANCE_PX(32),.LOCAL_EDGE_ASSIST(1),.EMPTY_TRACE(1),.ROBUST_EMPTY_CONTEXT(1),.ROBUST_SMALL_EMPTY(1),.STANDING_REVIEW(1),.SURFACE_REVIEW(1),.REVIEW_PROBE(0),.LOCAL_RECOVERY(1),.MULTITHRESHOLD_EMPTY(1),.CLASSIFIED_COUNT(1),.RESULT_RECORDER(1),.INPUT_WIDTH(1920),.INPUT_HEIGHT(1080),.WIDTH(1280),.HEIGHT(720),.SCALE_DISPLAY(1),.ROI_X0(600),.ROI_X1(680),.ROI_Y0(320),.ROI_Y1(400),.ASYNC_PROCESSING(1),.DIRECT_DETECTION(1),.SHAPE_MODEL(1),.LOCAL_SEARCH(1),.REGIONS(1),.CALIBRATION(1),.TRACKING(0),.MULTI_POCKETS(0)) dut(
 .capture_time_us(capture_us),.capture_time_valid(capture_time_valid),.capture_info(camera_capture),.latest_source_frame(latest_source),
 .relay_permit(1'b1),.relay_pause(1'b0),.relay_feed(relay_feed),.relay_status(relay_status),.count_command(17'd2),.count_live(),.processing_clk(procclk),.axi4s_video_aclk(clk),.I_rst_n(rst),.I_tlast(calast),.I_tuser(casof),.I_tdata(cadata),.I_tvalid(cav),.I_tdest(10'd0),.O_tready(1'b1),
 .O_tdata(video),.O_tlast(),.O_tuser(vsof),.O_tvalid(vv),.I_tready(),.view_ready(view_ready),.video_frame_good(good),.video_frame_bad(bad),.video_diagnostics(),
 .raw_start(fs),.raw_end(fe),.hs_valid(hs),.raw_valid(rv),.config_ok(1'b1),.lane_error(2'd0),
 .sample_valid(sv),.sample_mean(mean),.sample_min(),.sample_max(),.calibration_ok(1'b1),.present_high(1'b1),.threshold(8'd58),.class_state(),
 .observation_request(request),.wb_request(wb_request),.wb_active(),.observation_record(obs),.display_record(),
 .image_config(image_config),.frame_metadata(meta),.frame_metadata_ready(mready));
// The MC response model preserves the real common-port arbitration and
// synchronous FIFO read latency; physical DDR calibration is outside this test.
reg hclk=0,vs=0,rd=0;always #6.734 hclk=~hclk;
wire [23:0] display_rgb;wire display_ok;
reg [127:0] memory[0:691199];
reg [3:0] read_pipe=0;reg [127:0] data_pipe[0:3];
function integer index(input [24:0] address);
 begin
  if(address>=21000000) index=518400+(address-21000000)/8;
  else if(address>=14000000) index=345600+(address-14000000)/8;
  else if(address>=7000000) index=172800+(address-7000000)/8;
  else index=address/8;
 end
endfunction
always @(posedge dclk) begin
 if(rst && wen && ren) $fatal(1,"simultaneous MC read/write would lose read address");
 if(rst && wen) memory[index(waddr)]<=wdata;
 read_pipe<={read_pipe[2:0],ren};
 if(ren) data_pipe[0]<=memory[index(raddr)];
 for(integer q=1;q<4;q++) data_pipe[q]<=data_pipe[q-1];
end
video_out #(.MEASURE_LATENCY(1),.WIDTH(1280),.HEIGHT(720),.META_WIDTH(887)) reader(
 .I_completed_capture(completed_capture),.O_active_capture(active_capture),
 .I_rst_n(rst),.I_ddr_clk(dclk),.O_video_out_rd_busy(read_busy),.I_video_in_wr_busy(write_busy),
 .I_video_out_rp(completed_slot),.I_completed_valid(completed_valid),.I_completed_rp(completed_slot),
 .O_active_valid(active_valid),.O_active_rp(active_slot),.O_active_metadata(active_meta),.I_completed_metadata(completed_meta),
 .O_ddr_user_rd_en(ren),.O_ddr_user_addr(raddr),.I_ddr_user_ready(1'b1),
 .I_ddr_user_rd_valid(read_pipe[3]),.I_ddr_user_rd_data(data_pipe[3]),
 .I_dsi_clk(hclk),.I_video_vsync(vs),.I_video_rd_en(rd),.O_vdieo_data(display_rgb),
 .O_display_ok(display_ok),.O_underflow_frames(underflows));

// Actual captured packet includes several CSI decoding clocks before RAW SOF.
// The direct RAW fixture models those4 clocks after recovered-clock restart.
wire [954:0] frame_display_bundle;
status_cdc #(.WIDTH(955)) frame_crossing(.S_clk(dclk),.D_clk(hclk),.rst_n(rst),
 .S_data({active_capture,active_valid,active_slot,active_meta}),.D_data(frame_display_bundle));
wire [31:0] latest_display;
status_cdc #(.WIDTH(32)) latest_crossing(.S_clk(procclk),.D_clk(hclk),.rst_n(rst),.S_data(latest_source),.D_data(latest_display));
wire lat_new,lat_ok,osd_vs,osd_hs,osd_de;wire[15:0] lat_ms10,lat_lag;
wire[31:0] lat_source;wire[39:0] lat_bcd;wire[23:0] osd_rgb;
compact_inspector_osd #(.DEMO_UI(1),.FIVE_EMPTY_V7(1),.ADJACENT_V6(1),.RELAY_CLEAN_UI(1),.AUTO_RELAY(1),.RELAY_LEFT_LAYOUT(1),.RELAY_TARGET_X(152),.RELAY_ADVANCE_PX(32),.RELAY_TOL_PX(80),.WIDTH(1280),.HEIGHT(720)) overlay(
 .clk(hclk),.rst_n(rst),.vs(vs),.hs(1'b0),.de(rd),.rgb(display_rgb),.page(1'b1),
 .latency_new(lat_new),.latency_valid(lat_ok),.latency_ms10(lat_ms10),.latency_frame_lag(lat_lag),.latency_source_bcd(lat_bcd),
 .exposure(16'd1092),.gain(16'd40),.fps(16'd27),.width(16'd1920),.height(16'd1080),
 .wb_r(8'd100),.wb_b(8'd100),.roi_mean(8'd0),.roi_min(8'd0),.roi_max(8'd0),.wb_tune(1'b0),.wb_pending(1'b0),.roi_valid(1'b0),.cfg_done(1'b1),.view_mode(2'd0),.edge_count(13'd0),
 .lane_errors(16'd0),.format_errors(16'd0),.i2c_errors(16'd0),.gaps(16'd0),.overflow_frames(16'd0),.lost_frames(16'd0),.underflow_frames(16'd0),.frames(latest_display),.diagnostics(36'd0),.publish_diagnostic(27'd0),
 .objects(frame_display_bundle[198+:304]),.calibration_record(128'd0),.calibration_valid(1'b0),.local_wait_reason(4'd0),.relay_status(relay_status),.relay_diagnostic(96'd0),.relay_control_mode(3'd1),
 .live_record(dut.count_live),.frame_record(frame_display_bundle[631+:256]),.eligible(1'b1),
 .out_vs(osd_vs),.out_hs(osd_hs),.out_de(osd_de),.out_rgb(osd_rgb));
contest_latency_display latency_measure(.clk(hclk),.rst_n(rst),.us_gray(gray_us),.vs(osd_vs),.de(osd_de),
 .frame_valid(frame_display_bundle[889] && display_ok),.capture_info(frame_display_bundle[954:890]),.latest_source(latest_display),
 .sample_new(lat_new),.sample_valid(lat_ok),.latency_ms10(lat_ms10),.frame_lag(lat_lag),.source_frame(lat_source),.source_bcd(lat_bcd));
integer latency_samples=0;real first_pixel_at;reg frame_first=1;
always @(posedge hclk)begin
 if(osd_vs)frame_first=1;
 else if(osd_de && frame_first)begin first_pixel_at=$realtime;frame_first=0;end
 #1;
 if(rst && lat_new)begin
  if(!lat_ok || lat_source!=selected_capture[63:32])$fatal(1,"HDMI measured tuple is not actual displayed source");
  if($itor(lat_ms10)*100000.0>first_pixel_at-capture_started[lat_source]+100000.0 ||
     first_pixel_at-capture_started[lat_source]-$itor(lat_ms10)*100000.0>102000.0)
    $fatal(1,"measured latency does not match independent RAW SOF to HDMI pixel realtime");
  latency_samples++;
 end
end

integer frame_no=0,pattern=0,shift=0,move_y=0,row,b,l,pgm;


integer trace,records;
initial begin trace=$fopen("calibration_rgb.txt","w");records=$fopen("calibration_records.txt","w");end
always @(posedge procclk)if(rst)begin
 if(dut.post_accept && dut.post_x>=608 && dut.post_x<672 &&
  ((dut.post_y>=288 && dut.post_y<352) || (dut.post_y>=484 && dut.post_y<548)))
  $fwrite(trace,"%0d %0d %0d %0d %024h\n",frame_no,dut.post_x,dut.post_y,dut.post_tag[1:0],dut.post_rgb);
end
integer displays=0,checked_pixels=0,nonzero_pixels=0,accepted_frames=0,commits=0;
// Immutable original recorder, with only its module name changed.
reg baseline_start=0,baseline_sample=0;reg [31:0] baseline_frame=0;reg [607:0] baseline_objects=0;
wire baseline_busy;wire [2:0] baseline_state;wire [3:0] baseline_reason;wire [8:0] baseline_total,baseline_empty;
classified_pocket_counter_R9 #(.RECORD_ONLY(1),.MOTION_RECOVERY(1),.TAIL_RECOVERY(1),.HYST(4),.OBS_PER_REGION(4),.ORDERED_HANDOFF(1),.RECOVERABLE(1)) baseline(
 .clk(procclk),.rst_n(rst),.start_run(baseline_start),.finish_run(1'b0),.frame_bad(1'b0),.sample_new(baseline_sample),
 .frame_id(baseline_frame),.config_tag(64'h0444002800006464),.objects(baseline_objects),.busy(baseline_busy),
 .state(baseline_state),.reason(baseline_reason),.total(baseline_total),.empty_total(baseline_empty),.ledger_address(9'd511),.empty_address(9'd511));
integer event_count=0;
always @(negedge procclk)begin
 if(rst && dut.search_new)$display("SPEED_CANDIDATES source=%0d data=%0152h",frame_no,dut.recorder_candidates);
 if(rst && dut.classified_counting.pipeline.event_valid)begin
  event_count++;
  if(dut.classified_counting.pipeline.event_id!=event_count ||
     dut.classified_counting.pipeline.event_frame!=((event_count==1 ? 5 : event_count==2 ? 7 : event_count==3 ? 8 : 10)) ||
     dut.classified_counting.pipeline.event_kind!=((event_count==2 || event_count==3) ? 3 : 2))
   $fatal(1,"actual native event source/kind/number differs from finite physical crossing truth");
  $display("SPEED_EVENT id=%0d source=%0d kind=%0d",event_count,dut.classified_counting.pipeline.event_frame,dut.classified_counting.pipeline.event_kind);
 end
end

integer luma[0:921599];reg [75:0] aa,bb;
real frame_time,previous_fs=0,publish_time=0,result_time=0;
reg published_d=0,mready_d=0;
always @(posedge dclk)begin
 published_d<=writer.published;
 if(writer.published && !published_d)publish_time=$realtime;
end
always @(posedge procclk)begin
 mready_d<=mready;
 if(mready && !mready_d)result_time=$realtime;
end
always @(posedge procclk)if(rst)begin
 if(dut.post_commit)commits++;
 if(dut.post_accept)for(integer k=0;k<4;k++)luma[dut.post_y*1280+dut.post_x+k]=
  (int'(dut.post_rgb[95-k*24-:8])+2*int'(dut.post_rgb[87-k*24-:8])+int'(dut.post_rgb[79-k*24-:8]))/4;
end
// Same observed body scale36x44 processing pixels. Initial RAW translation minus3
// qualifies both empty sampling phases independently before this freeze.
// R1 phase0/4 shape rejection remains a separate preserved classifier boundary.
// A narrow sloping tape exposes the bright-background deadline failure.
function integer source(input integer px,py);
 integer idx,cx,dx,dy,ax,ay,shift_native;
 begin
  source=80;shift_native=(frame_no<=3 ? (frame_no-1)*30 : frame_no==4 ? 96 : frame_no==5 ? 138 : 186+(frame_no-6)*48);
  if(py>=390 && py<540)begin
   idx=(px-837-shift_native+13233)/66-200;
   cx=837+idx*66+shift_native;dx=px-cx;dy=py-480;
   ax=dx<0 ? -dx : dx;ay=dy<0 ? -dy : dy;
   if(idx==0 || idx==-3)begin
    if(ax<27 && ay<33 && !(ax>=23 && ay>=27))source=720;
   end else if(idx==-1 || idx==-2)begin
    if(dx*dx*56+dy*dy*90<=5040)source=APERTURE_RAW;
   end
   dy=py-420;
   if(idx>=-3 && idx<=0 && dx*dx+dy*dy<=100)begin source=360;if(dx*dx+dy*dy<=16)source=440;end
  end
 end
endfunction
// Compare real rendered bytes to their selected DDR pixel slot, including word crossings.
function [23:0] expected_pixel(input integer slot,pixel);
 reg [23:0] value;integer byte_pos,word_pos,offset;
 begin
  for(integer k=0;k<3;k++)begin
   byte_pos=pixel*3+k;word_pos=slot*172800+byte_pos/16;offset=byte_pos%16;
   value[23-k*8-:8]=memory[word_pos][127-offset*8-:8];
  end
  expected_pixel=value;
 end
endfunction
reg previous_rd=0;integer next_pixel=0;reg [1:0] selected_slot;reg [886:0] selected_meta;

always @(posedge hclk)begin
 #1;
 if(rst && previous_rd)begin
  if(display_rgb!==expected_pixel(selected_slot,next_pixel))
   $fatal(1,"cadence display byte mismatch slot=%0d pixel=%0d got=%h expected=%h",selected_slot,next_pixel,display_rgb,expected_pixel(selected_slot,next_pixel));
  if(active_slot!==selected_slot || active_meta!==selected_meta)$fatal(1,"late tuple changed active pixels/results inside one raster");
  if(active_capture!==selected_capture)$fatal(1,"capture timestamp/ID changed during actual raster");
  if(display_rgb!=0)nonzero_pixels++;
  next_pixel++;checked_pixels++;
 end
 previous_rd=rd;
end
initial begin
 wait(completed_valid);
 forever begin
  @(negedge hclk);vs=1;repeat(1000)@(negedge hclk);vs=0;repeat(30000)@(negedge hclk);
  if(!active_valid)$fatal(1,"cadence complete picture did not arm reader");
  selected_slot=active_slot;selected_meta=active_meta;selected_capture=active_capture;next_pixel=0;
  if(!selected_capture[64] || selected_capture[63:32]==0)$fatal(1,"complete video has no real capture stamp");
  for(integer yy=0;yy<720;yy++)begin
   for(integer xx=0;xx<1280;xx++)begin rd=1;@(negedge hclk);end
   rd=0;repeat(370)@(negedge hclk);
  end
  if(next_pixel!=921600 || underflows || !display_ok)$fatal(1,"cadence complete raster/underflow failure");
  displays++;
 end
end
task ticks(input integer count);begin repeat(count)@(negedge clk);end endtask
task frame(input integer kind,mode);
 real end_time;
 begin
  @(negedge clk);ticks(4);frame_time=$realtime;
  if(previous_fs!=0 && (frame_time-previous_fs<37020000 || frame_time-previous_fs>37050000))$fatal(1,"source cadence drifted from 27 FPS");
  previous_fs=frame_time;frame_no++;capture_started[frame_no]=frame_time;pattern=kind;request=mode;commits=0;publish_time=0;result_time=0;
  fs=1;ticks(1);fs=0;ticks(48);
  for(row=0;row<1080;row++)begin
   hs=1;ticks(3);
   for(b=0;b<480;b++)begin
    if(kind==4 && row==200 && b==100)wb_request=32'h00016464;
    rv=1;for(l=0;l<4;l++)raw[39-l*10-:10]=10'(source(1919-(b*4+l),row));ticks(1);rv=0;ticks(b%4==3 ? 3 : 1);
   end
   hs=0;ticks(98);
   // Preserve native LP738 active edges, but stop recovered CSI between rows.
   // The continuous post-AWB clock should observe the photographed LP0CF0.
   if(row!=1079)begin run_clk=0;#21550.0;run_clk=1;end
  end
  fe=1;ticks(1);fe=0;ticks(200);run_clk=0;end_time=$realtime;
  begin // A complete cold frame must satisfy the same proof as every later frame.
   while(!writer.published && $realtime<end_time+100000)#10;
   if(!completed_capture[64] || completed_capture[63:32]!=frame_no ||
     completed_capture[31:0]>$rtoi(frame_time/1000.0) ||
     $rtoi(frame_time/1000.0)-completed_capture[31:0]>2)
    $fatal(1,"capture tuple not actual RAW SOF frame=%0d tuple=%h time=%f",frame_no,completed_capture,frame_time);
  if(!writer.published || !cap || bad || !good || writer.written!=172800)
    $fatal(1,"cadence video blocked frame=%0d P=%h words=%0d good=%b bad=%b",frame_no,writer.publish_seen,writer.written,good,bad);
  end
  if($realtime<frame_time+37035000)#(frame_time+37035000-$realtime);
  begin
   if(commits!=1 || overflows || underflows)$fatal(1,"cadence native proof/transport failure");
   if(kind==4)begin if(mready || completed_meta!=0)$fatal(1,"WB-canceled result must leave live zero-label video");end
   else begin
    if(!mready || completed_meta!==meta || obs[114:83]!==wb_request || obs[45:28]!==request)
     $fatal(1,"analysis did not finish within real cadence frame=%0d phase=%0d ready=%b FG=%0d latency_ns=%0f",frame_no,dut.local_shape_detection.detector.phase,mready,dut.local_shape_detection.detector.capture_foreground,result_time-end_time);
    aa=meta[198+:76];bb=meta[274+:76];
     if(!meta[854] || meta[662:631]!=frame_no)$fatal(1,"count metadata source epoch or marker mismatch");
     if(!meta[630] || !meta[503] || !meta[567] || meta[629:502]!==dut.search_probe_record)
      $fatal(1,"passive trace full128 same-source metadata binding/completion missing");
     $display("TRACE_NATIVE source=%0d data=%032h",frame_no,meta[629:502]);
     $fwrite(records,"%0d %032h\n",frame_no,meta[629:502]);
     for(integer slot=0;slot<4;slot++)begin
      automatic reg [75:0] ob;automatic integer center;
      ob=meta[198+slot*76+:76];center=({1'b0,ob[41:31]}+ob[30:20])/2;
      if(ob[75] && (slot<2 ? (center<448 || center>=832) : (center<64 || center>=448)))$fatal(1,"native LEFT ROI bank mismatch");
     end
     if(relay_status[31:29]!=1 || relay_status[28:25]!=0 || !relay_feed)$fatal(1,"native left transport stopped S%0d F%0h",relay_status[31:29],relay_status[28:25]);
     if(frame_no>=4 && (meta[681:679]!=2 || meta[685:682]!=0))
      $fatal(1,"native speed_raw stream stopped frame%0d state%0d C%0d",frame_no,meta[681:679],meta[685:682]);
     // Mirroring changes the sampled body centre: final P is exactly636 at
     // source9, still INSIDE the strict leftward LINE_X-HYST boundary. It
     // genuinely crosses at source10. The original rightward oracle is kept
     // unchanged in local_edge/tb_edge_raw_mode1.v.
     if(meta[697:689]!=(frame_no<5 ? 0 : frame_no<7 ? 1 : frame_no<8 ? 2 : frame_no<10 ? 3 : 4))$fatal(1,"native speed_raw real crossing total/source mismatch source%0d total%0d",frame_no,meta[697:689]);
     $display("SPEED_NATIVE_RESULT source=%0d record=%064h total=%0d P=%0d E=%0d",frame_no,meta[886:631],meta[697:689],meta[706:698],meta[715:707]);
     if(frame_no==11 && (meta[706:698]!=2 || meta[715:707]!=2))$fatal(1,"native speed_raw class composition");
     // Read-only immutableR7 comparator consumes these same actual original2
     // classified results. It never modifies DUT pixels/results or the oracle.
     @(negedge procclk);baseline_objects=dut.recorder_candidates;baseline_frame=frame_no;baseline_sample=1;
     @(negedge procclk);baseline_sample=0;repeat(2)@(negedge procclk);
     while(baseline_busy)@(negedge procclk);
     $display("SPEED_NATIVE_COUNT source=%0d total=%0d present=%0d empty=%0d R8total=%0d R8empty=%0d R8state=%0d R8C=%0d",frame_no,meta[697:689],meta[706:698],meta[715:707],baseline_total,baseline_empty,baseline_state,baseline_reason);
    pgm=$fopen($sformatf("region_cadence_%0d.pgm",frame_no),"w");$fwrite(pgm,"P2\n1280 720\n255\n");
    for(integer yy=0;yy<720;yy++)begin for(integer xx=0;xx<1280;xx++)$fwrite(pgm,"%0d ",luma[yy*1280+xx]);$fwrite(pgm,"\n");end
    $fclose(pgm);
    $display("REF region cadence frame=%0d objects=%h state=%0d FG=%0d W=%0d H=%0d X0=%0d X1=%0d Y0=%0d Y1=%0d",frame_no,meta[501:198],dut.search_state,dut.search_fg,dut.search_w,dut.search_h,dut.search_x0,dut.search_x1,dut.search_y0,dut.search_y1);
   end
   if(dut.u_roi_sobel_view.line_min<3250 || dut.u_roi_sobel_view.line_min>3380)$fatal(1,"test does not match photographed wall-clock line period");
   accepted_frames++;
  end
  $display("CADENCE frame=%0d mode=%0d LP=%h active_ns=%0f publish_after_FE_ns=%0f result_after_FE_ns=%0f",frame_no,mode,dut.u_roi_sobel_view.line_min,end_time-frame_time,publish_time-end_time,result_time==0 ? -1.0 : result_time-end_time);
  if($realtime<frame_time+37037000)#(frame_time+37037000-$realtime);
  run_clk=1;ticks(20);
 end
endtask
initial begin
 ticks(8);rst=1;baseline_start=1;repeat(2)@(negedge procclk);baseline_start=0;ticks(20);
 repeat(12)frame(0,1);
 if(meta[697:689]!=4 || meta[706:698]!=2 || meta[715:707]!=2 || event_count!=4)$fatal(1,"native speed_raw four true classified crossings required");
 wait(displays>=4);repeat(4)@(negedge hclk);
 if(accepted_frames!=12 || checked_pixels<3686400 || nonzero_pixels<3600000 || overflows || underflows)$fatal(1,"cadence final counts failed");
 if(!relay_feed || relay_status[31:29]!=1 || relay_status[28:25]!=0 || relay_status[63:58]!=2 || relay_status[57] || relay_status[47:32]<150)
  $fatal(1,"native processing must keep feeding while TWO genuine EMPTY IDs wait >150ms before local arrival");
 if(latency_samples<20)$fatal(1,"insufficient real latency samples %0d",latency_samples);
 $display("PASS DEMO_NATIVE_LATENCY: %0d actual RAW SOF/DDR-slot/post-OSD-HDMI measurements; no timestamp inherited on bad or late metadata",latency_samples);
 $fclose(trace);$fclose(records);$display("PASS V3_NATIVE_MODE1: positive RAW360 aperture fixture, native line-clock gaps, LP0CF0 wall-clock, 27-FPS source start-to-start, finite mirrored LEFT real P,E,E,P ramp20to32px/source, final production controller enabled, 2 EMPTY queued, pre-arrival wait>150ms, unchanged R9 read-only comparison, same-slot late tuples, full exact RGB rasters=%0d pixels=%0d OF=%0d UF=%0d",displays,checked_pixels,overflows,underflows);$finish;
end
initial begin #1100000000;$fatal(1,"frame cadence watchdog");end
endmodule
