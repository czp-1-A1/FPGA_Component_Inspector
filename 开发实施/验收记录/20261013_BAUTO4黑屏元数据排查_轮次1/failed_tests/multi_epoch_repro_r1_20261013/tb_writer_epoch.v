`timescale 1ns/1ps
// Two source frame starts inside the pulse extender coalesce at the DDR end.
// The next complete frame must recover without a permanently offset epoch.
module tb_writer_epoch;
reg cclk=0,dclk=0,rst=0,fs=0,cv=0,good=0,mready=0;
always #4.444 cclk=~cclk;always #7.5 dclk=~dclk;
wire ready,cap,complete;wire [177:0] completed_meta;
video_in #(.WIDTH(32),.HEIGHT(4),.METADATA(1),.META_WIDTH(178)) dut(
 .I_rst_n(rst),.I_camera_clk(cclk),.I_camera_frame_start(fs),.I_camera_valid(cv),.I_camera_data(128'h1234),
 .I_mipi_rx_error(1'b0),.I_frame_good(good),.I_frame_bad(1'b0),.O_camera_ready(ready),
 .I_ddr_clk(dclk),.I_display_pause(1'b0),.I_video_out_rd_busy(1'b0),.I_active_valid(1'b0),.I_active_rp(2'd0),
 .O_completed_valid(complete),.O_capture_ok(cap),.I_ddr_user_ready(1'b1),
 .I_frame_metadata(178'h12345678),.I_frame_metadata_ready(mready),.O_completed_metadata(completed_meta));
task marker;
 begin @(negedge cclk);fs=1;@(negedge cclk);fs=0;end
endtask
initial begin
 repeat(10) @(negedge cclk);rst=1;
 marker();repeat(2) @(negedge cclk);marker();
 repeat(30) @(negedge cclk);
 marker();wait(ready);repeat(4) @(negedge cclk);
 for(integer i=0;i<24;i++) begin @(negedge cclk);cv=1;end
 @(negedge cclk);cv=0;good=1;mready=1;
 repeat(200) @(negedge cclk);
 $display("OBS epochs source=%0d writer=%0d received=%0d ready=%b written=%0d seen=P%h",dut.camera_epoch,dut.writer_epoch,dut.metadata_receive[194:179],dut.metadata_receive[178],dut.written,dut.publish_seen);
 if(!complete || !cap || !dut.published || completed_meta!==178'h12345678)
  $fatal(1,"coalesced startup marker permanently blocked a complete frame");
 if(dut.writer_epoch!=dut.camera_epoch) $fatal(1,"writer did not bind source epoch");
 $display("PASS writer epoch: coalesced startup markers, next complete frame recovers with matching source epoch and metadata");$finish;
end
initial begin #100000;$fatal(1,"writer epoch watchdog");end
endmodule
