`timescale 1ns/1ps
// Actual production 100MHz / HOLD_MS=1000: no shortened timing parameter.
module tb_relay_left_real_second;
 reg clk=0;always #5 clk=~clk;
 reg rst_n=0,permit=0,start_run=0,clear_run=0,good_frame=0,bad_frame=0;
 reg [31:0] current_frame=0;reg [15:0] counter_run=0;reg [2:0] counter_state=2;
 reg direction_valid=1,direction_right=0,event_valid=0;reg [15:0] event_run=1;
 reg [8:0] event_id=1;reg [1:0] event_kind=3;
 wire [8:0] query_id;reg position_new=0;reg [8:0] position_id=1;
 reg [15:0] position_run=1;reg [31:0] position_frame=0;
 reg [10:0] position_x=160;reg [9:0] position_y=320;
 wire feed_enable,cycle_done;wire [2:0] state;wire [3:0] fault;wire [63:0] status;
 reg transport_occupied=0;reg [15:0] station_run=0;reg [2:0] station_state=2;
 reg station_dv=1,station_dr=0;reg [8:0] counter_total=0,station_total=0,counter_uncertainty=0,station_uncertainty=0;
 reg station_event_valid=0;reg [15:0] station_event_run=1;reg [8:0] station_event_id=1;reg [1:0] station_event_kind=3;
 pocket_relay_stop_v2 dut(.pause(1'b0),.*);
 integer i;time hold_start;
 task ticks(input integer n);repeat(n)@(negedge clk);endtask
 task sample(input integer x);
  begin current_frame++;position_frame=current_frame;position_x=x;position_new=1;good_frame=1;
   ticks(1);position_new=0;good_frame=0;ticks(1);end
 endtask
 initial begin
  ticks(4);rst_n=1;permit=1;ticks(3);start_run=1;ticks(1);start_run=0;counter_run=1;station_run=1;good_frame=1;ticks(1);good_frame=0;counter_total=1;station_total=1;
  ticks(2);event_valid=1;ticks(1);event_valid=0;ticks(2);station_event_valid=1;ticks(1);station_event_valid=0;ticks(3);
  sample(176);sample(160);sample(160);sample(160);
  if(state!=3 || feed_enable)$fatal(1,"did not enter genuine position hold");
  // HOLD entered at the posedge immediately before the task's last tick.
  // Exact cycle boundaries are captured separately below.
  for(i=0;i<110;i++)begin
   ticks(999998);sample(160);
   if(cycle_done || state==1)begin
    if(state!=1 || fault!=0 || query_id!=0)$fatal(1,"bad production resume");
    $display("PASS V2 real one second: 100000000 processing clocks, default parameters");$finish;
   end
   if(state!=3 || feed_enable)$fatal(1,"unexpected early exit F%0d",fault);
  end
  $fatal(1,"did not resume after one second");
 end
 reg [2:0] previous_state=0;integer hold_cycles=0;reg entered=0;
 always @(negedge clk)begin
  if(state==3)begin
   if(!entered)begin entered=1;hold_cycles=0;hold_start=$time;end
   hold_cycles++;
   if(feed_enable)$fatal(1,"motor enabled during production hold");
  end
  if(entered && previous_state==3 && state!=3)begin
   if(hold_cycles!=100000000 || $time-hold_start!=1000000000)
    $fatal(1,"incorrect production hold %0d clocks %0t",hold_cycles,$time-hold_start);
  end
  previous_state=state;
 end
 initial begin #1200000000;$fatal(1,"real time bench timeout");end
endmodule
