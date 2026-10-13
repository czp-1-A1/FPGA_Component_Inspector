`timescale 1ns/1ps
module tb_frame_metadata;
reg cclk=0,dclk=0,hclk=0,rst=0,fs=0,cv=0,good=0,bad=0,mready=0,vs=0;
reg [127:0] pixels=0;reg [169:0] meta=0;
always #5 cclk=~cclk;always #3 dclk=~dclk;always #7 hclk=~hclk;
wire ready,complete,active,cbusy,rbusy,cap,wen,ren,display_ok;
wire [1:0] completed_slot,active_slot;wire [169:0] completed_meta,active_meta;
wire [24:0] wa,ra;wire [127:0] wd;
reg [1:0] rd_pipe=0;always @(posedge dclk) rd_pipe<={rd_pipe[0],ren};
video_in #(.WIDTH(32),.HEIGHT(4),.METADATA(1)) writer(
 .I_rst_n(rst),.I_camera_clk(cclk),.I_camera_frame_start(fs),.I_camera_valid(cv),.I_camera_data(pixels),
 .I_mipi_rx_error(1'b0),.I_frame_good(good),.I_frame_bad(bad),.O_camera_ready(ready),
 .I_ddr_clk(dclk),.I_display_pause(1'b0),.I_video_out_rd_busy(rbusy),.I_active_valid(active),.I_active_rp(active_slot),
 .O_video_in_wr_busy(cbusy),.O_video_out_rp(),.O_completed_valid(complete),.O_completed_rp(completed_slot),
 .O_capture_ok(cap),.O_lost_frames(),.O_overflow_frames(),.O_ddr_user_wr_en(wen),.O_ddr_user_addr(wa),
 .O_ddr_user_wr_data(wd),.I_ddr_user_ready(1'b1),.I_frame_metadata(meta),.I_frame_metadata_ready(mready),.O_completed_metadata(completed_meta));
video_out #(.WIDTH(32),.HEIGHT(4)) reader(
 .I_rst_n(rst),.I_ddr_clk(dclk),.O_video_out_rd_busy(rbusy),.I_video_in_wr_busy(cbusy),
 .I_video_out_rp(completed_slot),.I_completed_valid(complete),.I_completed_rp(completed_slot),
 .O_active_valid(active),.O_active_rp(active_slot),.O_ddr_user_rd_en(ren),.O_ddr_user_addr(ra),
 .I_ddr_user_ready(1'b1),.I_ddr_user_rd_valid(rd_pipe[1]),.I_ddr_user_rd_data(128'd0),
 .I_dsi_clk(hclk),.I_video_vsync(vs),.I_video_rd_en(1'b0),.O_vdieo_data(),.O_display_ok(display_ok),.O_underflow_frames(),
 .I_completed_metadata(completed_meta),.O_active_metadata(active_meta));
integer n;
task capture(input integer id);
 begin
  @(negedge cclk);mready=0;good=0;fs=1;@(negedge cclk);fs=0;
  wait(ready);repeat(4) @(negedge cclk);
  for(n=0;n<24;n=n+1) begin @(negedge cclk);cv=1;pixels=n;end
  @(negedge cclk);cv=0;good=1;
  // Complete pixels cannot publish an old result while the new result is pending.
  repeat(200) @(negedge cclk);
  if(complete && completed_meta==id) $fatal(1,"published pending metadata");
  @(negedge cclk);meta=id;mready=1;
  wait(cap && completed_meta==id);repeat(20) @(negedge cclk);
 end
endtask
task select_frame(input integer id);
 begin
  @(negedge hclk);vs=1;repeat(30) @(negedge hclk);vs=0;
  wait(active && active_meta==id);repeat(30) @(negedge hclk);
  if(active_slot!=completed_slot) $fatal(1,"metadata selected from different DDR slot");
 end
endtask
initial begin
 repeat(10) @(negedge cclk);rst=1;
 capture(101);select_frame(101);
 capture(202);
 if(active_meta!=101) $fatal(1,"new capture changed metadata of displayed old slot");
 select_frame(202);
 // A bad acquisition may not publish pixels or metadata.
 @(negedge cclk);mready=0;fs=1;good=0;@(negedge cclk);fs=0;bad=1;meta=303;mready=1;
 repeat(100) @(negedge cclk);
 if(completed_meta!=202) $fatal(1,"bad frame replaced completed metadata");
 $display("PASS frame metadata: epoch gating, late result, protected old active slot, atomic new slot, bad capture");$finish;
end
initial begin #1000000;$fatal(1,"frame metadata watchdog");end
endmodule
