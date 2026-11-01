`timescale 1ns/1ps
module tb_relay_left_faults;
 reg clk=0;always #5 clk=~clk;
 reg rst=0,permit=1,start=0,clear=0,good=0,bad=0,occupied=0,dv=0,dr=0,ldv=0,ldr=0;
 reg [31:0] frame=0,pframe=0;reg [15:0] run=0,local_run=0,erun=0,prun=0;
 reg [2:0] cs=1,ls=1;reg [8:0] total=0,local_total=0,unc=0,lunc=0,eid=0,pid=0;
 reg ev=0,pn=0;reg [1:0] kind=3;reg [10:0] px=240;reg [9:0] py=320;
 reg station_event_valid=0;reg [15:0] station_event_run=0;reg [8:0] station_event_id=0;reg [1:0] station_event_kind=3;
 wire feed,done;wire [2:0] state;wire [3:0] fault;wire [8:0] query;wire [63:0] status;
 pocket_relay_stop_v2 #(.CLK_HZ(1000)) dut(
 .clk(clk),.rst_n(rst),.permit(permit),.start_run(start),.clear_run(clear),.good_frame(good),.bad_frame(bad),.transport_occupied(occupied),
 .current_frame(frame),.counter_run(run),.station_run(local_run),.counter_state(cs),.station_state(ls),
 .direction_valid(dv),.direction_right(dr),.station_dv(ldv),.station_dr(ldr),.counter_total(total),.station_total(local_total),
 .counter_uncertainty(unc),.station_uncertainty(lunc),.event_valid(ev),.event_run(erun),.event_id(eid),.event_kind(kind),
 .station_event_valid(station_event_valid),.station_event_run(station_event_run),.station_event_id(station_event_id),.station_event_kind(station_event_kind),
 .query_id(query),.position_new(pn),.position_id(pid),.position_run(prun),.position_frame(pframe),.position_x(px),.position_y(py),
 .feed_enable(feed),.state(state),.fault(fault),.status(status),.cycle_done(done));
 integer checks=0,i;
 task ticks(input integer n);repeat(n)@(negedge clk);endtask
 task check(input bit ok,input string why);begin checks++;if(!ok)$fatal(1,"%s S%0d F%0h Q%0d",why,state,fault,query);end endtask
 task begin_clean;
  begin
   clear=1;ticks(1);clear=0;total=0;local_total=0;unc=0;lunc=0;bad=0;occupied=0;dv=0;ldv=0;permit=1;cs=1;ls=1;
   start=1;ticks(1);start=0;run++;local_run=run;ticks(1);
   check(state==5 && !feed,"alignment before feed");frame++;good=1;ticks(1);good=0;ticks(1);check(state==1 && feed,"clear alignment");
  end
 endtask
 task push(input integer n);
  begin total=n;ev=1;erun=run;eid=n;ticks(1);ev=0;ticks(1);end
 endtask
 task position(input integer xx);
  begin frame++;pframe=frame;prun=run;pid=query;px=xx;pn=1;good=1;ticks(1);pn=0;good=0;ticks(1);end
 endtask
 initial begin
  ticks(5);rst=1;ticks(3);check(!feed,"power on stopped");
  begin_clean();push(1);
  for(i=0;i<20;i++)begin good=1;ticks(1);good=0;ticks(19);end
  check(feed && fault==0 && !status[57],"transport >150ms is allowed without inventing X");
  local_total=1;station_event_run=run;station_event_id=1;station_event_kind=3;station_event_valid=1;ticks(1);station_event_valid=0;ticks(3);position(240);check(status[57] && status[11:1]==240,"local real position acquired");
  for(i=0;i<8;i++)begin good=1;ticks(1);good=0;ticks(19);end
  check(state==4 && fault==6 && !feed && query==1,"stale AFTER arrival freezes queue");
  start=1;ticks(1);start=0;run++;local_run=run;ticks(1);check(fault==10 && query==1,"restart cannot discard pending ID");
  begin_clean();occupied=1; // Fresh run starts stopped, actual occupied proof must fail.
  clear=1;ticks(1);clear=0;start=1;ticks(1);start=0;run++;local_run=run;good=1;ticks(1);good=0;ticks(1);
  check(fault==12 && !feed,"occupied transport cannot bind offset silently");
  begin_clean();push(1);local_total=2;ticks(2);check(fault==11 && !feed,"local prefix cannot overtake main prefix");
  begin_clean();unc=1;ticks(2);check(fault==13,"main raw uncertainty is not masked by UI");
  begin_clean();lunc=1;ticks(2);check(fault==13,"local uncertainty stops");
  begin_clean();dv=1;dr=1;ticks(2);check(fault==3,"right direction rejected");dr=0;
  begin_clean();push(1);local_total=1;station_event_run=run;station_event_id=1;station_event_kind=3;station_event_valid=1;ticks(1);station_event_valid=0;ticks(3);position(170);position(160);position(160);position(160);
  check(state==3 && !feed,"stable measured position required before hold");
  position(164);check(fault==9 && query==1,"hold drift does not complete");
  begin_clean();push(1);local_total=1;station_event_run=run;station_event_id=1;station_event_kind=3;station_event_valid=1;ticks(1);station_event_valid=0;ticks(3);position(140);check(fault==7,"overshoot stops");
  begin_clean();for(i=1;i<=33;i++)push(i);check(fault==5 && status[63:58]==32 && query==1,"queue full preserves32 real IDs");
  begin_clean();push(1);
  for(i=0;i<751;i++)begin good=1;ticks(1);good=0;ticks(19);end
  check(fault==14 && query==1 && !feed,"arrival wait is bounded15 seconds");
  begin_clean();push(1);station_event_run=run;station_event_id=1;station_event_kind=2;station_event_valid=1;ticks(1);station_event_valid=0;ticks(3);check(fault==4 && !feed && query==1,"P/E signature mismatch cannot stop next hole under wrong ID");
  begin_clean();permit=0;ticks(2);check(!feed && state==0,"permit removal stops");
  $display("PASS left faults: %0d assertions; alignment, delayed arrival/stale, prefix, raw uncertainty, direction, drift, queue32,15s deadline, clear/restart",checks);$finish;
 end
endmodule
