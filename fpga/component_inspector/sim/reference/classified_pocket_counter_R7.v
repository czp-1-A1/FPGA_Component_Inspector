// Consumes the UNMODIFIED frame_shape_search four-record result, once per
// proved source frame. Display rank is never an identity. No pixel RAM/search.
module classified_pocket_counter_R7 #(
 parameter LINE_X=640,HYST=3,MAX_STEP=12,Y_STEP=8,MAX_TOTAL=300,RECORD_ONLY=0,MOTION_RECOVERY=0,TAIL_RECOVERY=0
)(
 input wire clk,rst_n,start_run,finish_run,frame_bad,
 input wire sample_new,input wire [31:0] frame_id,input wire [63:0] config_tag,
 input wire [303:0] objects,
 output reg busy,output reg snapshot_new,
 output reg [2:0] state,output reg [3:0] reason,
 output reg [15:0] run_id,output reg [8:0] total,present_total,empty_total,review_total,
 output reg direction_valid,direction_right,output reg region,
 output reg [35:0] object_ids,
 output reg event_valid,output reg [15:0] event_run,
 output reg [8:0] event_id,output reg [31:0] event_frame,
 output reg [1:0] event_kind,output reg [3:0] event_reason,
 input wire [8:0] ledger_address,output reg [5:0] ledger_data,
 input wire [8:0] empty_address,output reg [8:0] empty_id
);
 localparam IDLE=0,ACQUIRE=1,RUN=2,LOST=3,DONE=4;
 localparam WAIT=0,LOAD=1,OBS=2,SCAN=3,ASSIGN=4,CHECK=5,MOTION=6,
            APPLY=7,CROSS_CHECK=8,EMIT=9,PUBLISH=10;
 reg [3:0] phase;
 reg [303:0] packet;reg [31:0] source_id,last_frame;
 reg [63:0] active_config;reg have_frame,have_region;
 reg [31:0] valid_tracks,used;
 // One packed, single-read track RAM. All FSM phases share its address;
 // separate variable-index arrays would infer several large read mux trees.
 (* ram_style="distributed" *) reg [(MOTION_RECOVERY ? 71 : (RECORD_ONLY ? 62 : 60))-1:0] tracks[0:31];
 reg [31:0] armed;
 reg [5:0] mapping[0:3];reg [2:0] oi;reg [5:0] si,found,free_slot;
 reg [2:0] matches,matched_count,positive,negative,visible,motion_count;
 reg [2:0] stable_frames;reg signed [12:0] accumulated,first_dx;
 reg [4:0] reverse_motion;
 wire signed [13:0] directed_dx=direction_right ? $signed({first_dx[12],first_dx}) : -$signed({first_dx[12],first_dx});
 wire signed [13:0] reverse_next=$signed({9'd0,reverse_motion})-directed_dx;
 reg [10:0] pitch,previous_speed;reg pitch_valid;
 reg signed [12:0] previous_dx;reg recovered_far,direct_anchor;
 reg [3:0] crossings;reg [1:0] cross_index;reg unstable_cross,motion_conflict;
 reg [5:0] ledger[0:MAX_TOTAL-1];reg [8:0] empty_ids[0:MAX_TOTAL-1];
 wire [75:0] ob=packet[oi[1:0]*76+:76];
 wire [11:0] cx_sum={1'b0,ob[41:31]}+ob[30:20];
 wire [10:0] cx=cx_sum[11:1];
 wire [10:0] cy_sum={1'b0,ob[19:10]}+ob[9:0];
 wire [9:0] cy=cy_sum[10:1];
 wire target=ob[75] && ob[74:73]>=2;
 wire selected=oi[1]==region;
 wire [4:0] track_address=(phase==SCAN || phase==CHECK) ? si[4:0] :
  phase==ASSIGN ? (matches==1 ? found[4:0] : free_slot[4:0]) : mapping[oi[1:0]][4:0];
 wire [(MOTION_RECOVERY ? 71 : (RECORD_ONLY ? 62 : 60))-1:0] track_word=tracks[track_address];
 wire [1:0] missing=RECORD_ONLY ? track_word>>60 : 2'd0;
 // Sum only SAME-FRAME measured anchor motion during a gap. It is not a
 // displayed position and is never used to synthesize a crossing/event.
 wire signed [8:0] missed_dx=MOTION_RECOVERY ? track_word>>62 : 9'sd0;
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
 wire critical=old_x<=LINE_X+HYST+3*match_step && old_x>=LINE_X-HYST-3*match_step;
 wire [9:0] old_y=track_word[20:11];wire [8:0] old_id=track_word[51:43];
 wire [1:0] old_kind=track_word[53:52],old_confirm=track_word[55:54];wire [3:0] old_mask=track_word[59:56];
 wire signed [12:0] dx=$signed({2'b0,cx})-$signed({2'b0,old_x});
 wire signed [11:0] dy=$signed({2'b0,cy})-$signed({2'b0,old_y});
 // Prediction is used ONLY to associate an actually returning result. It
 // cannot publish a box, create a hole, or emit a count in an absent frame.
 // Fast recovery additionally requires a same-frame, consecutively observed
 // anchor with consistent measured motion (checked before APPLY/EMIT).
 wire signed [13:0] predicted_dx=$signed({{5{missed_dx[8]}},missed_dx})+$signed({previous_dx[12],previous_dx});
 wire signed [13:0] prediction_error=$signed({dx[12],dx})-predicted_dx;
 // On a return, subtract the measured intervening anchor displacement. The
 // residual is the CURRENT step, not the whole multi-frame displacement.
 wire signed [13:0] returned_step=$signed({dx[12],dx})-$signed({{5{missed_dx[8]}},missed_dx});
 wire signed [13:0] motion_dx=MOTION_RECOVERY && missing!=0 ? returned_step : $signed({dx[12],dx});
 wire [10:0] recovery_radius=match_step<8 ? match_step : 11'd8;
 wire direct_near=dx>=-$signed({2'b0,match_step}) && dx<=$signed({2'b0,match_step});
 wire predicted_near=prediction_error>=-$signed({3'b0,recovery_radius}) && prediction_error<=$signed({3'b0,recovery_radius});
 wire conservative_gap=previous_speed*(missing+1)<=match_step;
 wire signed [13:0] anchor_error=$signed({first_dx[12],first_dx})-$signed({previous_dx[12],previous_dx});
 wire anchor_consistent=motion_count!=0 && anchor_error>=-HYST && anchor_error<=HYST;
 wire [10:0] reverse_limit=MOTION_RECOVERY ? match_step : 2*HYST;
 wire counted_guard=old_x<=LINE_X+HYST+reverse_limit && old_x>=LINE_X-HYST-reverse_limit;
 // A current matched anchor may accelerate; it need not repeat last speed.
 wire measured_anchor=direct_anchor && !motion_conflict && (positive==0 || negative==0);
 // With no observed anchor, keep at most two source-frame opportunities.
 // The prior displacement below predicts ASSOCIATION ONLY. No absent box,
 // class, crossing or event is ever generated from this estimate.
 wire signed [12:0] gap_step=TAIL_RECOVERY && !measured_anchor ? previous_dx : first_dx;
 wire signed [13:0] gap_motion=$signed({{5{missed_dx[8]}},missed_dx})+$signed({gap_step[12],gap_step});
 wire lone_return=TAIL_RECOVERY && visible==1 && matched_count==1 && pitch_valid &&
  previous_speed<=match_step && first_dx>=-$signed({2'b0,match_step}) && first_dx<=$signed({2'b0,match_step});
 wire signed [13:0] travelled_x=$signed({3'b0,old_x})+gap_motion;
 wire signed [13:0] counted_distance=direction_right ? travelled_x-LINE_X : LINE_X-travelled_x;
 wire counted_retire_safe=MOTION_RECOVERY && old_id!=0 && motion_count!=0 && (TAIL_RECOVERY ? measured_anchor : anchor_consistent) &&
  counted_distance>$signed({3'b0,reverse_limit})+HYST;
 wire near_track=valid_tracks[si[4:0]] &&
  (MOTION_RECOVERY && missing!=0 ? ((conservative_gap && direct_near) || predicted_near) : direct_near) &&
  dy>=-$signed({1'b0,match_y}) && dy<=$signed({1'b0,match_y}) &&
  (RECORD_ONLY || !pitch_valid || (dx*4<$signed({2'b0,pitch}) && dx*4>-$signed({2'b0,pitch}))) &&
  (!RECORD_ONLY || MOTION_RECOVERY || missing==0 || conservative_gap);
 wire r0=(packet[75] && packet[74:73]>=2)||(packet[151] && packet[150:149]>=2);
 wire r1=(packet[227] && packet[226:225]>=2)||(packet[303] && packet[302:301]>=2);
 wire [151:0] pair=r1 ? packet[303:152] : packet[151:0];
 wire pair_valid=pair[75] && pair[74:73]>=2 && pair[151] && pair[150:149]>=2;
 wire [11:0] separation2=({1'b0,pair[117:107]}+pair[106:96])-({1'b0,pair[41:31]}+pair[30:20]);
 wire [10:0] separation=separation2[11:1];
 wire [4:0] mi=mapping[oi[1:0]][4:0];
 wire upstream=RECORD_ONLY ? (direction_right ? cx<LINE_X-HYST : cx>LINE_X+HYST) : (direction_right ? ob[30:20]<LINE_X-HYST : ob[41:31]>LINE_X+HYST);
 wire downstream=RECORD_ONLY ? (direction_right ? cx>LINE_X+HYST : cx<LINE_X-HYST) : (direction_right ? ob[41:31]>LINE_X+HYST : ob[30:20]<LINE_X-HYST);
 integer q;
 task lose;
  input [3:0] why;
  begin state<=LOST;reason<=why;busy<=0;phase<=WAIT;snapshot_new<=1;end
 endtask
 // RAM contents are run-length bounded; never reset or expose stale addresses.
 always @(posedge clk)begin
  ledger_data<=ledger_address<total ? ledger[ledger_address] : 6'd0;
  empty_id<=empty_address<empty_total ? empty_ids[empty_address] : 9'd0;
 end
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin
   state<=IDLE;reason<=0;phase<=WAIT;busy<=0;snapshot_new<=0;
   run_id<=0;total<=0;present_total<=0;empty_total<=0;review_total<=0;
   direction_valid<=0;direction_right<=0;region<=0;have_region<=0;
   object_ids<=0;valid_tracks<=0;used<=0;armed<=0;packet<=0;
   source_id<=0;last_frame<=0;active_config<=0;have_frame<=0;
   stable_frames<=0;accumulated<=0;first_dx<=0;oi<=0;si<=0;pitch<=0;pitch_valid<=0;reverse_motion<=0;previous_speed<=0;previous_dx<=0;recovered_far<=0;direct_anchor<=0;
   found<=32;free_slot<=32;matches<=0;matched_count<=0;positive<=0;negative<=0;visible<=0;motion_count<=0;
   crossings<=0;cross_index<=0;unstable_cross<=0;motion_conflict<=0;event_valid<=0;event_run<=0;event_id<=0;event_frame<=0;event_kind<=0;event_reason<=0;
  end else begin
   snapshot_new<=0;event_valid<=0;
   if(start_run)begin
    run_id<=run_id+1'b1;state<=ACQUIRE;reason<=1;phase<=WAIT;busy<=0;
    total<=0;present_total<=0;empty_total<=0;review_total<=0;
    valid_tracks<=0;armed<=0;used<=0;object_ids<=0;have_frame<=0;have_region<=0;
    direction_valid<=0;stable_frames<=0;accumulated<=0;pitch_valid<=0;reverse_motion<=0;previous_speed<=0;previous_dx<=0;recovered_far<=0;direct_anchor<=0;snapshot_new<=1;
   end else if(finish_run)begin
    state<=RECORD_ONLY ? IDLE : DONE;reason<=0;busy<=0;phase<=WAIT;snapshot_new<=1;
    if(RECORD_ONLY)begin
     total<=0;present_total<=0;empty_total<=0;review_total<=0;object_ids<=0;
     valid_tracks<=0;used<=0;armed<=0;have_frame<=0;have_region<=0;
     direction_valid<=0;direction_right<=0;region<=0;stable_frames<=0;accumulated<=0;
     pitch_valid<=0;reverse_motion<=0;crossings<=0;previous_speed<=0;previous_dx<=0;recovered_far<=0;direct_anchor<=0;
     // Keep run_id monotonic: clearing the visible RUN count must never
     // allow old DDR metadata or an old event to acquire a new run identity.
    end
   end
   else if(frame_bad && (state==ACQUIRE || state==RUN))lose(6);
   else if(sample_new && busy)begin if(state==ACQUIRE || state==RUN)lose(8);end
   else case(phase)
    WAIT:if(sample_new && (state==ACQUIRE || state==RUN) && (!have_frame || frame_id!=last_frame))begin
     if(have_frame && (frame_id!=last_frame+1'b1 || config_tag!=active_config))lose(6);
     else begin
      packet<=objects;source_id<=frame_id;last_frame<=frame_id;active_config<=config_tag;have_frame<=1;
      busy<=1;phase<=LOAD;used<=0;oi<=0;object_ids<=0;
      matched_count<=0;positive<=0;negative<=0;visible<=0;motion_count<=0;crossings<=0;unstable_cross<=0;motion_conflict<=0;first_dx<=0;recovered_far<=0;direct_anchor<=0;
     end
    end
    LOAD:begin
     if(r0 && r1)begin
      if(state==RUN)lose(2);
      else begin valid_tracks<=0;armed<=0;have_region<=0;pitch_valid<=0;stable_frames<=0;accumulated<=0;reason<=2;phase<=PUBLISH;end
     end else if(!r0 && !r1)begin
      if(state==RUN)begin if(RECORD_ONLY)phase<=OBS;else lose(4);end
      else begin valid_tracks<=0;armed<=0;pitch_valid<=0;stable_frames<=0;reason<=1;phase<=PUBLISH;end
     end else if(have_region && region!=r1 && state==RUN)lose(2);
     else if(pair_valid && separation<=(RECORD_ONLY ? 2*HYST+2 : 2*MAX_STEP+2))lose(3);
     // Measured spacing is an integrity check only. Missing targets never
     // create IDs; an unexpected doubled gap stops this run instead.
     else if(!RECORD_ONLY && pair_valid && pitch_valid && have_region && region==r1 && (separation>pitch+(pitch>>2) || separation<pitch-(pitch>>2)))lose(9);
     else begin
      if(!have_region || region!=r1)begin valid_tracks<=0;armed<=0;stable_frames<=0;accumulated<=0;end
      if(pair_valid && (!pitch_valid || !have_region || region!=r1 || (RECORD_ONLY && separation<pitch)))begin pitch<=separation;pitch_valid<=1;end
      if(state==ACQUIRE)reason<=1;
      have_region<=1;region<=r1;phase<=OBS;
     end
    end
    OBS:begin
     mapping[oi[1:0]]<=32;
     if(target && selected)begin si<=0;matches<=0;found<=32;free_slot<=32;phase<=SCAN;visible<=visible+1'b1;end
     else if(!RECORD_ONLY && ob[75] && ob[74:73]==1 && selected && ob[41:31]<=LINE_X+HYST && ob[30:20]>=LINE_X-HYST && state==RUN)lose(7);
     else if(oi==3)begin si<=0;phase<=CHECK;end
     else oi<=oi+1'b1;
    end
    SCAN:begin
     if(!valid_tracks[si[4:0]] && free_slot==32)free_slot<=si;
     if(near_track)begin
      matches<=matches+1'b1;found<=si;
      if(used[si[4:0]])begin matches<=3;end
     end
     if(si==31)phase<=ASSIGN;else si<=si+1'b1;
    end
    ASSIGN:begin
     if(matches>1)lose(3);
     else if(matches==1)begin
      mapping[oi[1:0]]<=found;used[found[4:0]]<=1;matched_count<=matched_count+1'b1;
      if(missing==0)direct_anchor<=1;
      if(MOTION_RECOVERY && missing!=0 && !direct_near)recovered_far<=1;
      // A recovered observation spans several frames. Do not compare that
      // displacement to a one-frame velocity or invent intermediate positions.
      if(!RECORD_ONLY || missing==0 || (MOTION_RECOVERY && !conservative_gap))begin
       motion_count<=motion_count+1'b1;
       if(motion_dx>2)positive<=positive+1'b1;
       if(motion_dx< -2)negative<=negative+1'b1;
       if(motion_count==0)first_dx<=motion_dx;
       else if((motion_dx-first_dx)>(RECORD_ONLY ? 8 : 3) || (motion_dx-first_dx)< -(RECORD_ONLY ? 8 : 3))motion_conflict<=1;
      end
      if(!RECORD_ONLY && old_kind!=ob[74:73])lose(7);
      else if(oi==3)begin si<=0;phase<=CHECK;end else begin oi<=oi+1'b1;phase<=OBS;end
     end else if(free_slot==32)lose(8);
     else begin
      mapping[oi[1:0]]<=free_slot;used[free_slot[4:0]]<=1;valid_tracks[free_slot[4:0]]<=1;
      tracks[track_address]<={ob[72:69],2'd0,ob[74:73],9'd0,ob[30:20],ob[41:31],cy,cx};
      armed[free_slot[4:0]]<=0;
      if(oi==3)begin si<=0;phase<=CHECK;end else begin oi<=oi+1'b1;phase<=OBS;end
     end
    end
    CHECK:begin
     // Ranking may discard distant observations. Losing a target touching the
     // line is unsafe: do not silently replace it or infer it from the pitch.
     // After the final recorded observation, an empty packet is not proof
     // of an unrecorded hole. Preserve counted identity without advancing it.
     // Any armed/unrecorded target still follows the strict gap deadline.
     if(TAIL_RECOVERY && valid_tracks[si[4:0]] && !used[si[4:0]] && old_id!=0 &&
        state==RUN && visible==0 && (armed & valid_tracks)==0)begin
      if(si==31)phase<=MOTION;else si<=si+1'b1;
     end else if(RECORD_ONLY && valid_tracks[si[4:0]] && !used[si[4:0]] && critical && state==RUN &&
        ((armed[si[4:0]] && old_id==0) || (MOTION_RECOVERY && old_id!=0 && counted_guard && !counted_retire_safe)))begin
      if(missing<2 && (TAIL_RECOVERY || previous_speed*(missing+2)<=match_step || (MOTION_RECOVERY && anchor_consistent)))begin
       if(MOTION_RECOVERY)tracks[track_address]<={gap_motion[8:0],missing+2'd1,track_word[59:0]};
       else tracks[track_address]<={missing+2'd1,track_word[59:0]};
       if(si==31)phase<=MOTION;else si<=si+1'b1;
      end else lose(4);
     end else if(!RECORD_ONLY && valid_tracks[si[4:0]] && !used[si[4:0]] && old_left<=LINE_X+HYST+MAX_STEP && old_right>=LINE_X-HYST-MAX_STEP && state==RUN)lose(4);
     else begin
      if(!used[si[4:0]])begin valid_tracks[si[4:0]]<=0;armed[si[4:0]]<=0;end
      if(si==31)phase<=MOTION;else si<=si+1'b1;
     end
    end
    MOTION:begin
     if(RECORD_ONLY && motion_count!=0)begin
      previous_speed<=first_dx<0 ? -first_dx : first_dx;previous_dx<=first_dx;
     end
     if(motion_conflict || (positive!=0 && negative!=0) ||
        (MOTION_RECOVERY && recovered_far && !(TAIL_RECOVERY ? (anchor_consistent || measured_anchor || lone_return) : anchor_consistent)) ||
        (state==RUN && matched_count==0 && (!RECORD_ONLY || visible!=0)))lose(3);
     // One3px backward sample may be quantization/jitter; sustained slow
     // reverse must still stop. Forward motion pays off that evidence.
     else if(state==RUN && matched_count!=0 && directed_dx< -(MOTION_RECOVERY ? $signed({3'b0,reverse_limit}) : HYST))lose(5);
     else if(state==RUN && matched_count!=0 && reverse_next>=$signed({3'b0,reverse_limit}))lose(5);
     else begin
      if(state==RUN && matched_count!=0)reverse_motion<=reverse_next>0 ? reverse_next[4:0] : 5'd0;
      if(state==ACQUIRE)begin
       if(matched_count>=(RECORD_ONLY ? 1 : 2))begin
        if(stable_frames<3)stable_frames<=stable_frames+1'b1;
        accumulated<=accumulated+first_dx;
        if(stable_frames>=2 && (accumulated+first_dx>=4 || accumulated+first_dx<=-4))begin
         state<=RUN;reason<=0;direction_valid<=1;direction_right<=accumulated+first_dx>0;reverse_motion<=0;
        end
       end else begin stable_frames<=0;accumulated<=0;end
      end
      oi<=0;phase<=APPLY;
     end
    end
    APPLY:begin
     if(mapping[oi[1:0]]!=32)begin
      // The shared classifier owns kind/reason. Record its current result;
      // the recorder does not run another classifier or reject class changes.
      tracks[track_address]<={(RECORD_ONLY ? ob[72:69] : (old_mask | ob[72:69])),(old_confirm<3 ? old_confirm+2'd1 : old_confirm),(RECORD_ONLY ? ob[74:73] : old_kind),old_id,ob[30:20],ob[41:31],cy,cx};
      object_ids[oi[1:0]*9+:9]<=old_id;
      if(state==RUN && direction_valid)begin
       if(upstream && old_id==0)armed[mi]<=1;
       if(armed[mi] && downstream && old_id==0)begin
        if(old_confirm<(RECORD_ONLY ? 1 : 2))unstable_cross<=1;
        crossings[oi[1:0]]<=1;cross_index<=oi[1:0];
       end
      end
     end
     if(oi==3)phase<=CROSS_CHECK;else oi<=oi+1'b1;
    end
    CROSS_CHECK:begin
     if(unstable_cross)lose(7);
     else if((crossings & (crossings-1'b1))!=0)lose(3);
     else if(crossings!=0)begin oi<={1'b0,cross_index};phase<=EMIT;end
     else phase<=PUBLISH;
    end
    EMIT:begin
     if(total>=MAX_TOTAL)begin state<=DONE;phase<=PUBLISH;end
     else begin
      total<=total+1'b1;tracks[track_address]<={track_word[59:52],(total+9'd1),track_word[42:0]};armed[mi]<=0;
      object_ids[oi[1:0]*9+:9]<=total+1'b1;
      ledger[total]<={old_kind,old_mask};
      if(old_kind==3)begin empty_ids[empty_total]<=total+1'b1;empty_total<=empty_total+1'b1;end
      else begin present_total<=present_total+1'b1;if(old_mask!=0)review_total<=review_total+1'b1;end
      event_valid<=1;event_run<=run_id;event_id<=total+1'b1;event_frame<=source_id;event_kind<=old_kind;event_reason<=old_mask;
      if(total==MAX_TOTAL-1)begin state<=DONE;reason<=0;end
      phase<=PUBLISH;
     end
    end
    PUBLISH:begin snapshot_new<=1;busy<=0;phase<=WAIT;end
    default:phase<=WAIT;
   endcase
  end
 end
endmodule
