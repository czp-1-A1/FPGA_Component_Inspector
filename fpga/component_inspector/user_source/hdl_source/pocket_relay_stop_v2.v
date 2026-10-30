// Left station uses a second REAL ordered gate count. Global IDs are bound
// only after a proved clear transport startup; predicted search is not position.
module pocket_relay_stop_v2 #(
 parameter DIRECT_GLOBAL_TRACK=0,REGISTER_HISTORY=0,FIVE_EMPTY_V7=0,ADJACENT_V6=0,REACQUIRE_MS=500,RESTART_NEW_RUN=0,CLK_HZ=100000000,TARGET_X=160,ADVANCE_PX=16,POSITION_TOL_PX=8,
 parameter STILL_PX=2,HOLD_MS=1000,STALE_MS=150,STOP_TIMEOUT_MS=1200,
 parameter ARRIVAL_TIMEOUT_MS=15000,QUEUE_DEPTH=32
)(
 input wire external_hold,
 input wire clk,rst_n,permit,pause,start_run,clear_run,good_frame,bad_frame,transport_occupied,
 input wire [31:0] current_frame,input wire [15:0] counter_run,station_run,
 input wire [2:0] counter_state,station_state,
 input wire direction_valid,direction_right,station_dv,station_dr,
 input wire [8:0] counter_total,station_total,counter_uncertainty,station_uncertainty,
 input wire event_valid,input wire [15:0] event_run,
 input wire [8:0] event_id,input wire [1:0] event_kind,
 input wire station_event_valid,input wire [15:0] station_event_run,
 input wire [8:0] station_event_id,input wire [1:0] station_event_kind,
 output wire [8:0] query_id,
 input wire position_new,input wire [8:0] position_id,
 input wire [15:0] position_run,input wire [31:0] position_frame,
 input wire [10:0] position_x,input wire [9:0] position_y,
 output wire feed_enable,output reg [2:0] state,output reg [3:0] fault,
 input wire [63:0] station_diagnostic,output wire [95:0] diagnostic,
 output wire stationary_hint,output wire alarm_stop,
 output wire [63:0] status,output reg cycle_done
);
 // Unconnected pause preserves legacy benches; production drives a real 0/1.
 wire paused=(pause===1'b1);wire peer_holds=(external_hold===1'b1);
 reg feed_command;reg [2:0] empty_streak;reg alarm_latched;
 assign alarm_stop=FIVE_EMPTY_V7 && alarm_latched;
 assign feed_enable=feed_command && !paused && !alarm_stop;
 localparam IDLE=0,FEED=1,SETTLE=2,HOLD=3,FAULT=4,ALIGN=5,NEXT=6,REACQUIRE=7;
 localparam DIV=CLK_HZ/1000,DB=DIV>1 ? $clog2(DIV) : 1,QB=$clog2(QUEUE_DEPTH);
 localparam PARAM_OK=CLK_HZ>=1000 && CLK_HZ%1000==0 && QUEUE_DEPTH>=2 && QUEUE_DEPTH<=32 &&
  (QUEUE_DEPTH&(QUEUE_DEPTH-1))==0 && HOLD_MS>=1 && HOLD_MS<=2047 && STALE_MS>=2 && STALE_MS<255 &&
  ARRIVAL_TIMEOUT_MS>STALE_MS && ARRIVAL_TIMEOUT_MS<65535 && STOP_TIMEOUT_MS>=1 && STOP_TIMEOUT_MS<=2047 && REACQUIRE_MS>=STALE_MS && REACQUIRE_MS<=2047 &&
  TARGET_X>POSITION_TOL_PX+64 && TARGET_X+ADVANCE_PX<248 && ADVANCE_PX>=0;
 (* ram_style="distributed" *) reg [8:0] queue[0:QUEUE_DEPTH-1];
 reg [QB-1:0] rd,wr;reg [QB:0] count;
 reg active;reg [15:0] active_run;reg [8:0] last_empty;
 reg [DB-1:0] divider;reg [7:0] frame_age,position_age;
 reg [10:0] phase_ms,last_x,anchor_x;reg [9:0] last_y,anchor_y;
 reg [15:0] arrival_ms;reg [1:0] stable;reg have_position,have_source;
 reg [31:0] last_position_frame;
 reg retry_used;reg [8:0] frozen_head;reg [95:0] frozen_diagnostic;
 assign stationary_hint=ADJACENT_V6 && active && (!feed_enable || peer_holds);
 assign diagnostic=!ADJACENT_V6 ? 96'd0 : frozen_diagnostic[95] ? frozen_diagnostic :
  {1'b0,3'd0,active_run,position_age,station_diagnostic,4'd0};
 // Ordered P/E signature is checked before a local ID may drive a stop.
 // Valid prefix bounds guard this RAM; stale data from a previous run cannot
 // be read as a valid record. Equal-kind undetected skips still require field
 // sequence validation: numbering alone cannot prove an unseen physical hole.
 wire global_event_bad;wire [1:0] local_history_kind;
 // Explicit distributed RAM avoids consuming an ERAM per lane for
 // a 300-bit P/E signature. IDs and prefix bounds retain the original guards.
 wire history_write=rst_n && !clear_run && !start_run && permit && active && state!=FAULT && event_valid && !global_event_bad;
 generate if(DIRECT_GLOBAL_TRACK)begin
  assign local_history_kind=0;
 end else if(REGISTER_HISTORY)begin : signature_bits
  (* ram_style="dram" *) reg memory[0:299];
  always @(posedge clk)if(history_write)memory[event_id-9'd1]<=event_kind[0];
  assign local_history_kind={1'b1,memory[station_event_id-9'd1]};
 end else begin : legacy_signature
  (* ram_style="distributed" *) reg [1:0] kind_history[0:299];
  always @(posedge clk)if(history_write)kind_history[event_id-9'd1]<=event_kind;
  assign local_history_kind=kind_history[station_event_id-9'd1];
 end endgenerate
 reg [8:0] history_total,verified_total,verify_id;
 reg verify_pending;reg [1:0] expected_kind,observed_kind;
 assign global_event_bad=event_valid && (event_run!=active_run || event_id!=history_total+9'd1 ||
  event_id>300 || event_id==0 || event_kind<2);
 wire local_event_bad=!DIRECT_GLOBAL_TRACK && station_event_valid && (station_event_run!=active_run ||
  station_event_id!=verified_total+9'd1 || station_event_id>history_total || station_event_id==0);
 wire signature_bad=!DIRECT_GLOBAL_TRACK && verify_pending && expected_kind!=observed_kind;
 wire tick=divider==DIV-1;
 assign query_id=count!=0 ? queue[rd] : 9'd0;
 wire measured=position_new && count!=0 && position_id==query_id &&
  position_run==active_run && position_frame==current_frame && (DIRECT_GLOBAL_TRACK ? position_id<=counter_total : position_id<=station_total && position_id<=verified_total) &&
  (!have_source || position_frame!=last_position_frame);
 wire push=active && event_valid && event_kind==3 && event_run==active_run && event_id>last_empty;
 wire within_x=position_x>=TARGET_X-POSITION_TOL_PX && position_x<=TARGET_X+POSITION_TOL_PX;
 wire nearby=have_position && {1'b0,position_x}+STILL_PX>=last_x && position_x<=last_x+STILL_PX &&
  {1'b0,position_y}+STILL_PX>=last_y && position_y<=last_y+STILL_PX;
 wire at_anchor={1'b0,position_x}+STILL_PX>=anchor_x && position_x<=anchor_x+STILL_PX &&
  {1'b0,position_y}+STILL_PX>=anchor_y && position_y<=anchor_y+STILL_PX;
 wire counter_fault=bad_frame || counter_state==3 || counter_state==4 || counter_state==6 ||
  (!DIRECT_GLOBAL_TRACK && (station_state==3 || station_state==4 || station_state==6));
 wire wrong_direction=(direction_valid && direction_right) || (!DIRECT_GLOBAL_TRACK && station_dv && station_dr);
 wire uncertain=counter_uncertainty!=0 || (!DIRECT_GLOBAL_TRACK && station_uncertainty!=0);
 wire prefix_bad=counter_run!=active_run || (!DIRECT_GLOBAL_TRACK && (station_run!=active_run || station_total>counter_total));
 wire healthy=!counter_fault && !wrong_direction && !uncertain && !prefix_bad &&
  !global_event_bad && !local_event_bad && !signature_bad && !(push && count==QUEUE_DEPTH);
 // Only proved, ordered GLOBAL IDs count; repeated frames and queue depth do not.
 wire fifth_empty=FIVE_EMPTY_V7 && active && state!=FAULT && event_valid && !global_event_bad &&
  event_kind==3 && empty_streak==4 && healthy;
 wire pop=!fifth_empty && active && !paused && state==HOLD && healthy && tick && phase_ms==HOLD_MS-1 &&
  position_age<STALE_MS-1 && frame_age<STALE_MS-1 && permit &&
  !(measured && (!within_x || !at_anchor));
 // Lower32 keeps V1's S/F/ID/X layout. Upper32 is diagnostics; actual queue
 // count is6 bits, V marks a measurement of THIS head, L is local prefix count.
 wire [5:0] count6=count;
 assign status={count6,(have_source && (!ADJACENT_V6 || position_age<STALE_MS)),station_total,arrival_ms,state,fault,count6[3:0],query_id,last_x,feed_enable};
 task capture_context;input [2:0] cause;input [3:0] why;begin
  if(ADJACENT_V6 && (!frozen_diagnostic[95] || frozen_head!=query_id || why!=6))begin
   frozen_head<=query_id;
   frozen_diagnostic<={1'b1,cause,active_run,position_age,station_diagnostic,why};
  end
 end endtask
 task fail;input [3:0] why;begin
  state<=FAULT;fault<=why;feed_command<=0;capture_context(3,why);
 end endtask
 task relocate;input [2:0] cause;begin
  if(retry_used)fail(6);
  else begin
   state<=REACQUIRE;fault<=6;feed_command<=0;phase_ms<=0;stable<=0;have_position<=0;
   retry_used<=1;capture_context(cause,6);
  end
 end endtask
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin
   empty_streak<=0;alarm_latched<=0;
   state<=IDLE;fault<=0;feed_command<=0;active<=0;active_run<=0;rd<=0;wr<=0;count<=0;last_empty<=0;
   divider<=0;frame_age<=0;position_age<=0;phase_ms<=0;arrival_ms<=0;last_x<=0;last_y<=0;
   anchor_x<=0;anchor_y<=0;stable<=0;have_position<=0;have_source<=0;last_position_frame<=0;cycle_done<=0;
   retry_used<=0;frozen_diagnostic<=0;frozen_head<=0;
   history_total<=0;verified_total<=0;verify_id<=0;verify_pending<=0;expected_kind<=0;observed_kind<=0;
  end else begin
   verify_pending<=0;
   cycle_done<=0;divider<=tick ? 0 : divider+1'b1;
   if(tick)begin
    if(frame_age!=255)frame_age<=frame_age+1'b1;
    if(position_age!=255)position_age<=position_age+1'b1;
    if(!paused && (state==SETTLE || state==HOLD || (ADJACENT_V6 && (state==NEXT || state==REACQUIRE))) && phase_ms!=2047)phase_ms<=phase_ms+1'b1;
    if(!paused && !peer_holds && state==FEED && count!=0 && !have_source && arrival_ms!=65535)arrival_ms<=arrival_ms+1'b1;
   end
   if(good_frame)frame_age<=0;
   if(measured)begin
    last_position_frame<=position_frame;have_source<=1;position_age<=0;
    last_x<=position_x;last_y<=position_y;have_position<=1;
   end
   if(clear_run)begin
    empty_streak<=0;alarm_latched<=0;
    retry_used<=0;frozen_diagnostic<=0;frozen_head<=0;
    active<=0;state<=IDLE;fault<=0;feed_command<=0;rd<=0;wr<=0;count<=0;last_empty<=0;
    have_position<=0;have_source<=0;arrival_ms<=0;
    history_total<=0;verified_total<=0;verify_pending<=0;
   end else if(start_run)begin
    if(count!=0 && !RESTART_NEW_RUN)begin active<=0;fail(10);end
    else if(!PARAM_OK || !permit)begin active<=0;fail(11);end
    else begin
     empty_streak<=0;alarm_latched<=0;
     retry_used<=0;frozen_diagnostic<=0;frozen_head<=0;
     active<=1;state<=ALIGN;fault<=0;feed_command<=0;active_run<=counter_run+16'd1;
     last_empty<=0;rd<=0;wr<=0;count<=0;frame_age<=0;position_age<=0;phase_ms<=0;arrival_ms<=0;
     stable<=0;have_position<=0;have_source<=0;
     history_total<=0;verified_total<=0;verify_pending<=0;
    end
   end else if(!permit)begin active<=0;feed_command<=0;if(state!=FAULT)state<=IDLE;end
   else if(active && state!=FAULT)begin
    if(event_valid && !global_event_bad)begin
     history_total<=event_id;
     if(FIVE_EMPTY_V7)empty_streak<=event_kind==3 ? (empty_streak<5 ? empty_streak+1'b1 : 3'd5) : 3'd0;
    end
    if(station_event_valid && !local_event_bad)begin
     expected_kind<=local_history_kind;observed_kind<=station_event_kind;
     verify_id<=station_event_id;verify_pending<=1;
    end
    if(verify_pending && !signature_bad)verified_total<=verify_id;
    if(push && count<QUEUE_DEPTH)begin queue[wr]<=event_id;wr<=wr+1'b1;last_empty<=event_id;end
    if(pop)begin
     rd<=rd+1'b1;cycle_done<=1;retry_used<=0;
     if(ADJACENT_V6 && (count>1 || push))begin state<=NEXT;feed_command<=0;end
     else begin state<=FEED;feed_command<=1;end
     have_position<=0;have_source<=0;position_age<=0;arrival_ms<=0;stable<=0;phase_ms<=0;
    end
    case({push && count<QUEUE_DEPTH,pop})
     2'b10:count<=count+1'b1;
     2'b01:count<=count-1'b1;
     default:begin end
    endcase
    if(count==0 && push)begin have_position<=0;have_source<=0;position_age<=0;arrival_ms<=0;last_x<=0;end
    if(fifth_empty)begin alarm_latched<=1;fail(15);end
    else if(counter_fault)fail(1);
    else if(tick && frame_age>=STALE_MS-1 && !good_frame)fail(2);
    else if(wrong_direction)fail(3);
    else if(global_event_bad || signature_bad)fail(4);
    else if(push && count==QUEUE_DEPTH)fail(5);
    else if(uncertain)fail(13);
    else if(prefix_bad || local_event_bad)fail(11);
    else if(count!=0 && have_source && tick && position_age>=STALE_MS-1 && !measured && state!=REACQUIRE)begin
     if(ADJACENT_V6)relocate(1);else fail(6);
    end
    else if(!paused && count!=0 && !have_source && tick && arrival_ms>=ARRIVAL_TIMEOUT_MS-1 && !measured)fail(14);
    else if(paused && state!=FEED)begin
     stable<=0;have_position<=0;phase_ms<=0;
     if(state==HOLD)state<=SETTLE;
    end else case(state)
     ALIGN:if(good_frame)begin
      if(transport_occupied || counter_total!=0 || station_total!=0)fail(12);
      else begin state<=FEED;feed_command<=1;end
     end
     FEED:if(measured)begin
      if(position_x<TARGET_X-POSITION_TOL_PX)fail(7);
      else if(position_x<=TARGET_X+ADVANCE_PX)begin
       state<=SETTLE;feed_command<=0;phase_ms<=0;stable<=0;have_position<=0;
      end
     end
     SETTLE:begin
      if(measured)begin
       if(within_x && nearby)begin
        if(stable==2)begin state<=HOLD;anchor_x<=position_x;anchor_y<=position_y;phase_ms<=0;divider<=0;end
        else stable<=stable+1'b1;
       end else stable<=within_x ? 1 : 0;
      end
      if(tick && phase_ms>=STOP_TIMEOUT_MS-1)fail(8);
     end
     HOLD:if(measured && (!within_x || !at_anchor))fail(9);
     NEXT:if(ADJACENT_V6)begin
      // A new head gets a fresh measurement BEFORE any motor restart.
      if(measured)begin
       if(position_x<TARGET_X-POSITION_TOL_PX)fail(7);
       else if(within_x)begin state<=SETTLE;phase_ms<=0;stable<=0;have_position<=0;end
       else begin state<=FEED;feed_command<=1;end
      end else if(good_frame && station_total<query_id)begin state<=FEED;feed_command<=1;end
      else if(tick && phase_ms>=STALE_MS-1)relocate(2);
     end
     REACQUIRE:if(ADJACENT_V6)begin
      // Motor remains OFF. Three independent, current same-ID measurements
      // must be stable; HOLD is then restarted in full, never inherited.
      if(measured)begin
       if(position_x<TARGET_X-POSITION_TOL_PX)fail(7);
       else if(nearby && stable==2)begin
        fault<=0;phase_ms<=0;stable<=0;have_position<=0;
        if(within_x)state<=SETTLE;
        else begin state<=FEED;feed_command<=1;end
       end else stable<=nearby ? stable+1'b1 : 1;
      end
      if(tick && phase_ms>=REACQUIRE_MS-1)fail(6);
     end
     default:begin end
    endcase
   end
  end
 end
endmodule
