`timescale 1ns/1ps
module tb_video_metadata_fallback;
reg cclk=0,dclk=0,rst=0,fs=0,cv=0,good=0,bad=0,mready=0;
reg [517:0] meta=0,saved;
always #4.444 cclk=~cclk;always #7.5 dclk=~dclk;
wire ready,cap,complete,strict_cap;wire [517:0] completed_meta,strict_meta;
wire [25:0] diagnostic;
video_in #(.WIDTH(32),.HEIGHT(4),.METADATA(1),.META_WIDTH(518),.METADATA_REQUIRED(0)) dut(
 .I_rst_n(rst),.I_camera_clk(cclk),.I_camera_frame_start(fs),.I_camera_valid(cv),.I_camera_data(128'h1234),
 .I_mipi_rx_error(1'b0),.I_frame_good(good),.I_frame_bad(bad),.O_camera_ready(ready),
 .I_ddr_clk(dclk),.I_display_pause(1'b0),.I_video_out_rd_busy(1'b0),.I_active_valid(1'b0),.I_active_rp(2'd0),
 .O_completed_valid(complete),.O_capture_ok(cap),.I_ddr_user_ready(1'b1),
 .I_frame_metadata(meta),.I_frame_metadata_ready(mready),.O_completed_metadata(completed_meta),.O_publish_diagnostic(diagnostic));
video_in #(.WIDTH(32),.HEIGHT(4),.METADATA(1),.META_WIDTH(518)) strict_writer(
 .I_rst_n(rst),.I_camera_clk(cclk),.I_camera_frame_start(fs),.I_camera_valid(cv),.I_camera_data(128'h1234),
 .I_mipi_rx_error(1'b0),.I_frame_good(good),.I_frame_bad(bad),.O_camera_ready(),
 .I_ddr_clk(dclk),.I_display_pause(1'b0),.I_video_out_rd_busy(1'b0),.I_active_valid(1'b0),.I_active_rp(2'd0),
 .O_capture_ok(strict_cap),.I_ddr_user_ready(1'b1),.I_frame_metadata(meta),.I_frame_metadata_ready(mready),.O_completed_metadata(strict_meta));
task start_frame;
 begin
  @(negedge cclk);good=0;bad=0;mready=0;fs=1;
  @(negedge cclk);fs=0;wait(ready);repeat(4) @(negedge cclk);
 end
endtask
task pixels(input integer count);
 begin
  for(integer i=0;i<count;i++) begin @(negedge cclk);cv=1;end
  @(negedge cclk);cv=0;good=1;repeat(200) @(negedge cclk);
 end
endtask
initial begin
 repeat(10) @(negedge cclk);rst=1;
 start_frame();meta={178'h111,340'h123};mready=1;pixels(24);
 if(!complete || !cap || !strict_cap || completed_meta!==meta || strict_meta!==meta || diagnostic[25]) $fatal(1,"normal metadata not bound atomically");
 start_frame();meta={178'h222,340'h456};pixels(24);
 if(!cap || !dut.published || completed_meta!==518'd0 || strict_writer.published) $fatal(1,"missing metadata blocked video or retained old labels");
 if(!diagnostic[25] || diagnostic[16:0]!=={1'b0,8'd2,8'd2}) $fatal(1,"missing result diagnostic epoch/ready snapshot wrong");
 mready=1;repeat(200) @(negedge cclk);
 if(completed_meta!==518'd0 || !strict_cap || strict_meta!==meta) $fatal(1,"late metadata changed an already published AUTO4 slot or default strict behavior");
 start_frame();mready=1;bad=1;pixels(24);
 if(dut.published || cap || completed_meta!==518'd0) $fatal(1,"bad pixels bypassed integrity gate");
 start_frame();mready=1;pixels(20);
 if(dut.published || cap || completed_meta!==518'd0) $fatal(1,"short pixels bypassed exact-word gate");
 start_frame();meta={178'h333,340'h789};mready=1;pixels(24);
 if(!cap || !strict_cap || completed_meta!==meta || diagnostic[25]) $fatal(1,"next matching frame did not restore labels");
 saved=completed_meta;start_frame();mready=1;
 // A ready packet belonging to another frame may only supply zero metadata.
 force dut.metadata_receive={16'd0,1'b1,518'hbad};pixels(24);
 if(!cap || completed_meta!==518'd0 || !diagnostic[25] || diagnostic[16:0]!=={1'b1,8'd0,8'd6}) $fatal(1,"wrong epoch exposed stale labels or wrong M diagnostic");
 release dut.metadata_receive;
 start_frame();meta={178'h444,340'habc};mready=1;pixels(24);
 if(!cap || completed_meta!==meta || diagnostic[25]) $fatal(1,"wrong-epoch recovery failed");
 @(negedge cclk);rst=0;repeat(10) @(negedge cclk);
 if(complete || completed_meta!==518'd0 || diagnostic!==26'd0) $fatal(1,"reset retained completed slot");
 $display("PASS video metadata fallback: normal/absent/late/wrong epoch/recovery, no stale four-pocket labels, strict legacy mode, bad and short pixels rejected, W/M snapshot and reset");$finish;
end
initial begin #1000000;$fatal(1,"video metadata fallback watchdog");end
endmodule
