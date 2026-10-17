`timescale 1ns/1ps
// Real RAW10 bridge, demosaic, vendor ERAM, manual WB, Sobel and divider.
module tb_field_chain;
reg clk=0,rst=0,fs=0,fe=0,hs=0,rv=0;reg [39:0] raw=0;
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
wire [127:0] wdata;wire [630:0] active_meta;wire [15:0] overflows,underflows;
reg procclk=0;always #5 procclk=~procclk;
wire sv,mready,good,bad;wire [7:0] mean;wire [630:0] meta;wire [114:0] obs;
reg [31:0] image_config=32'h04440028;
reg [17:0] request=1;reg [31:0] wb_request=32'h00006464;
wire [127:0] video;wire vv,vsof,view_ready,cap;wire [630:0] completed_meta;
video_in #(.WIDTH(1280),.HEIGHT(720),.METADATA(1),.META_WIDTH(631),.METADATA_REQUIRED(0),.VIDEO_FIRST(1)) writer(
 .I_rst_n(rst),.I_camera_clk(procclk),.I_camera_frame_start(vsof),.I_camera_valid(vv),.I_camera_data(video),.I_mipi_rx_error(1'b0),
 .I_frame_good(good),.I_frame_bad(bad),.O_camera_ready(view_ready),.I_ddr_clk(dclk),.I_display_pause(1'b0),.I_video_out_rd_busy(read_busy),
 .I_active_valid(active_valid),.I_active_rp(active_slot),.I_ddr_user_ready(1'b1),.I_frame_metadata(meta),.I_frame_metadata_ready(mready),
  .O_completed_valid(completed_valid),.O_completed_rp(completed_slot),.O_video_in_wr_busy(write_busy),
 .O_ddr_user_wr_en(wen),.O_ddr_user_addr(waddr),.O_ddr_user_wr_data(wdata),.O_overflow_frames(overflows),
 .O_completed_metadata(completed_meta),.O_capture_ok(cap));
isp_top #(.INPUT_WIDTH(1920),.INPUT_HEIGHT(1080),.WIDTH(1280),.HEIGHT(720),.SCALE_DISPLAY(1),.ROI_X0(600),.ROI_X1(680),.ROI_Y0(320),.ROI_Y1(400),.ASYNC_PROCESSING(1),.DIRECT_DETECTION(1),.SHAPE_MODEL(1),.LOCAL_SEARCH(1),.REGIONS(1),.CALIBRATION(1),.TRACKING(0),.MULTI_POCKETS(0)) dut(
 .processing_clk(procclk),.axi4s_video_aclk(clk),.I_rst_n(rst),.I_tlast(calast),.I_tuser(casof),.I_tdata(cadata),.I_tvalid(cav),.I_tdest(10'd0),.O_tready(1'b1),
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
video_out #(.WIDTH(1280),.HEIGHT(720),.META_WIDTH(631)) reader(
 .I_rst_n(rst),.I_ddr_clk(dclk),.O_video_out_rd_busy(read_busy),.I_video_in_wr_busy(write_busy),
 .I_video_out_rp(completed_slot),.I_completed_valid(completed_valid),.I_completed_rp(completed_slot),
 .O_active_valid(active_valid),.O_active_rp(active_slot),.O_active_metadata(active_meta),.I_completed_metadata(completed_meta),
 .O_ddr_user_rd_en(ren),.O_ddr_user_addr(raddr),.I_ddr_user_ready(1'b1),
 .I_ddr_user_rd_valid(read_pipe[3]),.I_ddr_user_rd_data(data_pipe[3]),
 .I_dsi_clk(hclk),.I_video_vsync(vs),.I_video_rd_en(rd),.O_vdieo_data(display_rgb),
 .O_display_ok(display_ok),.O_underflow_frames(underflows));

integer frame_no=0,pattern=0,shift=0,move_y=0,row,b,l,pgm;
integer trace,records;
initial begin trace=$fopen("calibration_rgb.txt","w");records=$fopen("calibration_records.txt","w");end
always @(posedge procclk)if(rst)begin
 if(dut.post_accept && dut.post_x>=608 && dut.post_x<672 &&
  ((dut.post_y>=288 && dut.post_y<352) || (dut.post_y>=484 && dut.post_y<548)))
  $fwrite(trace,"%0d %0d %0d %0d %024h\n",frame_no,dut.post_x,dut.post_y,dut.post_tag[1:0],dut.post_rgb);
end
integer displays=0,checked_pixels=0,nonzero_pixels=0,accepted_frames=0,commits=0;
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
// Same observed body scale36x44 processing pixels, not the earlier oversized fixture.
// A narrow sloping tape exposes the bright-background deadline failure.
function integer source(input integer px,py);
 integer yy;
 begin
  yy=py+(pattern==3 ? (px-960)/8 : 0);
  source=80;
  if(pattern==3)source=px>=270 && px<1680 &&
   ((yy>=390 && yy<535) || (yy>=690 && yy<835)) ? 80 : 960;
  if(((px>=753 && px<807) || (px>=1113 && px<1167)) &&
   ((yy>=447 && yy<513) || (yy>=747 && yy<813)))source=720;
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
reg previous_rd=0;integer next_pixel=0;reg [1:0] selected_slot;reg [630:0] selected_meta;
always @(posedge hclk)begin
 #1;
 if(rst && previous_rd)begin
  if(display_rgb!==expected_pixel(selected_slot,next_pixel))
   $fatal(1,"cadence display byte mismatch slot=%0d pixel=%0d got=%h expected=%h",selected_slot,next_pixel,display_rgb,expected_pixel(selected_slot,next_pixel));
  if(active_slot!==selected_slot || active_meta!==selected_meta)$fatal(1,"late tuple changed active pixels/results inside one raster");
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
  selected_slot=active_slot;selected_meta=active_meta;next_pixel=0;
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
  @(negedge clk);frame_time=$realtime;
  if(previous_fs!=0 && (frame_time-previous_fs<38450000 || frame_time-previous_fs>38480000))$fatal(1,"source cadence drifted from 26 FPS");
  previous_fs=frame_time;frame_no++;pattern=kind;request=mode;commits=0;publish_time=0;result_time=0;
  fs=1;ticks(1);fs=0;ticks(48);
  for(row=0;row<1080;row++)begin
   hs=1;ticks(3);
   for(b=0;b<480;b++)begin
    if(kind==4 && row==200 && b==100)wb_request=32'h00016464;
    rv=1;for(l=0;l<4;l++)raw[39-l*10-:10]=10'(source(b*4+l,row));ticks(1);rv=0;ticks(b%4==3 ? 3 : 1);
   end
   hs=0;ticks(98);
   // Preserve native LP738 active edges, but stop recovered CSI between rows.
   // The continuous post-AWB clock should observe the photographed LP0CF0.
   if(row!=1079)begin run_clk=0;#21550.0;run_clk=1;end
  end
  fe=1;ticks(1);fe=0;ticks(200);run_clk=0;end_time=$realtime;
  if(frame_no!=1)begin
   while(!writer.published && $realtime<end_time+100000)#10;
   if(!writer.published || !cap || bad || !good || writer.written!=172800)
    $fatal(1,"cadence video blocked frame=%0d P=%h words=%0d good=%b bad=%b",frame_no,writer.publish_seen,writer.written,good,bad);
  end
  if($realtime<frame_time+38460000)#(frame_time+38460000-$realtime);
  if(frame_no==1)begin if(writer.published || !bad)$fatal(1,"warmup frame escaped proof");end
  else begin
   if(commits!=1 || overflows || underflows)$fatal(1,"cadence native proof/transport failure");
   if(kind==4)begin if(mready || completed_meta!=0)$fatal(1,"WB-canceled result must leave live zero-label video");end
   else begin
    if(!mready || completed_meta!==meta || obs[114:83]!==wb_request || obs[45:28]!==request)
     $fatal(1,"analysis did not finish within real cadence frame=%0d phase=%0d ready=%b FG=%0d latency_ns=%0f",frame_no,dut.local_shape_detection.detector.phase,mready,dut.local_shape_detection.detector.capture_foreground,result_time-end_time);
    aa=meta[198+:76];bb=meta[274+:76];
     if(!meta[630] || !meta[565] || !meta[629])$fatal(1,"calibration marker or either complete probe missing");
     $fwrite(records,"%0d %032h\n",frame_no,meta[629:502]);
   if(!meta[425] || !meta[501] || meta[424:423]!=2 || meta[500:499]!=2)
    $fatal(1,"second zone missing from 502-bit full-chain metadata");
    if(!aa[75] || !bb[75] || aa[74:73]!=2 || bb[74:73]!=2 || aa[41:31]>=bb[41:31])$fatal(1,"cadence dual result truth mismatch");
    pgm=$fopen($sformatf("region_cadence_%0d.pgm",frame_no),"w");$fwrite(pgm,"P2\n1280 720\n255\n");
    for(integer yy=0;yy<720;yy++)begin for(integer xx=0;xx<1280;xx++)$fwrite(pgm,"%0d ",luma[yy*1280+xx]);$fwrite(pgm,"\n");end
    $fclose(pgm);
    $display("REF region cadence frame=%0d objects=%h state=%0d FG=%0d W=%0d H=%0d X0=%0d X1=%0d Y0=%0d Y1=%0d",frame_no,meta[501:198],dut.search_state,dut.search_fg,dut.search_w,dut.search_h,dut.search_x0,dut.search_x1,dut.search_y0,dut.search_y1);
   end
   if(dut.u_roi_sobel_view.line_min<3250 || dut.u_roi_sobel_view.line_min>3380)$fatal(1,"test does not match photographed wall-clock line period");
   accepted_frames++;
  end
  $display("CADENCE frame=%0d mode=%0d LP=%h active_ns=%0f publish_after_FE_ns=%0f result_after_FE_ns=%0f",frame_no,mode,dut.u_roi_sobel_view.line_min,end_time-frame_time,publish_time-end_time,result_time==0 ? -1.0 : result_time-end_time);
  if($realtime<frame_time+38461500)#(frame_time+38461500-$realtime);
  run_clk=1;ticks(20);
 end
endtask
initial begin
 ticks(8);rst=1;ticks(20);
 frame(0,0);frame(0,0);frame(4,0);frame(3,0);frame(3,3);frame(3,1);frame(3,2);
 wait(displays>=4);repeat(4)@(negedge hclk);
 if(accepted_frames!=6 || checked_pixels<3686400 || nonzero_pixels<3600000 || overflows || underflows)$fatal(1,"cadence final counts failed");
 $fclose(trace);$fclose(records);$display("PASS field chain: native line-clock gaps, LP0CF0 wall-clock, 26-FPS source start-to-start, all four views, live WB-canceled zero-result video, same-slot late dual tuples, full exact RGB rasters=%0d pixels=%0d OF=%0d UF=%0d",displays,checked_pixels,overflows,underflows);$finish;
end
initial begin #320000000;$fatal(1,"frame cadence watchdog");end
endmodule
