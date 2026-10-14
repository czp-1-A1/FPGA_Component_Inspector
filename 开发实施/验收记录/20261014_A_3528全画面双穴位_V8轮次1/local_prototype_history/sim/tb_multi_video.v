`timescale 1ns/1ps
// Real RAW10 bridge, demosaic, vendor ERAM, manual WB, Sobel and divider.
module tb_multi_video;
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
wire [127:0] wdata;wire [517:0] active_meta;wire [15:0] overflows,underflows;
wire sv,mready,good,bad;wire [7:0] mean;wire [517:0] meta;wire [114:0] obs;
reg [17:0] request=1;
wire [127:0] video;wire vv,vsof,view_ready,cap;wire [517:0] completed_meta;
video_in #(.METADATA(1),.META_WIDTH(518),.METADATA_REQUIRED(0)) writer(
 .I_rst_n(rst),.I_camera_clk(clk),.I_camera_frame_start(vsof),.I_camera_valid(vv),.I_camera_data(video),.I_mipi_rx_error(1'b0),
 .I_frame_good(good),.I_frame_bad(bad),.O_camera_ready(view_ready),.I_ddr_clk(dclk),.I_display_pause(1'b0),.I_video_out_rd_busy(read_busy),
 .I_active_valid(active_valid),.I_active_rp(active_slot),.I_ddr_user_ready(1'b1),.I_frame_metadata(meta),.I_frame_metadata_ready(mready),
  .O_completed_valid(completed_valid),.O_completed_rp(completed_slot),.O_video_in_wr_busy(write_busy),
 .O_ddr_user_wr_en(wen),.O_ddr_user_addr(waddr),.O_ddr_user_wr_data(wdata),.O_overflow_frames(overflows),
 .O_completed_metadata(completed_meta),.O_capture_ok(cap));
isp_top #(.MULTI_POCKETS(1),.TRACKING(1),.HOLE_Y(380),.LATE_HOLE(1)) dut(
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
video_out #(.META_WIDTH(518)) reader(
 .I_rst_n(rst),.I_ddr_clk(dclk),.O_video_out_rd_busy(read_busy),.I_video_in_wr_busy(write_busy),
 .I_video_out_rp(completed_slot),.I_completed_valid(completed_valid),.I_completed_rp(completed_slot),
 .O_active_valid(active_valid),.O_active_rp(active_slot),.O_active_metadata(active_meta),.I_completed_metadata(completed_meta),
 .O_ddr_user_rd_en(ren),.O_ddr_user_addr(raddr),.I_ddr_user_ready(1'b1),
 .I_ddr_user_rd_valid(read_pipe[3]),.I_ddr_user_rd_data(data_pipe[3]),
 .I_dsi_clk(hclk),.I_video_vsync(vs),.I_video_rd_en(rd),.O_vdieo_data(display_rgb),
 .O_display_ok(display_ok),.O_underflow_frames(underflows));
integer display_rows=0,display_pixels=0,nonzero_pixels=0;
reg display_done=0;integer accepted_frames=0,rejected_frames=0;
// Begin a full active raster after an already published frame is selected.
initial begin
 wait(completed_valid);@(negedge hclk);vs=1;repeat(1000) @(negedge hclk);vs=0;
 repeat(30000) @(negedge hclk);
 if(!active_valid) $fatal(1,"published AUTO4 frame not selected by reader");
 for(integer dy=0;dy<600;dy++) begin
  for(integer dx=0;dx<1024;dx++) begin
   @(negedge hclk);rd=1;display_pixels++;
   if(display_rgb!==24'd0 && !$isunknown(display_rgb)) nonzero_pixels++;
  end
  @(negedge hclk);rd=0;repeat(319) @(negedge hclk);display_rows++;
 end
 repeat(8) @(negedge hclk);
 if(underflows!=0 || !display_ok || reader.return_bad || nonzero_pixels<600000)
  $fatal(1,"AUTO4 display failed rows=%0d nonzero=%0d UF=%0d overflow=%0d",display_rows,nonzero_pixels,underflows,overflows);
 $display("PASS multi video raster: 600 rows/614400 requests, nonzero=%0d, competing DDR read/write, no underflow",nonzero_pixels);display_done=1;
end

integer nrows=600;reg [517:0] saved_meta;integer row,b,l,x,h,c,v,shift=0,present=1,holes=1,frame_no=0;
integer total[0:3],cnt[0:3],low[0:3],high[0:3],edge_n[0:3],edge_c[0:3],edge_s[0:3];
integer luma,px,py;
always @(posedge clk) if(rst) begin
 if(dut.awb_pixel_sof) for(integer p=0;p<4;p++) begin total[p]=0;cnt[p]=0;low[p]=255;high[p]=0;edge_n[p]=0;edge_c[p]=0;edge_s[p]=0;end
 if(dut.roi_accept) for(integer p=0;p<4;p++) for(integer k=0;k<4;k++) begin
  px=dut.pocket_x0[p*11+:11];py=dut.pocket_y0[p*10+:10];
  if(dut.pocket_mask[p] && dut.roi_x+k>=px && dut.roi_x+k<px+80 && dut.roi_y>=py && dut.roi_y<py+80) begin
   luma=(int'(dut.awb_O_tdata[95-k*24-:8])+2*int'(dut.awb_O_tdata[87-k*24-:8])+int'(dut.awb_O_tdata[79-k*24-:8]))/4;
   total[p]+=luma;cnt[p]++;if(luma<low[p]) low[p]=luma;if(luma>high[p]) high[p]=luma;
  end
 end
 if(dut.gradient_valid) for(integer p=0;p<4;p++) for(integer k=0;k<4;k++) begin
  px=dut.pocket_x0[p*11+:11];py=dut.pocket_y0[p*10+:10];
  if(dut.pocket_mask[p] && dut.gradient_neighborhood[k] && dut.gradient_x+k>=px && dut.gradient_x+k<px+80 && dut.gradient_y>=py && dut.gradient_y<py+80) begin
   edge_n[p]++;edge_s[p]+=dut.gradient_magnitudes[k*11+:11];if(dut.gradient_magnitudes[k*11+:11]>=80) edge_c[p]++;
  end
 end
end
task ticks(input integer n);begin repeat(n) @(negedge clk);end endtask
task frame(input integer move,input integer part,input integer have_holes,input integer expected_lock,input integer mode);
 begin
  saved_meta=completed_meta;frame_no=frame_no+1;shift=move;present=part;holes=have_holes;request=mode;
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
      if((h%2)==0 && present && row>=324 && row<396 && x>=c-36 && x<c+36) v=(x/4+row/4)%2 ? 700 : 1000;
     end
     raw[39-l*10-:10]=v;
    end
    ticks(1);rv=0;ticks(1);
   end
   hs=0;ticks(80);
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
  if(!cap || !writer.published || writer.writer_epoch!=frame_no || completed_meta!==meta) $fatal(1,"AUTO4 full frame/metadata writer did not publish atomically epoch=%0d frame=%0d",writer.writer_epoch,frame_no);
  if(!mready || !good || bad) $fatal(1,"actual ISP tracking frame incomplete %0d",frame_no);
  if(meta[137]!==expected_lock) $fatal(1,"actual ISP lock %0d expected %0d got %b",frame_no,expected_lock,meta[137]);
  if(meta[169:138]!={16'd2244,16'd48} || meta[114:0]!=={dut.wb_frame_request,obs[82:46],dut.observation_tag,obs[27:0]} || meta[136:126]!=dut.track_x0 || meta[125:115]!=dut.track_x1) $fatal(1,"actual ISP metadata mixed epochs/coords/results");
  for(integer p=0;p<4;p++) begin
   if(meta[178+p*85+63]!==expected_lock) $fatal(1,"actual ISP pocket validity frame=%0d bank=%0d got=%b diag=%h",frame_no,p,meta[178+p*85+63],meta[177:170]);
   if(expected_lock) begin
    if(cnt[p]!=6400 || meta[178+p*85+53+:8]!=total[p]/6400 || meta[178+p*85+45+:8]!=low[p] || meta[178+p*85+37+:8]!=high[p]) $fatal(1,"actual ISP independent bank features");
    if(mode>=2 && (edge_n[p]!=6400 || meta[178+p*85+24+:13]!=edge_c[p] || meta[178+p*85+:24]!=edge_s[p])) $fatal(1,"actual ISP edge bank features");
    if(mode<2 && meta[178+p*85+61+:2]!=(total[p]>=6400*58 ? 2 : 3)) $fatal(1,"actual ISP bank class");
   end else if(meta[178+p*85+61+:2]!=1) $fatal(1,"invalid actual ISP bank retained classification");
  end
  if(meta[178+:340]!==dut.pocket_records) $fatal(1,"multi metadata mixed epoch");
  $display("OBS actual multi frame=%0d mode=%0d move=%0d lock=%0d mask=%b verified=%b first_mean=%0d",frame_no,mode,move,expected_lock,dut.pocket_mask,dut.pocket_verified,mean);
  end
 end
endtask
initial begin
 ticks(8);rst=1;ticks(20);
 frame(0,1,1,0,1);frame(0,1,1,0,1);frame(0,1,1,1,1);
 frame(4,1,1,1,0);frame(0,1,1,1,2);frame(4,1,1,1,3);
 wait(display_done);
 if(accepted_frames<3) $fatal(1,"insufficient complete frames under competing reader");
 if(overflows!=0) $fatal(1,"AUTO4 capture overflow under competing reader");
 $display("PASS multi video: actual correction/RAW10/vendor RAM/518-bit metadata/DDR reader arbitration; accepted=%0d rejected=%0d; complete 614400-pixel raster, no underflow, bad view preserves previous slot",accepted_frames,rejected_frames);$finish;
end
initial begin #100000000;$fatal(1,"actual ISP tracking watchdog");end
endmodule
