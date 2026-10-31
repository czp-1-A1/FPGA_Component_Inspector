"""Exact, reversible CHECK preparation rewrite; original track reads stay put."""

OLD_GAP = ''' wire signed [12:0] gap_step=TAIL_RECOVERY && !measured_anchor ? previous_dx : first_dx;
 wire signed [13:0] gap_motion=$signed({{(14-DX_BITS){missed_dx[DX_BITS-1]}},missed_dx})+$signed({gap_step[12],gap_step});'''

NEW_GAP = ''' wire signed [12:0] gap_step=TAIL_RECOVERY && !measured_anchor ? previous_dx : first_dx;
 // CHECK always follows READ_CHECK. Capture frame-only quantities while the
 // existing synchronous RAM read fetches the CURRENT track. Never capture
 // track_word-dependent data here: track_word still names the PREVIOUS track.
 // Reset/start/finish/bad/busy priorities in the original FSM remain intact;
 // a cancelled read cannot consume these values without another READ_CHECK.
 reg signed [12:0] check_gap_step;
 reg signed [13:0] check_gap_origin;
 reg signed [31:0] check_guard_distance;
 reg check_direction_right,check_retire_anchor;
 always @(posedge clk)if(phase==READ_CHECK)begin
  check_gap_step<=gap_step;
  check_gap_origin<=direction_right ? $signed({gap_step[12],gap_step})-LINE_X : LINE_X-$signed({gap_step[12],gap_step});
  check_guard_distance<=$signed({3'b0,reverse_limit})+HYST;
  check_direction_right<=direction_right;
  check_retire_anchor<=motion_count!=0 && (TAIL_RECOVERY ? measured_anchor : anchor_consistent);
 end
 wire signed [13:0] gap_motion=$signed({{(14-DX_BITS){missed_dx[DX_BITS-1]}},missed_dx})+$signed({check_gap_step[12],check_gap_step});'''

OLD_RETIRE = ''' wire signed [13:0] travelled_x=$signed({3'b0,old_x})+gap_motion;
 wire signed [13:0] counted_distance=direction_right ? travelled_x-LINE_X : LINE_X-travelled_x;
 wire counted_retire_safe=MOTION_RECOVERY && old_id!=0 && motion_count!=0 && (TAIL_RECOVERY ? measured_anchor : anchor_consistent) &&
  counted_distance>$signed({3'b0,reverse_limit})+HYST;'''

NEW_RETIRE = ''' // All position operations retain the original signed 14-bit modulo.
 // Move the frame-only (gap_step, LINE_X) add/subtract into READ_CHECK;
 // the fresh track contributes only (old_x + missed_dx) in CHECK.
 wire signed [13:0] check_track_position=$signed({3'b0,old_x})+$signed({{(14-DX_BITS){missed_dx[DX_BITS-1]}},missed_dx});
 wire signed [13:0] counted_distance=check_direction_right ? check_track_position+check_gap_origin : check_gap_origin-check_track_position;
 wire counted_retire_safe=MOTION_RECOVERY && old_id!=0 && check_retire_anchor &&
  counted_distance>check_guard_distance;'''

NEW_GAP_MINIMAL = ''' wire signed [12:0] gap_step=TAIL_RECOVERY && !measured_anchor ? previous_dx : first_dx;
 // CHECK follows the existing READ_CHECK RAM fetch. Only frame parameters
 // are prepared here; fresh track_word data is consumed in CHECK as before.
 reg signed [12:0] check_gap_step;
 reg check_retire_anchor;
 always @(posedge clk)if(phase==READ_CHECK)begin
  check_gap_step<=gap_step;
  check_retire_anchor<=motion_count!=0 && (TAIL_RECOVERY ? measured_anchor : anchor_consistent);
 end
 wire signed [13:0] gap_motion=$signed({{(14-DX_BITS){missed_dx[DX_BITS-1]}},missed_dx})+$signed({check_gap_step[12],check_gap_step});'''

NEW_RETIRE_MINIMAL = ''' wire signed [13:0] travelled_x=$signed({3'b0,old_x})+gap_motion;
 wire signed [13:0] counted_distance=direction_right ? travelled_x-LINE_X : LINE_X-travelled_x;
 wire counted_retire_safe=MOTION_RECOVERY && old_id!=0 && check_retire_anchor &&
  counted_distance>$signed({3'b0,reverse_limit})+HYST;'''

def apply(text,variant='offset'):
    blocks=(NEW_GAP_MINIMAL,NEW_RETIRE_MINIMAL) if variant=='minimal' else (NEW_GAP,NEW_RETIRE)
    for old,new in zip((OLD_GAP,OLD_RETIRE),blocks):
        assert text.count(old)==1 and new not in text
        text=text.replace(old,new,1)
    return text

def restore(text):
    blocks=(NEW_GAP,NEW_RETIRE) if 'check_gap_origin' in text else (NEW_GAP_MINIMAL,NEW_RETIRE_MINIMAL)
    for old,new in zip((OLD_GAP,OLD_RETIRE),blocks):
        assert text.count(new)==1 and old not in text
        text=text.replace(new,old,1)
    return text
