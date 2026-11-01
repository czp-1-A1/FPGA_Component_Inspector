`timescale 1ns/1ps
module tb_d3_essential_cdc;
 reg S_process_clk=0,S_hdmi_pixel_clk=0,I_sys_clk=0,S_csi_rx_clk=0,S_ddr_clk=0,S_rst_n=0;
 always #5 S_process_clk=~S_process_clk;always #11 S_hdmi_pixel_clk=~S_hdmi_pixel_clk;
 always #7 I_sys_clk=~I_sys_clk;always #9 S_csi_rx_clk=~S_csi_rx_clk;always #13 S_ddr_clk=~S_ddr_clk;
 reg motor_output=0;reg [2:0] relay_mode=0;reg [191:0] relay_diagnostic=0;reg [127:0] relay_status=0;
 reg [15:0] mon_width=0,mon_height=0,mon_fps=0,mon_lane=0,mon_format=0,mon_gap=0;
 reg [31:0] mon_frames=0,mon_seconds=0,wb_active=0;reg [35:0] video_diagnostics=0;
 reg [15:0] overflow_frames=0,lost_frames=0;reg capture_ok=0;reg [26:0] publish_diagnostic=0;
 extracted_r56_ui_cones #(.ESSENTIAL_UI(1)) dut(.*);
 extracted_r56_ui_cones #(.ESSENTIAL_UI(0)) baseline(.*);
 integer checks=0,seed=32'h56a12348;
 always @(negedge S_process_clk)if(S_rst_n)begin
  relay_status={$random(seed),$random(seed),$random(seed),$random(seed)};
  relay_diagnostic={$random(seed),$random(seed),$random(seed),$random(seed),$random(seed),$random(seed)};
  relay_mode=$random(seed);motor_output=$random(seed);overflow_frames=$random(seed);video_diagnostics=$random(seed);
 end
 always @(negedge I_sys_clk)if(S_rst_n)begin
  mon_width=$random(seed);mon_height=$random(seed);mon_fps=$random(seed);mon_lane=$random(seed);
  mon_format=$random(seed);mon_gap=$random(seed);mon_frames=$random(seed);mon_seconds=$random(seed);
 end
 always @(negedge S_csi_rx_clk)if(S_rst_n)wb_active=$random(seed);
 always @(negedge S_ddr_clk)if(S_rst_n)begin capture_ok=$random(seed);lost_frames=$random(seed);publish_diagnostic=$random(seed);end
 always @(posedge S_hdmi_pixel_clk)begin
  #2;
  if(S_rst_n)begin
   if({dut.relay_display_motor,dut.relay_display_mode,dut.relay_display_status[92:89],dut.relay_display_status[28:25]}!==
      {baseline.relay_display_motor,baseline.relay_display_mode,baseline.relay_display_status[92:89],baseline.relay_display_status[28:25]})$fatal(1,"relay atom or latency changed");
   if(dut.mon_display[159:112]!==baseline.mon_display[159:112])$fatal(1,"monitor atom or latency changed");
   if(dut.transport_display!==baseline.transport_display)$fatal(1,"transport guard changed");
   if(dut.mon_display[111:0]!==0 || dut.relay_display_diagnostic!==0 || dut.publish_display!==0 || dut.overflow_display!==0)$fatal(1,"removed debug channel leaked");
   checks++;
  end
 end
 initial begin
  repeat(12)@(negedge S_process_clk);S_rst_n=1;
  repeat(3000)@(negedge S_hdmi_pixel_clk);S_rst_n=0;
  repeat(12)@(negedge S_process_clk);S_rst_n=1;
  repeat(3000)@(negedge S_hdmi_pixel_clk);
  if(checks<5995)$fatal(1,"CDC coverage missing");
  $display("PASS ESSENTIAL CDC: %0d destination checks, 2 reset epochs, exact retained fields/latency vs original full mailbox, five asynchronous clocks, actual extracted top cones, removed debug zeros",checks);$finish;
 end
 initial begin #300000;$fatal(1,"CDC watchdog");end
endmodule
