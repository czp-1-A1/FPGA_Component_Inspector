`timescale 1ns/1ps
module tb_boundary24 #(parameter PARTS=6,CONSECUTIVE=3,STEP=24,GAP=0,NEGATIVE=0,WRONG_KIND=0,VARIABLE=0);
 reg clk=0;always #5 clk=~clk;
 reg rst_n=0,source_start=0,commit=0,sample=0,occupied=0;wire [16:0] command;reg sw=0;reg [3:0] keys=15;reg ui_clk=0;always #13 ui_clk=~ui_clk;
 wire [19:0] ui_request,control;
 pocket_key_motor_controls #(.CLK_HZ(100000),.DEBOUNCE_MS(2)) keys_ctl(ui_clk,rst_n,sw,keys,ui_request);
 status_cdc #(.WIDTH(20)) control_cdc(ui_clk,clk,rst_n,ui_request,control);
 assign command=control[16:0];
 wire permit=control[19:17]==1 || control[19:17]==2;
 wire paused=control[19:17]==2;
 reg [607:0] main_objects=0,local_objects=0;
 wire lev;wire [15:0] lerun;wire [8:0] leid;wire [1:0] lekind;
 wire [8:0] query,id,ev_id,main_total,local_total,main_unc,local_unc;
 wire pos_new,ev_new,begin_run,clear_run,good,bad,mdv,mdr,ldv,ldr;
 wire [15:0] main_run,local_run,pos_run,ev_run;wire [31:0] current_frame,pos_frame;
 wire [2:0] ms,ls,state;wire [3:0] fault;wire [1:0] kind;
 wire [10:0] x;wire [9:0] y;wire feed,done,stationary;wire [63:0] station_diag;wire [95:0] frozen_diag;wire [5:0] radius;wire [63:0] status;
 wire shv,lhv;wire [10:0] shx,lhx;wire [9:0] shy,lhy;
 classified_count_pipeline #(.LINE_X(640),.LOCAL_RECOVERY(1),.RECORD_ONLY(1),.MOTION_RECOVERY(1),.TAIL_RECOVERY(1),
  .OBS_PER_REGION(4),.ORDERED_HANDOFF(1),.RECOVERABLE(1),.VELOCITY_ASSOC(1),.STOP_CYCLES(1000000)) main(
  .clk(clk),.rst_n(rst_n),.source_start(source_start),.frame_commit(commit),.frame_bad(1'b0),.sample_new(sample),
  .config_tag(64'd1),.objects(main_objects),.empty_probe(32'd0),.command(command),.stop_query_id(9'd0),
  .event_valid(ev_new),.event_run(ev_run),.event_id(ev_id),.event_kind(kind),
  .stop_begin(begin_run),.stop_clear(clear_run),.stop_good_frame(good),.stop_bad_frame(bad),
  .stop_run(main_run),.stop_state(ms),.stop_current_frame(current_frame),.stop_direction_valid(mdv),.stop_direction_right(mdr),
  .stop_total(main_total),.stop_uncertainty(main_unc));
 classified_count_pipeline #(.STOP_POSITION(1),.LINE_X(256),.LOCAL_RECOVERY(0),.RECORD_ONLY(1),.MOTION_RECOVERY(1),.TAIL_RECOVERY(1),
  .OBS_PER_REGION(4),.ORDERED_HANDOFF(1),.RECOVERABLE(1),.VELOCITY_ASSOC(1),.STOP_CYCLES(1000000)) station(
  .clk(clk),.rst_n(rst_n),.source_start(source_start),.frame_commit(commit),.frame_bad(1'b0),.sample_new(sample),
  .config_tag(64'd1),.objects(local_objects),.empty_probe(32'd0),.command(command),.stop_query_id(query),.event_valid(lev),.event_run(lerun),.event_id(leid),.event_kind(lekind),
  .stop_position_new(pos_new),.stop_position_id(id),.stop_position_run(pos_run),.stop_position_frame(pos_frame),.stop_position_x(x),.stop_position_y(y),
  .stop_run(local_run),.stop_state(ls),.stop_direction_valid(ldv),.stop_direction_right(ldr),
  .stop_total(local_total),.stop_uncertainty(local_unc),.stop_search_valid(shv),.stop_search_x(shx),.stop_search_y(shy),
  .hold_valid(lhv),.hold_x(lhx),.hold_y(lhy));
 pocket_relay_stop_v2 #(.RESTART_NEW_RUN(1),.CLK_HZ(100000),.HOLD_MS(1000),.ADVANCE_PX(32),.POSITION_TOL_PX(80)) ctl(
  .clk(clk),.rst_n(rst_n),.permit(permit),.pause(paused),.start_run(begin_run),.clear_run(clear_run),.good_frame(good),.bad_frame(bad),
  .transport_occupied(occupied),.current_frame(current_frame),.counter_run(main_run),.station_run(local_run),
  .counter_state(ms),.station_state(ls),.direction_valid(mdv),.direction_right(mdr),.station_dv(ldv),.station_dr(ldr),
  .counter_total(main_total),.station_total(local_total),.counter_uncertainty(main_unc),.station_uncertainty(local_unc),
  .event_valid(ev_new),.event_run(ev_run),.event_id(ev_id),.event_kind(kind),.query_id(query),
  .station_event_valid(lev),.station_event_run(lerun),.station_event_id(leid),.station_event_kind(lekind),
  .position_new(pos_new),.position_id(id),.position_run(pos_run),.position_frame(pos_frame),.position_x(x),.position_y(y),
  .feed_enable(feed),.state(state),.fault(fault),.status(status),.cycle_done(done));
 reg drop_query=0;integer dropped=0;reg pause_tested=0;reg [15:0] saved_run;
 integer lead=820,frames=0,events=0,completions=0,measurements=0,wait_frames=0,hold_cycles=0;
 integer a,b,i,j,k,idx,best,bestd,distance_ref,coast;bit selected[0:PARTS-1];bit begun=0;
 function integer empty(input integer n);empty=n>=1 && n<=CONSECUTIVE;endfunction
 function [75:0] obj(input integer xx,input integer n);
  obj={1'b1,(empty(n) ? 2'd3 : 2'd2),4'd0,13'd64,7'd8,7'd8,11'(xx-4),11'(xx+4),10'd312,10'd328};
 endfunction
 task ticks(input integer n);repeat(n)@(negedge clk);endtask
 // Independent scene reference supplies only REAL boxes, never IDs. Same
 // four-slot limit as detector: three nearest plus a current held head.
 task pack_zone(input integer lo,input integer hi,input integer center,input bit local_zone);
  reg [303:0] packet;integer xx,held,slot,reserve;
  begin
   packet=0;for(i=0;i<PARTS;i++)selected[i]=0;
   for(slot=0;slot<4;slot++)begin
    best=-1;bestd=99999;
    for(i=0;i<PARTS;i++)begin
     xx=lead+i*40;distance_ref=xx>center ? xx-center : center-xx;
     if(xx>=lo && xx<hi && !(local_zone && drop_query && i==query-1) && !selected[i] && distance_ref<bestd)begin best=i;bestd=distance_ref;end
    end
    if(best>=0)begin selected[best]=1;packet[slot*76+:76]=obj(lead+best*40,best);end
   end
   if(local_zone && !drop_query && shv && query>0 && query<=PARTS)begin
    held=lead+(query-1)*40;
    if(held>=lo && held<hi && !selected[query-1] && held>=shx-radius && held<=shx+radius)packet[3*76+:76]=obj(held,query-1);
   end
   if(local_zone && drop_query && WRONG_KIND)
    packet[3*76+:76]={1'b1,2'd2,4'd0,13'd64,7'd8,7'd8,11'(lead+(query-1)*40-4),11'(lead+(query-1)*40+4),10'd312,10'd328};
   if(local_zone)local_objects={304'd0,packet};else main_objects={304'd0,packet};
  end
 endtask
 task frame(input bit material);
  begin
   // Keep the gap continuous across SETTLE -> REACQUIRE. Dropping only in
   // SETTLE would accidentally make the target return upon entering S7.
   drop_query=material && query==4 && (state==2 || dropped!=0) && dropped<GAP;
   if(drop_query)dropped++;
   if(material)begin pack_zone(448,832,640,0);pack_zone(64,448,256,1);end
   else begin main_objects=0;local_objects=0;end
   source_start=1;ticks(1);source_start=0;ticks(2);commit=1;ticks(1);commit=0;ticks(2);sample=1;ticks(1);sample=0;ticks(3693);frames++;
  end
 endtask
 always @(negedge clk)if(rst_n)begin
  if(begin_run)events=0;
  if(ev_new)begin
   events++;if(ev_id!=events || kind!=(empty(events-1) ? 3 : 2))$fatal(1,"global event order observed ID%0d kind%0d expected%0d kind%0d frame%0d lead%0d state%0d",ev_id,kind,events,empty(events-1)?3:2,frames,lead,ms);
  end
  if(state==7)hold_cycles=0;
  if(pos_new)begin
   measurements++;
   if(drop_query)$fatal(1,"absent query generated an actual position");
   if(id!=query || x!=lead+(id-1)*40 || y!=320 || pos_frame!=current_frame)$fatal(1,"not current same-ID physical measurement");
  end
  if(state==3)begin hold_cycles++;if(feed)$fatal(1,"hold drove feed");end
  if(done)begin
   completions++;
   if(hold_cycles<100000)$fatal(1,"less than complete one second");hold_cycles=0;
  end
  if(state==4 && !(NEGATIVE && dropped!=0 && fault==6 && query==4 && !feed && completions==2 && frozen_diag[95]))$fatal(1,"unexpected fault F%0h MS%0d LS%0d main%0d local%0d lead%0d",fault,ms,ls,main_total,local_total,lead);
 end
 task key(input integer n);
  begin keys=15^(1<<n);repeat(450)@(negedge ui_clk);keys=15;repeat(450)@(negedge ui_clk);ticks(100);end
 endtask
 initial begin
  ticks(5);rst_n=1;ticks(1500);key(0);
  if(feed || state!=5)$fatal(1,"start must await clear-transport proof");
  frame(0);if(!feed || state!=1)$fatal(1,"clear transport did not arm");
  coast=0;
  for(k=0;k<1500 && completions<CONSECUTIVE && state!=4;k++)begin
   frame(1);
   if(query!=0 && !status[57])wait_frames++;
   if(!pause_tested && query==2 && lead>450 && lead<600)begin
    saved_run=main_run;key(1);
    repeat(7)frame(1);
    if(feed || query!=2 || fault!=0 || main_run!=saved_run || !paused)$fatal(1,"pause lost RUN, head or permit");
    key(1);if(!feed || paused || main_run!=saved_run)$fatal(1,"resume did not keep RUN");
    pause_tested=1;
   end
   if(feed)begin lead-=(VARIABLE ? (query==2 ? 3 : query==3 ? 6 : 4) : STEP);coast=0;end
   else if(state==2 && coast<3)begin lead-=(VARIABLE ? (query==2 ? 3 : query==3 ? 6 : 4) : STEP);coast++;end
  end
  if(NEGATIVE)begin
   if(state!=4 || fault!=6 || query!=4 || completions!=2 || feed || dropped<16)$fatal(1,"negative scenario not bounded");
   repeat(20)frame(1);
   if(query!=4 || completions!=2 || feed || fault!=6)$fatal(1,"negative head silently discarded");
   $display("PASS ADJACENT V6 negative kind%0d: persistent lost/different-kind ID4, two prior full holds, one stopped retry bounded, no false position/completion, queue retained",WRONG_KIND);$finish;
  end
  if(completions!=CONSECUTIVE || events!=PARTS || main_total!=PARTS || local_total<CONSECUTIVE+1 || query!=0 || !feed || wait_frames<10 || measurements<15)
   $fatal(1,"incomplete run events%0d done%0d wait%0d pos%0d local%0d",events,completions,wait_frames,measurements,local_total);
  if(GAP!=0 && dropped!=GAP)$fatal(1,"missing-frame scenario not exercised");
  if(!pause_tested)$fatal(1,"pause path never exercised");
  key(3);if(feed)$fatal(1,"K4 stop");
  saved_run=main_run;key(0);frame(0);
  if(!feed || fault!=0 || main_run!=saved_run+1 || main_total!=0 || query!=0)$fatal(1,"K1 restart after completed run");
  // Recreate six abandoned queues. Every explicit SW3 restart must reset
  // BOTH real counters and the queue in the same RUN, without a clear chord.
  for(a=0;a<6;a++)begin
   lead=820;
   for(b=0;b<150 && query==0;b++)begin frame(1);lead-=4;end
   if(query!=2)$fatal(1,"no real EMPTY queued before restart");
   saved_run=main_run;sw=1;repeat(450)@(negedge ui_clk);ticks(100);if(feed)$fatal(1,"SW3 up stop");
   sw=0;repeat(450)@(negedge ui_clk);ticks(100);frame(0);
   if(fault!=0 || !feed || main_total!=0 || local_total!=0 || query!=0 || main_run!=saved_run+1 || main_run!=local_run)$fatal(1,"SW3 restart requires clear or mismatches actual counter RUN");
  end
  saved_run=main_run;key(2);ticks(500);if(feed || query!=0 || main_total!=0 || main_run!=saved_run || ms!=0)$fatal(1,"single K3 actual counter clear");
  $display("PASS ADJACENT V6 transport parts%0d adjacent%0d step%0d coast3 gap%0d: %0d real frames, wait%0d frames, %0d actual same-ID positions, each hold>=100000 clocks",PARTS,CONSECUTIVE,STEP,dropped,frames,wait_frames,measurements);$finish;
 end
 initial begin #500000000;$fatal(1,"left transport timeout");end
endmodule
