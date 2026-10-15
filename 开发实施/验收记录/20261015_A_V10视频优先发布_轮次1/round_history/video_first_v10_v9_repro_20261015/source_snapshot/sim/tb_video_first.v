`timescale 1ns/1ps
module tb_video_first;
reg cclk=0,dclk=0,rst=0,fs=0,cv=0,good=0,bad=0,mready=0;
reg [349:0] meta=0;wire ready,cap,completed_valid;wire [349:0] completed;
wire [25:0] diagnostic;
always #5 cclk=~cclk;always #7.5 dclk=~dclk;
video_in #(.WIDTH(32),.HEIGHT(4),.METADATA(1),.META_WIDTH(350),.METADATA_REQUIRED(0),.METADATA_WAIT_CYCLES(200)) dut(
 .I_rst_n(rst),.I_camera_clk(cclk),.I_camera_frame_start(fs),.I_camera_valid(cv),.I_camera_data(128'h123456),
 .I_mipi_rx_error(1'b0),.I_frame_good(good),.I_frame_bad(bad),.O_camera_ready(ready),
 .I_ddr_clk(dclk),.I_display_pause(1'b0),.I_video_out_rd_busy(1'b0),.I_active_valid(1'b0),.I_active_rp(2'd0),
 .O_capture_ok(cap),.O_completed_valid(completed_valid),.I_ddr_user_ready(1'b1),
 .I_frame_metadata(meta),.I_frame_metadata_ready(mready),.O_completed_metadata(completed),.O_publish_diagnostic(diagnostic));

task start_frame;
 begin @(negedge cclk);cv=0;good=0;bad=0;mready=0;fs=1;@(negedge cclk);fs=0;wait(ready);repeat(4)@(negedge cclk);end
endtask
task pixels(input integer count);
 begin for(integer i=0;i<count;i++)begin @(negedge cclk);cv=1;end @(negedge cclk);cv=0;good=1;end
endtask
task prompt_video;
 begin
  wait(dut.complete_frame);repeat(16)@(negedge dclk);
  if(!dut.published || !completed_valid || !cap || dut.written!=24 || completed!=0)begin
   $display("REPRO video blocked: Pseen=%h words=%0d complete=%b wait=%0d published=%b",dut.publish_seen,dut.written,dut.complete_frame,dut.metadata_wait,dut.published);
   $fatal(1,"complete video must display before an analysis result; next frame can arrive before legacy timeout");
  end
 end
endtask
initial begin
 repeat(8)@(negedge cclk);rst=1;
 start_frame;pixels(24);prompt_video;
 // Result arrives in this same source epoch, after video was made available.
 meta=350'h123456789abcdef;mready=1;repeat(32)@(negedge dclk);
 if(completed!==meta)$fatal(1,"same-frame late result was not attached to its completed video slot");
 mready=0;meta=350'hbad;repeat(32)@(negedge dclk);
 if(completed!==350'h123456789abcdef)$fatal(1,"attached tuple changed after its one allowed update");
 start_frame;pixels(24);prompt_video;
 // A following source FS arrives before the old 200-cycle wait can expire.
 start_frame;meta=350'h555;mready=1;pixels(23);repeat(220)@(negedge dclk);
 if(dut.published || cap || completed!=0)$fatal(1,"partial next frame relabeled the previous complete video");
 start_frame;pixels(24);bad=1;repeat(220)@(negedge dclk);
 if(dut.published || cap)$fatal(1,"video-first bypassed bad-frame proof");
 start_frame;pixels(24);prompt_video;
 $display("PASS video first: prompt complete video despite slower analysis, one same-epoch tuple attachment, no replacement after ready drops, next epoch/partial/bad rejection and recovery");$finish;
end
initial begin #1000000;$fatal(1,"video-first watchdog");end
endmodule
