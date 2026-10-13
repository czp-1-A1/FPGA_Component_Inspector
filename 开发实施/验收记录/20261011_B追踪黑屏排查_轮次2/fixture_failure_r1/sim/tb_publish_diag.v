`timescale 1ns/1ps
module tb_publish_diag;
reg cclk=0,dclk=0,rst=0,fs=0,cv=0,good=0,bad=0,mready=0;
reg [177:0] meta=0;
always #5 cclk=~cclk;always #3 dclk=~dclk;
wire ready,cap,wen;wire [24:0] diagnostic;
video_in #(.WIDTH(32),.HEIGHT(4),.METADATA(1),.META_WIDTH(178)) dut(
 .I_rst_n(rst),.I_camera_clk(cclk),.I_camera_frame_start(fs),.I_camera_valid(cv),.I_camera_data(128'd0),
 .I_mipi_rx_error(1'b0),.I_frame_good(good),.I_frame_bad(bad),.O_camera_ready(ready),
 .I_ddr_clk(dclk),.I_display_pause(1'b0),.I_video_out_rd_busy(1'b0),.I_active_valid(1'b0),.I_active_rp(2'd0),
 .O_video_in_wr_busy(),.O_video_out_rp(),.O_completed_valid(),.O_completed_rp(),
 .O_capture_ok(cap),.O_lost_frames(),.O_overflow_frames(),.O_ddr_user_wr_en(wen),.O_ddr_user_addr(),
 .O_ddr_user_wr_data(),.I_ddr_user_ready(1'b1),.I_frame_metadata(meta),.I_frame_metadata_ready(mready),
 .O_completed_metadata(),.O_publish_diagnostic(diagnostic));
integer n;
task start_frame;
 begin
  @(negedge cclk);mready=0;good=0;bad=0;fs=1;
  @(negedge cclk);fs=0;wait(ready);repeat(4) @(negedge cclk);
 end
endtask
task send_words(input integer count);
 begin
  for(n=0;n<count;n=n+1) begin @(negedge cclk);cv=1;end
  @(negedge cclk);cv=0;
 end
endtask
task check_snapshot(input [7:0] flags,input integer count);
 begin
  if(diagnostic!=={flags,count[16:0]})
   $fatal(1,"snapshot expected P%h/W%0d got P%h/W%0d",flags,count,diagnostic[24:17],diagnostic[16:0]);
 end
endtask
initial begin
 repeat(10) @(negedge cclk);rst=1;start_frame();check_snapshot(8'h00,0);
 send_words(24);good=1;mready=1;wait(cap);repeat(30) @(negedge cclk);
 start_frame();check_snapshot(8'hfb,24);
 // No done, no good: the short frame stays in FIFO and never publishes.
 send_words(20);mready=1;repeat(100) @(negedge cclk);
 if(cap) $fatal(1,"short frame published");
 start_frame();check_snapshot(8'h61,0);
 // Complete pixels and proof, but current metadata is not ready.
 send_words(24);good=1;repeat(200) @(negedge cclk);
 if(cap || dut.written!=24) $fatal(1,"metadata wait altered pixel gate");
 start_frame();check_snapshot(8'h5b,24);
 send_words(24);good=1;mready=1;wait(cap);repeat(30) @(negedge cclk);
 start_frame();check_snapshot(8'hfb,24);
 send_words(10);bad=1;mready=1;repeat(100) @(negedge cclk);
 if(cap) $fatal(1,"bad frame published");
 start_frame();check_snapshot(8'h65,0);
 @(negedge cclk);rst=0;repeat(10) @(negedge cclk);check_snapshot(8'h00,0);
 rst=1;start_frame();send_words(24);good=1;mready=1;
 // Explicit boundary injection: a closing FS coincides with the final MC
 // command. The diagnostic must count it; publication must still reject FS.
 wait(dut.written==23 && wen);@(negedge dclk);
 if(dut.written!=23 || !wen) $fatal(1,"missed final command boundary");
 force dut.frame_sync=3'b010;
 @(posedge dclk);#1;
 if(diagnostic[16:0]!=24 || !diagnostic[18] || diagnostic[24])
  $fatal(1,"closing command missing or incorrectly published");
 @(negedge dclk);release dut.frame_sync;
 $display("PASS publish diagnostic: first FS/reset, complete/short/metadata wait/bad/recovery, no cross-frame inheritance, closing MC command");$finish;
end
initial begin #1000000;$fatal(1,"publish diagnostic watchdog");end
endmodule
