`timescale 1ns/1ps
module tb_adjacent_v6_control;
 reg clk=0;always #5 clk=~clk;
 reg rst_n=0,permit=1,pause=0,start=0,clear=0,good=0,bad=0,occupied=0;
 reg [31:0] frame_id=0;reg [15:0] run_id=0;
 reg [8:0] gt=0,lt=0;reg [2:0] gs=2,ls=2;
 reg ev=0,lev=0,pnew=0;reg [8:0] eid=0,lid=0,pid=0;
 reg [1:0] ek=3,lk=3;reg [15:0] prun=0;reg [31:0] pf=0;
 reg [10:0] px=0;reg [9:0] py=320;
 wire [8:0] query;wire feed,done,stationary;wire [2:0] state;wire [3:0] fault;
 wire [63:0] status;wire [95:0] diag;
 wire [63:0] sd={frame_id,query,ls,4'd0,8'hc4,8'he8};
 pocket_relay_stop_v2 #(.ADJACENT_V6(1),.RESTART_NEW_RUN(1),.CLK_HZ(100000),.ADVANCE_PX(32),.POSITION_TOL_PX(80)) dut(
 .clk(clk),.rst_n(rst_n),.permit(permit),.pause(pause),.start_run(start),.clear_run(clear),.good_frame(good),.bad_frame(bad),.transport_occupied(occupied),
 .current_frame(frame_id),.counter_run(run_id),.station_run(run_id),.counter_state(gs),.station_state(ls),
 .direction_valid(1'b1),.direction_right(1'b0),.station_dv(1'b1),.station_dr(1'b0),
 .counter_total(gt),.station_total(lt),.counter_uncertainty(9'd0),.station_uncertainty(9'd0),
 .event_valid(ev),.event_run(run_id),.event_id(eid),.event_kind(ek),
 .station_event_valid(lev),.station_event_run(run_id),.station_event_id(lid),.station_event_kind(lk),
 .position_new(pnew),.position_id(pid),.position_run(prun),.position_frame(pf),.position_x(px),.position_y(py),.query_id(query),
 .station_diagnostic(sd),.diagnostic(diag),.stationary_hint(stationary),.feed_enable(feed),.state(state),.fault(fault),.status(status),.cycle_done(done));
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
   forbid_feed=0;clear=1;ticks(2);clear=0;ticks(3);gt=0;lt=0;gs=2;ls=2;
   start=1;ticks(1);run_id++;start=0;ticks(3);source(0,0,0);
   require(state==1 && feed,"clean transport did not start");cycles=0;
  end
 endtask
 task add_id(input integer n,input bit local_arrived);
  begin
   eid=n;gt=n;ev=1;ticks(1);ev=0;ticks(3);
   if(local_arrived)begin lid=n;lt=n;lev=1;ticks(1);lev=0;ticks(4);end
  end
 endtask
 task settle(input integer xx);
  begin repeat(5)source(1,query,xx);require(state==3,"stable actual target did not hold");end
 endtask
 initial begin
  ticks(5);rst_n=1;ticks(4);
  // Three true adjacent head positions are all in the accepted region.
  // Each ID must be measured separately, with no intervening motor pulse.
  begin_case();add_id(1,1);add_id(2,1);add_id(3,1);settle(140);
  i=holds;forbid_feed=1;
  for(j=0;j<100 && holds<i+3;j++)begin
   if(query==3 && holds==i+2)forbid_feed=0;
   source(1,query,query==1 ? 140 : query==2 ? 187 : 234);
  end
  require(holds==i+3 && query==0 && feed && fault==0,"three independent holds/queue pops");
  // Lost during HOLD: valid image frames continue, but the target does not.
  begin_case();add_id(1,1);settle(160);cycles=0;
  repeat(12)source(1,1,160);
  repeat(5)source(0,0,0);
  require(state==7 && !feed && fault==6 && status[57]==0,"stale did not enter stopped reacquisition");
  forbid_feed=1;frozen=diag;require(frozen[95] && frozen[3:0]==6,"first loss not frozen");
  // Wrong ID, run and old frame are never recovery measurements.
  source(1,2,160);require(state==7,"neighbor ID revived head");
  frame_id++;good=1;ticks(1);good=0;pid=1;px=160;prun=run_id-1;pf=frame_id;pnew=1;ticks(1);pnew=0;ticks(3698);require(state==7,"wrong RUN revived head");
  frame_id++;good=1;ticks(1);good=0;prun=run_id;pf=frame_id-1;pnew=1;ticks(1);pnew=0;ticks(3698);require(state==7,"old source revived head");
  cycles=0;repeat(7)source(1,1,160);
  require(state==3 && fault==0 && diag===frozen,"actual recovery or frozen context failed");
  i=holds;
  for(j=0;j<27;j++)source(1,1,160);
  forbid_feed=0;source(1,1,160);require(holds==i+1 && query==0,"recovery did not restart full hold");
  // A second loss of THIS head is bounded, rather than an infinite retry.
  begin_case();add_id(1,1);settle(160);repeat(5)source(0,0,0);repeat(7)source(1,1,160);
  require(state==3,"first retry unavailable");repeat(5)source(0,0,0);
  require(state==4 && fault==6 && query==1 && !feed,"second loss silently restarted or popped");
  // Persistent absence exhausts the one bounded attempt, preserving identity.
  begin_case();add_id(1,1);source(1,1,230);repeat(19)source(0,0,0);
  require(state==4 && fault==6 && query==1 && !feed,"permanent loss did not stop at bounded timeout");
  // A head not yet counted at the station is genuinely upstream: resume.
  begin_case();add_id(1,1);add_id(2,0);settle(160);i=holds;
  for(j=0;j<32 && holds==i;j++)source(1,1,160);
  require(query==2 && state==6 && !feed,"upstream next not selected while stopped");
  source(0,0,0);require(state==1 && feed,"unarrived next never resumed");
  // Existing frame and station faults take precedence over reacquisition.
  lid=2;lt=2;lev=1;ticks(1);lev=0;ticks(4);
  source(1,2,230);repeat(5)source(0,0,0);bad=1;ticks(1);bad=0;
  require(state==4 && fault==1 && !feed,"bad frame was auto-recovered");
  $display("PASS ADJACENT V6 control: %0d checks, no-pulse three IDs, fresh full holds, stopped bounded recovery, wrong ID/run/frame rejection, second loss and permanent absence, upstream handover, hard-fault precedence",checks);$finish;
 end
 initial begin #200000000;$fatal(1,"v6 control timeout");end
endmodule
