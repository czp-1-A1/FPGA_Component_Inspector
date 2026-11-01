`timescale 1ns/1ps
module tb_alarm_field_repro;
 reg clk=0;always #5 clk=~clk;
 reg rst_n=0,start=0,clear=0,good=0,ev=0,lev=0;
 reg [31:0] frame=0;reg [15:0] run=0;
 reg [8:0] gt=0,lt=0,eid=0,lid=0,uncertain=0;
 reg [2:0] gs=2,ls=2;reg [1:0] kind=3,local_kind=3;
 wire alarm,feed,done,stationary;wire [2:0] state;wire [3:0] fault;wire [8:0] query;
 wire [63:0] status;wire [95:0] diagnostic;
 pocket_relay_stop_v2 #(.FIVE_EMPTY_V7(1),.ADJACENT_V6(1),.RESTART_NEW_RUN(1),
 .CLK_HZ(100000),.TARGET_X(152),.ADVANCE_PX(32),.POSITION_TOL_PX(80)) dut(
 .clk(clk),.rst_n(rst_n),.permit(1'b1),.pause(1'b0),.start_run(start),.clear_run(clear),
 .good_frame(good),.bad_frame(1'b0),.transport_occupied(1'b0),.current_frame(frame),
 .counter_run(run),.station_run(run),.counter_state(gs),.station_state(ls),
 .direction_valid(1'b1),.direction_right(1'b0),.station_dv(1'b1),.station_dr(1'b0),
 .counter_total(gt),.station_total(lt),.counter_uncertainty(9'd0),.station_uncertainty(uncertain),
 .event_valid(ev),.event_run(run),.event_id(eid),.event_kind(kind),
 .station_event_valid(lev),.station_event_run(run),.station_event_id(lid),.station_event_kind(local_kind),
 .query_id(query),.position_new(1'b0),.position_id(9'd0),.position_run(run),.position_frame(frame),
 .position_x(11'd0),.position_y(10'd320),.feed_enable(feed),.state(state),.fault(fault),
 .station_diagnostic(64'd0),.diagnostic(diagnostic),.stationary_hint(stationary),.alarm_stop(alarm),.status(status),.cycle_done(done));
 task ticks(input integer n);repeat(n)@(negedge clk);endtask
 task begin_case;
 begin
  ev=0;lev=0;clear=1;ticks(2);clear=0;gt=0;lt=0;gs=2;ls=2;uncertain=0;local_kind=3;
  start=1;ticks(1);start=0;run=run+1;ticks(3);frame=frame+1;good=1;ticks(1);good=0;ticks(3);
  if(state!=1 || !feed || alarm)$fatal(1,"baseline transport did not start");
 end endtask
 task add(input integer n);
 begin eid=n;gt=n;ev=1;ticks(1);ev=0;ticks(3);end endtask
 integer i;
 initial begin
  ticks(4);rst_n=1;ticks(3);
  begin_case();for(i=1;i<=5;i=i+1)add(i);
  if(!alarm || state!=4 || fault!=15 || feed)$fatal(1,"healthy five baseline failed");
  $display("CASE healthy E1-E5: alarm=%0d fault=%0d feed=%0d",alarm,fault,feed);
  begin_case();for(i=1;i<=4;i=i+1)add(i);ls=3;add(5);
  if(alarm || state!=4 || fault!=1 || feed)$fatal(1,"same-cycle station fault not reproduced");
  $display("REPRO same fifth E5 + local LOST: global_empty=5 alarm=%0d fault=%0d feed=%0d",alarm,fault,feed);
  begin_case();for(i=1;i<=4;i=i+1)add(i);uncertain=1;add(5);
  if(alarm || state!=4 || fault!=13 || feed)$fatal(1,"same-cycle uncertainty not reproduced");
  $display("REPRO same fifth E5 + local uncertainty: global_empty=5 alarm=%0d fault=%0d feed=%0d",alarm,fault,feed);
  begin_case();for(i=1;i<=4;i=i+1)add(i);
  // A local observed PRESENT for a globally recorded EMPTY starts signature
  // comparison; its mismatch becomes visible on the same clock as global E5.
  lid=1;lt=1;local_kind=2;lev=1;ticks(1);lev=0;eid=5;gt=5;ev=1;ticks(1);ev=0;ticks(3);
  if(alarm || state!=4 || fault!=4 || feed)$fatal(1,"signature collision not reproduced");
  $display("REPRO same fifth E5 + P/E signature mismatch: global_empty=5 alarm=%0d fault=%0d feed=%0d",alarm,fault,feed);
  begin_case();for(i=1;i<=4;i=i+1)add(i);ls=3;ticks(2);add(5);
  if(alarm || state!=4 || fault!=1 || feed)$fatal(1,"already-faulted fifth not reproduced");
  $display("REPRO transport faults after E4, then valid global E5: global_empty=5 alarm=%0d fault=%0d feed=%0d",alarm,fault,feed);
  $display("PASS FIELD DIAGNOSTIC: healthy fifth alarm works; four distinct transport-fault scenarios suppress fifth-EMPTY alarm in unmodified production source. This proves software vulnerability, not the actual video's hidden fault code.");
  $finish;
 end
 initial begin #1000000;$fatal(1,"diagnostic timeout");end
endmodule
