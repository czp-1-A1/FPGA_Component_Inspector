// Full-frame PPC4 RGB detector. Native frame guard proves input completeness.
// Legacy: two objects. REGIONS: two independently bound zones, two objects each.
// A shared flood-fill engine runs during vertical blanking, without video backpressure.
module frame_shape_search #(
 parameter PRESENT_TRACE=0,
 parameter WIDTH=1024,HEIGHT=600,REGIONS=0,DUAL_REGION_COUNT=0,
 parameter INDEXED_CANDIDATES=1,
 // Counting-only trial margin from upstream's measured six-cell extent.
 // A phase-eroded locating hole can also measure six cells. Expand only in
 // the taught pocket-row band, retaining the existing brightness/dark proof.
 // Legacy instantiations retain their exact recipe when this is zero.
 parameter COUNT_EMPTY_MARGIN=0,EMPTY_ROW_TOLERANCE=16,EMPTY_DIAGNOSTICS=0,
 parameter LOCAL_EDGE_ASSIST=0,EMPTY_TRACE=0,ROBUST_EMPTY_CONTEXT=0,ROBUST_SMALL_EMPTY=0,STANDING_REVIEW=0,SURFACE_REVIEW=0,REVIEW_PROBE=0,ROW_GUARDED_BRIGHT_EMPTY=0,COUNT_CANDIDATES=0,MULTITHRESHOLD_EMPTY=0,
 parameter [7:0] FOREGROUND=100,
 // T100 bodies keep their taught geometry. A second T80 pass measures holes.
 // Cache only the two default zones plus16 source pixels of vertical context;
 // accepted small contours are <=16 pixels, never cropped at a zone outline.
 parameter SMALL_HOLES=REGIONS,SMALL_FOREGROUND=80,
 // Same3528 photo trial: broaden presence only; quality remains review.
 // Bounds use half-resolution cells. Feed holes max9 never enter this envelope.
 parameter PLACEMENT_REVIEW=REGIONS,POSE_LONG_MIN=14,POSE_SHORT_MIN=5,
 parameter SMALL_Y0=HEIGHT/3-16,SMALL_Y1=HEIGHT*5/6+16,
 parameter PRESENT_LONG_MIN=26,PRESENT_LONG_MAX=39,PRESENT_SHORT_MIN=20,PRESENT_SHORT_MAX=36,
 parameter REVIEW_LONG_MAX=43,REVIEW_SHORT_MAX=38,
 parameter EMPTY_LONG_MIN=5,EMPTY_LONG_MAX=13,EMPTY_SHORT_MIN=4,EMPTY_SHORT_MAX=12,
 parameter HOLE_LONG_MIN=14,HOLE_LONG_MAX=23,HOLE_SHORT_MIN=10,HOLE_SHORT_MAX=21
)(
 input wire clk,rst_n,frame_start,pixel_sof,pixel_accept,invalidate,
 input wire [10:0] pixel_x,input wire [9:0] pixel_y,input wire [95:0] rgb,
 output reg ready,sample_new,located,output reg [1:0] state,
 output reg [12:0] foreground_count,output reg [6:0] box_width,box_height,
 output reg [10:0] box_x0,box_x1,output reg [9:0] box_y0,box_y1,
 output reg review_required,
 // Two 76-bit records, left object in [75:0]. Valid,class,reason,FG,W,H,x0,x1,y0,y1.
 // reason[3:0]: side reference, fill, aspect, size; these are model diagnostics.
 output wire [151:0] objects,
 output wire [303:0] region_objects,output wire [31:0] empty_probe,
 // Extra classified neighbours stay in this processing domain. Original UI
 // always receives its original best2, independently of this counting sideband.
 output wire [607:0] recorder_objects,
 input wire recorder_hold_valid,input wire [10:0] recorder_hold_x,input wire [9:0] recorder_hold_y,
 input wire recorder_hold_valid2,input wire [10:0] recorder_hold_x2,input wire [9:0] recorder_hold_y2,
 output wire [127:0] probe_record,output wire probe_ready
);
// Average each 2x2 source block; every source pixel contributes. Detection
// covers WIDTH x HEIGHT, with a half-size internal mask. 220 mm needs new calibration.
localparam W=WIDTH/2,H=HEIGHT/2,WORDS=W*H/4;
localparam INDEXED=INDEXED_CANDIDATES && REGIONS && COUNT_CANDIDATES && !EMPTY_DIAGNOSTICS;
reg [151:0] legacy_objects;reg [303:0] legacy_region_objects;reg [607:0] recorder_storage;
assign objects=INDEXED ? (ready ? recorder_storage[151:0] : 152'd0) : legacy_objects;
assign region_objects=INDEXED ? (ready ? {recorder_storage[455:304],recorder_storage[151:0]} : 304'd0) : legacy_region_objects;
assign recorder_objects=INDEXED ? (ready ? recorder_storage : 608'd0) : recorder_storage;
 localparam XB=$clog2(W),YB=$clog2(H),QB=XB+YB;
reg [7:0] mask [0:WORDS-1];reg [QB-1:0] queue [0:1023];
reg [17:0] pair_line [0:WIDTH/4-1];reg [17:0] pair_q,pair_d;
reg [10:0] x_d;reg [9:0] y_d;reg accept_d;
wire [9:0] gray_sum [0:3];
genvar lane;
generate for(lane=0;lane<4;lane=lane+1) begin : gray
 assign gray_sum[lane]={2'b0,rgb[95-lane*24-:8]}+{1'b0,rgb[87-lane*24-:8],1'b0}+{2'b0,rgb[79-lane*24-:8]};
end endgenerate
wire [8:0] pair0={1'b0,gray_sum[0][9:2]}+gray_sum[1][9:2];
wire [8:0] pair1={1'b0,gray_sum[2][9:2]}+gray_sum[3][9:2];
wire [9:0] block0={1'b0,pair_d[8:0]}+pair_q[8:0];
wire [9:0] block1={1'b0,pair_d[17:9]}+pair_q[17:9];
wire [1:0] half_fg={block1[9:2]>=FOREGROUND,block0[9:2]>=FOREGROUND};
wire [1:0] half_dark={block1[9:2]<=FOREGROUND,block0[9:2]<=FOREGROUND};
reg [1:0] first_fg,first_dark;
reg [15:0] cap_addr;reg [7:0] cap_data;reg cap_write,cap_last,seen;
reg [15:0] cap_count;reg [17:0] capture_foreground;
reg small_pass;
wire processed_body_we;wire [15:0] processed_body_addr;
// Certify complete words connected to a border or a >=44-cell horizontal run.
// The latter exceeds this 3528 recipe's maximum review dimension (43 cells).
// Its connected remnants cannot be valid objects; bound bright-background work
// even below a tilted tape, where a top/left border proof alone cannot reach.
// A separate one-bit word map marks contacts so remaining fragments are also
// rejected, while the original dark-reference plane remains unchanged.
reg ignored_border [0:WORDS-1];
reg border_line [0:W/4-1];
reg border_line_q,border_left,cap_ignored,ignored_q;
reg [3:0] foreground_run; // previous full words, saturates10 (44 cells with this word)
// Each capture write occupies one of two clocks. Back-certify the ten preceding
// full words through unused write slots, without modifying their dark bits.
reg cap_backfill;reg [3:0] back_count;reg [15:0] back_addr;
wire ignore_we=(cap_write || back_count!=0) && !invalidate && !frame_start;
wire [15:0] ignore_wa=cap_write ? cap_addr : back_addr;
wire ignore_wd=cap_write ? cap_ignored : 1'b1;
reg [$clog2(W/4)-1:0] cap_column;
wire [3:0] capture_fg_word={half_fg,first_fg};
wire ignore_capture_word=(&capture_fg_word) &&
 (y_d==1 || y_d==HEIGHT-1 || x_d<8 || x_d==WIDTH-4 ||
  (y_d>1 && border_line_q) || (x_d>=8 && border_left) || (REGIONS && foreground_run==10));
wire [2:0] cap_fg={2'b0,cap_data[0]}+{2'b0,cap_data[1]}+{2'b0,cap_data[2]}+{2'b0,cap_data[3]};
function [15:0] address;
 input [XB-1:0] ax; input [YB-1:0] ay;
 begin address=ay*(W/4)+(ax>>2);end
endfunction
always @(posedge clk)begin
 if(pixel_accept && !pixel_y[0])pair_line[pixel_x[10:2]]<={pair1,pair0};
 pair_q<=pair_line[pixel_x[10:2]];
 border_line_q<=border_line[pixel_x[10:3]];
 if(cap_write)begin
  border_line[cap_column]<=cap_ignored;
 end
 if(ignore_we)ignored_border[ignore_wa]<=ignore_wd;
end
always @(posedge clk or negedge rst_n)begin
 if(!rst_n)begin back_count<=0;back_addr<=0;end
 else if(frame_start || invalidate)back_count<=0;
 else if(cap_write && cap_backfill)begin back_count<=10;back_addr<=cap_addr-1'b1;end
 else if(!cap_write && back_count!=0)begin back_count<=back_count-1'b1;back_addr<=back_addr-1'b1;end
end
always @(posedge clk or negedge rst_n)begin
 if(!rst_n)begin accept_d<=0;x_d<=0;y_d<=0;pair_d<=0;first_fg<=0;first_dark<=0;cap_write<=0;cap_last<=0;cap_addr<=0;cap_data<=0;border_left<=0;cap_ignored<=0;cap_column<=0;foreground_run<=0;cap_backfill<=0;end
 else begin
  accept_d<=pixel_accept && !invalidate && !frame_start;x_d<=pixel_x;y_d<=pixel_y;pair_d<={pair1,pair0};
  cap_write<=accept_d && y_d[0] && x_d[2] && !invalidate && !frame_start;
  cap_last<=x_d==WIDTH-4 && y_d==HEIGHT-1;cap_addr<=address(x_d[10:1],y_d[9:1]);
  if(accept_d && y_d[0] && !x_d[2])begin first_fg<=half_fg;first_dark<=half_dark;end
  cap_data<={half_dark,first_dark,(ignore_capture_word ? 4'd0 : capture_fg_word)};
  cap_ignored<=ignore_capture_word;cap_column<=x_d[10:3];
  cap_backfill<=REGIONS && (&capture_fg_word) && foreground_run==10 && !border_left;
  if(accept_d && y_d[0] && x_d[2])begin
   border_left<=ignore_capture_word;
   if(!(&capture_fg_word))foreground_run<=0;
   else if(x_d<8)foreground_run<=1;
   else if(foreground_run!=10)foreground_run<=foreground_run+1'b1;
  end
  if(frame_start || invalidate)begin accept_d<=0;cap_write<=0;border_left<=0;foreground_run<=0;cap_backfill<=0;end
 end
end
reg [15:0] mem_addr,mem_write_addr;reg [7:0] mem_data;reg mem_write;
reg [7:0] mask_read,forward_data;reg forward_valid;
wire [7:0] high_q=forward_valid ? forward_data : mask_read;
wire [3:0] small_q;wire small_ignored;
wire [7:0] mem_q={high_q[7:4],small_pass ? small_q : high_q[3:0]};
wire active_ignored=small_pass ? small_ignored : ignored_q;
// One explicitly multiplexed write port and one read port. Conditional writes
// to two different addresses otherwise look like a three-port RAM to TD.
wire mask_we=(cap_write || (mem_write && !small_pass)) && !invalidate && !frame_start;
wire [15:0] mask_wa=cap_write ? cap_addr : mem_write_addr;
wire [7:0] mask_wd=cap_write ? cap_data : mem_data;
reg [9:0] q_read,q_write_addr;reg [QB-1:0] q_data,q_q;reg q_write;
// Independent synchronous capture/read-modify-write port; processing starts
// after capture completes. Infer RAM, never reset the arrays.
always @(posedge clk)begin
 if(mask_we)mask[mask_wa]<=mask_wd;
 // Explicit forwarding makes a read of the just-cleared packed word independent
 // of the device RAM's read-during-write mode. Read and mark use separate ports.
 mask_read<=mask[mem_addr];
 ignored_q<=ignored_border[mem_addr];
 if(q_write) queue[q_write_addr]<=q_data;
 q_q<=queue[q_read];
end
always @(posedge clk or negedge rst_n)begin
 if(!rst_n)begin forward_valid<=0;forward_data<=0;end
 else begin forward_valid<=mask_we && mask_wa==mem_addr;forward_data<=mask_wd;end
end
// Same capture clocks/2x2 means and shared flood engine. These small RAMs
// hold only T80 foreground and its border certificate; T100 dark refs stay intact.
generate if(SMALL_HOLES)begin : small_holes
 localparam BASE=(SMALL_Y0/2)*(W/4),DEPTH=((SMALL_Y1-SMALL_Y0)/2)*(W/4);
 reg [3:0] memory[0:DEPTH-1];reg ignored[0:DEPTH-1];
 reg line_border[0:W/4-1];reg line_q,left_border;reg [3:0] foreground_run;
 reg cap_backfill;reg [3:0] back_count;reg [15:0] back_addr;
 wire [1:0] half_small={block1[9:2]>=SMALL_FOREGROUND,block0[9:2]>=SMALL_FOREGROUND};
 reg [1:0] first_small;wire [3:0] word_small={half_small,first_small};
 wire ignore_word=(&word_small) && (y_d==SMALL_Y0+1 || y_d==SMALL_Y1-1 ||
  x_d<8 || x_d==WIDTH-4 || (y_d>SMALL_Y0+1 && line_q) || (x_d>=8 && left_border) || foreground_run==10);
 reg [3:0] cap_small;reg cap_ignore,cap_inside;
 wire capture=cap_write && cap_inside;
 // Once T100 has identified a body, its T80 rectangle is already accounted
 // for. Certify it through the existing one-bit map instead of flooding it
 // twice. This also prevents low-threshold fragments inside it becoming holes.
 wire body_inside=processed_body_we && processed_body_addr>=BASE && processed_body_addr<BASE+DEPTH;
 wire ignore_we=(capture || back_count!=0 || body_inside) && !invalidate && !frame_start;
 wire [15:0] ignore_wa=capture ? cap_addr-BASE : back_count!=0 ? back_addr : processed_body_addr-BASE;
 wire ignore_wd=capture ? cap_ignore : 1'b1;
 wire read_inside=mem_addr>=BASE && mem_addr<BASE+DEPTH;
 wire write_enable=(capture || (mem_write && small_pass)) && !invalidate && !frame_start;
 wire [15:0] wa=(capture ? cap_addr : mem_write_addr)-BASE;
 wire [3:0] wd=capture ? cap_small : mem_data[3:0];
 reg [3:0] read_value,forward_value;reg read_ignore,read_inside_d,forward;
 wire [$clog2(DEPTH)-1:0] ra=read_inside ? mem_addr-BASE : 0;
 always @(posedge clk)begin
  line_q<=line_border[pixel_x[10:3]];
  if(capture)line_border[cap_column]<=cap_ignore;
  if(ignore_we)ignored[ignore_wa[$clog2(DEPTH)-1:0]]<=ignore_wd;
  if(write_enable)memory[wa[$clog2(DEPTH)-1:0]]<=wd;
  // Unconditional synchronous RAM read; mask invalid context after the RAM.
  // An else assignment on its output makes TD implement the array in LUTs.
  read_value<=memory[ra];read_ignore<=ignored[ra];read_inside_d<=read_inside;
 end
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin first_small<=0;cap_small<=0;cap_ignore<=0;cap_inside<=0;left_border<=0;foreground_run<=0;cap_backfill<=0;back_count<=0;back_addr<=0;forward<=0;forward_value<=0;end
  else begin
   if(accept_d && y_d[0] && !x_d[2])first_small<=half_small;
   cap_small<=ignore_word ? 4'd0 : word_small;cap_ignore<=ignore_word;
   cap_inside<=y_d>=SMALL_Y0 && y_d<SMALL_Y1;
   cap_backfill<=(&word_small) && foreground_run==10 && !left_border;
   if(capture && cap_backfill)begin back_count<=10;back_addr<=cap_addr-BASE-1'b1;end
   else if(!capture && back_count!=0)begin back_count<=back_count-1'b1;back_addr<=back_addr-1'b1;end
   if(accept_d && y_d[0] && x_d[2])begin
    left_border<=ignore_word;
    if(!(&word_small))foreground_run<=0;
    else if(x_d<8)foreground_run<=1;
    else if(foreground_run!=10)foreground_run<=foreground_run+1'b1;
   end
   forward<=write_enable && wa==mem_addr-BASE;forward_value<=wd;
   if(frame_start || invalidate)begin cap_inside<=0;left_border<=0;foreground_run<=0;cap_backfill<=0;back_count<=0;forward<=0;end
  end
 end
 assign small_q=read_inside_d ? (forward ? forward_value : read_value) : 4'd0;
 assign small_ignored=!read_inside_d || read_ignore;
end else begin : no_small_holes
 assign small_q=0;assign small_ignored=0;
end endgenerate
localparam IDLE=0,SCAN_REQ=1,SCAN_WAIT=2,SCAN_CHECK=3,SEED_MARK=4,
 POP_REQ=5,POP_WAIT=6,POP_VALUE=7,NEIGH_REQ=8,NEIGH_WAIT=9,NEIGH_CHECK=10,
 NEIGH_NEXT=12,AREA_CALC=13,COMPARE=14,
 REF_REQ=15,REF_WAIT=16,REF_CHECK=17,FINISHED=18,SCALE=19,PUBLISH=20,REF_ORIGIN=21,SMALL_INSERT=22,BODY_ACCOUNTED=23,HIGH_REQ=24,HIGH_CHECK=25;
localparam COVER_REQ=26,COVER_SCAN=27,CAND_SELECT=28,CAND_COMMIT=29,
 REF_BOX=30,PACK_REQ=31,PACK_SCAN=32,PACK_FINISH=33,SURFACE_WAIT=34;
reg [5:0] phase;
reg [5:0] candidate_after_phase;
// Four same-frame T100 shape proofs perROI. These do not enter the original
// candidate bank. T80 must independently measure the EXACT bounding box.
// One synchronous-read contour cache, no pixel RAM and no array reset.
localparam HIGH_BOX_BITS=2*(XB+YB);
(* ram_style="distributed" *) reg [HIGH_BOX_BITS-1:0] high_boxes[0:7];
reg [11:0] high_distances[0:7];reg [7:0] high_valid;
reg [2:0] high_index;reg [HIGH_BOX_BITS-1:0] high_box_q;
reg high_confirmed;
always @(posedge clk)if(phase==HIGH_REQ)high_box_q<=high_boxes[high_index];
reg [XB-1:0] sx,cx,nx,xmin,xmax;reg [YB-1:0] sy,cy,ny,ymin,ymax;
reg [1:0] direction;
assign processed_body_we=phase==BODY_ACCOUNTED && !small_pass && PLACEMENT_REVIEW;
assign processed_body_addr=address(nx,ny);
wire neighbor_foreground=mem_q[nx[1:0]] && !active_ignored;
reg [9:0] q_head,q_tail;reg [10:0] q_count;
reg [17:0] component_count;reg border;
// Same-position field RAW samples reached five threshold cells (A20).
// Count >100 cells from the unchanged dark plane, saturating at6; a wholly
// bright small object still cannot become EMPTY. This is a trial bound.
reg [2:0] bright_count;
reg [17:0] component_area;
wire [83:0] region_bounds;wire [31:0] region_models;
wire [239:0] region_recipes;wire [1:0] region_supported;
generate if(REGIONS)begin : regions
 inspection_region_config #(.WIDTH(WIDTH),.HEIGHT(HEIGHT)) cfg(region_bounds,region_models,region_recipes,region_supported);
end else begin : full_frame
 assign region_bounds=0;assign region_models=0;assign region_recipes=0;assign region_supported=0;
end endgenerate
function inside_region;
 input [10:0] px;input [9:0] py;input [41:0] bounds;
 begin inside_region=px>=bounds[41:31] && px<bounds[30:20] && py>=bounds[19:10] && py<bounds[9:0];end
endfunction
wire [10:0] center_x=({1'b0,xmin}+xmax),center_y=({1'b0,ymin}+ymax);
wire in_region0=inside_region(center_x,center_y[9:0],region_bounds[41:0]);
wire in_region1=inside_region(center_x,center_y[9:0],region_bounds[83:42]);
wire region_now=REGIONS && !in_region0 && in_region1;
wire allowed_now=!REGIONS || ((in_region0 || in_region1) && region_supported[region_now]);
reg held_valid,held_valid2;reg [10:0] held_x,held_x2;reg [9:0] held_y,held_y2;reg [1:0] held_found;
reg candidate_region,candidate_allowed;reg [11:0] distance;
wire [41:0] candidate_bounds=candidate_region ? region_bounds[83:42] : region_bounds[41:0];
wire [10:0] target_x=REGIONS ? ({1'b0,candidate_bounds[41:31]}+candidate_bounds[30:20])/2 : WIDTH/2;
wire [10:0] target_y=REGIONS ? ({1'b0,candidate_bounds[19:10]}+candidate_bounds[9:0])/2 : HEIGHT/2;
wire [10:0] dx=center_x>target_x ? center_x-target_x : target_x-center_x;
wire [10:0] dy=center_y>target_y ? center_y-target_y : target_y-center_y;
// Distances use source coordinates, avoiding a half-pixel truncation at zone edges.
wire [9:0] legacy_dx=(center_x>>1)>W/2 ? (center_x>>1)-W/2 : W/2-(center_x>>1);
wire [9:0] legacy_dy=(center_y>>1)>H/2 ? (center_y>>1)-H/2 : H/2-(center_y>>1);
wire [11:0] distance_now=REGIONS ? {1'b0,dx}+dy : {2'b0,legacy_dx}+legacy_dy;
wire [9:0] width_now={1'b0,xmax}-xmin+1'b1,height_now={1'b0,ymax}-ymin+1'b1;
reg [9:0] long_side,short_side;
reg [22:0] fg20,area17,fg5,area3,fg10,area9,fg4;
reg [13:0] long20,short21,short31,long5,short7,short9;
wire [119:0] profile=candidate_region ? region_recipes[239:120] : region_recipes[119:0];
wire [7:0] p_lmin=REGIONS ? profile[7:0] : PRESENT_LONG_MIN,p_lmax=REGIONS ? profile[15:8] : PRESENT_LONG_MAX;
wire [7:0] p_smin=REGIONS ? profile[23:16] : PRESENT_SHORT_MIN,p_smax=REGIONS ? profile[31:24] : PRESENT_SHORT_MAX;
wire [7:0] r_lmax=REGIONS ? profile[39:32] : REVIEW_LONG_MAX,r_smax=REGIONS ? profile[47:40] : REVIEW_SHORT_MAX;
wire [7:0] e_lmin=REGIONS ? profile[55:48] : EMPTY_LONG_MIN,e_lmax=REGIONS ? profile[63:56] : EMPTY_LONG_MAX;
wire [7:0] e_smin=REGIONS ? profile[71:64] : EMPTY_SHORT_MIN,e_smax=REGIONS ? profile[79:72] : EMPTY_SHORT_MAX;
wire [7:0] h_lmin=REGIONS ? profile[87:80] : HOLE_LONG_MIN,h_lmax=REGIONS ? profile[95:88] : HOLE_LONG_MAX;
wire [7:0] h_smin=REGIONS ? profile[103:96] : HOLE_SHORT_MIN,h_smax=REGIONS ? profile[111:104] : HOLE_SHORT_MAX;
wire present_match=long_side>=p_lmin && long_side<=p_lmax && short_side>=p_smin && short_side<=p_smax &&
 long20>=short21 && long20<=short31 && (PLACEMENT_REVIEW ? fg5>={component_area,2'b00} : fg20>=area17);
// P10..P15: narrow standing projections and flipped/rotated lower-fill bodies
// must retain PRESENT, with review. No new mask RAM or separate detector.
wire pose_match=PLACEMENT_REVIEW && long_side>=POSE_LONG_MIN && long_side<=r_lmax &&
 short_side>=POSE_SHORT_MIN && short_side<=r_smax && long_side<={short_side,2'b00} && fg20>=area9;
wire present_review_match=(long_side>=p_lmin && long_side<=r_lmax && short_side>=p_smin && short_side<=r_smax &&
 long20>=short21 && long5<=short9 && fg4>=area3) || pose_match;
wire circular=long5<=short7 && fg5>=area3 && fg10<=area9;
// The field probe proved bright real empty holes were rejected by the old
// absolute bright-count cap. Admit them only on the observed pocket row,
// retaining circle/size/feed/body and subsequent local dark-reference proof.
// The anchor comes only from a recognized body in THIS source frame. No
// previous/bad-frame row is reused and no unobserved pocket is generated.
reg [1:0] row_anchor_valid;
reg [10:0] row_anchor_y [0:1];reg [11:0] row_anchor_distance [0:1];
wire row_anchor_available=ROW_GUARDED_BRIGHT_EMPTY && REGIONS && row_anchor_valid[candidate_region];
wire [10:0] empty_row_target=row_anchor_available ? row_anchor_y[candidate_region] : target_y;
wire [10:0] empty_row_delta=center_y>empty_row_target ? center_y-empty_row_target : empty_row_target-center_y;
wire guarded_bright_empty=ROW_GUARDED_BRIGHT_EMPTY && REGIONS && empty_row_delta<=EMPTY_ROW_TOLERANCE;
wire expanded_empty=COUNT_EMPTY_MARGIN && REGIONS && long_side<=6 && short_side<=6 &&
 empty_row_delta<=EMPTY_ROW_TOLERANCE;
wire base_empty_geometry=long_side>=e_lmin && short_side>=e_smin &&
 ((long_side<=e_lmax && short_side<=e_smax) || expanded_empty);
// R22: retain an ACTUALLY measured aperture in the field overlap (7x6/7x5),
// then require local signed Sobel + dark context before publishing it.
// With no current body anchor, use the taught row more narrowly. A wide
// provisional aperture additionally needs a measured off-row hole this frame.
reg [1:0] edge_feed_observed;
reg [9:0] edge_feed_y[0:1];
wire edge_row=REGIONS && (row_anchor_available ? empty_row_delta<=EMPTY_ROW_TOLERANCE : dy<=8);
wire edge_aperture_shape=LOCAL_EDGE_ASSIST && SMALL_HOLES && small_pass && edge_row &&
 long_side>=3 && long_side<=8 && short_side>=3 && short_side<=8 &&
 bright_count>=2 && long5<=short9 && {component_count,1'b0}>=component_area &&
 component_count<component_area && fg10<=area9+23'd10;
wire empty_geometry=base_empty_geometry || edge_aperture_shape;
// Opt-in small-aperture phase/shape tolerance. Keep an ACTUAL T80
// component, at least two T100 cells and a CURRENT measured body row.
// Existing size/feed/body exclusion and subsequent local dark proof remain.
// No pixel, target, identity or event is generated by this branch.
wire robust_small_shape=ROBUST_SMALL_EMPTY && SMALL_HOLES && small_pass && row_anchor_available &&
 guarded_bright_empty && bright_count>=2 && long5<=short9 && fg5>=area3;
wire empty_match=(circular || robust_small_shape || edge_aperture_shape) && empty_geometry &&
 (!SMALL_HOLES || bright_count<=5 || guarded_bright_empty);
wire geometric_sprocket_match=circular && long_side>=h_lmin && long_side<=h_lmax && short_side>=h_smin && short_side<=h_smax;
wire sprocket_match=geometric_sprocket_match && !edge_aperture_shape;
wire high_shape=MULTITHRESHOLD_EMPTY && REGIONS && SMALL_HOLES && !small_pass &&
 circular && empty_geometry && guarded_bright_empty && !sprocket_match &&
 !(present_match || present_review_match);
// Rescue only a compact, overfilled T80 shape. Undersized/elongated/weak
// components remain rejected. The brighter subset must have been measured
// as a circle with the same box earlier in THIS source frame.
wire covers_body;
wire high_lookup=MULTITHRESHOLD_EMPTY && small_pass && width_now==4 && height_now==4 && empty_geometry &&
 guarded_bright_empty && long5<=short7 && fg5>=area3 && fg10>area9 &&
 !sprocket_match && !covers_body;
reg [2:0] high_write_index;reg [11:0] high_worst;reg high_free;integer hi;
always @*begin
 high_write_index={candidate_region,2'b00};high_worst=0;high_free=0;
 for(hi=0;hi<4;hi=hi+1)begin
  if(!high_valid[{candidate_region,2'b00}+hi])begin
   if(!high_free)high_write_index={candidate_region,2'b00}+hi;
   high_free=1;
  end else if(!high_free && high_distances[{candidate_region,2'b00}+hi]>=high_worst)begin
   high_write_index={candidate_region,2'b00}+hi;
   high_worst=high_distances[{candidate_region,2'b00}+hi];
  end
 end
end
wire [1:0] candidate_state=SMALL_HOLES ?
 (small_pass ? (sprocket_match ? 0 : (empty_match || (MULTITHRESHOLD_EMPTY && high_confirmed)) ? 3 : pose_match ? 2 : 1) : (present_match || present_review_match) ? 2 : 1) :
 sprocket_match ? 0 : (present_match || present_review_match) ? 2 : empty_match ? 3 : 1;
wire [3:0] candidate_reason={1'b0,(PLACEMENT_REVIEW ? fg5<{component_area,2'b00} : fg20<area17),long20<short21 || long20>short31,
 long_side<p_lmin || long_side>p_lmax || short_side<p_smin || short_side>p_smax};
localparam REGION_SLOTS=REGIONS && COUNT_CANDIDATES ? 4 : 2;
localparam SLOTS=REGIONS ? 2*REGION_SLOTS : 2;
reg found_bank [0:SLOTS-1];reg [11:0] distance_bank [0:SLOTS-1];reg [17:0] count_bank [0:SLOTS-1];
reg [XB-1:0] xmin_bank [0:SLOTS-1],xmax_bank [0:SLOTS-1];
reg [YB-1:0] ymin_bank [0:SLOTS-1],ymax_bank [0:SLOTS-1];
reg [1:0] state_bank [0:SLOTS-1];reg [3:0] reason_bank [0:SLOTS-1];
reg weak_bank[0:SLOTS-1];reg [15:0] dark_bank[0:SLOTS-1];
localparam SURFACE_ACTIVE=SURFACE_REVIEW && REGIONS;
wire surface_ready,surface_normal,surface_empty_ok;wire [31:0] local_edge_strengths;
wire present_trace_select;wire [100:0] present_trace_metrics;
reg [$clog2(SLOTS)-1:0] ref_index;reg legacy_pair_selected;
wire surface_needed=(SURFACE_ACTIVE && state_bank[ref_index]==2 && !weak_bank[ref_index]) ||
 (LOCAL_EDGE_ASSIST && REGIONS && state_bank[ref_index]==3);
wire edge_reference_region=REGIONS && ref_index>=REGION_SLOTS;
localparam GEOMETRY_BITS=2*(XB+YB);
reg [1:0] pointer_bank[0:7];
wire [GEOMETRY_BITS-1:0] geometry_q;
reg [1:0] cover_index;reg covered_body;reg [3:0] contained_mask;
reg [3:0] retained_pending;reg pending_new;
reg [2:0] pack_index;reg [GEOMETRY_BITS-1:0] pack_anchor;reg [1:0] pack_duplicate;
wire [1:0] pack_order=pack_index[1:0]==0 ? 2'd3 : pack_index[1:0]==1 ? 2'd0 : pack_index[1:0]==2 ? 2'd1 : 2'd2;
wire [2:0] pack_slot={pack_index[2],pack_order};
wire swap0=found_bank[1] && xmin_bank[1]<xmin_bank[0];
wire swap1=found_bank[5] && xmin_bank[5]<xmin_bank[4];
wire [2:0] pack_destination=pack_slot[1:0]<2 && (pack_slot[2] ? swap1 : swap0) ? pack_slot^3'd1 : pack_slot;
wire geometry_read=INDEXED && ((phase==COVER_REQ) || (phase==COVER_SCAN && cover_index!=3) ||
 (phase==REF_ORIGIN && found_bank[ref_index]) || phase==PACK_REQ || (phase==PACK_SCAN && pack_index!=7));
wire [2:0] next_pack_index=pack_index+1'b1;
wire [1:0] next_pack_order=next_pack_index[1:0]==0 ? 2'd3 : next_pack_index[1:0]==1 ? 2'd0 : next_pack_index[1:0]==2 ? 2'd1 : 2'd2;
wire [2:0] geometry_read_slot=phase==COVER_REQ ? {candidate_region,2'd0} :
 phase==COVER_SCAN ? {candidate_region,cover_index+2'd1} : phase==REF_ORIGIN ? ref_index :
 phase==PACK_REQ ? 3'd3 : {next_pack_index[2],next_pack_order};
wire [XB-1:0] read_xmin=geometry_q[XB-1:0],read_xmax=geometry_q[2*XB-1:XB];
wire [YB-1:0] read_ymin=geometry_q[2*XB+YB-1:2*XB],read_ymax=geometry_q[GEOMETRY_BITS-1:2*XB+YB];
wire [10:0] edge_ref_y=INDEXED ? ({1'b0,read_ymin}+read_ymax) : ({1'b0,ymin_bank[ref_index]}+ymax_bank[ref_index]);
wire [10:0] edge_feed_delta=edge_ref_y>edge_feed_y[edge_reference_region] ? edge_ref_y-edge_feed_y[edge_reference_region] : edge_feed_y[edge_reference_region]-edge_ref_y;
// A larger aperture requires a SEPARATE measured hole row, even when a body
// row is available. A candidate can never certify its own locating-hole role.
wire edge_role_ok=!reason_bank[ref_index][0] || (edge_feed_observed[edge_reference_region] && edge_feed_delta>=24 && edge_feed_delta<=80);
reg [1:0] allocated_record;reg free_found;integer free_i;
always @*begin
 allocated_record=0;free_found=0;
 for(free_i=0;free_i<4;free_i=free_i+1)if(!retained_pending[free_i] && !free_found)begin allocated_record=free_i;free_found=1;end
end
generate if(INDEXED)begin : indexed_geometry
 reg [GEOMETRY_BITS-1:0] memory[0:7];reg [GEOMETRY_BITS-1:0] q;
 always @(posedge clk)begin
  if(rst_n && !frame_start && !invalidate && !pixel_sof)begin
   if(phase==CAND_COMMIT && pending_new)memory[{candidate_region,allocated_record}]<={ymax,ymin,xmax,xmin};
   if(geometry_read)q<=memory[{geometry_read_slot[2],pointer_bank[geometry_read_slot]}];
  end
 end
 assign geometry_q=q;
end else begin : no_indexed_geometry
 assign geometry_q=0;
end endgenerate
wire [$clog2(SLOTS)-1:0] bank0=candidate_region ? REGION_SLOTS : 0,bank1=bank0+1'b1;
wire [$clog2(SLOTS)-1:0] bank2=COUNT_CANDIDATES && REGIONS ? bank0+2 : bank0,bank3=COUNT_CANDIDATES && REGIONS ? bank0+3 : bank0;
wire candidate_preferred=candidate_state>=2;
wire [10:0] selected_held_x=DUAL_REGION_COUNT && candidate_region ? held_x2 : held_x;
wire [9:0] selected_held_y=DUAL_REGION_COUNT && candidate_region ? held_y2 : held_y;
wire selected_held_valid=DUAL_REGION_COUNT && candidate_region ? held_valid2 : held_valid;
wire [10:0] held_dx=center_x>selected_held_x ? center_x-selected_held_x : selected_held_x-center_x;
wire [10:0] held_dy=center_y>selected_held_y ? center_y-selected_held_y : selected_held_y-center_y;
wire preferred_main=COUNT_CANDIDATES && REGIONS && selected_held_valid && candidate_preferred && held_dx<=12 && held_dy<=16;
wire before_best=!found_bank[bank0] || (candidate_preferred && state_bank[bank0]<2) ||
 ((candidate_preferred==(state_bank[bank0]>=2)) && (distance<distance_bank[bank0] ||
 (distance==distance_bank[bank0] && component_count>count_bank[bank0])));
wire before_second=!found_bank[bank1] || (candidate_preferred && state_bank[bank1]<2) ||
 ((candidate_preferred==(state_bank[bank1]>=2)) && (distance<distance_bank[bank1] ||
 (distance==distance_bank[bank1] && component_count>count_bank[bank1])));
wire before_third=!found_bank[bank2] || (candidate_preferred && state_bank[bank2]<2) ||
 ((candidate_preferred==(state_bank[bank2]>=2)) && (distance<distance_bank[bank2] ||
 (distance==distance_bank[bank2] && component_count>count_bank[bank2])));
wire before_fourth=!found_bank[bank3] || (candidate_preferred && state_bank[bank3]<2) ||
 ((candidate_preferred==(state_bank[bank3]>=2)) && (distance<distance_bank[bank3] ||
 (distance==distance_bank[bank3] && component_count>count_bank[bank3])));
// Compile the original nonblocking destination priorities to old-source/new
// tags. Allocation is registered BEFORE the write edge to bound its path.
reg [11:0] sort_actions;reg [3:0] retained_now;reg has_new_now;integer action_i;reg [2:0] old_source;
always @*begin
 sort_actions={3'd3,3'd2,3'd1,3'd0};
 if((before_best && found_bank[bank0]) || (!before_best && before_second && found_bank[bank1]))begin
  if(!held_found[candidate_region])sort_actions[11:9]=2;sort_actions[8:6]=1;
 end else if(!before_best && !before_second && before_third)begin
  if(found_bank[bank2] && !held_found[candidate_region])sort_actions[11:9]=2;sort_actions[8:6]=4;
 end else if(!before_best && !before_second && !before_third && before_fourth && !held_found[candidate_region])sort_actions[11:9]=4;
 if(preferred_main)sort_actions[11:9]=4;
 if(before_best)begin if(found_bank[bank0])sort_actions[5:3]=0;sort_actions[2:0]=4;end
 else if(before_second)sort_actions[5:3]=4;
 retained_now=0;has_new_now=0;old_source=0;
 for(action_i=0;action_i<4;action_i=action_i+1)begin
  old_source=sort_actions[action_i*3+:3];
  if(old_source==4)has_new_now=1;
  else if(found_bank[{candidate_region,old_source[1:0]}])retained_now[pointer_bank[{candidate_region,old_source[1:0]}]]=1;
 end
end
wire found=found_bank[0] || found_bank[1] || (REGIONS && (found_bank[SLOTS-REGION_SLOTS] || found_bank[SLOTS-REGION_SLOTS+1]));

reg [8:0] left_dark,right_dark;
reg ref_side;reg [2:0] ref_word;reg [6:0] ref_row;
reg [9:0] origin_x,origin_y;reg [3:0] ref_mask;integer ref_lane_index;
reg [2:0] dark_word;integer dark_lane;
wire [9:0] ref_cx=INDEXED ? ({1'b0,read_xmin}+read_xmax)>>1 : ({1'b0,xmin_bank[ref_index]}+xmax_bank[ref_index])>>1;
wire [9:0] ref_cy=INDEXED ? ({1'b0,read_ymin}+read_ymax)>>1 : ({1'b0,ymin_bank[ref_index]}+ymax_bank[ref_index])>>1;
// Small holes use a local8x8 side strip; legacy8x40 strips can land on
// the next body or outside a tilted carrier. Same75% dark fraction, no stale data.
wire local_empty_ref=SMALL_HOLES && state_bank[ref_index]==3;
// Four bbox-relative sectors retain the original75% dark fraction. Top and
// bottom must BOTH be dark. A lateral sector may fail only when its outer
// samples remain bright ABOVE and BELOW the aperture, proving an extended
// tape-end boundary rather than a local bright neighbour. All samples reuse
// the captured mask and existing2x8-row reference loops: no new image RAM,
// unobserved target or added FSM cycle. Bodies and opt-out retain old proof.
wire context_ref=ROBUST_EMPTY_CONTEXT && local_empty_ref;
wire [9:0] context_x0=INDEXED ? read_xmin : xmin_bank[ref_index];
wire [9:0] context_x1=INDEXED ? read_xmax : xmax_bank[ref_index];
wire [9:0] context_y0=INDEXED ? read_ymin : ymin_bank[ref_index];
wire [9:0] context_y1=INDEXED ? read_ymax : ymax_bank[ref_index];
reg [5:0] context_dark;reg [1:0] context_good;
reg context_vertical_ok,context_left_ok,context_left_edge;
reg [2:0] context_edge_dark;reg [2:0] context_edge_word;reg context_upper_edge_ok;
wire [5:0] context_sum=context_dark+{3'd0,dark_word};
wire context_sector_ok=context_sum>=6'd24;
wire [2:0] context_edge_sum=context_edge_dark+context_edge_word;
wire context_edge_ok=context_upper_edge_ok && context_edge_sum<=2;
wire context_reference_ok=context_vertical_ok &&
 (context_left_ok || context_left_edge) && (context_sector_ok || context_edge_ok);
wire [7:0] ref_min=local_empty_ref ? 8'd48 : REGIONS ? (ref_index>=REGION_SLOTS ? region_recipes[239:232] : region_recipes[119:112]) : 8'd240;
wire signed [10:0] strip_start=context_ref ?
 (ref_side ? (ref_row[2] ? $signed({1'b0,context_x1})+11'sd1 : $signed({1'b0,context_x0})-11'sd8) : $signed({1'b0,origin_x})-11'sd4) :
 $signed({1'b0,origin_x})+(local_empty_ref ? (ref_side ? 11'sd4 : -11'sd12) : (ref_side ? 11'sd20 : -11'sd28));
wire signed [10:0] word_x=(strip_start & -11'sd4)+$signed({6'b0,ref_word,2'b0});
wire [9:0] context_lateral_y=ref_row[1:0]==0 ? origin_y-10'd8 : ref_row[1:0]==1 ? origin_y-10'd2 : ref_row[1:0]==2 ? origin_y+10'd1 : origin_y+10'd7;
wire [9:0] word_y=context_ref ?
 (ref_side ? context_lateral_y : (ref_row[2] ? context_y1+10'd1 : context_y0-10'd4)+{8'd0,ref_row[1:0]}) :
 origin_y-(local_empty_ref ? 10'd4 : 10'd20)+ref_row;
wire ref_last_row=ref_row==(local_empty_ref ? 7'd7 : 7'd39);
wire background_reference_ok=context_ref ? context_reference_ok : left_dark>=ref_min && right_dark+dark_word>=ref_min;
wire reference_ok=background_reference_ok && (!LOCAL_EDGE_ASSIST || state_bank[ref_index]!=3 || (surface_empty_ok && edge_role_ok));
always @*begin
 dark_word=0;
 for(dark_lane=0;dark_lane<4;dark_lane=dark_lane+1)
  if(ref_mask[dark_lane])dark_word=dark_word+mem_q[4+dark_lane];
 context_edge_word=0;
 for(dark_lane=0;dark_lane<4;dark_lane=dark_lane+1)
  if(context_ref && ref_side && (ref_row[1:0]==0 || ref_row[1:0]==3) && ref_mask[dark_lane] &&
    (ref_row[2] ? (ref_word==2 || (ref_word==1 && dark_lane>=strip_start[1:0])) :
      (ref_word==0 || (ref_word==1 && dark_lane<strip_start[1:0]))))
   context_edge_word=context_edge_word+mem_q[4+dark_lane];
end
wire [SLOTS*76-1:0] records;
genvar slot;
generate if(!INDEXED)begin : legacy_formatters
 for(slot=0;slot<SLOTS;slot=slot+1)begin : packed_records
 wire [10:0] bw=(xmax_bank[slot]-xmin_bank[slot]+1)*2,bh=(ymax_bank[slot]-ymin_bank[slot]+1)*2;
 wire [10:0] bx0=xmin_bank[slot]*2>1 ? xmin_bank[slot]*2-2 : 0;
 wire [10:0] bx1=xmax_bank[slot]*2+4<WIDTH ? xmax_bank[slot]*2+4 : WIDTH;
 wire [9:0] by0=ymin_bank[slot]*2>1 ? ymin_bank[slot]*2-2 : 0;
 wire [9:0] by1=ymax_bank[slot]*2+4<HEIGHT ? ymax_bank[slot]*2+4 : HEIGHT;
 assign records[slot*76+:76]=found_bank[slot] ?
  {1'b1,state_bank[slot],reason_bank[slot],(count_bank[slot]>2047 ? 13'd8191 : {count_bank[slot][10:0],2'b0}),
   (bw>127 ? 7'd127 : bw[6:0]),(bh>127 ? 7'd127 : bh[6:0]),bx0,bx1,by0,by1} : 76'd0;
end
end else begin : indexed_formatter
 assign records=0;
end endgenerate
// Exactly one bbox/size/clamp formatter feeds the existing recorder storage.
wire [10:0] packed_w=(read_xmax-read_xmin+1)*2,packed_h=(read_ymax-read_ymin+1)*2;
wire [10:0] packed_x0=read_xmin*2>1 ? read_xmin*2-2 : 0;
wire [10:0] packed_x1=read_xmax*2+4<WIDTH ? read_xmax*2+4 : WIDTH;
wire [9:0] packed_y0=read_ymin*2>1 ? read_ymin*2-2 : 0;
wire [9:0] packed_y1=read_ymax*2+4<HEIGHT ? read_ymax*2+4 : HEIGHT;
wire [75:0] packed_one=found_bank[pack_slot] ?
 {1'b1,state_bank[pack_slot],reason_bank[pack_slot],(count_bank[pack_slot]>2047 ? 13'd8191 : {count_bank[pack_slot][10:0],2'b0}),
 (packed_w>127 ? 7'd127 : packed_w[6:0]),(packed_h>127 ? 7'd127 : packed_h[6:0]),packed_x0,packed_x1,packed_y0,packed_y1} : 76'd0;
wire [151:0] sorted0=INDEXED ? recorder_storage[151:0] : found_bank[1] && xmin_bank[1]<xmin_bank[0] ?
 {records[75:0],records[151:76]} : records[151:0];
wire [151:0] sorted1;
generate if(REGIONS)begin
 assign sorted1=INDEXED ? recorder_storage[455:304] : found_bank[REGION_SLOTS+1] && xmin_bank[REGION_SLOTS+1]<xmin_bank[REGION_SLOTS] ?
 {records[REGION_SLOTS*76+:76],records[(REGION_SLOTS+1)*76+:76]} : records[REGION_SLOTS*76+:152];
end else assign sorted1=0;endgenerate
wire [607:0] recorder_packet;
generate if(INDEXED)begin : indexed_packet
 assign recorder_packet=recorder_storage;
end else if(COUNT_CANDIDATES && REGIONS)begin : extended_candidates
 // Within eachROI slots0/1 are EXACTLY the original UI pair, X sorted.
 // Slots2/3 are additional real measurements, not pitch-generated positions.
 wire duplicate0=(found_bank[0] && xmin_bank[3]==xmin_bank[0] && xmax_bank[3]==xmax_bank[0] && ymin_bank[3]==ymin_bank[0] && ymax_bank[3]==ymax_bank[0]) ||
  (found_bank[1] && xmin_bank[3]==xmin_bank[1] && xmax_bank[3]==xmax_bank[1] && ymin_bank[3]==ymin_bank[1] && ymax_bank[3]==ymax_bank[1]) ||
  (found_bank[2] && xmin_bank[3]==xmin_bank[2] && xmax_bank[3]==xmax_bank[2] && ymin_bank[3]==ymin_bank[2] && ymax_bank[3]==ymax_bank[2]);
 wire duplicate1=(found_bank[4] && xmin_bank[7]==xmin_bank[4] && xmax_bank[7]==xmax_bank[4] && ymin_bank[7]==ymin_bank[4] && ymax_bank[7]==ymax_bank[4]) ||
  (found_bank[5] && xmin_bank[7]==xmin_bank[5] && xmax_bank[7]==xmax_bank[5] && ymin_bank[7]==ymin_bank[5] && ymax_bank[7]==ymax_bank[5]) ||
  (found_bank[6] && xmin_bank[7]==xmin_bank[6] && xmax_bank[7]==xmax_bank[6] && ymin_bank[7]==ymin_bank[6] && ymax_bank[7]==ymax_bank[6]);
 assign recorder_packet={duplicate1 ? 76'd0 : records[7*76+:76],records[6*76+:76],sorted1,
  duplicate0 ? 76'd0 : records[3*76+:76],records[2*76+:76],sorted0};
end else begin : original_candidates
 assign recorder_packet={304'd0,sorted1,sorted0};
end endgenerate
wire [75:0] primary_record=!REGIONS ? records[75:0] : sorted0[75] ? sorted0[75:0] :
 sorted0[151] ? sorted0[151:76] : sorted1[75] ? sorted1[75:0] : sorted1[151:76];
// Seed only inside an enabled zone. Flood-fill still follows the complete
// component outside the dashed outline, so a slight overlap cannot crop it.
wire [3:0] seed_mask;
generate for(slot=0;slot<4;slot=slot+1)begin : region_seed
 wire [10:0] seed_x=((sx & ~3)+slot)*2;
 wire [9:0] seed_y=sy*2;
 assign seed_mask[slot]=!REGIONS ||
  (region_supported[0] && inside_region(seed_x,seed_y,region_bounds[41:0])) ||
  (region_supported[1] && inside_region(seed_x,seed_y,region_bounds[83:42]));
end endgenerate
wire [3:0] seed_word=mem_q[3:0] & seed_mask & {4{!active_ignored}};
// Do not duplicate a body with a small low-threshold fragment. Conversely,
// remove T100 fragments contained in a measured T80 empty/feed contour.
assign covers_body=INDEXED ? covered_body : (found_bank[bank0] && state_bank[bank0]==2 && xmin<=xmax_bank[bank0] && xmax>=xmin_bank[bank0] && ymin<=ymax_bank[bank0] && ymax>=ymin_bank[bank0]) ||
 (found_bank[bank1] && state_bank[bank1]==2 && xmin<=xmax_bank[bank1] && xmax>=xmin_bank[bank1] && ymin<=ymax_bank[bank1] && ymax>=ymin_bank[bank1]);
// Passive probe uses existing measurements, never feeds a class or candidate.
generate if(REGIONS && EMPTY_DIAGNOSTICS)begin : empty_diagnostics
 wire [10:0] probe_ref_x={1'b0,xmin_bank[ref_index]}+xmax_bank[ref_index];
 wire [10:0] probe_ref_y={1'b0,ymin_bank[ref_index]}+ymax_bank[ref_index];
 wire [9:0] probe_ref_width={1'b0,xmax_bank[ref_index]}-xmin_bank[ref_index]+10'd1;
 wire [9:0] probe_ref_height={1'b0,ymax_bank[ref_index]}-ymin_bank[ref_index]+10'd1;
 empty_candidate_probe #(.CENTER_X(WIDTH/2)) probe(
  .clk(clk),.rst_n(rst_n),.cancel(frame_start || invalidate || pixel_sof),
  .measure(phase==COMPARE && small_pass),
  .allowed(candidate_allowed && width_now>=3 && height_now>=3 && width_now<=12 && height_now<=12 && dx<=96 && empty_row_delta<=48),
  .region(candidate_region),.distance(distance),.center_x(center_x),.center_y(center_y),
  .width(width_now),.height(height_now),.bright_count(bright_count),
  .geometry_ok(empty_geometry),.shape_ok(circular),.row_ok(empty_row_delta<=EMPTY_ROW_TOLERANCE),
  .feed(sprocket_match),.covered(covers_body),.raw_empty(empty_match && !sprocket_match && !covers_body),.area_ok(component_count>=6),
  .ref_complete(phase==REF_CHECK && ref_side && ref_word==2 && ref_last_row),
  .ref_empty(state_bank[ref_index]==3),.ref_ok(reference_ok),
  .ref_x(probe_ref_x),
  .ref_y(probe_ref_y),
  .ref_width(probe_ref_width),
  .ref_height(probe_ref_height),
  .records(records),.word(empty_probe));
end else begin : no_empty_diagnostics
 assign empty_probe=0;
end endgenerate
integer bi;
reg [9:0] trial_x,trial_y;reg neighbor_ok;
always @*begin
 trial_x={1'b0,cx};trial_y={1'b0,cy};neighbor_ok=1;
 case(direction)
  0:begin trial_x={1'b0,cx}-1'b1;neighbor_ok=cx!=0;end
  1:begin trial_x={1'b0,cx}+1'b1;neighbor_ok=cx<W-1;end
  2:begin trial_y={1'b0,cy}-1'b1;neighbor_ok=cy!=0;end
  3:begin trial_y={1'b0,cy}+1'b1;neighbor_ok=cy<H-1;end
 endcase
end
// Scan only the enabled regions; the shared mask still stores complete image context.
reg scan_region;
wire [41:0] scan_bounds=scan_region ? region_bounds[83:42] : region_bounds[41:0];
wire [XB-1:0] scan_x0=REGIONS ? (scan_bounds[41:31]>>3)<<2 : 0;
wire [XB-1:0] scan_xlast=REGIONS ? ((scan_bounds[30:20]-1)>>3)<<2 : W-4;
wire [YB-1:0] scan_ylast=REGIONS ? (scan_bounds[9:0]-1)>>1 : H-1;
task advance_scan;
 begin
  if(sx>=scan_xlast)begin
   sx<=scan_x0;
   if(sy>=scan_ylast)begin
    if(REGIONS && !scan_region)begin
     scan_region<=1;sx<=(region_bounds[83:73]>>3)<<2;sy<=region_bounds[61:52]>>1;
     mem_addr<=address((region_bounds[83:73]>>3)<<2,region_bounds[61:52]>>1);phase<=PLACEMENT_REVIEW ? SCAN_WAIT : SCAN_REQ;
    end else begin
    if(SMALL_HOLES && !small_pass)begin
     small_pass<=1;scan_region<=0;sx<=(region_bounds[41:31]>>3)<<2;sy<=region_bounds[19:10]>>1;
     mem_addr<=address((region_bounds[41:31]>>3)<<2,region_bounds[19:10]>>1);phase<=PLACEMENT_REVIEW ? SCAN_WAIT : SCAN_REQ;
    end else if(found)begin legacy_pair_selected<=found_bank[1] && state_bank[0]!=0 && state_bank[1]!=0;
     ref_index<=0;ref_side<=0;ref_word<=0;ref_row<=0;left_dark<=0;right_dark<=0;phase<=REF_ORIGIN;end
    else begin ready<=1;sample_new<=1;located<=0;state<=0;phase<=FINISHED;end
    end
   // SCAN_CHECK already holds this word's address. Advance by word offsets
   // instead of inferring another row-address multiplier for the prefetch.
   end else begin sy<=sy+1'b1;mem_addr<=mem_addr+(W/4)-(sx>>2)+(scan_x0>>2);phase<=PLACEMENT_REVIEW ? SCAN_WAIT : SCAN_REQ;end
  end else begin sx<=(sx & ~3)+4;mem_addr<=mem_addr+1'b1;phase<=PLACEMENT_REVIEW ? SCAN_WAIT : SCAN_REQ;end
 end
endtask
task copy_candidate;
 input [$clog2(SLOTS)-1:0] dst,src;
 begin
  found_bank[dst]<=found_bank[src];distance_bank[dst]<=distance_bank[src];count_bank[dst]<=count_bank[src];
  if(!INDEXED)begin xmin_bank[dst]<=xmin_bank[src];xmax_bank[dst]<=xmax_bank[src];ymin_bank[dst]<=ymin_bank[src];ymax_bank[dst]<=ymax_bank[src];end
  else begin pointer_bank[dst]<=pointer_bank[src];if(dst%4<2)xmin_bank[dst]<=xmin_bank[src];end
  state_bank[dst]<=state_bank[src];reason_bank[dst]<=reason_bank[src];weak_bank[dst]<=weak_bank[src];
 end
endtask
task store_candidate;
 input [$clog2(SLOTS)-1:0] dst;
 begin
  found_bank[dst]<=1;distance_bank[dst]<=distance;count_bank[dst]<=component_count;
  if(!INDEXED)begin xmin_bank[dst]<=xmin;xmax_bank[dst]<=xmax;ymin_bank[dst]<=ymin;ymax_bank[dst]<=ymax;end
  else begin pointer_bank[dst]<=allocated_record;if(dst%4<2)xmin_bank[dst]<=xmin;end
  state_bank[dst]<=candidate_state;reason_bank[dst]<=small_pass ? (candidate_state==2 ? 4'hf : (LOCAL_EDGE_ASSIST && candidate_state==3 && !base_empty_geometry) ? 4'h1 : 4'd0) : candidate_reason;weak_bank[dst]<=small_pass;
 end
endtask
task retain_candidate;
 begin
     // The original first2 insertions below remain unchanged. Extend only
     // displaced valid entries; filling a vacant slot must not duplicate a
     // neighbour already retained in a later slot.
     if(COUNT_CANDIDATES && REGIONS)begin
      if((before_best && found_bank[bank0]) || (!before_best && before_second && found_bank[bank1]))begin
       if(!held_found[candidate_region])copy_candidate(bank3,bank2);copy_candidate(bank2,bank1);
      end else if(!before_best && !before_second && before_third)begin
       if(found_bank[bank2] && !held_found[candidate_region])copy_candidate(bank3,bank2);
       store_candidate(bank2);
      end else if(!before_best && !before_second && !before_third && before_fourth && !held_found[candidate_region])store_candidate(bank3);
      if(preferred_main)begin store_candidate(bank3);held_found[candidate_region]<=1;end
     end
     if(before_best)begin
      if(found_bank[bank0])begin
       found_bank[bank1]<=1;distance_bank[bank1]<=distance_bank[bank0];count_bank[bank1]<=count_bank[bank0];
       xmin_bank[bank1]<=xmin_bank[bank0];
       if(!INDEXED)begin xmax_bank[bank1]<=xmax_bank[bank0];ymin_bank[bank1]<=ymin_bank[bank0];ymax_bank[bank1]<=ymax_bank[bank0];end
       else pointer_bank[bank1]<=pointer_bank[bank0];
       state_bank[bank1]<=state_bank[bank0];reason_bank[bank1]<=reason_bank[bank0];weak_bank[bank1]<=weak_bank[bank0];
      end
      found_bank[bank0]<=1;distance_bank[bank0]<=distance;count_bank[bank0]<=component_count;
      xmin_bank[bank0]<=xmin;
      if(!INDEXED)begin xmax_bank[bank0]<=xmax;ymin_bank[bank0]<=ymin;ymax_bank[bank0]<=ymax;end
      else pointer_bank[bank0]<=allocated_record;
      state_bank[bank0]<=candidate_state;reason_bank[bank0]<=small_pass ? (candidate_state==2 ? 4'hf : (LOCAL_EDGE_ASSIST && candidate_state==3 && !base_empty_geometry) ? 4'h1 : 4'd0) : candidate_reason;weak_bank[bank0]<=small_pass;
     end else if(before_second)begin
      found_bank[bank1]<=1;distance_bank[bank1]<=distance;count_bank[bank1]<=component_count;
      xmin_bank[bank1]<=xmin;
      if(!INDEXED)begin xmax_bank[bank1]<=xmax;ymin_bank[bank1]<=ymin;ymax_bank[bank1]<=ymax;end
      else pointer_bank[bank1]<=allocated_record;
      state_bank[bank1]<=candidate_state;reason_bank[bank1]<=small_pass ? (candidate_state==2 ? 4'hf : (LOCAL_EDGE_ASSIST && candidate_state==3 && !base_empty_geometry) ? 4'h1 : 4'd0) : candidate_reason;weak_bank[bank1]<=small_pass;
     end
 end
endtask
always @(posedge clk or negedge rst_n)begin
 if(!rst_n)begin
  cover_index<=0;covered_body<=0;contained_mask<=0;retained_pending<=0;pending_new<=0;candidate_after_phase<=SCAN_REQ;
  pack_index<=0;pack_anchor<=0;pack_duplicate<=0;
  for(bi=0;bi<8;bi=bi+1)pointer_bank[bi]<=bi%4;
  high_valid<=0;high_index<=0;high_confirmed<=0;
  held_valid<=0;held_x<=0;held_y<=0;held_valid2<=0;held_x2<=0;held_y2<=0;held_found<=0;
  edge_feed_observed<=0;edge_feed_y[0]<=0;edge_feed_y[1]<=0;row_anchor_valid<=0;row_anchor_y[0]<=0;row_anchor_y[1]<=0;row_anchor_distance[0]<=4095;row_anchor_distance[1]<=4095;
  small_pass<=0;ready<=0;sample_new<=0;located<=0;state<=1;review_required<=0;legacy_objects<=0;legacy_region_objects<=0;recorder_storage<=0;foreground_count<=0;box_width<=0;box_height<=0;
  box_x0<=0;box_x1<=0;box_y0<=0;box_y1<=0;seen<=0;cap_count<=0;capture_foreground<=0;phase<=IDLE;
  mem_addr<=0;mem_write_addr<=0;mem_data<=0;mem_write<=0;q_read<=0;q_write_addr<=0;q_data<=0;q_write<=0;
  candidate_region<=0;candidate_allowed<=0;distance<=0;scan_region<=0;sx<=0;sy<=0;cx<=0;cy<=0;nx<=0;ny<=0;xmin<=0;xmax<=0;ymin<=0;ymax<=0;direction<=0;
  q_head<=0;q_tail<=0;q_count<=0;component_count<=0;bright_count<=0;border<=0;component_area<=0;long_side<=0;short_side<=0;fg20<=0;area17<=0;fg5<=0;area3<=0;fg10<=0;area9<=0;fg4<=0;long20<=0;short21<=0;short31<=0;long5<=0;short7<=0;short9<=0;
  for(bi=0;bi<SLOTS;bi=bi+1)begin
   found_bank[bi]<=0;distance_bank[bi]<=4095;count_bank[bi]<=0;xmin_bank[bi]<=0;xmax_bank[bi]<=0;
   ymin_bank[bi]<=0;ymax_bank[bi]<=0;state_bank[bi]<=1;reason_bank[bi]<=0;weak_bank[bi]<=0;dark_bank[bi]<=0;
  end
  ref_index<=0;legacy_pair_selected<=0;ref_side<=0;ref_word<=0;ref_row<=0;
  origin_x<=0;origin_y<=0;ref_mask<=0;
  left_dark<=0;right_dark<=0;context_dark<=0;context_good<=0;context_vertical_ok<=1;context_left_ok<=0;context_left_edge<=0;context_edge_dark<=0;context_upper_edge_ok<=0;
 end else begin
  sample_new<=0;mem_write<=0;q_write<=0;
  if(frame_start || invalidate)begin high_valid<=0;high_confirmed<=0;held_valid<=0;held_valid2<=0;held_found<=0;edge_feed_observed<=0;row_anchor_valid<=0;small_pass<=0;ready<=0;located<=0;state<=1;review_required<=0;legacy_objects<=0;legacy_region_objects<=0;recorder_storage<=0;phase<=IDLE;seen<=0;cap_count<=0;capture_foreground<=0;end
  else if(pixel_sof)begin
   high_valid<=0;high_confirmed<=0;
   held_valid<=COUNT_CANDIDATES && recorder_hold_valid;held_x<=recorder_hold_x;held_y<=recorder_hold_y;held_found<=0;
   held_valid2<=COUNT_CANDIDATES && DUAL_REGION_COUNT && recorder_hold_valid2;held_x2<=recorder_hold_x2;held_y2<=recorder_hold_y2;
   edge_feed_observed<=0;row_anchor_valid<=0;small_pass<=0;scan_region<=0;seen<=1;cap_count<=0;capture_foreground<=0;ready<=0;located<=0;state<=1;review_required<=0;legacy_objects<=0;legacy_region_objects<=0;recorder_storage<=0;phase<=IDLE;
   foreground_count<=0;box_width<=0;box_height<=0;
   for(bi=0;bi<SLOTS;bi=bi+1)begin
    found_bank[bi]<=0;distance_bank[bi]<=4095;count_bank[bi]<=0;reason_bank[bi]<=0;weak_bank[bi]<=0;dark_bank[bi]<=0;
   end
  end else if(cap_write && seen)begin
   cap_count<=cap_count+1'b1;capture_foreground<=capture_foreground+cap_fg;
   if(cap_last)begin
    if(cap_count==WORDS-1)begin
     if(!SMALL_HOLES && (capture_foreground+cap_fg==0 || capture_foreground+cap_fg==W*H))begin
      ready<=1;sample_new<=1;located<=0;state<=0;phase<=FINISHED;
     end else begin
      scan_region<=0;sx<=REGIONS ? (region_bounds[41:31]>>3)<<2 : 0;
      sy<=REGIONS ? region_bounds[19:10]>>1 : 0;phase<=SCAN_REQ;
     end
    end
    else begin ready<=1;sample_new<=1;state<=1;located<=0;phase<=FINISHED;end
   end
  end else case(phase)
   SCAN_REQ:begin mem_addr<=address(sx,sy);phase<=SCAN_WAIT;end
   SCAN_WAIT:phase<=SCAN_CHECK;
   SCAN_CHECK:begin
    if(|seed_word)begin
     // Lowest remaining lane; return to this same word after the component.
     nx<=(sx & ~3)+(seed_word[0] ? 0 : seed_word[1] ? 1 : seed_word[2] ? 2 : 3);phase<=SEED_MARK;
    end else advance_scan;
   end
   SEED_MARK:begin
    mem_write_addr<=mem_addr;mem_data<=mem_q & ~(8'b1<<nx[1:0]);mem_write<=1;
    xmin<=nx;xmax<=nx;ymin<=sy;ymax<=sy;component_count<=1;bright_count<=!high_q[4+nx[1:0]];border<=nx==0 || nx==W-1 || sy==0 || sy==H-1;
    q_write_addr<=0;q_data<={sy,nx};q_write<=1;q_head<=0;q_tail<=1;q_count<=1;phase<=POP_REQ;
   end
   POP_REQ:begin q_read<=q_head;phase<=POP_WAIT;end
   POP_WAIT:phase<=POP_VALUE;
   POP_VALUE:begin cx<=q_q[XB-1:0];cy<=q_q[QB-1:XB];q_head<=q_head+1'b1;q_count<=q_count-1'b1;direction<=0;phase<=NEIGH_REQ;end
   NEIGH_REQ:begin
    if(neighbor_ok)begin nx<=trial_x[XB-1:0];ny<=trial_y[YB-1:0];mem_addr<=address(trial_x[XB-1:0],trial_y[YB-1:0]);phase<=NEIGH_WAIT;end
    else phase<=NEIGH_NEXT;
   end
   NEIGH_WAIT:phase<=NEIGH_CHECK;
   NEIGH_CHECK:begin
    if(active_ignored)border<=1;
    if(neighbor_foreground)begin
     if(q_count==1024 || component_count==W*H)begin ready<=1;sample_new<=1;state<=1;located<=0;phase<=FINISHED;end
     else begin
      mem_write_addr<=mem_addr;mem_data<=mem_q & ~(8'b1<<nx[1:0]);mem_write<=1;
      q_write_addr<=q_tail;q_data<={ny,nx};q_write<=1;q_tail<=q_tail+1'b1;q_count<=q_count+1'b1;
      component_count<=component_count+1'b1;
      if(!high_q[4+nx[1:0]] && bright_count<6)bright_count<=bright_count+1'b1;
      if(nx<xmin)xmin<=nx;if(nx>xmax)xmax<=nx;if(ny<ymin)ymin<=ny;if(ny>ymax)ymax<=ny;
      if(nx==0 || nx==W-1 || ny==0 || ny==H-1)border<=1;
     end
    end
    if(!(neighbor_foreground && (q_count==1024 || component_count==W*H)))begin
     if(direction==3)begin
      if(q_count==0 && !neighbor_foreground)phase<=AREA_CALC;else phase<=POP_REQ;
     end else begin
      direction<=direction+1'b1;
      // Issue the next read now; the preceding mark has its own write address.
      case(direction)
       0:begin nx<=cx+1'b1;ny<=cy;mem_addr<=address(cx+1'b1,cy);phase<=cx<W-1 ? NEIGH_WAIT : NEIGH_NEXT;end
       1:begin nx<=cx;ny<=cy-1'b1;mem_addr<=address(cx,cy-1'b1);phase<=cy!=0 ? NEIGH_WAIT : NEIGH_NEXT;end
       2:begin nx<=cx;ny<=cy+1'b1;mem_addr<=address(cx,cy+1'b1);phase<=cy<H-1 ? NEIGH_WAIT : NEIGH_NEXT;end
      endcase
     end
    end
   end
   NEIGH_NEXT:begin
    if(direction==3)begin if(q_count==0)phase<=AREA_CALC;else phase<=POP_REQ;end
    else begin direction<=direction+1'b1;phase<=NEIGH_REQ;end
   end
   AREA_CALC:begin high_confirmed<=0;candidate_region<=region_now;candidate_allowed<=allowed_now;component_area<=width_now*height_now;
    long_side<=width_now>height_now ? width_now : height_now;short_side<=width_now<height_now ? width_now : height_now;phase<=SCALE;end
   SCALE:begin
    distance<=distance_now;
    fg20<={4'b0,component_count}*23'd20;area17<={4'b0,component_area}*23'd17;
    fg5<={4'b0,component_count}*23'd5;area3<={4'b0,component_area}*23'd3;
    fg10<={4'b0,component_count}*23'd10;area9<={4'b0,component_area}*23'd9;
    fg4<={2'b0,component_count,2'b0};
    long20<={4'b0,long_side}*14'd20;short21<={4'b0,short_side}*14'd21;short31<={4'b0,short_side}*14'd31;
    long5<={4'b0,long_side}*14'd5;short7<={4'b0,short_side}*14'd7;short9<={4'b0,short_side}*14'd9;
    covered_body<=0;contained_mask<=0;cover_index<=0;
    phase<=INDEXED && small_pass && allowed_now && !border && component_count>=6 && width_now>=3 && height_now>=3 ? COVER_REQ : COMPARE;
   end
   COMPARE:begin
    if(LOCAL_EDGE_ASSIST && candidate_allowed && !border && component_count>=8 && circular &&
       long_side>=5 && long_side<=10 && short_side>=4 && short_side<=10 && empty_row_delta>=24 && empty_row_delta<=80)begin
     edge_feed_observed[candidate_region]<=1;edge_feed_y[candidate_region]<=center_y[9:0];
    end
    phase<=SCAN_REQ;
    if(high_shape && candidate_allowed && !border && component_count>=6 &&
       width_now>=3 && height_now>=3 && (high_free || distance<high_worst))begin
     high_boxes[high_write_index]<={ymax,ymin,xmax,xmin};
     high_distances[high_write_index]<=distance;high_valid[high_write_index]<=1;
    end
    if(candidate_allowed && (!REGIONS || candidate_state!=0 || small_pass) && !border && (component_count>=8 || (small_pass && empty_match && component_count>=6)) && width_now>=3 && height_now>=3)begin
     if(!small_pass)begin
      if(ROW_GUARDED_BRIGHT_EMPTY && REGIONS && candidate_state==2 &&
         (!row_anchor_valid[candidate_region] || distance<row_anchor_distance[candidate_region]))begin
       row_anchor_valid[candidate_region]<=1;row_anchor_y[candidate_region]<=center_y;
       row_anchor_distance[candidate_region]<=distance;
      end
      if(INDEXED)begin
       candidate_after_phase<=PLACEMENT_REVIEW && candidate_state==2 ? BODY_ACCOUNTED : SCAN_REQ;
       phase<=CAND_SELECT;
       if(PLACEMENT_REVIEW && candidate_state==2)begin nx<=xmin & ~3;ny<=ymin;end
      end else begin retain_candidate;
       if(PLACEMENT_REVIEW && candidate_state==2)begin nx<=xmin & ~3;ny<=ymin;phase<=BODY_ACCOUNTED;end
      end
     end
     else if(high_lookup)begin high_index<={candidate_region,2'b00};phase<=HIGH_REQ;end
     else if((empty_match || sprocket_match || pose_match) && !covers_body)begin
      if(INDEXED)begin
      for(bi=0;bi<4;bi=bi+1)if(contained_mask[bi])found_bank[{candidate_region,bi[1:0]}]<=0;
     end else begin
      for(bi=0;bi<SLOTS;bi=bi+1)if(found_bank[bi] && state_bank[bi]!=2 && bi/REGION_SLOTS==candidate_region &&
       xmin_bank[bi]>=xmin && xmax_bank[bi]<=xmax && ymin_bank[bi]>=ymin && ymax_bank[bi]<=ymax)found_bank[bi]<=0;end
      if((empty_match || pose_match) && !sprocket_match)phase<=SMALL_INSERT;
     end
    end
   end
   HIGH_REQ:phase<=HIGH_CHECK;
   HIGH_CHECK:begin
    if(high_valid[high_index] && high_box_q=={ymax,ymin,xmax,xmin})begin
     high_confirmed<=1;
     // Remove T100 fragments contained in this independently measured T80
     // contour, exactly as the original EMPTY insertion does.
     if(INDEXED)begin
      for(bi=0;bi<4;bi=bi+1)if(contained_mask[bi])found_bank[{candidate_region,bi[1:0]}]<=0;
     end else begin
      for(bi=0;bi<SLOTS;bi=bi+1)if(found_bank[bi] && state_bank[bi]!=2 && bi/REGION_SLOTS==candidate_region &&
       xmin_bank[bi]>=xmin && xmax_bank[bi]<=xmax && ymin_bank[bi]>=ymin && ymax_bank[bi]<=ymax)found_bank[bi]<=0;end
     phase<=SMALL_INSERT;
    end else if(high_index[1:0]==3)phase<=SCAN_REQ;
    else begin high_index<=high_index+1'b1;phase<=HIGH_REQ;end
   end
   SMALL_INSERT:begin
    if(INDEXED)begin candidate_after_phase<=SCAN_REQ;phase<=CAND_SELECT;end
    else begin retain_candidate;phase<=SCAN_REQ;end
   end
   COVER_REQ:begin cover_index<=0;phase<=COVER_SCAN;end
   COVER_SCAN:begin
    if(found_bank[{candidate_region,cover_index}])begin
     if(cover_index<2 && state_bank[{candidate_region,cover_index}]==2 &&
        xmin<=read_xmax && xmax>=read_xmin && ymin<=read_ymax && ymax>=read_ymin)covered_body<=1;
     if(state_bank[{candidate_region,cover_index}]!=2 && read_xmin>=xmin && read_xmax<=xmax && read_ymin>=ymin && read_ymax<=ymax)contained_mask[cover_index]<=1;
    end
    if(cover_index==3)phase<=COMPARE;else cover_index<=cover_index+1'b1;
   end
   CAND_SELECT:begin retained_pending<=retained_now;pending_new<=has_new_now;phase<=CAND_COMMIT;end
   CAND_COMMIT:begin retain_candidate;phase<=candidate_after_phase;end
   BODY_ACCOUNTED:begin
    if(nx+4>xmax)begin
     nx<=xmin & ~3;
     if(ny==ymax)phase<=SCAN_REQ;else ny<=ny+1'b1;
    end else nx<=nx+4;
   end
   // Separate bbox-center arithmetic from dark-pixel counting and thresholds.
   REF_ORIGIN:begin
    context_dark<=0;context_good<=0;context_vertical_ok<=1;context_left_ok<=0;context_left_edge<=0;context_edge_dark<=0;context_upper_edge_ok<=0;
    if(!REGIONS && ref_index==1 && !legacy_pair_selected)phase<=INDEXED ? PACK_REQ : PUBLISH;
    else if(!found_bank[ref_index])begin
     if(ref_index==SLOTS-1)phase<=INDEXED ? PACK_REQ : PUBLISH;else ref_index<=ref_index+1'b1;
    end else if(INDEXED)phase<=REF_BOX;
    else begin origin_x<=ref_cx;origin_y<=ref_cy;phase<=surface_needed ? SURFACE_WAIT : REF_REQ;end
   end
   REF_BOX:begin origin_x<=ref_cx;origin_y<=ref_cy;phase<=surface_needed ? SURFACE_WAIT : REF_REQ;end
   SURFACE_WAIT:if(surface_ready)phase<=REF_REQ;
   REF_REQ:begin
    mem_addr<=address(word_x[XB-1:0],word_y[YB-1:0]);
    for(ref_lane_index=0;ref_lane_index<4;ref_lane_index=ref_lane_index+1)ref_mask[ref_lane_index]<=word_x>=0 && word_x<W && word_y<H &&
     (ref_word==1 || (ref_word==0 && ref_lane_index>=strip_start[1:0]) || (ref_word==2 && ref_lane_index<strip_start[1:0]));
    phase<=REF_WAIT;
   end
   REF_WAIT:phase<=REF_CHECK;
   REF_CHECK:begin
    if(ref_side)right_dark<=right_dark+dark_word;else left_dark<=left_dark+dark_word;
    if(context_ref)begin
     if(ref_word==2 && ref_row[1:0]==3)begin
      context_dark<=0;context_edge_dark<=0;
      if(!ref_side || !ref_row[2])context_good<=context_good+{1'b0,context_sector_ok};
      if(!ref_side)context_vertical_ok<=context_vertical_ok && context_sector_ok;
      else if(!ref_row[2])begin context_left_ok<=context_sector_ok;context_left_edge<=context_edge_ok;end
     end else begin
      context_dark<=context_sum;
      if(ref_side && ref_word==2 && ref_row[1:0]==0)begin context_upper_edge_ok<=context_edge_sum<=2;context_edge_dark<=0;end
      else context_edge_dark<=context_edge_sum;
     end
    end
    if(ref_side && ref_word==2 && ref_last_row)begin
     if(REVIEW_PROBE)dark_bank[ref_index]<={left_dark[8] ? 8'hff : left_dark[7:0],(right_dark+dark_word)>=256 ? 8'hff : (right_dark[7:0]+{5'd0,dark_word})};
     // Neighboring parts or a tape end may contaminate the side strips.
     // Preserve a recognized 3528 body, but do not assert quality is normal.
     if(state_bank[ref_index]==2)begin
      // F is the generic weak-gray review code, not four failed measurements.
      if(surface_needed)reason_bank[ref_index][3]<=!surface_normal;
      else if(reason_bank[ref_index]!=4'hf)reason_bank[ref_index][3]<=left_dark<ref_min || right_dark+dark_word<ref_min;
     end
     else begin
      reason_bank[ref_index]<=0;
      if(!reference_ok)state_bank[ref_index]<=REGIONS ? 1 : 0;
     end
     if(ref_index==SLOTS-1)phase<=INDEXED ? PACK_REQ : PUBLISH;
     else begin ref_index<=ref_index+1'b1;ref_side<=0;ref_word<=0;ref_row<=0;left_dark<=0;right_dark<=0;phase<=REF_ORIGIN;end
    end else begin
     if(ref_word==2)begin ref_word<=0;if(ref_last_row)begin ref_row<=0;ref_side<=1;end else ref_row<=ref_row+1'b1;end
     else ref_word<=ref_word+1'b1;
     phase<=REF_REQ;
    end
   end
   PACK_REQ:begin pack_index<=0;pack_duplicate<=0;phase<=PACK_SCAN;end
   PACK_SCAN:begin
    for(bi=0;bi<8;bi=bi+1)if(pack_destination==bi)recorder_storage[bi*76+:76]<=packed_one;
    if(pack_order==3)pack_anchor<=geometry_q;
    else if(found_bank[pack_slot] && pack_anchor==geometry_q)pack_duplicate[pack_index[2]]<=1;
    if(pack_index==7)phase<=PACK_FINISH;else pack_index<=pack_index+1'b1;
   end
   PACK_FINISH:begin
    if(pack_duplicate[0])recorder_storage[3*76+:76]<=0;
    if(pack_duplicate[1])recorder_storage[7*76+:76]<=0;
    phase<=PUBLISH;
   end
   PUBLISH:begin
     ready<=1;sample_new<=1;located<=primary_record[75];state<=primary_record[74:73];
     review_required<=primary_record[74:73]==2 && |primary_record[72:69];
     if(!INDEXED)begin
      legacy_objects<=(!REGIONS && !legacy_pair_selected) ? {76'd0,records[75:0]} : sorted0;
      legacy_region_objects<={sorted1,sorted0};recorder_storage<=recorder_packet;
     end
     foreground_count<=primary_record[68:56];box_width<=primary_record[55:49];box_height<=primary_record[48:42];
     box_x0<=primary_record[41:31];box_x1<=primary_record[30:20];box_y0<=primary_record[19:10];box_y1<=primary_record[9:0];phase<=FINISHED;
   end
   default:begin end
  endcase
 end
end
// Passive diagnostics never feed classification, retention, FSM or readiness.
wire [127:0] review_probe_record;wire review_probe_ready;
generate if(PRESENT_TRACE && REGIONS && LOCAL_EDGE_ASSIST)begin : present_motion_trace
 reg chosen,region_tag,weak_tag;
 reg [1:0] public_slot,grid_phase;
 reg [3:0] final_reason;
 reg [$clog2(SLOTS)-1:0] chosen_bank;
 wire region_now=ref_index>=REGION_SLOTS;
 wire visible_slot=ref_index==0 || ref_index==1 || ref_index==REGION_SLOTS || ref_index==REGION_SLOTS+1;
 wire swapped=region_now ? (found_bank[REGION_SLOTS+1] && xmin_bank[REGION_SLOTS+1]<xmin_bank[REGION_SLOTS]) : swap0;
 wire select_phase=INDEXED ? phase==REF_BOX : phase==REF_ORIGIN;
 wire allow_trace=!chosen || (region_now==region_tag && final_reason==0);
 assign present_trace_select=select_phase && allow_trace && found_bank[ref_index] && state_bank[ref_index]==2 && visible_slot && !weak_bank[ref_index];
 wire [100:0] observed=weak_tag ? 101'd0 : present_trace_metrics;
 assign probe_record=chosen ? {4'h1,1'b1,region_tag,public_slot,weak_tag,observed[8],
  (weak_tag ? 8'h80 : observed[7:0]),observed[100:90],observed[89:50],observed[49:14],
  observed[13:11],observed[10],observed[9],final_reason,grid_phase,12'd0} : 128'd0;
 assign probe_ready=1;
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin chosen<=0;region_tag<=0;weak_tag<=0;public_slot<=0;grid_phase<=0;final_reason<=0;chosen_bank<=0;end
  else if(frame_start || invalidate || pixel_sof)begin chosen<=0;region_tag<=0;weak_tag<=0;public_slot<=0;grid_phase<=0;final_reason<=0;chosen_bank<=0;end
  else begin
   if(select_phase && allow_trace && found_bank[ref_index] && state_bank[ref_index]==2 && visible_slot)begin
    chosen<=1;chosen_bank<=ref_index;region_tag<=region_now;weak_tag<=weak_bank[ref_index];
    public_slot<={1'b0,ref_index[0]^swapped};
    grid_phase<=INDEXED ? {read_ymin[0],read_xmin[0]} : {ymin_bank[ref_index][0],xmin_bank[ref_index][0]};
    final_reason<=reason_bank[ref_index];
   end
   if(chosen && ref_index==chosen_bank && phase==REF_CHECK && ref_side && ref_word==2 && ref_last_row)begin
    final_reason<=surface_needed ? {!surface_normal,reason_bank[ref_index][2:0]} : reason_bank[ref_index];
   end
  end
 end
end else if(EMPTY_TRACE && REGIONS)begin : empty_trace_measurement
 wire [10:0] trace_ref_x=INDEXED ? ({1'b0,read_xmin}+read_xmax) : ({1'b0,xmin_bank[ref_index]}+xmax_bank[ref_index]);
 wire [9:0] trace_ref_y=INDEXED ? ({1'b0,read_ymin}+read_ymax) : ({1'b0,ymin_bank[ref_index]}+ymax_bank[ref_index]);
 wire [9:0] trace_ref_w=INDEXED ? ({1'b0,read_xmax}-read_xmin+1'b1) : ({1'b0,xmax_bank[ref_index]}-xmin_bank[ref_index]+1'b1);
 wire [9:0] trace_ref_h=INDEXED ? ({1'b0,read_ymax}-read_ymin+1'b1) : ({1'b0,ymax_bank[ref_index]}-ymin_bank[ref_index]+1'b1);
 empty_gate_trace trace(
  .clk(clk),.rst_n(rst_n),.cancel(frame_start || invalidate || pixel_sof),
  .measure(phase==COMPARE && small_pass && candidate_allowed && width_now<=12 && height_now<=12),
  .region(candidate_region),.score({1'b0,dx}+empty_row_delta),.x(center_x),.y(center_y[9:0]),
  .width(width_now[4:0]),.height(height_now[4:0]),.area(component_count),.bright(bright_count),.row_delta(empty_row_delta),
  .flags({row_anchor_available,empty_geometry,circular,robust_small_shape,guarded_bright_empty,sprocket_match,covers_body,
          (empty_match && !sprocket_match && !covers_body),border}),
  .insert(phase==SMALL_INSERT),.reference_begin((INDEXED ? phase==REF_BOX : phase==REF_ORIGIN) && found_bank[ref_index] && state_bank[ref_index]==3),
  .reference_done(phase==REF_CHECK && ref_side && ref_word==2 && ref_last_row && state_bank[ref_index]==3),
  .reference_region(phase==PACK_SCAN ? pack_index[2] : ref_index>=REGION_SLOTS),.reference_x(trace_ref_x),.reference_y(trace_ref_y),.reference_width(trace_ref_w),.reference_height(trace_ref_h),.reference_ok(reference_ok),
  .publish(phase==PACK_SCAN && found_bank[pack_slot] && state_bank[pack_slot]==3),.sample(sample_new),
  .overflow(phase==NEIGH_CHECK && neighbor_foreground && (q_count==1024 || component_count==W*H)),.record(probe_record));
 assign probe_ready=1'b1;
end else begin : no_empty_trace
 assign probe_record=review_probe_record;assign probe_ready=review_probe_ready;
end endgenerate
// P02 same-frame surface proof over R16 indexed candidates.
generate if((REVIEW_PROBE || SURFACE_REVIEW || LOCAL_EDGE_ASSIST) && REGIONS)begin : review_measurement
 wire [$clog2(SLOTS)-1:0] index0=found_bank[1] && (!found_bank[0] || xmin_bank[1]<xmin_bank[0]) ? 1 : 0;
 wire [$clog2(SLOTS)-1:0] index1=found_bank[REGION_SLOTS+1] && (!found_bank[REGION_SLOTS] || xmin_bank[REGION_SLOTS+1]<xmin_bank[REGION_SLOTS]) ? REGION_SLOTS+1 : REGION_SLOTS;
 wire [35:0] references={weak_bank[index1],found_bank[index1] && state_bank[index1]==2,dark_bank[index1],
                       weak_bank[index0],found_bank[index0] && state_bank[index0]==2,dark_bank[index0]};
 reg [15:0] first_gray;reg [31:0] gray_word;reg [10:0] gray_x;reg [9:0] gray_y;
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin first_gray<=0;gray_word<=0;gray_x<=0;gray_y<=0;end
  else begin
   if(accept_d && y_d[0] && !x_d[2])first_gray<={block1[9:2],block0[9:2]};
   gray_word<={block1[9:2],block0[9:2],first_gray};gray_x<=x_d;gray_y<=y_d;
   if(frame_start || invalidate || pixel_sof)first_gray<=0;
  end
 end
 if(!(PRESENT_TRACE && REGIONS && LOCAL_EDGE_ASSIST))begin : no_present_trace_selection
 assign present_trace_select=0;
end
if(REVIEW_PROBE)begin : diagnostic_probe
 present_review_probe #(.WIDTH(WIDTH),.HEIGHT(HEIGHT)) probe(
  .clk(clk),.rst_n(rst_n),.cancel(frame_start || invalidate || pixel_sof),
  .write_enable(cap_write),.write_x(gray_x),.write_y(gray_y),.write_data(gray_word),
  .measure(sample_new),.objects(region_objects),.references(references),.ready(review_probe_ready),.record(review_probe_record));
end else begin : no_diagnostic_probe
 assign review_probe_record=0;assign review_probe_ready=1;
end
if(LOCAL_EDGE_ASSIST)begin : edge_surface_measurement
 local_edge_surface_check #(.TRACE(PRESENT_TRACE && REGIONS),.STANDING_REVIEW(STANDING_REVIEW),.WIDTH(WIDTH),.HEIGHT(HEIGHT),.FOREGROUND(FOREGROUND)) surface(
  .clk(clk),.rst_n(rst_n),.cancel(frame_start || invalidate || pixel_sof),
  .write_enable(cap_write),.write_x(gray_x),.write_y(gray_y),.write_data(gray_word),
  .measure((INDEXED ? phase==REF_BOX : phase==REF_ORIGIN) && found_bank[ref_index] && surface_needed),
  .measure_empty(state_bank[ref_index]==3),
  .xmin({{(10-XB){1'b0}},(INDEXED ? read_xmin : xmin_bank[ref_index])}),.xmax({{(10-XB){1'b0}},(INDEXED ? read_xmax : xmax_bank[ref_index])}),
  .ymin({{(10-YB){1'b0}},(INDEXED ? read_ymin : ymin_bank[ref_index])}),.ymax({{(10-YB){1'b0}},(INDEXED ? read_ymax : ymax_bank[ref_index])}),
  .ready(surface_ready),.normal(surface_normal),.empty_ok(surface_empty_ok),.edge_strengths(local_edge_strengths),
  .trace_enable(present_trace_select),.trace_metrics(present_trace_metrics));
end else if(SURFACE_REVIEW)begin : surface_measurement
 assign present_trace_metrics=0;
 assign surface_empty_ok=1;assign local_edge_strengths=0;
 present_surface_check #(.STANDING_REVIEW(STANDING_REVIEW),.WIDTH(WIDTH),.HEIGHT(HEIGHT),.FOREGROUND(FOREGROUND)) surface(
  .clk(clk),.rst_n(rst_n),.cancel(frame_start || invalidate || pixel_sof),
  .write_enable(cap_write),.write_x(gray_x),.write_y(gray_y),.write_data(gray_word),
  .measure((INDEXED ? phase==REF_BOX : phase==REF_ORIGIN) && found_bank[ref_index] && surface_needed),
  .xmin({{(10-XB){1'b0}},(INDEXED ? read_xmin : xmin_bank[ref_index])}),.xmax({{(10-XB){1'b0}},(INDEXED ? read_xmax : xmax_bank[ref_index])}),
  .ymin({{(10-YB){1'b0}},(INDEXED ? read_ymin : ymin_bank[ref_index])}),.ymax({{(10-YB){1'b0}},(INDEXED ? read_ymax : ymax_bank[ref_index])}),
  .ready(surface_ready),.normal(surface_normal));
end else begin : surface_disabled
 assign present_trace_metrics=0;assign surface_ready=1;assign surface_normal=0;assign surface_empty_ok=1;assign local_edge_strengths=0;
end
end else begin : no_review_measurement
 assign present_trace_metrics=0;assign surface_ready=1;assign surface_normal=0;assign surface_empty_ok=1;assign local_edge_strengths=0;
 assign review_probe_record=0;assign review_probe_ready=1;
end endgenerate
endmodule

// Two 64-bit per-source-frame traces, one nearest measured small component per
// ROI. Source X/Y exact bbox centres; W/H are half-resolution cells; A is cell
// population, B saturates at6. No candidate is generated by this module.
module empty_gate_trace(
 input wire clk,rst_n,cancel,measure,region,input wire [11:0] score,
 input wire [10:0] x,input wire [9:0] y,input wire [4:0] width,height,
 input wire [17:0] area,input wire [2:0] bright,input wire [10:0] row_delta,
 input wire [8:0] flags,input wire insert,reference_begin,reference_done,reference_region,
 input wire [10:0] reference_x,input wire [9:0] reference_y,reference_width,reference_height,
 input wire reference_ok,publish,sample,overflow,
 output wire [127:0] record);
reg [63:0] trace0,trace1;reg [11:0] best0,best1;
wire [63:0] selected=region ? trace1 : trace0;
wire [63:0] referred=reference_region ? trace1 : trace0;
wire matching_insert=selected[63] && selected[62:52]==x && selected[51:42]==y && selected[41:37]==width && selected[36:32]==height;
wire matching_reference=referred[63] && referred[62:52]==reference_x && referred[51:42]==reference_y && referred[41:37]==reference_width && referred[36:32]==reference_height;
wire [63:0] measured={1'b1,x,y,width,height,(area>255 ? 8'hff : area[7:0]),bright,(row_delta>63 ? 6'h3f : row_delta[5:0]),flags[8:1],4'd0,flags[0],2'd0};
always @(posedge clk or negedge rst_n)begin
 if(!rst_n)begin trace0<=0;trace1<=0;best0<=4095;best1<=4095;end
 else if(cancel)begin trace0<=0;trace1<=0;best0<=4095;best1<=4095;end
 else begin
  if(measure && (!selected[63] || score<(region ? best1 : best0)))begin
   if(region)begin trace1<=measured;best1<=score;end else begin trace0<=measured;best0<=score;end
  end
  if(insert && matching_insert)begin if(region)trace1[7]<=1;else trace0[7]<=1;end
  if(reference_begin && matching_reference)begin if(reference_region)trace1[6]<=1;else trace0[6]<=1;end
  if(reference_done && matching_reference)begin
   if(reference_region)begin trace1[5]<=1;trace1[4]<=reference_ok;end
   else begin trace0[5]<=1;trace0[4]<=reference_ok;end
  end
  if(publish && matching_reference)begin if(reference_region)trace1[3]<=1;else trace0[3]<=1;end
  if(sample)begin trace0[1]<=1;trace1[1]<=1;end
  if(overflow)begin trace0[0]<=1;trace1[0]<=1;end
 end
end
assign record={trace1,trace0};
endmodule
