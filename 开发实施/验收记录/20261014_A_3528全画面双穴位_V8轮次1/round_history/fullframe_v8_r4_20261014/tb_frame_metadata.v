`timescale 1ns/1ps
module tb_frame_metadata;
reg cclk=0,dclk=0,rst=0,fs=0,cv=0,good=0,bad=0,mready=0;
reg [349:0] meta=0;wire ready,cap;wire [349:0] completed;
always #4.444 cclk=~cclk;always #7.5 dclk=~dclk;
video_in #(.WIDTH(32),.HEIGHT(4),.METADATA(1),.META_WIDTH(350),.METADATA_REQUIRED(0),.METADATA_WAIT_CYCLES(200)) dut(
 .I_rst_n(rst),.I_camera_clk(cclk),.I_camera_frame_start(fs),.I_camera_valid(cv),.I_camera_data(128'h123456),
 .I_mipi_rx_error(1'b0),.I_frame_good(good),.I_frame_bad(bad),.O_camera_ready(ready),
 .I_ddr_clk(dclk),.I_display_pause(1'b0),.I_video_out_rd_busy(1'b0),.I_active_valid(1'b0),.I_active_rp(2'd0),
 .O_capture_ok(cap),.I_ddr_user_ready(1'b1),.I_frame_metadata(meta),.I_frame_metadata_ready(mready),.O_completed_metadata(completed));
task start_frame;
 begin @(negedge cclk);cv=0;good=0;bad=0;mready=0;fs=1;@(negedge cclk);fs=0;wait(ready);repeat(4)@(negedge cclk);end
endtask
task pixels(input integer count);
 begin for(integer i=0;i<count;i++)begin @(negedge cclk);cv=1;end @(negedge cclk);cv=0;good=1;end
endtask
task wait_publish;
 begin for(integer n=0;n<600 && !dut.published;n++)@(negedge dclk);if(!dut.published || !cap || dut.written!=24)$fatal(1,"bounded full-frame publication failed");end
endtask
initial begin
 repeat(8)@(negedge cclk);rst=1;
 start_frame;pixels(24);wait(dut.complete_frame);repeat(60)@(negedge dclk);
 if(dut.published || dut.metadata_wait<60)$fatal(1,"writer published before late analysis");
 meta={152'h123456789abcdef123456789abcdef123456789,198'habcdef};mready=1;wait_publish;
 if(completed!==meta)$fatal(1,"late two-object tuple not atomic");
 start_frame;pixels(24);wait_publish;
 if(completed!=0 || dut.metadata_wait!=200)$fatal(1,"timeout reused old geometry or changed bound");
 meta={350{1'b1}};mready=1;repeat(40)@(negedge dclk);
 if(completed!=0)$fatal(1,"late metadata relabeled an already published video slot");
 start_frame;pixels(23);repeat(250)@(negedge dclk);
 if(dut.published)$fatal(1,"timeout published partial video");
 start_frame;meta={152'h789abcdef123456789abcdef123456789abcdef,198'h13579};mready=1;pixels(24);wait_publish;
 if(completed!==meta || dut.O_lost_frames!=1)$fatal(1,"new source epoch did not replace incomplete frame cleanly");
 start_frame;pixels(24);bad=1;repeat(300)@(negedge dclk);
 if(dut.published || cap)$fatal(1,"timeout bypassed native bad-frame proof");
 $display("PASS frame metadata: late matching dual tuple, exact bounded zero-result fallback, no late relabeling, partial-frame and bad-frame rejection, source epoch cancellation/recovery");$finish;
end
initial begin #1000000;$fatal(1,"frame metadata watchdog");end
endmodule
