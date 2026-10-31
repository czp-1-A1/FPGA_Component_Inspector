`timescale 1ns/1ps
module tb_relay_queue;
 reg clk=0;always #5 clk=~clk;
 reg rst_n=0,permit=1,start_run=0,clear_run=0,good_frame=1,bad_frame=0;
 reg [31:0] current_frame=0;reg [15:0] counter_run=0;reg [2:0] counter_state=2;
 reg direction_valid=1,direction_right=1,event_valid=0;reg [15:0] event_run=1;
 reg [8:0] event_id=0;reg [1:0] event_kind=3;
 wire [8:0] query_id;reg position_new=0;reg [8:0] position_id=0;
 reg [15:0] position_run=1;reg [31:0] position_frame=0;
 reg [10:0] position_x=0;reg [9:0] position_y=320;
 wire feed_enable,cycle_done;wire [2:0] state;wire [3:0] fault;wire [31:0] status;
 pocket_relay_stop #(.CLK_HZ(1000),.HOLD_MS(5),.STALE_MS(30)) dut(.*);
 integer completed=0;
 always @(negedge clk)if(cycle_done)completed++;
 task tick;@(negedge clk);endtask
 task event_add(input integer id);
  begin event_id=id;event_valid=1;tick;event_valid=0;tick;end
 endtask
 task position(input integer id,input integer x);
  begin current_frame++;position_frame=current_frame;position_id=id;position_x=x;position_new=1;
   tick;position_new=0;tick;end
 endtask
 task stop_and_hold(input integer id);
  begin position(id,736);position(id,760);position(id,760);position(id,760);
   if(state!=3 || feed_enable)$fatal(1,"wrong head hold ID%0d S%0d F%0d",id,state,fault);
  end
 endtask
 initial begin
  repeat(3)tick;rst_n=1;tick;start_run=1;tick;start_run=0;counter_run=1;tick;
  event_add(1);event_add(2);event_add(2);
  if(query_id!=1 || status[24:21]!=2)$fatal(1,"ordered distinct queue missing");
  stop_and_hold(1);repeat(7)tick;
  if(query_id!=2 || status[24:21]!=1 || completed!=1 || !feed_enable)$fatal(1,"did not resume with second head");
  position(1,770);if(!feed_enable || state!=1)$fatal(1,"old head position stopped second pocket");
  position(2,720);if(!feed_enable)$fatal(1,"second head stopped before trigger");
  stop_and_hold(2);repeat(7)tick;
  if(query_id!=0 || completed!=2 || !feed_enable)$fatal(1,"consecutive queue did not drain once each");
  event_add(3);stop_and_hold(3);
  wait(dut.phase_ms==4);@(negedge clk);counter_state=3;tick;
  if(state!=4 || query_id!=3 || completed!=2 || feed_enable)$fatal(1,"fault at hold expiry discarded pending ID");
  $display("PASS relay queue: two ordered EMPTY stops, duplicate suppression, old-position isolation, fault at expiry retains head");$finish;
 end
 initial begin #100000;$fatal(1,"queue timeout");end
endmodule
