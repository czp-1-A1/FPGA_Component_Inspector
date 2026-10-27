`timescale 1ns/1ps
module tb_pocket_relay_stop;
 reg clk=0;always #5 clk=~clk;
 reg rst_n=0,permit=0,start_run=0,clear_run=0,good_frame=0,bad_frame=0;
 reg [31:0] current_frame=0;reg [15:0] counter_run=0;reg [2:0] counter_state=2;
 reg direction_valid=1,direction_right=1,event_valid=0;reg [15:0] event_run=1;
 reg [8:0] event_id=0;reg [1:0] event_kind=3;
 wire [8:0] query_id;reg position_new=0;reg [8:0] position_id=0;
 reg [15:0] position_run=1;reg [31:0] position_frame=0;
 reg [10:0] position_x=0;reg [9:0] position_y=320;
 wire feed_enable,cycle_done;wire [2:0] state;wire [3:0] fault;wire [31:0] status;
 pocket_relay_stop #(.CLK_HZ(1000),.STALE_MS(20),.STOP_TIMEOUT_MS(40),.QUEUE_DEPTH(2)) dut(.*);
 integer checks=0,hold_ticks;
 task check(input bit ok,input string message);
  begin checks++;if(!ok)begin $display("FAIL %s S=%0d F=%0d Q=%0d",message,state,fault,status[24:21]);$fatal(1);end end
 endtask
 task step;begin @(negedge clk);end endtask
 task boot;
  begin rst_n=0;permit=0;start_run=0;clear_run=0;event_valid=0;position_new=0;bad_frame=0;
   direction_right=1;counter_state=2;counter_run=0;event_run=1;event_kind=3;position_run=1;
   current_frame=0;position_frame=0;good_frame=0;repeat(3)step;rst_n=1;step;
   check(!feed_enable,"reset never starts motor");
   permit=1;repeat(2)step;check(!feed_enable,"permission alone cannot start");
   start_run=1;step;start_run=0;counter_run=1;step;check(feed_enable,"deliberate new run feeds");
  end
 endtask
 task event_add(input integer id,input integer kind);
  begin event_id=id;event_kind=kind;event_valid=1;step;event_valid=0;step;end
 endtask
 task position(input integer id,input integer xx);
  begin current_frame++;position_frame=current_frame;position_id=id;position_x=xx;
   good_frame=1;position_new=1;step;position_new=0;good_frame=0;step;end
 endtask
 task enter_hold;
  begin event_add(1,3);position(1,735);check(feed_enable,"before trigger keeps feeding");
   position(1,736);check(!feed_enable && state==2,"cross trigger cuts output");
   position(1,760);position(1,760);position(1,760);check(state==3,"three real stable positions enter hold");
  end
 endtask
 initial begin
  boot;event_add(1,2);check(query_id==0,"PRESENT never queues");event_add(2,3);event_add(2,3);
  check(status[24:21]==1 && query_id==2,"duplicate EMPTY is not duplicated");
  position(99,760);check(feed_enable,"wrong ID cannot trigger");
  position_run=2;position(2,760);check(feed_enable,"wrong RUN cannot trigger");position_run=1;
  current_frame++;position_frame=current_frame-1;position_id=2;position_new=1;step;position_new=0;
  check(feed_enable,"historical source position cannot trigger");
  position(2,735);position(2,736);check(state==2,"valid measured crossing stops");
  position(2,740);position(2,740);position(2,740);check(state==2,"off-target stationary pocket cannot enter hold");
  repeat(42)begin good_frame=1;position(2,740);end
  check(state==4 && fault==8 && !feed_enable,"off-target timeout stays stopped");

  boot;enter_hold;hold_ticks=dut.phase_ms;
  while(state==3)begin
   check(!feed_enable,"motor remains off through hold");
   good_frame=1;
   if(dut.phase_ms%5==0)begin current_frame++;position_frame=current_frame;position_id=1;position_x=760;position_new=1;end
   else position_new=0;
   step;
   if(state==3)check(dut.phase_ms<1000,"hold timer bounded");
  end
  position_new=0;good_frame=0;
  check(feed_enable && query_id==0 && cycle_done && dut.phase_ms==0,"one full second completes then resumes once");

  boot;enter_hold;position(1,764);check(state==4 && fault==9,"drift interrupts hold");
  boot;event_add(1,3);event_add(2,3);event_add(3,3);check(state==4 && fault==5 && status[24:21]==2,"overflow stops without dropping queued IDs");
  boot;enter_hold;repeat(22)begin good_frame=1;step;end good_frame=0;
  check(state==4 && fault==6,"no fresh target during hold stops");
  boot;repeat(22)step;check(state==4 && fault==2,"camera silence stops even with empty queue");
  boot;bad_frame=1;step;check(state==4 && fault==1,"bad frame stops");
  boot;direction_right=0;step;check(state==4 && fault==3,"unexpected reverse stops");
  boot;event_add(1,3);position(1,770);check(state==4 && fault==7,"late target outside window stops");
  boot;event_add(1,3);permit=0;step;check(!feed_enable && query_id==1,"SW3 up stops and retains pending ID");
  permit=1;start_run=1;step;start_run=0;check(state==4 && fault==10,"new run cannot silently discard pending ID");
  clear_run=1;step;clear_run=0;check(query_id==0 && !feed_enable && state==0,"explicit clear acknowledges queue");
  $display("PASS pocket relay controller: %0d checks",checks);$finish;
 end
 initial begin #200000;$fatal(1,"bench timeout");end
endmodule
