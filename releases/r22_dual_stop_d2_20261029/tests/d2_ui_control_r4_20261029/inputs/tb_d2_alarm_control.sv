`timescale 1ns/1ps
module tb_d2_alarm_control;
 reg clk=0;always #5 clk=~clk;
 reg rst_n=0,permit=1,pause=0,start=0,clear=0,good=0,bad=0,occupied=0;
 reg [31:0] frame_id=0;reg [15:0] run_id=0;
 reg [8:0] gt=0,lt=0;reg [2:0] gs=2,ls=2;
 reg ev=0,lev=0,pnew=0;reg [8:0] eid=0,lid=0,pid=0;
 reg [1:0] ek=3,lk=3;reg [15:0] prun=0;reg [31:0] pf=0;
 reg [10:0] px=0;reg [9:0] py=320;
 wire [8:0] query;wire feed,done,stationary;wire [2:0] state;wire [3:0] fault;
 wire [63:0] status;wire [95:0] diag;wire alarm_stop,motor_pin;reg [2:0] gate_mode=1;reg [15:0] issued_run=0;
 extracted_d2_motor motor(clk,rst_n,gate_mode,feed,alarm_stop,motor_pin);
 wire [63:0] sd={frame_id,query,ls,4'd0,8'hc4,8'he8};
 pocket_relay_stop_v2 #(.FIVE_EMPTY_V7(1),.TARGET_X(152),.ADJACENT_V6(1),.RESTART_NEW_RUN(1),.CLK_HZ(100000),.ADVANCE_PX(32),.POSITION_TOL_PX(80)) dut(
 .clk(clk),.rst_n(rst_n),.permit(permit),.pause(pause),.start_run(start),.clear_run(clear),.good_frame(good),.bad_frame(bad),.transport_occupied(occupied),
 .current_frame(frame_id),.counter_run(run_id),.station_run(run_id),.counter_state(gs),.station_state(ls),
 .direction_valid(1'b1),.direction_right(1'b0),.station_dv(1'b1),.station_dr(1'b0),
 .counter_total(gt),.station_total(lt),.counter_uncertainty(9'd0),.station_uncertainty(9'd0),
 .event_valid(ev),.event_run(issued_run),.event_id(eid),.event_kind(ek),
 .station_event_valid(lev),.station_event_run(run_id),.station_event_id(lid),.station_event_kind(lk),
 .position_new(pnew),.position_id(pid),.position_run(prun),.position_frame(pf),.position_x(px),.position_y(py),.query_id(query),
 .alarm_stop(alarm_stop),.station_diagnostic(sd),.diagnostic(diag),.stationary_hint(stationary),.feed_enable(feed),.state(state),.fault(fault),.status(status),.cycle_done(done));
 integer holds=0,cycles=0,checks=0,i,j,prev_query=0;reg forbid_feed=0;reg [95:0] frozen;
 task ticks(input integer n);repeat(n)@(negedge clk);endtask
 task require(input bit ok,input string why);begin checks++;if(!ok)$fatal(1,"%s S%0d F%0d Q%0d",why,state,fault,query);end endtask
 always @(negedge clk)if(rst_n)begin
  if(state==3)cycles++;
  if(done)begin
   if(cycles<100000)$fatal(1,"not a complete fresh one-second hold %0d",cycles);
   holds++;cycles=0;
  end
  if(forbid_feed && feed && query!=0)$fatal(1,"motor pulse during in-window handover/reacquisition");
 end
 task source(input bit measured,input integer which,input integer xx);
  begin
   frame_id++;good=1;ticks(1);good=0;
   pid=which;px=xx;prun=run_id;pf=frame_id;pnew=measured;ticks(1);pnew=0;ticks(3698);
  end
 endtask
 task begin_case;
  begin
   permit=1;pause=0;gate_mode=1;forbid_feed=0;clear=1;ticks(2);clear=0;ticks(3);gt=0;lt=0;gs=2;ls=2;
   start=1;ticks(1);run_id++;issued_run=run_id;start=0;ticks(3);source(0,0,0);
   require(state==1 && feed,"clean transport did not start");cycles=0;
  end
 endtask
 task add_id(input integer n,input bit local_arrived);
  begin
   eid=n;issued_run=run_id;gt=n;ev=1;ticks(1);ev=0;ticks(3);
   if(local_arrived)begin lid=n;lt=n;lev=1;ticks(1);lev=0;ticks(4);end
  end
 endtask
 task settle(input integer xx);
  begin repeat(5)source(1,query,xx);require(state==3,"stable actual target did not hold");end
 endtask
 initial begin
  ticks(5);rst_n=1;ticks(4);
  // Eight queued EMPTYs, but broken into two groups by a real PRESENT.
  begin_case();for(i=1;i<=4;i++)add_id(i,0);
  repeat(6)source(0,0,0);
  require(!alarm_stop && fault==0 && status[63:58]==4,"four holes/repeated frames falsely alarmed");
  ek=2;add_id(5,0);ek=3;for(i=6;i<=9;i++)add_id(i,0);
  require(!alarm_stop && fault==0 && status[63:58]==8,"queue depth confused with consecutive holes");
  add_id(10,0);ticks(4);
  require(alarm_stop && fault==15 && state==4 && !feed && !motor_pin && query==1 && status[63:58]==9,"fifth consecutive EMPTY not latched with queue retained");
  // Production motor register must reject manual and resume modes too.
  permit=0;gate_mode=4;ticks(3);gate_mode=3;ticks(6);
  require(alarm_stop && !motor_pin,"manual motor mode bypassed alarm after stop");
  permit=1;pause=1;gate_mode=2;ticks(5);pause=0;gate_mode=1;ticks(5);
  require(alarm_stop && !motor_pin,"pause/resume bypassed alarm");
  gate_mode=4;clear=1;ticks(2);clear=0;ticks(3);
  require(!alarm_stop && !motor_pin && query==0,"single clear did not clear-and-stop");
  // Explicit fresh RUN resets a four-hole streak, without requiring clear.
  begin_case();for(i=1;i<=4;i++)add_id(i,0);
  permit=0;gate_mode=4;ticks(4);permit=1;gate_mode=1;start=1;ticks(1);
  run_id++;issued_run=run_id;start=0;gt=0;lt=0;ticks(3);source(0,0,0);add_id(1,0);
  require(!alarm_stop && fault==0 && status[63:58]==1,"fresh RUN inherited old streak");
  // A fifth event on the precise HOLD completion clock wins over queue pop.
  begin_case();for(i=1;i<=4;i++)add_id(i,1);settle(152);j=holds;
  fork
   begin forever source(1,1,152);end
   begin
    while(!(dut.phase_ms==999 && dut.tick))ticks(1);
    eid=5;gt=5;issued_run=run_id;ev=1;ticks(1);ev=0;ticks(4);
    require(alarm_stop && fault==15 && !motor_pin && query==1 && status[63:58]==5 && holds==j,"alarm/pop collision skipped head or resumed motor");
   end
  join_any
  disable fork;
  // ID gaps and wrong epochs are hard faults, never evidence of five holes.
  begin_case();for(i=1;i<=4;i++)add_id(i,0);eid=6;gt=6;ev=1;ticks(1);ev=0;ticks(4);
  require(fault==4 && !alarm_stop && !motor_pin,"invalid ordinal counted as fifth EMPTY");
  begin_case();for(i=1;i<=4;i++)add_id(i,0);eid=5;gt=5;issued_run=run_id-1;ev=1;ticks(1);ev=0;ticks(4);
  require(fault==4 && !alarm_stop && !motor_pin,"wrong RUN counted as fifth EMPTY");
  // Fifth valid event can arrive while paused; the alarm remains latched.
  begin_case();for(i=1;i<=4;i++)add_id(i,0);pause=1;gate_mode=2;add_id(5,0);ticks(4);
  require(alarm_stop && fault==15 && !motor_pin,"fifth EMPTY ignored while paused");
  pause=0;gate_mode=1;ticks(4);require(!motor_pin,"paused alarm automatically restarted");
  // An explicit K1/newRUN clears an already latched alarm, keeps motor off
  // during alignment, then starts only after a clean source-frame proof.
  start=1;ticks(1);run_id++;issued_run=run_id;gt=0;lt=0;start=0;ticks(3);
  require(!alarm_stop && !motor_pin && state==5,"explicit newRUN did not reset alarm into stopped alignment");
  source(0,0,0);require(fault==0 && feed && motor_pin && query==0,"explicit newRUN failed clean-transport proof");
  $display("PASS D2 V7 ALARM CONTROL: %0d checks; groups4+P+4, queue8 no alarm, fifth locks, production motor body cannot bypass, clear/newRUN reset, exact hold/pop collision priority, invalid ID/RUN, paused arrival",checks);$finish;
 end
 initial begin #200000000;$fatal(1,"alarm control timeout");end
endmodule
