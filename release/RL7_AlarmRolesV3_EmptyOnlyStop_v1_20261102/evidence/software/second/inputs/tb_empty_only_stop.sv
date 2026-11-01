`timescale 1ns/1ps
module tb_empty_only_stop;
 reg clk=0;always #5 clk=~clk;
 reg rst_n=0,permit=1,pause=0,start=0,clear=0,good=0,bad=0,occupied=0;
 reg [31:0] frame=0,pframe=0;reg [15:0] run=0,lrun=0,erun=0,prun=0;
 reg [2:0] cs=2,ls=2,mode=1;
 reg dv=1,dr=0,ldv=1,ldr=0;reg [8:0] total=0,ltotal=0,unc=0,lunc=0;
 reg ev=0,lev=0,pn=0;reg [8:0] eid=0,lid=0,pid=0;
 reg [1:0] kind=3,lkind=3;reg [10:0] px=240;reg [9:0] py=320;
 wire feed,done,alarm_stop,motor,stationary;wire [2:0] state;wire [3:0] fault;
 wire [8:0] query;wire [63:0] status;wire [95:0] diagnostic;
 extracted_production_motor output_register(clk,rst_n,mode,feed,alarm_stop,motor);
 pocket_relay_stop_v2 #(.EMPTY_ONLY_STOP(1),.FIVE_EMPTY_V7(1),.ADJACENT_V6(1),
  .RESTART_NEW_RUN(1),.CLK_HZ(1000),.TARGET_X(152),.ADVANCE_PX(32),.POSITION_TOL_PX(80)) dut(
  .clk(clk),.rst_n(rst_n),.permit(permit),.pause(pause),.start_run(start),.clear_run(clear),
  .good_frame(good),.bad_frame(bad),.transport_occupied(occupied),.current_frame(frame),
  .counter_run(run),.station_run(lrun),.counter_state(cs),.station_state(ls),
  .direction_valid(dv),.direction_right(dr),.station_dv(ldv),.station_dr(ldr),
  .counter_total(total),.station_total(ltotal),.counter_uncertainty(unc),.station_uncertainty(lunc),
  .event_valid(ev),.event_run(erun),.event_id(eid),.event_kind(kind),
  .station_event_valid(lev),.station_event_run(lrun),.station_event_id(lid),.station_event_kind(lkind),
  .query_id(query),.position_new(pn),.position_id(pid),.position_run(prun),.position_frame(pframe),
  .position_x(px),.position_y(py),.feed_enable(feed),.state(state),.fault(fault),.status(status),
  .station_diagnostic(64'h1234),.diagnostic(diagnostic),.stationary_hint(stationary),.alarm_stop(alarm_stop),.cycle_done(done));
 integer checks=0,i,j,completed=0;reg [8:0] saved_head;reg [5:0] saved_count;
 task tick(input integer n);repeat(n)@(negedge clk);endtask
 task check(input bit ok,input string why);begin checks++;if(!ok)$fatal(1,"%s S%0d F%0h Q%0d feed%0b motor%0b",why,state,fault,query,feed,motor);end endtask
 always @(posedge clk)if(rst_n && done)completed++;
 task begin_case;
  begin
   permit=1;pause=0;mode=1;good=1;bad=0;occupied=0;cs=2;ls=2;unc=0;lunc=0;dr=0;ldr=0;ev=0;lev=0;pn=0;
   clear=1;tick(2);clear=0;total=0;ltotal=0;kind=3;lkind=3;tick(2);
   start=1;tick(1);start=0;run++;lrun=run;erun=run;tick(3);
   check(feed && motor && state==1 && !alarm_stop,"explicit new RUN feeds");
  end
 endtask
 task add_global(input integer n,input integer k);
  begin total=n;eid=n;kind=k;erun=run;ev=1;tick(1);ev=0;tick(2);end
 endtask
 task add_local(input integer n,input integer k);
  begin ltotal=n;lid=n;lkind=k;lev=1;tick(1);lev=0;tick(3);end
 endtask
 task position(input integer x);
  begin frame++;pframe=frame;prun=run;pid=query;px=x;pn=1;tick(1);pn=0;tick(1);end
 endtask
 task no_fault_stop(input integer code,input string why);
  begin tick(3);check(feed && motor && state==1 && fault==code && !alarm_stop && !done,why);end
 endtask
 task hold_empty;
  begin add_global(1,3);add_local(1,3);position(184);position(152);position(152);position(152);
   check(state==3 && !feed && !motor && query==1,"actual EMPTY alone enters HOLD");end
 endtask
 initial begin
  tick(3);check(!motor && !feed,"reset stops");rst_n=1;tick(3);
  // Every state loss code from either counter, held for longer than old recovery.
  for(i=0;i<2;i++)for(j=3;j<=6;j++)if(j!=5)begin
   begin_case();if(i==0)cs=j;else ls=j;
   repeat(600)begin tick(1);check(feed && motor && !alarm_stop && !done,"persistent counter/station loss never brakes");end
   check(fault==1 && diagnostic[95],"loss diagnostic retained");
  end
  begin_case();good=0;repeat(800)begin tick(1);check(feed && motor && !alarm_stop,"camera silence never brakes");end
  check(fault==2,"camera silence recorded");
  begin_case();bad=1;no_fault_stop(1,"bad frame diagnostic only");
  begin_case();dr=1;no_fault_stop(3,"main reverse diagnostic only");
  begin_case();ldr=1;no_fault_stop(3,"station reverse diagnostic only");
  begin_case();unc=1;no_fault_stop(13,"main uncertainty diagnostic only");
  begin_case();lunc=1;no_fault_stop(13,"station uncertainty diagnostic only");
  begin_case();lrun=run+1;no_fault_stop(11,"epoch mismatch diagnostic only");
  begin_case();occupied=1;total=0;ltotal=0;start=1;tick(1);start=0;run++;lrun=run;erun=run;tick(4);
  no_fault_stop(12,"occupied startup records association failure without fault parking");
  begin_case();ltotal=1;no_fault_stop(11,"local overtaking diagnostic only");
  begin_case();add_global(1,2);add_global(3,2);check(feed && motor && fault==4 && query==0,"global ID gap never stops or creates EMPTY");
  begin_case();add_global(1,3);add_local(1,2);check(feed && motor && fault==4 && query==1,"signature mismatch retains unresolved EMPTY and feeds");
  begin_case();add_global(1,3);lid=2;ltotal=2;lev=1;tick(1);lev=0;no_fault_stop(11,"local ID gap feeds");
  begin_case();add_global(1,3);add_local(1,3);position(240);
  saved_head=query;saved_count=status[63:58];repeat(900)begin tick(1);check(feed && motor && !done && state!=7,"stale target never enters stopped REACQUIRE");end
  check(fault==6 && query==saved_head && status[63:58]==saved_count,"stale target queue retained without false completion");
  // A restored same-ID measurement can still stop the actual EMPTY.
  position(184);check(state==2 && !feed && !motor,"fresh EMPTY still brakes after loss");
  begin_case();add_global(1,3);repeat(15020)begin tick(1);check(feed && motor && !done,"arrival deadline never brakes");end
  check(fault==14 && query==1,"arrival timeout recorded without queue deletion");
  begin_case();add_global(1,3);add_local(1,3);position(60);no_fault_stop(7,"overshoot feeds");
  begin_case();add_global(1,3);add_local(1,3);position(184);check(!feed,"EMPTY initial braking");
  for(i=0;i<65;i++)begin position(240);tick(18);end
  no_fault_stop(8,"settling timeout resumes instead of fault parking");
  begin_case();hold_empty();position(156);no_fault_stop(9,"drift resumes without completing EMPTY");check(query==1,"drift retains head");
  begin_case();hold_empty();repeat(160)tick(1);no_fault_stop(6,"loss during HOLD resumes instead of fault parking");check(query==1,"interrupted HOLD not popped");
  // No direct queue manipulation: alternating P/E fills all32 slots without five consecutive E.
  begin_case();for(i=1;i<=65;i++)add_global(i,(i%2)==1 ? 3 : 2);
  check(feed && motor && fault==5 && status[63:58]==32 && query==1 && !alarm_stop,"full queue never fault parks or deletes known IDs");
  begin_case();hold_empty();j=completed;i=0;
  while(state==3 && i<1100)begin
   check(!feed && !motor,"EMPTY holds continuously");position(152);i=i+2;
  end
  tick(2);check(i>=1000 && completed==j+1 && feed && motor && query==0,"full1000ms hold completes exactly once");
  // PRESENTs never stop. Four E / P / four E do not latch; fifth real E does.
  begin_case();for(i=1;i<=20;i++)begin add_global(i,2);check(feed && motor && query==0 && !alarm_stop,"PRESENT never brakes");end
  begin_case();for(i=1;i<=4;i++)add_global(i,3);add_global(5,2);for(i=6;i<=9;i++)add_global(i,3);
  check(feed && motor && !alarm_stop,"4E P 4E has no alarm");add_global(10,3);
  check(state==4 && fault==15 && alarm_stop && !feed && !motor && query==1,"fifth consecutive EMPTY remains latched stop");
  bad=1;cs=4;good=0;mode=3;tick(800);check(alarm_stop && !motor && !done,"faults/manual cannot bypass real EMPTY alarm");
  // Invalid fifth event cannot manufacture an alarm.
  begin_case();for(i=1;i<=4;i++)add_global(i,3);eid=6;total=6;ev=1;tick(1);ev=0;tick(3);
  check(feed && motor && !alarm_stop && fault==4,"ID gap not treated as fifth EMPTY");
  // Fifth valid E wins on the exact normal HOLD completion edge, without pop.
  begin_case();hold_empty();for(i=2;i<=4;i++)add_global(i,3);j=completed;
  while(dut.phase_ms<998)begin position(152);end
  while(dut.phase_ms<999)tick(1);
  eid=5;total=5;kind=3;erun=run;ev=1;tick(1);ev=0;tick(3);
  check(alarm_stop && !motor && !done && query==1 && status[63:58]==5 && completed==j,"fifth E preempts exact HOLD pop");
  // AlarmRoles V3: the valid global ledger still owns the fifth-E alarm
  // while local faults only record context and keep feeding before that E.
  for(i=0;i<4;i++)begin
   begin_case();for(j=1;j<=4;j++)add_global(j,3);
   case(i)
    0:ls=3;
    1:lunc=1;
    2:begin add_local(1,2);end
    3:lrun=run+1;
   endcase
   tick(3);check(feed && motor && !alarm_stop,"prior local fault must not park before fifth E");
   saved_head=diagnostic[3:0];check(diagnostic[95],"first prior-fault context captured");
   add_global(5,3);
   check(alarm_stop && fault==15 && !feed && !motor && state==4 && status[63:58]==5,"V3 fifth E wins despite prior local anomaly");
   check(diagnostic[3:0]==saved_head,"V3 alarm preserves first transport-fault context");
  end
  begin_case();for(i=1;i<=4;i++)add_global(i,3);ls=3;add_global(5,3);
  check(alarm_stop && fault==15 && !motor,"same-cycle fifth E and local LOST still alarm");
  begin_case();for(i=1;i<=4;i++)add_global(i,3);add_global(4,3);add_global(5,3);
  check(feed && motor && fault==4 && !alarm_stop && !dut.alarm_tracking,"invalid global sequence disarms fifth watcher without fault parking");
  begin_case();cs=4;pause=1;mode=2;tick(10);check(!feed && !motor,"manual pause still stops during loss");
  pause=0;mode=1;tick(3);check(feed && motor,"manual resume during loss");
  permit=0;mode=0;tick(3);check(!motor && !feed,"manual stop still stops during loss");
  clear=1;tick(2);clear=0;tick(2);check(query==0 && !motor && !alarm_stop,"clear stops and acknowledges queue");
  check(completed==1,"only successful EMPTY HOLD reported complete");
  $display("PASS EMPTY_ONLY_STOP: %0d checks; persistent losses, association, all runtime fault codes, real EMPTY HOLD/alarm, queue retention, motor register, pause/stop/clear",checks);$finish;
 end
 initial begin #2000000;$fatal(1,"timeout");end
endmodule
