`timescale 1ns/1ps
// Real RAW10 bridge, demosaic, vendor ERAM, manual WB, Sobel and divider.
module tb_local_video;
reg clk=0,rst=0,fs=0,fe=0,hs=0,rv=0;reg [39:0] raw=0;
wire av,asof,alast;wire [39:0] adata;
always #4.444 clk=~clk;reg dclk=0;always #7.5 dclk=~dclk;
wire cav,casof,calast;wire [39:0] cadata;
image_correction correction(.I_clk(clk),.I_rst_n(rst),.I_raw_data(adata),.I_raw_valid(av),
 .I_raw_frame_start(asof),.I_raw_frame_end(alast),.O_raw_tdata(cadata),.O_raw_tlast(calast),
 .O_raw_tvalid(cav),.O_raw_tuser(casof),.O_raw_tready(1'b1));

uial2axis #(.IMG_WIDTH(1024),.IMG_HEIGHT(600),.INPUT_DATA_WIDTH(40)) bridge(clk,rst,raw,rv,fs,fe,av,adata,asof,alast);
wire read_busy,write_busy,active_valid,completed_valid,wen,ren;
wire [1:0] active_slot,completed_slot;wire [24:0] waddr,raddr;
wire [127:0] wdata;wire [197:0] active_meta;wire [15:0] overflows,underflows;
wire sv,mready,good,bad;wire [7:0] mean;wire [197:0] meta;wire [114:0] obs;
reg [17:0] request=1;
wire [127:0] video;wire vv,vsof,view_ready,cap;wire [197:0] completed_meta;
video_in #(.METADATA(1),.META_WIDTH(198),.METADATA_REQUIRED(0)) writer(
 .I_rst_n(rst),.I_camera_clk(clk),.I_camera_frame_start(vsof),.I_camera_valid(vv),.I_camera_data(video),.I_mipi_rx_error(1'b0),
 .I_frame_good(good),.I_frame_bad(bad),.O_camera_ready(view_ready),.I_ddr_clk(dclk),.I_display_pause(1'b0),.I_video_out_rd_busy(read_busy),
 .I_active_valid(active_valid),.I_active_rp(active_slot),.I_ddr_user_ready(1'b1),.I_frame_metadata(meta),.I_frame_metadata_ready(mready),
  .O_completed_valid(completed_valid),.O_completed_rp(completed_slot),.O_video_in_wr_busy(write_busy),
 .O_ddr_user_wr_en(wen),.O_ddr_user_addr(waddr),.O_ddr_user_wr_data(wdata),.O_overflow_frames(overflows),
 .O_completed_metadata(completed_meta),.O_capture_ok(cap));
isp_top #(.DIRECT_DETECTION(1),.SHAPE_MODEL(1),.LOCAL_SEARCH(1),.TRACKING(0),.MULTI_POCKETS(0)) dut(
 .axi4s_video_aclk(clk),.I_rst_n(rst),.I_tlast(calast),.I_tuser(casof),.I_tdata(cadata),.I_tvalid(cav),.I_tdest(10'd0),.O_tready(1'b1),
 .O_tdata(video),.O_tlast(),.O_tuser(vsof),.O_tvalid(vv),.I_tready(),.view_ready(view_ready),.video_frame_good(good),.video_frame_bad(bad),.video_diagnostics(),
 .raw_start(fs),.raw_end(fe),.hs_valid(hs),.raw_valid(rv),.config_ok(1'b1),.lane_error(2'd0),
 .sample_valid(sv),.sample_mean(mean),.sample_min(),.sample_max(),.calibration_ok(1'b1),.present_high(1'b1),.threshold(8'd58),.class_state(),
 .observation_request(request),.wb_request(32'h00006464),.wb_active(),.observation_record(obs),.display_record(),
 .image_config({16'd2244,16'd48}),.frame_metadata(meta),.frame_metadata_ready(mready));
// The MC response model preserves the real common-port arbitration and
// synchronous FIFO read latency; physical DDR calibration is outside this test.
reg hclk=0,vs=0,rd=0;always #9.615 hclk=~hclk;
wire [23:0] display_rgb;wire display_ok;
reg [127:0] memory[0:460799];
reg [3:0] read_pipe=0;reg [127:0] data_pipe[0:3];
function integer index(input [24:0] address);
 begin
  if(address>=21000000) index=345600+(address-21000000)/8;
  else if(address>=14000000) index=230400+(address-14000000)/8;
  else if(address>=7000000) index=115200+(address-7000000)/8;
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
video_out #(.META_WIDTH(198)) reader(
 .I_rst_n(rst),.I_ddr_clk(dclk),.O_video_out_rd_busy(read_busy),.I_video_in_wr_busy(write_busy),
 .I_video_out_rp(completed_slot),.I_completed_valid(completed_valid),.I_completed_rp(completed_slot),
 .O_active_valid(active_valid),.O_active_rp(active_slot),.O_active_metadata(active_meta),.I_completed_metadata(completed_meta),
 .O_ddr_user_rd_en(ren),.O_ddr_user_addr(raddr),.I_ddr_user_ready(1'b1),
 .I_ddr_user_rd_valid(read_pipe[3]),.I_ddr_user_rd_data(data_pipe[3]),
 .I_dsi_clk(hclk),.I_video_vsync(vs),.I_video_rd_en(rd),.O_vdieo_data(display_rgb),
 .O_display_ok(display_ok),.O_underflow_frames(underflows));
reg [197:0] slot_truth[0:3];reg published_d=0;
always @(posedge dclk)begin published_d<=writer.published;if(writer.published && !published_d)slot_truth[completed_slot]<=completed_meta;end
integer display_rows=0,display_pixels=0,nonzero_pixels=0;
reg display_done=0;integer accepted_frames=0,rejected_frames=0;
// Begin a full active raster after an already published frame is selected.
initial begin
 wait(completed_valid);@(negedge hclk);vs=1;repeat(1000) @(negedge hclk);vs=0;
 repeat(30000) @(negedge hclk);
 if(active_meta!==slot_truth[active_slot])$fatal(1,"reader metadata is not from its selected pixel slot");
 if(!active_valid) $fatal(1,"published AUTO4 frame not selected by reader");
 for(integer dy=0;dy<600;dy++) begin
  for(integer dx=0;dx<1024;dx++) begin
   @(negedge hclk);rd=1;display_pixels++;
   if(display_rgb!==24'd0 && !$isunknown(display_rgb)) nonzero_pixels++;
  end
  @(negedge hclk);rd=0;repeat(319) @(negedge hclk);display_rows++;
 end
 repeat(8) @(negedge hclk);
 if(active_meta!==slot_truth[active_slot])$fatal(1,"metadata changed during competing frame display");
 if(underflows!=0 || !display_ok || reader.return_bad || nonzero_pixels<600000)
  $fatal(1,"AUTO4 display failed rows=%0d nonzero=%0d UF=%0d overflow=%0d",display_rows,nonzero_pixels,underflows,overflows);
 $display("PASS multi video raster: 600 rows/614400 requests, nonzero=%0d, competing DDR read/write, no underflow",nonzero_pixels);display_done=1;
end

integer nrows=600;reg [197:0] saved_meta;integer row,b,l,x,h,c,v,shift=0,present=1,holes=1,frame_no=0;
integer total[0:3],cnt[0:3],low[0:3],high[0:3],edge_n[0:3],edge_c[0:3],edge_s[0:3];
integer slow=0,move_y=0;integer luma,px,py,fg_ref,xmin_ref,xmax_ref,ymin_ref,ymax_ref,w_ref,h_ref;
always @(posedge clk) if(rst) begin
 if(dut.awb_pixel_sof) for(integer p=0;p<1;p++) begin fg_ref=0;xmin_ref=999;xmax_ref=-1;ymin_ref=999;ymax_ref=-1;total[p]=0;cnt[p]=0;low[p]=255;high[p]=0;edge_n[p]=0;edge_c[p]=0;edge_s[p]=0;end
 if(dut.roi_accept) for(integer p=0;p<1;p++) for(integer k=0;k<4;k++) begin
  if(dut.roi_x+k>=416 && dut.roi_x+k<608 && dut.roi_y>=228 && dut.roi_y<372)begin
   luma=(int'(dut.awb_O_tdata[95-k*24-:8])+2*int'(dut.awb_O_tdata[87-k*24-:8])+int'(dut.awb_O_tdata[79-k*24-:8]))/4;
   if(luma>=100)begin fg_ref++;if(int'(dut.roi_x)+k<xmin_ref)xmin_ref=dut.roi_x+k;if(int'(dut.roi_x)+k>xmax_ref)xmax_ref=dut.roi_x+k;
    if(int'(dut.roi_y)<ymin_ref)ymin_ref=dut.roi_y;if(int'(dut.roi_y)>ymax_ref)ymax_ref=dut.roi_y;end
  end
  px=472;py=260;
  if(dut.roi_x+k>=px && dut.roi_x+k<px+80 && dut.roi_y>=py && dut.roi_y<py+80) begin
   luma=(int'(dut.awb_O_tdata[95-k*24-:8])+2*int'(dut.awb_O_tdata[87-k*24-:8])+int'(dut.awb_O_tdata[79-k*24-:8]))/4;
   total[p]+=luma;cnt[p]++;if(luma<low[p]) low[p]=luma;if(luma>high[p]) high[p]=luma;
  end
 end
 if(dut.gradient_valid) for(integer p=0;p<1;p++) for(integer k=0;k<4;k++) begin
  px=472;py=260;
  if(dut.gradient_neighborhood[k] && dut.gradient_x+k>=px && dut.gradient_x+k<px+80 && dut.gradient_y>=py && dut.gradient_y<py+80) begin
   edge_n[p]++;edge_s[p]+=dut.gradient_magnitudes[k*11+:11];if(dut.gradient_magnitudes[k*11+:11]>=80) edge_c[p]++;
  end
 end
end
task ticks(input integer n);begin repeat(n) @(negedge clk);end endtask
task frame(input integer move,input integer part,input integer have_holes,input integer expected_lock,input integer mode);
 begin
  saved_meta=completed_meta;frame_no=frame_no+1;shift=move;present=part;holes=0;request=mode;
  fs=1;ticks(1);fs=0;ticks(48);
  for(row=0;row<nrows;row=row+1) begin
   hs=1;ticks(3);
   for(b=0;b<256;b=b+1) begin
    rv=1;
    for(l=0;l<4;l=l+1) begin
     x=b*4+l;v=80;
     if(holes && row>=264 && row<297) begin
      for(h=-2;h<=2;h=h+1) begin
       c=456+shift+96*h;
       if((x-c)*(x-c)+(row-280)*(row-280)<=256) v=800;
      end
     end
     for(h=-2;h<=2;h=h+1) begin
      c=456+shift+96*h-32;
      if(present && row>=263+move_y && row<338+move_y && x>=481+shift && x<544+shift) v=720;
     end
     raw[39-l*10-:10]=v;
    end
    ticks(1);rv=0;ticks(1);
   end
   hs=0;ticks(slow ? 1200 : 80);
  end
  fe=1;ticks(1);fe=0;ticks(700);
  if(expected_lock==-1) begin
   if(!bad || good || completed_meta!==saved_meta || writer.published) $fatal(1,"short AUTO4 frame published old/fresh metadata");
   $display("OBS actual multi writer rejects short native frame");
  end else if(frame_no==1) begin
   $display("OBS ISP initial line-span learning frame good=%b bad=%b ready=%b",good,bad,mready);
  end else if(bad) begin
   // At ~315 input FPS against 61 Hz HDMI this fixture deliberately exceeds
   // field duty (27 FPS). Backpressure marks incomplete views as bad; the
   // last good slot must keep displaying instead of publishing partial pixels.
   if(good || cap || writer.published || completed_meta!==saved_meta)
    $fatal(1,"competing DDR stress published a bad frame");
   if(!dut.video_reject_reason[0]) $fatal(1,"unexpected fixture integrity failure %h",dut.video_reject_reason);
   rejected_frames++;
   $display("OBS competing DDR stress rejects incomplete view frame=%0d reason=%h",frame_no,dut.video_reject_reason);
  end else begin
  accepted_frames++;
  if(!cap || !writer.published || writer.writer_epoch!=frame_no )
   $fatal(1,"fixed direct video did not publish a full frame without metadata");
  if(!good || bad || (slow && (!sv || !obs[24])) || obs[114:83]!==32'h00006464 || obs[45:28]!==request)
   $fatal(1,"direct frame observation incomplete or wrong epoch");
  if(slow && (cnt[0]!=6400 || obs[23:16]!=total[0]/6400 || obs[15:8]!=low[0] || obs[7:0]!=high[0]))
   $fatal(1,"direct frame independent luma reference");
  w_ref=fg_ref==0?0:xmax_ref-xmin_ref+1;h_ref=fg_ref==0?0:ymax_ref-ymin_ref+1;
  if(slow && obs[82:46]!=={2'b0,13'(fg_ref),7'(w_ref),7'(h_ref),8'd100})$fatal(1,"shape video atomic FG/W/H mismatch FG=%0d/%0d W=%0d/%0d H=%0d/%0d bits=%h/%h",obs[80:68],fg_ref,obs[67:61],w_ref,obs[60:54],h_ref,obs[82:46],{2'b0,13'(fg_ref),7'(w_ref),7'(h_ref),8'd100});
  if(mode>=2 && (edge_n[0]!=6400 || dut.edge_count!=edge_c[0] || dut.edge_sum!=edge_s[0]))$fatal(1,"Sobel diagnostics changed");
  if(slow)begin
   if(!mready || obs[26:25]!=2 || completed_meta!==meta || completed_meta[197:178]!=={dut.search_y0,dut.search_y1} ||
    completed_meta[137:115]!=={1'b1,dut.search_x0,dut.search_x1})$fatal(1,"complete local detection not bound to current video epoch");
   if(dut.search_x0!=xmin_ref-2 || dut.search_x1!=xmax_ref+3 || dut.search_y0!=ymin_ref-2 || dut.search_y1!=ymax_ref+3)
    $fatal(1,"native source bbox reference mismatch");
  end else if(completed_meta!=0)$fatal(1,"missing local result inherited stale box/class");
  $display("OBS direct video frame=%0d view=%0d mean=%0d EC=%0d GS=%0d class=%0d",frame_no,mode,mean,edge_c[0],edge_s[0],obs[26:25]);

  end
 end
endtask
initial begin
 ticks(8);rst=1;ticks(20);
 slow=0;frame(0,1,0,0,1);frame(0,1,0,1,1); // Deliberately faster than local processing: complete video, zero metadata.
 slow=1;frame(0,1,0,1,0);
 move_y=12;frame(20,1,0,1,3); // Full object outside old fixed core.
 move_y=0;frame(-20,1,0,1,2);
 wait(display_done);
 if(accepted_frames<3 || overflows!=0)$fatal(1,"local video publication/overflow");
 // Select a later, fully detected frame and verify geometry follows the new slot.
 @(negedge hclk);vs=1;repeat(1000)@(negedge hclk);vs=0;repeat(30000)@(negedge hclk);
 if(active_meta!==slot_truth[active_slot] || !active_meta[24] || !active_meta[137])$fatal(1,"new slot pixels/geometry/result did not swap together");
 $display("PASS local video: actual correction/RAW10/vendor RAM, optional metadata writer and competing DDR reader, zero-metadata video fallback, independent native component bbox/area, shifted frame geometry tied to slot; accepted=%0d rejected=%0d OF=%0d UF=%0d",accepted_frames,rejected_frames,overflows,underflows);$finish;
end
initial begin #120000000;$fatal(1,"local video watchdog");end
endmodule
