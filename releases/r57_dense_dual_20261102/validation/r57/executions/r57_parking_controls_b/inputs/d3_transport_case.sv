`timescale 1ns/1ps
// Physical source-object sequence. All counters, station associations, queues
// and motor arbitration are production RTL; no forced stop positions/events.
module d3_transport_case #(parameter CASE_ID=0);
 localparam CLK_HZ=1000000,FRAME_CYCLES=40000;
 reg clk=0;always #500 clk=~clk;
 reg rst=0,fs=0,proof=0,sample=0;reg [16:0] command=0;
 reg permit=0,pause=0;reg motor=0;
 reg [607:0] main_objects=0,station_objects=0;
 wire [511:0] frame_record,live;wire ready;
 wire [1:0] main_snapshot,main_motion_valid,main_seed_valid;wire [25:0] main_dx;wire [11:0] main_radius;
 wire [21:0] main_seed_x;wire [19:0] main_seed_y;
 wire [1:0] events,main_start,main_clear,main_good,main_bad,main_dv,main_dr;
 wire [31:0] event_run,main_run;wire [17:0] event_id,main_total,main_uncertainty;
 wire [63:0] event_frame,main_frame;wire [3:0] event_kind;wire [7:0] event_reason;wire [5:0] main_state;
 wire feed,alarm;wire [127:0] status;wire [191:0] diagnostic;wire [1:0] done;
 wire [1:0] main_hold_valid;wire [21:0] main_hold_x;wire [19:0] main_hold_y;
 wire [511:0] reference_frame_record;
 wire [511:0] reference_live_record;
 wire [0:0] reference_record_ready;
 wire [1:0] reference_event_valid;
 wire [31:0] reference_event_run;
 wire [17:0] reference_event_id;
 wire [63:0] reference_event_frame;
 wire [3:0] reference_event_kind;
 wire [7:0] reference_event_reason;
 wire [1:0] reference_hold_valid;
 wire [21:0] reference_hold_x;
 wire [19:0] reference_hold_y;
 dual_region_count_pipeline #(.STOP_CYCLES(CLK_HZ/1000*150)) counters(
  .clk(clk),.rst_n(rst),.source_start(fs),.frame_commit(proof),.frame_bad(1'b0),.sample_new(sample),
  .config_tag(64'd1),.objects(main_objects),.empty_probe(32'd0),.command(command),.frame_record(frame_record),.live_record(live),.record_ready(ready),
  .event_valid(events),.event_run(event_run),.event_id(event_id),.event_frame(event_frame),.event_kind(event_kind),.event_reason(event_reason),
  .hold_valid(main_hold_valid),.hold_x(main_hold_x),.hold_y(main_hold_y),
  .parking_snapshot(main_snapshot),.parking_motion_valid(main_motion_valid),.parking_seed_valid(main_seed_valid),
  .parking_dx(main_dx),.parking_radius(main_radius),.parking_seed_x(main_seed_x),.parking_seed_y(main_seed_y),
  .parking_start(main_start),.parking_clear(main_clear),.parking_good(main_good),.parking_bad(main_bad),.parking_run(main_run),.parking_frame(main_frame),
  .parking_state(main_state),.parking_dv(main_dv),.parking_dr(main_dr),.parking_total(main_total),.parking_uncertainty(main_uncertainty));
 dual_region_count_pipeline #(.OBSERVE_PARKING(0),.STOP_CYCLES(CLK_HZ/1000*150)) reference_counter(
  .clk(clk),.rst_n(rst),.source_start(fs),.frame_commit(proof),.frame_bad(1'b0),.sample_new(sample),
  .config_tag(64'd1),.objects(main_objects),.empty_probe(32'd0),.command(command),
  .frame_record(reference_frame_record),
  .live_record(reference_live_record),
  .record_ready(reference_record_ready),
  .event_valid(reference_event_valid),
  .event_run(reference_event_run),
  .event_id(reference_event_id),
  .event_frame(reference_event_frame),
  .event_kind(reference_event_kind),
  .event_reason(reference_event_reason),
  .hold_valid(reference_hold_valid),
  .hold_x(reference_hold_x),
  .hold_y(reference_hold_y));
 always @(posedge clk)if(rst)begin #2;if({frame_record,live,ready,events,event_run,event_id,event_frame,event_kind,event_reason,main_hold_valid,main_hold_x,main_hold_y}!=={reference_frame_record,reference_live_record,reference_record_ready,reference_event_valid,reference_event_run,reference_event_id,reference_event_frame,reference_event_kind,reference_event_reason,reference_hold_valid,reference_hold_x,reference_hold_y})$fatal(1,"R27B public output changed at frame%0d",frame_no);end
 dual_lane_parking #(.CLK_HZ(CLK_HZ)) dut(
  .clk(clk),.rst_n(rst),.permit(permit),.pause(pause),.actual_motor_running(motor),
  .source_start(fs),.frame_commit(proof),.frame_bad(1'b0),.sample_new(sample),.config_tag(64'd1),.command(command),.station_objects(station_objects),
  .main_snapshot(main_snapshot),.main_motion_valid(main_motion_valid),.main_seed_valid(main_seed_valid),
  .main_dx(main_dx),.main_radius(main_radius),.main_seed_x(main_seed_x),.main_seed_y(main_seed_y),
  .main_start(main_start),.main_clear(main_clear),.main_good(main_good),.main_bad(main_bad),.main_run(main_run),.main_frame(main_frame),
  .main_state(main_state),.main_dv(main_dv),.main_dr(main_dr),.main_total(main_total),.main_uncertainty(main_uncertainty),
  .event_valid(events),.event_run(event_run),.event_id(event_id),.event_kind(event_kind),.transport_occupied(2'd0),
  .feed_enable(feed),.alarm_stop(alarm),.status(status),.diagnostic(diagnostic),.cycle_done(done));
 always @(posedge clk or negedge rst)if(!rst)motor<=0;else motor<=permit && !pause && feed && !alarm;
 localparam OBJECTS=(CASE_ID==4 ? 10 : 6);
 integer displacement=0,frame_no=0,hold_cycles[0:1],completions[0:1],event_count[0:1];
 integer lane,idx,checks=0;
 integer round_no=0;integer expected_done[0:1];reg drop_started=0,drop_active=0;integer drop_frames=0;reg pause_used=0;integer paused_frames=0;
 reg [63:0] old_status[0:1];reg [8:0] old_query[0:1];
 function integer kind(input integer row,n);
  begin
   if(CASE_ID==11)kind=(n>=1 && n<=4) ? 3 : 2;
   else if(CASE_ID==1)kind=(n>=1 && n<=3) ? 3 : 2;
   else if(CASE_ID==2 || CASE_ID==3)kind=(row==(CASE_ID-2) && n>=1 && n<=5) ? 3 : 2;
   else if(CASE_ID==4)kind=(row==0 && n!=0 && n!=5) ? 3 : 2;
   else kind=(row==0 ? (n==1 || n==2 || n==3) : (n==2 || n==4)) ? 3 : 2;
  end
 endfunction
 function [75:0] object(input integer xx,yy,kk);
  integer w,h;begin w=kk==3 ? 12 : 36;h=kk==3 ? 12 : 44;
   object={1'b1,2'(kk),4'd0,13'(w*h),7'(w),7'(h),11'(xx-w/2),11'(xx+w/2),10'(yy-h/2),10'(yy+h/2)};
  end
 endfunction
 task ticks(input integer n);repeat(n)@(negedge clk);endtask
 task assemble;
  integer row,bank,kk,ss,xx,yy,chosen,d,dmin,mask,x0,x1,center;
  reg [303:0] packet;reg [75:0] a,b;
  begin
   main_objects=0;station_objects=0;
   for(row=0;row<2;row++)begin
    yy=row ? 516 : 320;
    for(bank=0;bank<2;bank++)begin
     packet=0;mask=0;
     for(ss=0;ss<4;ss++)begin
      chosen=-1;dmin=99999;
      for(kk=0;kk<OBJECTS;kk++)begin
       xx=800+kk*80+((row && CASE_ID!=1) ? 32 : 0)-displacement;
       d=xx>(bank ? 256 : 640) ? xx-(bank ? 256 : 640) : (bank ? 256 : 640)-xx;
       if(!(mask&(1<<kk)) && xx>=(bank ? 64 : 400) && xx<(bank ? 400 : 880) && d<dmin)begin chosen=kk;dmin=d;end
      end
      if(chosen!=-1)begin
       mask=mask|(1<<chosen);xx=800+chosen*80+((row && CASE_ID!=1) ? 32 : 0)-displacement;
       packet[ss*76+:76]=object(xx,yy,kind(row,chosen));
      end
     end
     a=packet[75:0];b=packet[151:76];
     if(b[75] && b[41:31]<a[41:31])begin packet[75:0]=b;packet[151:76]=a;end
     if(bank && row==0 && drop_active)begin
      for(integer z=0;z<4;z++)begin
       a=packet[z*76+:76];
       if(a[75] && ((a[41:31]+a[30:20])/2)==880-displacement)begin
        if(CASE_ID==9)packet[z*76+:76]=object(880-displacement,yy,2);
        else packet[z*76+:76]=0;
       end
      end
     end
     if(bank)station_objects[row*304+:304]=packet;else main_objects[row*304+:304]=packet;
    end
   end
  end
 endtask
 // Count exact clocks spent in HOLD, and bind each completion to its old head.
 always @(posedge clk)begin
  if(rst)begin
   for(integer l=0;l<2;l++)begin
    old_status[l]=status[l*64+:64];old_query[l]=old_status[l][20:12];
    if(old_status[l][31:29]==3)hold_cycles[l]++;
    if(events[l])begin
     event_count[l]++;
     if(event_id[l*9+:9]!=event_count[l] || event_kind[l*2+:2]!=kind(l,event_count[l]-1))$fatal(1,"R27B event order/class changed lane%0d",l);
    end
   end
   #1;
   for(integer l=0;l<2;l++)if(done[l])begin
    if(hold_cycles[l]<CLK_HZ)$fatal(1,"short HOLD lane%0d cycles%0d",l,hold_cycles[l]);
    idx=0;
    for(integer n=0;n<OBJECTS;n++)if(kind(l,n)==3)begin
     if(idx==0 && completions[l]==0)idx=n+1;
    end
    // Select the (completions+1)th actual EMPTY in this lane.
    begin integer seen;seen=0;for(integer n=0;n<OBJECTS;n++)if(kind(l,n)==3)begin
     if(seen==completions[l])idx=n+1;seen++;
    end end
    if(old_query[l]!=idx)$fatal(1,"wrong completed ID lane%0d got%0d want%0d",l,old_query[l],idx);
    completions[l]++;hold_cycles[l]=0;checks++;
    $display("D3_DONE lane%0d id%0d frame%0d displacement%0d Q%0d",l,old_query[l],frame_no,displacement,status[l*64+58+:6]);
   end
  end
 end
 always @(posedge clk)if(rst)for(integer row=0;row<2;row++)if(dut.position_new[row])begin
  integer id,truth;id=dut.position_id[row*9+:9];truth=800+(id-1)*80+((row && CASE_ID!=1) ? 32 : 0)-displacement;
  if(dut.position_x[row*11+:11]!=truth || dut.position_frame[row*32+:32]!=main_frame[row*32+:32])$fatal(1,"wrong physical hole/epoch lane%0d id%0d got%0d truth%0d",row,id,dut.position_x[row*11+:11],truth);
 end
 initial begin
  for(lane=0;lane<2;lane++)begin hold_cycles[lane]=0;completions[lane]=0;event_count[lane]=0;end
  for(lane=0;lane<2;lane++)begin
   expected_done[lane]=0;for(integer n=0;n<OBJECTS;n++)if(kind(lane,n)==3)expected_done[lane]++;
  end
  ticks(8);rst=1;ticks(4);permit=1;command=2;ticks(200);
  for(frame_no=1;frame_no<=900;frame_no++)begin
   if(CASE_ID>=6 && CASE_ID<=9 && !drop_started && 880-displacement<=192 && 880-displacement>=176)begin drop_started=1;drop_active=1;drop_frames=0;end
   if(drop_active)begin drop_frames++;if(drop_frames>(CASE_ID==6 ? 1 : CASE_ID==7 ? 7 : 900))drop_active=0;end
   assemble();fs=1;ticks(1);fs=0;proof=1;ticks(1);proof=0;ticks(2);sample=1;ticks(1);sample=0;
   ticks(1000);
   if(CASE_ID==2 || CASE_ID==3)begin
    if(alarm)begin
     if(!dut.lane_alarm[CASE_ID-2] || dut.lane_alarm[3-CASE_ID])$fatal(1,"five EMPTY alarm mixed lanes");
     if(event_count[CASE_ID-2]!=6)$fatal(1,"alarm was not fifth real consecutive EMPTY");
     ticks(2*CLK_HZ);if(motor || !alarm)$fatal(1,"alarm auto resumed");
     command=5;ticks(200);if(alarm || motor || main_total!=0)$fatal(1,"single clear did not reset alarm/count/stop");
     $display("PASS D3 CASE%0d five consecutive EMPTY lane%0d, peer isolated, latched motor stop, single clear",CASE_ID,CASE_ID-2);$finish;
    end
   end
   if((CASE_ID==8 || CASE_ID==9) && status[31:29]==4)begin
    if(status[28:25]!=6 || completions[0]!=0 || motor)$fatal(1,"unseen/wrong-class query fabricated completion or wrong guard");
    $display("PASS D3 CASE%0d persistent absence/wrong class retains ID, no stale completion, F6 motor stop",CASE_ID);$finish;
   end
   if(status[28:25]!=0 && !(CASE_ID>=6 && status[31:29]==7) || status[92:89]!=0)$fatal(1,"parking fault frame%0d mainstates%h status%h diag%h",frame_no,main_state,status,diagnostic);
   ticks(FRAME_CYCLES-1005);
   if(CASE_ID==5 && !pause_used && status[31:29]==3)begin pause=1;pause_used=1;paused_frames=0;end
   if(pause)begin
    paused_frames++;if(motor)$fatal(1,"pause left motor on");
    if(paused_frames==10)pause=0;
   end
   if(motor)displacement+=(CASE_ID==4 ? (frame_no%3==0 ? 4 : frame_no%3==1 ? 8 : 12) : 8);
   if(event_count[0]==OBJECTS && event_count[1]==OBJECTS && completions[0]==expected_done[0] && completions[1]==expected_done[1] && status[63:58]==0 && status[127:122]==0 && motor)begin
    if(alarm)$fatal(1,"spurious fifth EMPTY across P or lanes");
    if(CASE_ID==10 && round_no==0)begin
     round_no=1;displacement=0;command=4;
     for(lane=0;lane<2;lane++)begin hold_cycles[lane]=0;completions[lane]=0;event_count[lane]=0;end
     ticks(200);
    end else begin
    $display("PASS D3 CASE%0d: %0d frames, independent IDs%0d/%0d, full-second holds%0d/%0d, shared motor resume, both queues empty",CASE_ID,frame_no,event_count[0],event_count[1],completions[0],completions[1]);$finish;end
   end
  end
  $fatal(1,"dual transport did not finish events%0d/%0d done%0d/%0d status%h",event_count[0],event_count[1],completions[0],completions[1],status);
 end
 initial begin #(64'd60000000000);$fatal(1,"watchdog");end
endmodule
