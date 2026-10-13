`timescale 1ns/1ps
// Real independent monitor window with the CSI clock itself stopped.
module tb_stop_recovery;
reg rx=0,refclk=0,pixel=0,run_rx=1,rst=0,fs=0,sn=0,sv=0;
always #4.444 if(run_rx) rx=~rx;
always #10 refclk=~refclk;
always #9.615 pixel=~pixel;
wire [15:0] fps,w,h,l,f,g;wire [31:0] frames,seconds;
input_monitor #(.REF_HZ(1000)) monitor(rx,refclk,rst,fs,1'b0,1'b0,1'b0,2'b0,w,h,l,f,fps,g,seconds,frames);
wire [27:0] sr,dr;wire valid;wire [1:0] state;
roi_result_snapshot snapshot(rx,rst,fs,1'b0,1'b0,sv,sn,2'd0,8'd85,8'd27,8'd255,sr);
status_cdc #(.WIDTH(28)) mailbox(rx,pixel,rst,sr,dr);
roi_display_state gate(pixel,rst,1'b1,16'd2244,16'd48,fps,1'b0,dr,18'd0,valid,state);
task fs_pulse;begin @(negedge rx);fs=1;@(negedge rx);fs=0;end endtask
task publish;begin
 @(negedge rx);sv=1;sn=1;@(negedge rx);sn=0;
 repeat(25) @(negedge pixel);
 if(!valid || state!==0) $fatal(1,"monitor recovery sample did not arm");
end endtask
integer scenario,ticks;
initial begin
 for(scenario=0;scenario<2;scenario=scenario+1) begin
  run_rx=1;rst=0;fs=0;sn=0;sv=0;repeat(5) @(negedge refclk);rst=1;
  fs_pulse;wait(fps!=0);repeat(45) @(negedge pixel);publish;
  // Stop immediately after an event at either end of the FPS window.
  wait(monitor.second_count==(scenario==0 ? 150 : 980));fs_pulse;
  if(fps==0) $fatal(1,"test must stop an active input window");
  @(negedge rx);run_rx=0;ticks=0;
  while(fps!=0 && ticks<2010) begin @(negedge refclk);ticks=ticks+1;end
  if(fps!=0 || ticks>2005) $fatal(1,"independent monitor stop bound %d",ticks);
  repeat(4) @(negedge pixel);
  if(valid || state!==1) $fatal(1,"stopped CSI record still valid");
  $display("OBS stop window phase=%0d clears in %0d reference clocks (REF_HZ=1000)",scenario,ticks);
  run_rx=1;fs_pulse;wait(fps!=0);repeat(45) @(negedge pixel);
  if(valid || state!==1) $fatal(1,"FPS returned without fresh completion");
  publish;
 end
 $display("PASS stop recovery: real monitor, independent 50MHz reference, two window boundaries, frozen CSI mailbox, no stale rearm, fresh UNCAL statistics");$finish;
end
initial begin #300000;$fatal(1,"stop/recovery watchdog");end
endmodule
