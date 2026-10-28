`timescale 1ns/1ps
// Position-level replay of seven observed stops; not a sensor RAW replay.
module tb_relay_wide_stop;
 reg clk=0;always #5 clk=~clk;
 reg rst=0,permit=1,pause=0,start=0,clear=0,good=0;
 reg [31:0] frame=0,pframe=0;reg[15:0] run=0;
 reg[8:0] total=0,local_total=0,eid=0,lid=0,pid=0;
 reg ev=0,lev=0,pn=0;reg[10:0] px=240;
 wire feed,done;wire[2:0] state;wire[3:0] fault;wire[8:0] query;wire[63:0] status;
 pocket_relay_stop_v2 #(.RESTART_NEW_RUN(1),.CLK_HZ(1000),.ADVANCE_PX(32),.POSITION_TOL_PX(80)) dut(
 .clk(clk),.rst_n(rst),.permit(permit),.pause(pause),.start_run(start),.clear_run(clear),.good_frame(good),.bad_frame(1'b0),.transport_occupied(1'b0),
 .current_frame(frame),.counter_run(run),.station_run(run),.counter_state(3'd1),.station_state(3'd1),
 .direction_valid(1'b1),.direction_right(1'b0),.station_dv(1'b1),.station_dr(1'b0),
 .counter_total(total),.station_total(local_total),.counter_uncertainty(9'd0),.station_uncertainty(9'd0),
 .event_valid(ev),.event_run(run),.event_id(eid),.event_kind(2'd3),
 .station_event_valid(lev),.station_event_run(run),.station_event_id(lid),.station_event_kind(2'd3),
 .query_id(query),.position_new(pn),.position_id(pid),.position_run(run),.position_frame(pframe),.position_x(px),.position_y(10'd320),
 .feed_enable(feed),.state(state),.fault(fault),.status(status),.cycle_done(done));
 integer i,j,checks=0,completed=0,hold_cycles=0;reg[2:0] previous=0;
 integer observed[0:6];
 always @(negedge clk)if(rst)begin
  if(state==3)hold_cycles++;
  if(previous==3 && state!=3)begin
   if(state==1 && hold_cycles!=1000)$fatal(1,"hold must last1000 clocks, got%0d",hold_cycles);
   hold_cycles=0;
  end
  if(done)completed++;
  previous=state;
 end
 task ticks(input integer n);repeat(n)@(negedge clk);endtask
 task check(input bit ok,input string why);begin checks++;if(!ok)$fatal(1,"%s S%0d F%0h ID%0d",why,state,fault,query);end endtask
 task begin_run(input integer n);
  begin
   clear=1;ticks(1);clear=0;total=0;local_total=0;
   start=1;ticks(1);start=0;run++;ticks(2);good=1;frame++;ticks(1);good=0;ticks(2);
   check(state==1 && feed,"aligned RUN starts");
   for(j=1;j<=n;j++)begin total=j;eid=j;ev=1;ticks(1);ev=0;ticks(2);end
   for(j=1;j<=n;j++)begin local_total=j;lid=j;lev=1;ticks(1);lev=0;ticks(3);end
  end
 endtask
 task position(input integer x);
  begin frame++;pframe=frame;pid=query;px=x;pn=1;good=1;ticks(1);pn=0;good=0;ticks(1);end
 endtask
 task complete_stop(input integer x,input integer next_id);
  integer t,old_count;
  begin
   old_count=completed;position(240);check(state==1 && feed,"upstream coordinate must keep feeding");
   position(192);check(state==2 && !feed,"same trigger192 stops motor");
   position(x);position(x);position(x);check(state==3 && !feed,"in-window stable endpoint starts hold");
   for(t=0;t<110 && state==3;t++)begin position(x);ticks(8);end
   check(state==1 && fault==0 && feed && query==next_id,"complete hold automatically resumes next queued ID");
   check(completed==old_count+1,"each queued ID completed once");
  end
 endtask
 initial begin
  observed[0]=131;observed[1]=137;observed[2]=145;observed[3]=169;observed[4]=139;observed[5]=121;observed[6]=157;
  ticks(5);rst=1;ticks(3);begin_run(7);
  for(i=0;i<7;i++)begin
   check(query==i+1,"FIFO head before observed stop");
   complete_stop(observed[i],i==6 ? 0:i+2);
  end
  check(completed==7,"seven endpoints continue in one RUN without a key restart");
  begin_run(1);complete_stop(80,0);
  begin_run(1);complete_stop(240,0);
  begin_run(1);position(79);check(state==4 && fault==7 && query==1 && !feed,"outside lower boundary retains fault and queue");
  begin_run(1);position(192);
  for(i=0;i<125;i++)begin position(241);ticks(8);end
  check(state==4 && fault==8 && query==1 && !feed,"outside upper boundary is not silently completed");
  begin_run(1);position(192);position(121);position(121);position(121);check(state==3,"wide lower endpoint qualifies");
  position(125);check(state==4 && fault==9 && query==1 && !feed,"wide window does not bypass actual drift");
  begin_run(1);position(192);position(131);position(131);position(131);
  good=1;ticks(160);good=0;
  check(state==4 && fault==6 && query==1 && !feed,"lost target remains a stop, never an automatic skip");
  $display("PASS WIDE STOP: %0d assertions; seven observed endpoints sequentially held1000ms, boundaries80/240, outside/drift/stale retained",checks);$finish;
 end
 initial begin #1000000;$fatal(1,"wide stop timeout");end
endmodule
