`timescale 1ns/1ps
// Complete pixels must remain readable even when AUTO4 metadata is absent.
module tb_video_fallback_display;
reg cclk=0,dclk=0,hclk=0,rst=0,fs=0,cv=0,good=0,mready=0,vs=0,rd=0;
reg [517:0] meta=0;
always #4.444 cclk=~cclk;always #7.5 dclk=~dclk;always #9.615 hclk=~hclk;
wire ready,complete,active,cbusy,rbusy,cap,ren,display_ok;
wire [1:0] completed_slot,active_slot;wire [517:0] completed_meta,active_meta;
wire [23:0] rgb;wire [15:0] underflows;
reg [3:0] read_pipe=0;always @(posedge dclk) read_pipe<={read_pipe[2:0],ren};
video_in #(.WIDTH(32),.HEIGHT(4),.METADATA(1),.META_WIDTH(518),.METADATA_REQUIRED(0)) writer(
 .I_rst_n(rst),.I_camera_clk(cclk),.I_camera_frame_start(fs),.I_camera_valid(cv),.I_camera_data({16{8'h5a}}),
 .I_mipi_rx_error(1'b0),.I_frame_good(good),.I_frame_bad(1'b0),.O_camera_ready(ready),
 .I_ddr_clk(dclk),.I_display_pause(1'b0),.I_video_out_rd_busy(rbusy),.I_active_valid(active),.I_active_rp(2'd0),
 .O_video_in_wr_busy(cbusy),.O_completed_valid(complete),.O_completed_rp(completed_slot),.O_capture_ok(cap),
 .I_ddr_user_ready(1'b1),.I_frame_metadata(meta),.I_frame_metadata_ready(mready),.O_completed_metadata(completed_meta));
video_out #(.WIDTH(32),.HEIGHT(4),.META_WIDTH(518)) reader(
 .I_rst_n(rst),.I_ddr_clk(dclk),.O_video_out_rd_busy(rbusy),.I_video_in_wr_busy(cbusy),
 .I_video_out_rp(completed_slot),.I_completed_valid(complete),.I_completed_rp(completed_slot),
 .O_active_valid(active),.O_active_rp(active_slot),.O_active_metadata(active_meta),.I_completed_metadata(completed_meta),
 .O_ddr_user_rd_en(ren),.O_ddr_user_addr(),.I_ddr_user_ready(1'b1),
 .I_ddr_user_rd_valid(read_pipe[3]),.I_ddr_user_rd_data({16{8'h5a}}),
 .I_dsi_clk(hclk),.I_video_vsync(vs),.I_video_rd_en(rd),.O_vdieo_data(rgb),.O_display_ok(display_ok),.O_underflow_frames(underflows));
reg previous_rd=0;integer checked=0;
always @(posedge hclk) begin
 #1;if(rst && previous_rd) begin
  if(rgb!==24'h5a5a5a) $fatal(1,"fallback pixel read is black/corrupt: %h",rgb);
  checked++;
 end
 previous_rd=rd;
end
task capture(input integer id,input integer has_result);
 begin
  @(negedge cclk);mready=0;good=0;fs=1;@(negedge cclk);fs=0;
  wait(ready);repeat(4) @(negedge cclk);meta=id;mready=has_result;
  for(integer i=0;i<24;i++) begin @(negedge cclk);cv=1;end
  @(negedge cclk);cv=0;good=1;repeat(200) @(negedge cclk);
  if(!cap || completed_meta!==(has_result ? 518'(id) : 518'd0)) $fatal(1,"wrong completed metadata/slot");
 end
endtask
task display(input integer id);
 begin
  @(negedge hclk);vs=1;repeat(100) @(negedge hclk);vs=0;repeat(100) @(negedge hclk);
  if(!active || active_meta!==518'(id) || active_slot!=completed_slot) $fatal(1,"reader failed to select fallback slot atomically");
  for(integer y=0;y<4;y++) begin
   for(integer x=0;x<32;x++) begin rd=1;@(negedge hclk);end
   rd=0;repeat(20) @(negedge hclk);
  end
  if(!display_ok || underflows || reader.return_bad || reader.issued!=24) $fatal(1,"fallback display transport failed");
 end
endtask
initial begin
 repeat(10) @(negedge cclk);rst=1;
 capture(101,1);display(101);
 capture(202,0);display(0);
 capture(303,1);display(303);
 if(checked!=384) $fatal(1,"incomplete pixel verification %0d",checked);
 $display("PASS video fallback display: 384 exact RGB pixels, normal/zero metadata/recovery slots, unchanged metadata binding, no black video or underflow");$finish;
end
initial begin #1000000;$fatal(1,"video fallback display watchdog");end
endmodule
