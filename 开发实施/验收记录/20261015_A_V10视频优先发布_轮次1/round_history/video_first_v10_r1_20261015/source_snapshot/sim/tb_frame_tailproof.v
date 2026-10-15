`timescale 1ns/1ps
// Real RAW10 bridge, demosaic, vendor ERAM, manual WB, Sobel and divider.
module tb_frame_tailproof;
reg clk=0,rst=0,fs=0,fe=0,hs=0,rv=0;reg [39:0] raw=0;
wire av,asof,alast;wire [39:0] adata;
always #4.444 clk=~clk;reg dclk=0;always #7.5 dclk=~dclk;
wire cav,casof,calast;wire [39:0] cadata;
image_correction correction(.I_clk(clk),.I_rst_n(rst),.I_raw_data(adata),.I_raw_valid(av),
 .I_raw_frame_start(asof),.I_raw_frame_end(alast),.O_raw_tdata(cadata),.O_raw_tlast(calast),
 .O_raw_tvalid(cav),.O_raw_tuser(casof),.O_raw_tready(1'b1));

// Same native packet window as the production wrapper; guard receives raw rv.
reg native_packet_open=0;
always @(posedge clk or negedge rst)begin
 if(!rst)native_packet_open<=0;else if(fs)native_packet_open<=1;else if(fe)native_packet_open<=0;
end
uial2axis #(.IMG_WIDTH(1024),.IMG_HEIGHT(600),.INPUT_DATA_WIDTH(40)) bridge(clk,rst,raw,rv && native_packet_open && !fe,fs,fe,av,adata,asof,alast);
wire read_busy,write_busy,active_valid,completed_valid,wen,ren;
wire [1:0] active_slot,completed_slot;wire [24:0] waddr,raddr;
wire [127:0] wdata;wire [349:0] active_meta;wire [15:0] overflows,underflows;
wire sv,mready,good,bad;wire [7:0] mean;wire [349:0] meta;wire [114:0] obs;
reg [17:0] request=1;reg [31:0] wb_request=32'h00006464;
wire [127:0] video;wire vv,vsof,view_ready,cap;wire [349:0] completed_meta;
video_in #(.METADATA(1),.META_WIDTH(350),.METADATA_REQUIRED(0),.METADATA_WAIT_CYCLES(1500000)) writer(
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
 .observation_request(request),.wb_request(wb_request),.wb_active(),.observation_record(obs),.display_record(),
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
video_out #(.META_WIDTH(350)) reader(
 .I_rst_n(rst),.I_ddr_clk(dclk),.O_video_out_rd_busy(read_busy),.I_video_in_wr_busy(write_busy),
 .I_video_out_rp(completed_slot),.I_completed_valid(completed_valid),.I_completed_rp(completed_slot),
 .O_active_valid(active_valid),.O_active_rp(active_slot),.O_active_metadata(active_meta),.I_completed_metadata(completed_meta),
 .O_ddr_user_rd_en(ren),.O_ddr_user_addr(raddr),.I_ddr_user_ready(1'b1),
 .I_ddr_user_rd_valid(read_pipe[3]),.I_ddr_user_rd_data(data_pipe[3]),
 .I_dsi_clk(hclk),.I_video_vsync(vs),.I_video_rd_en(rd),.O_vdieo_data(display_rgb),
 .O_display_ok(display_ok),.O_underflow_frames(underflows));
reg [349:0] slot_truth[0:3];reg published_d=0;
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

integer row,b,l,x,v,frame_no=0,pgm,pattern=0,shift=0,move_y=0;
reg bad_d=0;
always @(posedge clk)begin
 bad_d<=bad;
 if(rst && bad && !bad_d)$display("DIAG full fault frame=%0d reason=%h guard_bad=%b raw_done=%b processed_done=%b reported=%b roi_invalidate=%b awb_valid=%b pixel_sof=%b view_bad=%b tag=%h/%h wb=%h/%h nativeFS/FE=%b/%b",frame_no,dut.video_reject_reason,dut.u_roi_guard.bad,dut.u_roi_guard.raw_done,dut.u_roi_guard.processed_done,dut.u_roi_guard.reported,dut.roi_invalidate,dut.awb_O_tvalid,dut.awb_pixel_sof,dut.view_frame_bad,dut.observation_tag,request,dut.wb_frame_request,wb_request,fs,fe);
end
integer luma[0:614399];reg [349:0] before_meta;integer commits=0,post_cycles=0;
reg [75:0] aa,bb;
always @(posedge clk)if(rst)begin
 if(dut.roi_commit)commits++;
 if(dut.roi_accept)for(integer k=0;k<4;k++)luma[dut.roi_y*1024+dut.roi_x+k]=(int'(dut.awb_O_tdata[95-k*24-:8])+2*int'(dut.awb_O_tdata[87-k*24-:8])+int'(dut.awb_O_tdata[79-k*24-:8]))/4;
end
function integer source(input integer px,py);
 integer dx,dy;begin
 source=80;
 if(pattern==3)source=px>=40 && px<984 && py>=180 && py<440 ? 80 : 960;
 if(px>=424+shift && px<488+shift && py>=262+move_y && py<338+move_y)source=720;
 if(pattern==2)begin dx=px-552-shift;dy=py-300-move_y;if(dx*dx+dy*dy<=81)source=600;end
 else if(px>=520+shift && px<584+shift && py>=262+move_y && py<338+move_y)source=720;
 if(pattern==1 && px>=444+shift && px<468+shift && py>=280+move_y && py<320+move_y)source=80;
 end
endfunction
task ticks(input integer n);begin repeat(n)@(negedge clk);end endtask
task frame(input integer kind,mode,dx,dy);
 begin
 @(negedge clk);before_meta=completed_meta;frame_no++;pattern=kind;shift=dx;move_y=dy;request=mode;commits=0;
 fs=1;ticks(1);fs=0;ticks(48);
 for(row=0;row<600;row++)begin
  hs=1;ticks(3);
  for(b=0;b<256;b++)begin
   if(kind==4 && row==200 && b==100)wb_request=32'h00016464;
   if(kind==5 && row==200 && b==100)request=request+4;
   rv=1;for(l=0;l<4;l++)raw[39-l*10-:10]=10'(source(b*4+l,row));ticks(1);rv=0;ticks(1);
  end
  hs=0;ticks(200);
 end
 fe=1;ticks(1);fe=0;
 if(kind==6)begin
  ticks(40);if(!dut.frame_input_closed)$fatal(1,"post-proof fault fixture did not reach closed input");
  rv=1;ticks(1);rv=0;ticks(4);
 end
 // Full-frame analysis intentionally follows FE. Bound it inside the 27-FPS
 // frame period, and require it before DDR publication, not after publication.
 post_cycles=0;
 while(post_cycles<3000000 && !writer.published && !bad)begin ticks(1);post_cycles++;end
 // The truth monitor observes the registered publication on its next DDR edge.
 if(writer.published)repeat(2)@(negedge dclk);
 $display("DIAG full publication frame=%0d pub=%b cap=%b good=%b bad=%b commits=%0d slot=%0d truth_equal=%b metadata_ready=%b wait=%0d words=%0d",frame_no,writer.published,cap,good,bad,commits,completed_slot,completed_meta===slot_truth[completed_slot],mready,writer.metadata_wait,writer.written);
 if(frame_no==1 || kind==5 || kind==6)begin
  if(!bad || good || writer.published || completed_meta!==before_meta)$fatal(1,"bad native frame published dual metadata");
 end else begin
  if(!writer.published || !cap || !good || bad || commits!=1 || completed_meta!==slot_truth[completed_slot])$fatal(1,"full-frame video did not publish complete slot %0d",frame_no);
  if(kind==4)begin if(completed_meta!=0 || mready)$fatal(1,"canceled WB result inherited full-frame objects");end
  else begin
   if(!mready || completed_meta!==meta || obs[114:83]!==wb_request || obs[45:28]!==request)$fatal(1,"late metadata has wrong source epoch/config");
   aa=meta[198+:76];bb=meta[274+:76];
   if(!aa[75] || !bb[75] || aa[74:73]!=2 || bb[74:73]!=(kind==2 ? 3 : 2))$fatal(1,"native dual classes wrong A=%h B=%h",aa,bb);
   if(aa[41:31]>=bb[41:31])$fatal(1,"native pockets not independently ordered");
   pgm=$fopen($sformatf("native_full_%0d.pgm",frame_no),"w");$fwrite(pgm,"P2\n1024 600\n255\n");
   for(integer yy=0;yy<600;yy++)begin for(integer xx=0;xx<1024;xx++)$fwrite(pgm,"%0d ",luma[yy*1024+xx]);$fwrite(pgm,"\n");end
   $fclose(pgm);
   $display("REF native frame=%0d objects=%h state=%0d FG=%0d W=%0d H=%0d X0=%0d X1=%0d Y0=%0d Y1=%0d post_FE_cycles=%0d",frame_no,meta[349:198],dut.search_state,dut.search_fg,dut.search_w,dut.search_h,dut.search_x0,dut.search_x1,dut.search_y0,dut.search_y1,post_cycles);
  end
  accepted_frames++;
 end
 // Preserve the measured 27-FPS opportunity; a passing detector may not rely
 // on an arbitrarily long test-only blanking interval or hidden extra frame.
 if(post_cycles<3750000)ticks(3750000-post_cycles);
 end
endtask
initial begin
 ticks(8);rst=1;ticks(20);
 frame(0,0,0,0);frame(6,3,0,0);frame(0,3,0,0);
 wait(display_done);@(negedge hclk);vs=1;repeat(1000)@(negedge hclk);vs=0;repeat(30000)@(negedge hclk);
 if(active_meta!==slot_truth[active_slot] || !active_meta[349] || !active_meta[273] || active_meta[24]!=1)$fatal(1,"post-fault recovery did not bind both objects to valid pixels");
 if(accepted_frames!=1 || overflows!=0 || underflows!=0)$fatal(1,"post-proof fault escaped frame transport checks");
 $display("PASS frame tail proof: actual native extra RAW data after full-frame commit is rejected while input is closed; no bad-slot publication, complete dual recovery, full competing DDR raster and no OF/UF");$finish;
end
initial begin #450000000;$fatal(1,"full-frame video watchdog");end
endmodule
