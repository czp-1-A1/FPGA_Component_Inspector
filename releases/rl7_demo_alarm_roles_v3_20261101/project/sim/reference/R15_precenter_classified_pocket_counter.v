// Consumes the UNMODIFIED frame_shape_search four-record result, once per
// proved source frame. Display rank is never an identity. No pixel RAM/search.
module R15_precenter_classified_pocket_counter #(
 parameter LINE_X=640,HYST=3,MAX_STEP=12,Y_STEP=8,MAX_TOTAL=300,RECORD_ONLY=0,MOTION_RECOVERY=0,TAIL_RECOVERY=0,OBS_PER_REGION=2,ORDERED_HANDOFF=0,RECOVERABLE=0,VELOCITY_ASSOC=0,LOCAL_RECOVERY=0
)(
 input wire clk,rst_n,start_run,finish_run,frame_bad,
 input wire sample_new,input wire [31:0] frame_id,input wire [63:0] config_tag,
 input wire [152*OBS_PER_REGION-1:0] objects,
 output reg busy,output reg snapshot_new,
 output reg [2:0] state,output reg [3:0] reason,
 output reg [15:0] run_id,output reg [8:0] total,present_total,empty_total,review_total,
 output reg direction_valid,direction_right,output reg region,
 output reg [35:0] object_ids,
 output reg event_valid,output reg [15:0] event_run,
 output reg [8:0] event_id,output reg [31:0] event_frame,
 output reg [1:0] event_kind,output reg [3:0] event_reason,
 input wire [8:0] ledger_address,output reg [5:0] ledger_data,
 input wire [8:0] empty_address,output reg [8:0] empty_id,
 output reg hold_valid,output reg [10:0] hold_x,output reg [9:0] hold_y,
 output reg [15:0] diagnostic,output reg [8:0] uncertainty_from
);
 localparam IDLE=0,ACQUIRE=1,RUN=2,LOST=3,DONE=4,HOLD=5,CHECK_REQUIRED=6;
 wire tracking=state==RUN || (RECOVERABLE && state==HOLD);
 localparam WAIT=0,LOAD=1,OBS=2,SCAN=3,ASSIGN=4,CHECK=5,MOTION=6,
            APPLY=7,CROSS_CHECK=8,EMIT=9,PUBLISH=10,ORDER_SCAN=11,ORDER_SELECT=12,
            READ_SCAN=13,READ_ASSIGN=14,READ_CHECK=15,READ_APPLY=16,
            READ_ORDER=17,READ_LEAD=18,READ_EMIT=19,READ_SKIP=20,SKIP=21,APPLY_SETUP=22;
 // Only oneROI may be active. Capture its4 observations once, rather than
 // storing and repeatedly muxing both608-bit region banks in the recorder.
 // Legacy2-perROI mode retains its original packet and display-ID mapping.
 localparam OBS_COUNT=ORDERED_HANDOFF ? OBS_PER_REGION : 2*OBS_PER_REGION;
 localparam OI_BITS=$clog2(OBS_COUNT),REGION_BITS=$clog2(OBS_PER_REGION);
 localparam GAP_BITS=RECOVERABLE ? 4 : ORDERED_HANDOFF ? 3 : 2;
 localparam DX_BITS=RECOVERABLE ? 10 : 9;
 localparam TRACK_BITS=MOTION_RECOVERY ? 60+DX_BITS+GAP_BITS : (RECORD_ONLY ? 60+GAP_BITS : 60);
 reg [4:0] phase;
 reg [76*OBS_COUNT-1:0] packet;reg packet_region,packet_ambiguous;reg [31:0] source_id,last_frame;
 function region_has_target;
  input [76*OBS_PER_REGION-1:0] data;
  integer region_slot;
  begin region_has_target=0;
   for(region_slot=0;region_slot<OBS_PER_REGION;region_slot=region_slot+1)
    region_has_target=region_has_target | (data[region_slot*76+75] && data[region_slot*76+73+:2]>=2);
  end
 endfunction
 wire incoming_r0=region_has_target(objects[0+:76*OBS_PER_REGION]);
 wire incoming_r1=region_has_target(objects[76*OBS_PER_REGION+:76*OBS_PER_REGION]);
 reg [63:0] active_config;reg have_frame,have_region;
 reg [31:0] valid_tracks,used;
 reg [31:0] frame_tracks;reg frame_trusted,gap_open;
 // One packed, single-read track RAM. All FSM phases share its address;
 // separate variable-index arrays would infer several large read mux trees.
 (* ram_style="distributed" *) reg [TRACK_BITS-1:0] tracks[0:31];
 reg [31:0] armed;
 // A quarantined identity remains available for a bounded actual return,
 // but cannot block the ordered publisher or reserve a classifier slot.
 // Counted tracks retain their IDs as before. No missing track emits.
 reg [31:0] quarantined;
 reg [5:0] mapping[0:OBS_COUNT-1];reg [2:0] oi;reg [5:0] si,found,free_slot;
 reg [2:0] matches,matched_count,positive,negative,visible,motion_count;
 reg [13:0] best_error;
 reg [2:0] stable_frames;reg signed [12:0] accumulated,first_dx;
 reg [4:0] reverse_motion;
 wire signed [13:0] directed_dx=direction_right ? $signed({first_dx[12],first_dx}) : -$signed({first_dx[12],first_dx});
 wire signed [13:0] reverse_next=$signed({9'd0,reverse_motion})-directed_dx;
 reg [10:0] pitch,previous_speed;reg pitch_valid;
 reg [10:0] pitch_candidate;reg [1:0] pitch_votes;
 reg signed [12:0] previous_dx;reg recovered_far,direct_anchor;reg [2:0] direct_count;
 reg [OBS_COUNT-1:0] crossings;reg [OI_BITS-1:0] cross_index;reg unstable_cross,motion_conflict;
 // Each pending entry was observed crossing in a proved source frame.
 // Valid bits reset, RAM contents do not. Later classifier changes cannot
 // rewrite a deferred real event's kind/reason/source identity.
 reg [31:0] cross_pending;
 (* ram_style="distributed" *) reg [37:0] pending_event[0:31];
 reg [5:0] lead_track;reg [4:0] emit_track;reg signed [13:0] lead_x;
 wire [37:0] pending_word=pending_event[emit_track];
 reg [5:0] ledger[0:MAX_TOTAL-1];reg [8:0] empty_ids[0:MAX_TOTAL-1];
 wire [75:0] ob=packet[oi[OI_BITS-1:0]*76+:76];
 wire [11:0] cx_sum={1'b0,ob[41:31]}+ob[30:20];
 wire [10:0] cx=cx_sum[11:1];
 wire [10:0] cy_sum={1'b0,ob[19:10]}+ob[9:0];
 wire [9:0] cy=cy_sum[10:1];
 wire target=ob[75] && ob[74:73]>=2;
 wire selected=ORDERED_HANDOFF || oi[OI_BITS-1]==region;
 wire [1:0] display_index=ORDERED_HANDOFF ? {region,oi[0]} : {oi[OI_BITS-1],oi[0]};
 wire display_slot=oi[REGION_BITS-1:0]<2;
 wire [4:0] track_address=(phase==SCAN || phase==READ_SCAN || phase==CHECK || phase==READ_CHECK || phase==ORDER_SCAN || phase==READ_ORDER || phase==READ_SKIP || phase==SKIP) ? si[4:0] :
  ((phase==EMIT || phase==READ_EMIT) && ORDERED_HANDOFF) ? emit_track :
  ((phase==ORDER_SELECT || phase==READ_LEAD) && ORDERED_HANDOFF) ? lead_track[4:0] :
  (phase==ASSIGN || phase==READ_ASSIGN) ? (matches==1 ? found[4:0] : free_slot[4:0]) : mapping[oi[OI_BITS-1:0]][4:0];
 // Capture the selected track word before any arithmetic/state action.
 // No reset on this data register: every consumer has a prior READ state,
 // and invalid track addresses remain masked by valid_tracks as before.
 reg [TRACK_BITS-1:0] track_word;
 always @(posedge clk)if(phase==READ_SCAN || phase==READ_ASSIGN || phase==READ_CHECK ||
   phase==READ_APPLY || phase==READ_ORDER || phase==READ_LEAD || phase==READ_EMIT || phase==READ_SKIP)
  track_word<=tracks[track_address];
 wire [GAP_BITS-1:0] missing=RECORD_ONLY ? track_word>>60 : 0;
 // Sum only SAME-FRAME measured anchor motion during a gap. It is not a
 // displayed position and is never used to synthesize a crossing/event.
 wire signed [DX_BITS-1:0] missed_dx=MOTION_RECOVERY ? track_word>>(60+GAP_BITS) : {DX_BITS{1'b0}};
 // Association is bounded below half an actually observed spacing. Spacing
 // never creates a target or an event. A temporarily absent target is kept
 // for at most two proved source frames and must be observed again to count.
 wire [10:0] half_spacing=MOTION_RECOVERY ? (pitch-1'b1)>>1 :
  (pitch>(2*HYST+2) ? (pitch-2*HYST-2)>>1 : 0);
 wire [10:0] match_step=RECORD_ONLY && pitch_valid ? (half_spacing<32 ? half_spacing : 11'd32) : MAX_STEP;
 wire [10:0] match_y=RECORD_ONLY ? 16 : Y_STEP;
 wire [10:0] old_x=track_word[10:0],old_left=track_word[31:21],old_right=track_word[42:32];
 // Include the distance reachable during the two-frame observation grace
 // plus the returning frame. Missing targets are never moved or counted.
 // Ordered mode permits four missed source opportunities, so the guarded
 // upstream span must include those four steps plus the actual return step.
 // Keeping the legacy three-step span silently retired an armed E at572
 // before its genuine source10 return. This is retention, never an event.
 localparam CRITICAL_STEPS=RECOVERABLE ? 9 : ORDERED_HANDOFF ? 5 : 3;
 wire critical=old_x<=LINE_X+HYST+CRITICAL_STEPS*match_step && old_x>=LINE_X-HYST-CRITICAL_STEPS*match_step;
 wire [9:0] old_y=track_word[20:11];wire [8:0] old_id=track_word[51:43];
 wire [1:0] old_kind=track_word[53:52],old_confirm=track_word[55:54];wire [3:0] old_mask=track_word[59:56];
 wire signed [12:0] dx=$signed({2'b0,cx})-$signed({2'b0,old_x});
 wire signed [11:0] dy=$signed({2'b0,cy})-$signed({2'b0,old_y});
 // Prediction is used ONLY to associate an actually returning result. It
 // cannot publish a box, create a hole, or emit a count in an absent frame.
 // Fast recovery additionally requires a same-frame, consecutively observed
 // anchor with consistent measured motion (checked before APPLY/EMIT).
 wire signed [13:0] predicted_dx=$signed({{(14-DX_BITS){missed_dx[DX_BITS-1]}},missed_dx})+$signed({previous_dx[12],previous_dx});
 wire signed [13:0] prediction_error=$signed({dx[12],dx})-predicted_dx;
 // On a return, subtract the measured intervening anchor displacement. The
 // residual is the CURRENT step, not the whole multi-frame displacement.
 wire signed [13:0] returned_step=$signed({dx[12],dx})-$signed({{(14-DX_BITS){missed_dx[DX_BITS-1]}},missed_dx});
 wire signed [13:0] motion_dx=MOTION_RECOVERY && missing!=0 ? returned_step : $signed({dx[12],dx});
 wire [10:0] recovery_radius=match_step<8 ? match_step : 11'd8;
 wire direct_near=dx>=-$signed({2'b0,match_step}) && dx<=$signed({2'b0,match_step});
 wire predicted_near=prediction_error>=-$signed({3'b0,recovery_radius}) && prediction_error<=$signed({3'b0,recovery_radius});
 wire [OBS_COUNT-1:0] real_observations;
 // Match a CURRENT classified measurement to its predicted identity. The
 // old centre-only radius aliases adjacent pockets above half-pitch/frame,
 // and an initially doubled measured pitch can make two tracks overlap.
 // Prior velocity shifts the association window, never an observed position
 // or an event. Before motion is learned retain the conservative old gate.
 wire velocity_window=VELOCITY_ASSOC && previous_speed!=0;
 wire bootstrap_window=VELOCITY_ASSOC && state==ACQUIRE && !pitch_valid && previous_speed==0 &&
  real_observations!=0 && (real_observations & (real_observations-1'b1))==0;
 wire bootstrap_near=dx>=-32 && dx<=32;
 wire signed [13:0] association_delta=velocity_window ? prediction_error : $signed({dx[12],dx});
 wire [13:0] association_error=association_delta[13] ? -association_delta : association_delta;
 wire velocity_near=association_error<={3'b0,match_step};
 wire [14:0] score_with_margin={1'b0,association_error}+HYST;
 wire [14:0] best_with_margin={1'b0,best_error}+HYST;
 wire conservative_gap=previous_speed*(missing+1)<=match_step;
 wire signed [13:0] anchor_error=$signed({first_dx[12],first_dx})-$signed({previous_dx[12],previous_dx});
 wire anchor_consistent=motion_count!=0 && anchor_error>=-HYST && anchor_error<=HYST;
 wire [10:0] reverse_limit=MOTION_RECOVERY ? match_step : 2*HYST;
 wire counted_guard=old_x<=LINE_X+HYST+reverse_limit && old_x>=LINE_X-HYST-reverse_limit;
 // A current matched anchor may accelerate; it need not repeat last speed.
 wire measured_anchor=direct_anchor && !motion_conflict && (positive==0 || negative==0);
 wire anchored_group=ORDERED_HANDOFF && direct_count>=2 && measured_anchor;
 wire signed [13:0] next_hold_x=lead_x+$signed({previous_dx[12],previous_dx});
 wire signed [13:0] order_position=$signed({3'b0,old_x})+$signed({{(14-DX_BITS){missed_dx[DX_BITS-1]}},missed_dx});
 wire [4:0] event_slot=ORDERED_HANDOFF ? emit_track : mapping[oi[OI_BITS-1:0]][4:0];
 wire [1:0] recorded_kind=ORDERED_HANDOFF ? pending_word[5:4] : old_kind;
 wire [3:0] recorded_mask=ORDERED_HANDOFF ? pending_word[3:0] : old_mask;
 wire [31:0] recorded_frame=ORDERED_HANDOFF ? pending_word[37:6] : source_id;
 // With no observed anchor, keep at most two source-frame opportunities.
 // The prior displacement below predicts ASSOCIATION ONLY. No absent box,
 // class, crossing or event is ever generated from this estimate.
 wire signed [12:0] gap_step=TAIL_RECOVERY && !measured_anchor ? previous_dx : first_dx;
 wire signed [13:0] gap_motion=$signed({{(14-DX_BITS){missed_dx[DX_BITS-1]}},missed_dx})+$signed({gap_step[12],gap_step});
 wire [10:0] trusted_step=VELOCITY_ASSOC && pitch_valid && pitch>2*HYST+2 ? pitch-HYST-1 : match_step;
 wire lone_return=TAIL_RECOVERY && visible==1 && matched_count==1 && pitch_valid &&
  previous_speed<=trusted_step && first_dx>=-$signed({2'b0,trusted_step}) && first_dx<=$signed({2'b0,trusted_step}) &&
  (!VELOCITY_ASSOC || (anchor_error>=-8 && anchor_error<=8));
 wire signed [13:0] travelled_x=$signed({3'b0,old_x})+gap_motion;
 wire signed [13:0] counted_distance=direction_right ? travelled_x-LINE_X : LINE_X-travelled_x;
 wire counted_retire_safe=MOTION_RECOVERY && old_id!=0 && motion_count!=0 && (TAIL_RECOVERY ? measured_anchor : anchor_consistent) &&
  counted_distance>$signed({3'b0,reverse_limit})+HYST;
 wire local_return_near=!LOCAL_RECOVERY || !quarantined[si[4:0]] || predicted_near;
 wire near_track=valid_tracks[si[4:0]] && local_return_near &&
  // A finalized EMPTY must not steal an adjacent PRESENT when its tiny
  // observed centre flickers towards that body. Its recorded kind is fixed;
  // a different classified kind may enter only as a new upstream identity.
  !(RECOVERABLE && old_id!=0 && old_kind==3 && ob[74:73]!=3) &&
  (bootstrap_window ? bootstrap_near : VELOCITY_ASSOC && velocity_window ? velocity_near :
   (MOTION_RECOVERY && missing!=0 ? ((conservative_gap && direct_near) || predicted_near) : direct_near)) &&
  dy>=-$signed({1'b0,match_y}) && dy<=$signed({1'b0,match_y}) &&
  (RECORD_ONLY || !pitch_valid || (dx*4<$signed({2'b0,pitch}) && dx*4>-$signed({2'b0,pitch}))) &&
  (!RECORD_ONLY || MOTION_RECOVERY || missing==0 || conservative_gap);
 genvar observation;
 generate for(observation=0;observation<OBS_COUNT;observation=observation+1)begin : typed_observations
  assign real_observations[observation]=packet[observation*76+75] && packet[observation*76+73+:2]>=2;
 end endgenerate
 wire r0,r1;wire [151:0] pair;
 generate if(ORDERED_HANDOFF)begin : single_region_observations
  assign r0=(|real_observations) && (!packet_region || packet_ambiguous);
  assign r1=(|real_observations) && (packet_region || packet_ambiguous);
  assign pair=packet[151:0];
 end else begin : original_region_observations
  assign r0=|real_observations[OBS_PER_REGION-1:0];
  assign r1=|real_observations[OBS_COUNT-1:OBS_PER_REGION];
  assign pair=r1 ? packet[OBS_PER_REGION*76+:152] : packet[151:0];
 end endgenerate
 wire pair_valid=pair[75] && pair[74:73]>=2 && pair[151] && pair[150:149]>=2;
 wire [11:0] separation2=({1'b0,pair[117:107]}+pair[106:96])-({1'b0,pair[41:31]}+pair[30:20]);
 wire [10:0] separation=separation2[11:1];
 wire [4:0] mi=mapping[oi[OI_BITS-1:0]][4:0];
 wire upstream=RECORD_ONLY ? (direction_right ? cx<LINE_X-HYST : cx>LINE_X+HYST) : (direction_right ? ob[30:20]<LINE_X-HYST : ob[41:31]>LINE_X+HYST);
 wire downstream=RECORD_ONLY ? (direction_right ? cx>LINE_X+HYST : cx<LINE_X-HYST) : (direction_right ? ob[41:31]>LINE_X+HYST : ob[30:20]<LINE_X-HYST);
 wire signed [13:0] skipped_motion=$signed({{(14-DX_BITS){missed_dx[DX_BITS-1]}},missed_dx})+$signed({previous_dx[12],previous_dx});
 integer q;
 task mark_gap;
  begin if(LOCAL_RECOVERY && uncertainty_from==0)uncertainty_from<=total+9'd1;end
 endtask
 task next_observation;
  begin
   if(oi==OBS_COUNT-1)begin si<=0;phase<=RECOVERABLE ? MOTION : READ_CHECK;end
   else begin oi<=oi+1'b1;phase<=OBS;end
  end
 endtask
 task lose;
  input [3:0] why;
  begin state<=LOST;reason<=why;hold_valid<=0;busy<=0;phase<=WAIT;snapshot_new<=1;end
 endtask
 // Keep the first error detail until an explicit new-run/full-clear.
 task note_fault;
  input [3:0] subreason;input [5:0] track;input [GAP_BITS-1:0] gap;
  begin if(diagnostic==0)diagnostic<={subreason,track,{{(4-GAP_BITS){1'b0}},gap},(direct_count>=3 ? 2'd3 : direct_count[1:0])};end
 endtask
 // Association errors occur before CHECK/APPLY in recoverable mode. Only
 // newly allocated valid bits need rollback; prior RAM words are untouched.
 task recover_sample;
  input [3:0] subreason;input [5:0] track;
  begin
   note_fault(subreason,track,0);frame_trusted<=0;used<=0;object_ids<=0;
   if(state==ACQUIRE)begin
    state<=ACQUIRE;reason<=1;valid_tracks<=0;armed<=0;stable_frames<=0;accumulated<=0;phase<=PUBLISH;
   end else begin state<=HOLD;reason<=3;valid_tracks<=frame_tracks;si<=0;phase<=READ_SKIP;end
  end
 endtask
 // RAM contents are run-length bounded; never reset or expose stale addresses.
 always @(posedge clk)begin
  ledger_data<=ledger_address<total ? ledger[ledger_address] : 6'd0;
  empty_id<=empty_address<empty_total ? empty_ids[empty_address] : 9'd0;
 end
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin
   state<=IDLE;reason<=0;hold_valid<=0;hold_x<=0;hold_y<=0;phase<=WAIT;busy<=0;snapshot_new<=0;
   diagnostic<=0;uncertainty_from<=0;quarantined<=0;frame_tracks<=0;frame_trusted<=0;gap_open<=0;pitch_candidate<=0;pitch_votes<=0;
   run_id<=0;total<=0;present_total<=0;empty_total<=0;review_total<=0;
   direction_valid<=0;direction_right<=0;region<=0;have_region<=0;
   object_ids<=0;packet_region<=0;packet_ambiguous<=0;cross_pending<=0;lead_track<=32;emit_track<=0;lead_x<=0;valid_tracks<=0;used<=0;armed<=0;cross_pending<=0;packet<=0;
   source_id<=0;last_frame<=0;active_config<=0;have_frame<=0;
   stable_frames<=0;accumulated<=0;first_dx<=0;oi<=0;si<=0;pitch<=0;pitch_valid<=0;reverse_motion<=0;previous_speed<=0;previous_dx<=0;recovered_far<=0;direct_anchor<=0;direct_count<=0;
   found<=32;free_slot<=32;matches<=0;best_error<=14'h3fff;matched_count<=0;positive<=0;negative<=0;visible<=0;motion_count<=0;
   crossings<=0;cross_index<=0;unstable_cross<=0;motion_conflict<=0;event_valid<=0;event_run<=0;event_id<=0;event_frame<=0;event_kind<=0;event_reason<=0;
  end else begin
   snapshot_new<=0;event_valid<=0;
   if(start_run)begin
    diagnostic<=0;uncertainty_from<=0;quarantined<=0;frame_tracks<=0;frame_trusted<=0;gap_open<=0;pitch_candidate<=0;pitch_votes<=0;
    run_id<=run_id+1'b1;hold_valid<=0;state<=ACQUIRE;reason<=1;phase<=WAIT;busy<=0;
    total<=0;present_total<=0;empty_total<=0;review_total<=0;
    valid_tracks<=0;armed<=0;cross_pending<=0;used<=0;object_ids<=0;have_frame<=0;have_region<=0;
    direction_valid<=0;stable_frames<=0;accumulated<=0;pitch_valid<=0;reverse_motion<=0;previous_speed<=0;previous_dx<=0;recovered_far<=0;direct_anchor<=0;direct_count<=0;snapshot_new<=1;
   end else if(finish_run)begin
    state<=RECORD_ONLY ? IDLE : DONE;hold_valid<=0;reason<=0;busy<=0;phase<=WAIT;snapshot_new<=1;
    if(RECORD_ONLY)begin
     diagnostic<=0;uncertainty_from<=0;quarantined<=0;frame_tracks<=0;frame_trusted<=0;gap_open<=0;pitch_candidate<=0;pitch_votes<=0;
     total<=0;present_total<=0;empty_total<=0;review_total<=0;object_ids<=0;
     valid_tracks<=0;used<=0;armed<=0;cross_pending<=0;have_frame<=0;have_region<=0;
     direction_valid<=0;direction_right<=0;region<=0;stable_frames<=0;accumulated<=0;
     pitch_valid<=0;reverse_motion<=0;crossings<=0;previous_speed<=0;previous_dx<=0;recovered_far<=0;direct_anchor<=0;direct_count<=0;
     // Keep run_id monotonic: clearing the visible RUN count must never
     // allow old DDR metadata or an old event to acquire a new run identity.
    end
   end
   else if(frame_bad && (state==ACQUIRE || tracking))lose(6);
   else if(sample_new && busy)begin if(state==ACQUIRE || tracking)lose(8);end
   else case(phase)
    WAIT:if(sample_new && (state==ACQUIRE || tracking) && (!have_frame || frame_id!=last_frame))begin
     if(have_frame && (frame_id!=last_frame+1'b1 || config_tag!=active_config))lose(6);
     else begin
      if(ORDERED_HANDOFF)packet<=incoming_r1 ? objects[76*OBS_PER_REGION+:76*OBS_PER_REGION] : objects[0+:76*OBS_PER_REGION];
      else packet<=objects;
      packet_region<=incoming_r1;packet_ambiguous<=incoming_r0 && incoming_r1;
      source_id<=frame_id;last_frame<=frame_id;active_config<=config_tag;have_frame<=1;
      busy<=1;phase<=LOAD;used<=0;frame_tracks<=valid_tracks;frame_trusted<=1;gap_open<=0;oi<=0;object_ids<=0;
      matched_count<=0;positive<=0;negative<=0;visible<=0;motion_count<=0;crossings<=0;unstable_cross<=0;motion_conflict<=0;first_dx<=0;recovered_far<=0;direct_anchor<=0;direct_count<=0;
     end
    end
    READ_SCAN:phase<=SCAN;
    READ_ASSIGN:phase<=ASSIGN;
    READ_CHECK:phase<=CHECK;
    READ_APPLY:phase<=APPLY;
    READ_ORDER:phase<=ORDER_SCAN;
    READ_LEAD:phase<=ORDER_SELECT;
    READ_EMIT:phase<=EMIT;
    READ_SKIP:phase<=SKIP;
    LOAD:begin
     if(r0 && r1)begin
      if(tracking)lose(2);
      else begin valid_tracks<=0;armed<=0;have_region<=0;pitch_valid<=0;stable_frames<=0;accumulated<=0;reason<=2;phase<=PUBLISH;end
     end else if(!r0 && !r1)begin
      if(tracking)begin if(RECORD_ONLY)phase<=OBS;else lose(4);end
      else begin valid_tracks<=0;armed<=0;pitch_valid<=0;stable_frames<=0;reason<=1;phase<=PUBLISH;end
     end else if(have_region && region!=r1 && tracking)lose(2);
     else if(pair_valid && separation<=(RECORD_ONLY ? 2*HYST+2 : 2*MAX_STEP+2))begin
      if(RECOVERABLE)recover_sample(7,6'd32);else lose(3);
     end
     // Measured spacing is an integrity check only. Missing targets never
     // create IDs; an unexpected doubled gap stops this run instead.
     else if(!RECORD_ONLY && pair_valid && pitch_valid && have_region && region==r1 && (separation>pitch+(pitch>>2) || separation<pitch-(pitch>>2)))lose(9);
     else begin
      if(!have_region || region!=r1)begin valid_tracks<=0;armed<=0;stable_frames<=0;accumulated<=0;end
      if(pair_valid && (!pitch_valid || !have_region || region!=r1))begin
       pitch<=separation;pitch_valid<=1;pitch_votes<=0;
      end else if(pair_valid && RECORD_ONLY && separation<pitch)begin
       if(!RECOVERABLE)begin pitch<=separation;pitch_valid<=1;end
       // A single weak-empty centre jump must not shrink every track's
       // matching radius. Three agreeing measured source pairs are needed.
       else if(separation+2>=pitch_candidate && separation<=pitch_candidate+2 && pitch_votes!=0)begin
        if(pitch_votes==2)begin pitch<=separation;pitch_votes<=0;end
        else pitch_votes<=pitch_votes+1'b1;
       end else begin pitch_candidate<=separation;pitch_votes<=1;end
      end else if(RECOVERABLE) pitch_votes<=0;
      if(state==ACQUIRE)reason<=1;
      have_region<=1;region<=r1;phase<=OBS;
     end
    end
    OBS:begin
     mapping[oi[OI_BITS-1:0]]<=32;
     if(target && selected)begin si<=0;matches<=0;best_error<=14'h3fff;found<=32;free_slot<=32;phase<=READ_SCAN;visible<=visible+1'b1;end
     else if(!RECORD_ONLY && ob[75] && ob[74:73]==1 && selected && ob[41:31]<=LINE_X+HYST && ob[30:20]>=LINE_X-HYST && tracking)lose(7);
     else if(oi==OBS_COUNT-1)begin si<=0;phase<=RECOVERABLE ? MOTION : READ_CHECK;end
     else oi<=oi+1'b1;
    end
    SCAN:begin
     if(!valid_tracks[si[4:0]] && free_slot==32)free_slot<=si;
     if(near_track)begin
      if(VELOCITY_ASSOC)begin
       if(matches==0 || association_error<best_error)begin
        best_error<=association_error;found<=si;
        matches<=matches==0 || score_with_margin<{1'b0,best_error} ? 1 : 2;
       end else if({1'b0,association_error}<=best_with_margin)matches<=2;
      end else begin
       matches<=matches+1'b1;found<=si;
       if(used[si[4:0]])begin matches<=3;end
      end
     end
     if(si==31)phase<=READ_ASSIGN;else begin si<=si+1'b1;phase<=READ_SCAN;end
    end
    ASSIGN:begin
     if(matches>1 || (VELOCITY_ASSOC && matches==1 && used[found[4:0]]))begin
      if(LOCAL_RECOVERY && tracking)begin
       // This observation cannot be uniquely attached. Preserve every other
       // independent match in this source packet; do not classify it again.
       note_fault(1,found,0);next_observation();
      end else if(RECOVERABLE)recover_sample(1,found);else lose(3);
     end
     else if(LOCAL_RECOVERY && tracking && matches==1 && motion_count!=0 &&
       ((motion_dx-first_dx)>8 || (motion_dx-first_dx)<-8) && !(old_id!=0 && old_kind==3))begin
      note_fault(2,found,missing);next_observation();
     end
     else if(matches==1)begin
      mapping[oi[OI_BITS-1:0]]<=found;used[found[4:0]]<=1;matched_count<=matched_count+1'b1;
      if(missing==0 && !(RECOVERABLE && old_id!=0 && old_kind==3))begin direct_anchor<=1;direct_count<=direct_count+1'b1;end
      if(MOTION_RECOVERY && missing!=0 && !direct_near)recovered_far<=1;
      // A recovered observation spans several frames. Do not compare that
      // displacement to a one-frame velocity or invent intermediate positions.
      if((!RECORD_ONLY || missing==0 || (MOTION_RECOVERY && !conservative_gap)) && !(RECOVERABLE && old_id!=0 && old_kind==3))begin
       motion_count<=motion_count+1'b1;
       if(motion_dx>2)positive<=positive+1'b1;
       if(motion_dx< -2)negative<=negative+1'b1;
       if(motion_count==0)first_dx<=motion_dx;
       else if((motion_dx-first_dx)>(RECORD_ONLY ? 8 : 3) || (motion_dx-first_dx)< -(RECORD_ONLY ? 8 : 3))motion_conflict<=1;
      end
      if(!RECORD_ONLY && old_kind!=ob[74:73])lose(7);
      else if(oi==OBS_COUNT-1)begin si<=0;phase<=RECOVERABLE ? MOTION : READ_CHECK;end else begin oi<=oi+1'b1;phase<=OBS;end
     end else if(free_slot==32)lose(8);
     else begin
      mapping[oi[OI_BITS-1:0]]<=free_slot;used[free_slot[4:0]]<=1;valid_tracks[free_slot[4:0]]<=1;
      tracks[track_address]<={ob[72:69],2'd0,ob[74:73],9'd0,ob[30:20],ob[41:31],cy,cx};
      armed[free_slot[4:0]]<=0;quarantined[free_slot[4:0]]<=0;
      if(oi==OBS_COUNT-1)begin si<=0;phase<=RECOVERABLE ? MOTION : READ_CHECK;end else begin oi<=oi+1'b1;phase<=OBS;end
     end
    end
    CHECK:begin
     // Ranking may discard distant observations. Losing a target touching the
     // line is unsafe: do not silently replace it or infer it from the pitch.
     // After the final recorded observation, an empty packet is not proof
     // of an unrecorded hole. Preserve counted identity without advancing it.
     // Any armed/unrecorded target still follows the strict gap deadline.
     if(ORDERED_HANDOFF && valid_tracks[si[4:0]] && !used[si[4:0]] && cross_pending[si[4:0]] && old_id==0)begin
      // A cached crossing is real evidence. Advance only its association/order
      // estimate while an earlier armed identity blocks publication.
      tracks[track_address]<={gap_motion[DX_BITS-1:0],(missing=={GAP_BITS{1'b1}} ? missing : missing+{{(GAP_BITS-1){1'b0}},1'b1}),track_word[59:0]};
      if(si==31)phase<=RECOVERABLE ? APPLY_SETUP : MOTION;else begin si<=si+1'b1;phase<=READ_CHECK;end
     end else if(TAIL_RECOVERY && valid_tracks[si[4:0]] && !used[si[4:0]] && old_id!=0 &&
        tracking && visible==0 && (armed & valid_tracks)==0)begin
      if(si==31)phase<=RECOVERABLE ? APPLY_SETUP : MOTION;else begin si<=si+1'b1;phase<=READ_CHECK;end
     end else if(RECOVERABLE && valid_tracks[si[4:0]] && !used[si[4:0]] && old_id!=0 && tracking)begin
      // Already counted: park its ID for de-duplication. Loss alone cannot
      // block other real crossings. Retire only with measured downstream proof.
      if(counted_retire_safe)begin valid_tracks[si[4:0]]<=0;armed[si[4:0]]<=0;end
      else if(missing<8)tracks[track_address]<={gap_motion[DX_BITS-1:0],missing+{{(GAP_BITS-1){1'b0}},1'b1},track_word[59:0]};
      if(si==31)phase<=APPLY_SETUP;else begin si<=si+1'b1;phase<=READ_CHECK;end
     end else if(RECOVERABLE && valid_tracks[si[4:0]] && !used[si[4:0]] && armed[si[4:0]] && old_id==0 && tracking)begin
      if(LOCAL_RECOVERY && (quarantined[si[4:0]] || missing>=8))begin
       // The ordered grace has expired. Keep the actual identity locally,
       // release later observed crossings, and make numbering uncertainty
       // persistent. Neither this branch nor retirement increments totals.
       quarantined[si[4:0]]<=1;mark_gap();note_fault(6,si,missing);
       if(missing==15)begin valid_tracks[si[4:0]]<=0;armed[si[4:0]]<=0;quarantined[si[4:0]]<=0;end
       else tracks[track_address]<={gap_motion[DX_BITS-1:0],missing+{{(GAP_BITS-1){1'b0}},1'b1},track_word[59:0]};
      end else begin
      gap_open<=1;
      if(missing<8)begin
       tracks[track_address]<={gap_motion[DX_BITS-1:0],missing+{{(GAP_BITS-1){1'b0}},1'b1},track_word[59:0]};
       if(missing>=(anchored_group ? 4 : 2))begin state<=HOLD;reason<=4;note_fault(6,si,missing);end
      end else begin state<=CHECK_REQUIRED;reason<=4;hold_valid<=0;note_fault(6,si,missing);end
      end
      if(si==31)phase<=APPLY_SETUP;else begin si<=si+1'b1;phase<=READ_CHECK;end
     end else if(RECORD_ONLY && valid_tracks[si[4:0]] && !used[si[4:0]] && critical && tracking &&
        ((armed[si[4:0]] && old_id==0) || (MOTION_RECOVERY && old_id!=0 && counted_guard && !counted_retire_safe)))begin
      if(missing<(anchored_group ? 4 : 2) && (TAIL_RECOVERY || previous_speed*(missing+2)<=match_step || (MOTION_RECOVERY && anchor_consistent)))begin
       if(MOTION_RECOVERY)tracks[track_address]<={gap_motion[DX_BITS-1:0],missing+{{(GAP_BITS-1){1'b0}},1'b1},track_word[59:0]};
       else tracks[track_address]<={missing+{{(GAP_BITS-1){1'b0}},1'b1},track_word[59:0]};
       if(si==31)phase<=RECOVERABLE ? APPLY_SETUP : MOTION;else begin si<=si+1'b1;phase<=READ_CHECK;end
      end else lose(4);
     end else if(!RECORD_ONLY && valid_tracks[si[4:0]] && !used[si[4:0]] && old_left<=LINE_X+HYST+MAX_STEP && old_right>=LINE_X-HYST-MAX_STEP && tracking)lose(4);
     else begin
      if(!used[si[4:0]])begin valid_tracks[si[4:0]]<=0;armed[si[4:0]]<=0;end
      if(si==31)phase<=RECOVERABLE ? APPLY_SETUP : MOTION;else begin si<=si+1'b1;phase<=READ_CHECK;end
     end
    end
    MOTION:begin
     if(RECORD_ONLY && !RECOVERABLE && motion_count!=0)begin
      previous_speed<=first_dx<0 ? -first_dx : first_dx;previous_dx<=first_dx;
     end
     if(motion_conflict || (positive!=0 && negative!=0) ||
        (MOTION_RECOVERY && recovered_far && !(TAIL_RECOVERY ? (anchor_consistent || measured_anchor || lone_return) : anchor_consistent)) ||
        (tracking && !LOCAL_RECOVERY && matched_count==0 && (!RECORD_ONLY || visible!=0)))begin
      if(RECOVERABLE)recover_sample(motion_conflict ? 2 : (positive!=0 && negative!=0) ? 3 : recovered_far ? 4 : 5,6'd32);
      else lose(3);
     end
     // One3px backward sample may be quantization/jitter; sustained slow
     // reverse must still stop. Forward motion pays off that evidence.
     else if(tracking && matched_count!=0 && directed_dx< -(MOTION_RECOVERY ? $signed({3'b0,reverse_limit}) : HYST))lose(5);
     else if(tracking && matched_count!=0 && reverse_next>=$signed({3'b0,reverse_limit}))lose(5);
     else begin
      if(tracking && matched_count!=0)reverse_motion<=reverse_next>0 ? reverse_next[4:0] : 5'd0;
      if(state==ACQUIRE)begin
       if(VELOCITY_ASSOC && motion_count!=0)begin
        if(first_dx>2)direction_right<=1;
        else if(first_dx< -2)direction_right<=0;
       end
       if(matched_count>=(RECORD_ONLY ? 1 : 2))begin
        if(stable_frames<3)stable_frames<=stable_frames+1'b1;
        accumulated<=accumulated+first_dx;
        if(stable_frames>=2 && (accumulated+first_dx>=4 || accumulated+first_dx<=-4))begin
         state<=RUN;reason<=0;direction_valid<=1;direction_right<=accumulated+first_dx>0;reverse_motion<=0;
        end
       end else begin stable_frames<=0;accumulated<=0;end
      end
      if(RECOVERABLE)begin si<=0;phase<=READ_CHECK;end
      else begin oi<=0;phase<=READ_APPLY;end
     end
    end
    SKIP:begin
     if(valid_tracks[si[4:0]])begin
      if(missing<8)tracks[track_address]<={skipped_motion[DX_BITS-1:0],missing+{{(GAP_BITS-1){1'b0}},1'b1},track_word[59:0]};
      else if(armed[si[4:0]] && old_id==0 && !cross_pending[si[4:0]])begin
       if(LOCAL_RECOVERY)begin
        quarantined[si[4:0]]<=1;mark_gap();
        if(missing==15)begin valid_tracks[si[4:0]]<=0;armed[si[4:0]]<=0;quarantined[si[4:0]]<=0;end
        else tracks[track_address]<={skipped_motion[DX_BITS-1:0],missing+{{(GAP_BITS-1){1'b0}},1'b1},track_word[59:0]};
       end else begin state<=CHECK_REQUIRED;hold_valid<=0;end
      end
     end
     if(si==31)begin si<=0;lead_track<=32;lead_x<=0;phase<=READ_ORDER;end
     else begin si<=si+1'b1;phase<=READ_SKIP;end
    end
    APPLY_SETUP:begin
     if(motion_count!=0)begin previous_speed<=first_dx<0 ? -first_dx : first_dx;previous_dx<=first_dx;end
     if(state==HOLD && !gap_open && matched_count!=0)begin state<=RUN;reason<=0;end
     oi<=0;phase<=READ_APPLY;
    end
    APPLY:begin
     if(mapping[oi[OI_BITS-1:0]]!=32)begin
      if(LOCAL_RECOVERY)quarantined[mi]<=0;
      // The shared classifier owns kind/reason. Record its current result;
      // the recorder does not run another classifier or reject class changes.
      tracks[track_address]<={(RECORD_ONLY ? ob[72:69] : (old_mask | ob[72:69])),(old_confirm<3 ? old_confirm+2'd1 : old_confirm),(RECORD_ONLY ? ob[74:73] : old_kind),old_id,ob[30:20],ob[41:31],cy,cx};
      if(display_slot)object_ids[display_index*9+:9]<=old_id;
      if(tracking && direction_valid)begin
       if(upstream && old_id==0)armed[mi]<=1;
       if(armed[mi] && downstream && old_id==0 && (!ORDERED_HANDOFF || !cross_pending[mi]))begin
        if(old_confirm<(RECORD_ONLY ? 1 : 2))unstable_cross<=1;
        crossings[oi[OI_BITS-1:0]]<=1;cross_index<=oi[OI_BITS-1:0];
        if(ORDERED_HANDOFF)begin cross_pending[mi]<=1;pending_event[mi]<={source_id,ob[74:73],ob[72:69]};end
       end
      end
     end
     if(oi==OBS_COUNT-1)phase<=CROSS_CHECK;else begin oi<=oi+1'b1;phase<=READ_APPLY;end
    end
    CROSS_CHECK:begin
     if(unstable_cross)lose(7);
     else if(ORDERED_HANDOFF && (tracking || (VELOCITY_ASSOC && state==ACQUIRE && motion_count!=0)))begin si<=0;lead_track<=32;lead_x<=0;phase<=READ_ORDER;end
     else if((crossings & (crossings-1'b1))!=0)lose(3);
     else if(crossings!=0)begin oi<={1'b0,cross_index};phase<=READ_EMIT;end
     else phase<=PUBLISH;
    end
    ORDER_SCAN:begin
     // The leading armed identity owns the next number. A temporarily absent
     // earlier target blocks later genuine crossings; no pitch creates events.
     if(valid_tracks[si[4:0]] && (armed[si[4:0]] || (VELOCITY_ASSOC && state==ACQUIRE && old_confirm>=1)) && old_id==0 &&
        (!LOCAL_RECOVERY || !quarantined[si[4:0]] || cross_pending[si[4:0]]) &&
        (lead_track==32 || (direction_right ? order_position>lead_x : order_position<lead_x)))begin
      lead_track<=si;lead_x<=order_position;
     end
     if(si==31)phase<=READ_LEAD;else begin si<=si+1'b1;phase<=READ_ORDER;end
    end
    ORDER_SELECT:begin
     // This sideband reserves an actually measured main identity for the next
     // source frame. It changes candidate retention only, never classification.
     hold_valid<=(!RECOVERABLE || tracking || (VELOCITY_ASSOC && state==ACQUIRE)) && lead_track!=32;
     if(lead_track!=32)begin hold_x<=next_hold_x<0 ? 0 : next_hold_x>1279 ? 1279 : next_hold_x[10:0];hold_y<=old_y;end
     if((!RECOVERABLE || (state==RUN && frame_trusted)) && lead_track!=32 && cross_pending[lead_track[4:0]])begin emit_track<=lead_track[4:0];phase<=READ_EMIT;end
     else phase<=PUBLISH;
    end
    EMIT:begin
     if(total>=MAX_TOTAL)begin state<=DONE;phase<=PUBLISH;end
     else begin
      total<=total+1'b1;
      // A deferred real crossing can be numbered while its target is absent.
      // Keep its gap displacement; clearing it makes the last measured centre
      // look current and can alias the next physical pocket on the next frame.
      if(RECOVERABLE)tracks[track_address]<={track_word[TRACK_BITS-1:52],(total+9'd1),track_word[42:0]};
      else tracks[track_address]<={track_word[59:52],(total+9'd1),track_word[42:0]};
      armed[event_slot]<=0;
      if(ORDERED_HANDOFF)begin
       cross_pending[emit_track]<=0;
       for(q=0;q<OBS_COUNT;q=q+1)if(mapping[q]=={1'b0,emit_track} && q%OBS_PER_REGION<2)
        object_ids[(((ORDERED_HANDOFF ? region : q/OBS_PER_REGION)*2)+q%OBS_PER_REGION)*9+:9]<=total+1'b1;
      end else object_ids[display_index*9+:9]<=total+1'b1;
      ledger[total]<={recorded_kind,recorded_mask};
      if(recorded_kind==3)begin empty_ids[empty_total]<=total+1'b1;empty_total<=empty_total+1'b1;end
      else begin present_total<=present_total+1'b1;if(recorded_mask!=0)review_total<=review_total+1'b1;end
      event_valid<=1;event_run<=run_id;event_id<=total+1'b1;event_frame<=recorded_frame;event_kind<=recorded_kind;event_reason<=recorded_mask;
      if(total==MAX_TOTAL-1)begin state<=DONE;reason<=0;hold_valid<=0;phase<=PUBLISH;end
      else if(ORDERED_HANDOFF)begin si<=0;lead_track<=32;lead_x<=0;phase<=READ_ORDER;end
      else phase<=PUBLISH;
     end
    end
    PUBLISH:begin snapshot_new<=1;busy<=0;phase<=WAIT;end
    default:phase<=WAIT;
   endcase
  end
 end
endmodule
