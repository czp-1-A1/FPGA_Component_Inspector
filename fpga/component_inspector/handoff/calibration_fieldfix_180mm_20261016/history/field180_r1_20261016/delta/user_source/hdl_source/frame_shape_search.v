// Full-frame PPC4 RGB detector. Native frame guard proves input completeness.
// Legacy: two objects. REGIONS: two independently bound zones, two objects each.
// A shared flood-fill engine runs during vertical blanking, without video backpressure.
module frame_shape_search #(
 parameter WIDTH=1024,HEIGHT=600,REGIONS=0,
 parameter [7:0] FOREGROUND=100,
 // T100 bodies keep their taught geometry. A second T80 pass measures holes.
 // Cache only the two default zones plus16 source pixels of vertical context;
 // accepted small contours are <=16 pixels, never cropped at a zone outline.
 parameter SMALL_HOLES=REGIONS,SMALL_FOREGROUND=80,
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
 output reg [151:0] objects,
 output reg [303:0] region_objects
);
// Average each 2x2 source block; every source pixel contributes. Detection
// covers WIDTH x HEIGHT, with a half-size internal mask. 220 mm needs new calibration.
localparam W=WIDTH/2,H=HEIGHT/2,WORDS=W*H/4;
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
// Certify complete words connected to a border or a >=64-cell horizontal run.
// The latter exceeds this 3528 recipe's maximum review dimension (43 cells).
// Its connected remnants cannot be valid objects; bound bright-background work
// even below a tilted tape, where a top/left border proof alone cannot reach.
// A separate one-bit word map marks contacts so remaining fragments are also
// rejected, while the original dark-reference plane remains unchanged.
reg ignored_border [0:WORDS-1];
reg border_line [0:W/4-1];
reg border_line_q,border_left,cap_ignored,ignored_q;
reg [3:0] foreground_run; // previous full words, saturates15 (64 cells with this word)
reg [$clog2(W/4)-1:0] cap_column;
wire [3:0] capture_fg_word={half_fg,first_fg};
wire ignore_capture_word=(&capture_fg_word) &&
 (y_d==1 || y_d==HEIGHT-1 || x_d<8 || x_d==WIDTH-4 ||
  (y_d>1 && border_line_q) || (x_d>=8 && border_left) || (REGIONS && foreground_run==15));
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
  ignored_border[cap_addr]<=cap_ignored;
 end
end
always @(posedge clk or negedge rst_n)begin
 if(!rst_n)begin accept_d<=0;x_d<=0;y_d<=0;pair_d<=0;first_fg<=0;first_dark<=0;cap_write<=0;cap_last<=0;cap_addr<=0;cap_data<=0;border_left<=0;cap_ignored<=0;cap_column<=0;foreground_run<=0;end
 else begin
  accept_d<=pixel_accept && !invalidate && !frame_start;x_d<=pixel_x;y_d<=pixel_y;pair_d<={pair1,pair0};
  cap_write<=accept_d && y_d[0] && x_d[2] && !invalidate && !frame_start;
  cap_last<=x_d==WIDTH-4 && y_d==HEIGHT-1;cap_addr<=address(x_d[10:1],y_d[9:1]);
  if(accept_d && y_d[0] && !x_d[2])begin first_fg<=half_fg;first_dark<=half_dark;end
  cap_data<={half_dark,first_dark,(ignore_capture_word ? 4'd0 : capture_fg_word)};
  cap_ignored<=ignore_capture_word;cap_column<=x_d[10:3];
  if(accept_d && y_d[0] && x_d[2])begin
   border_left<=ignore_capture_word;
   if(!(&capture_fg_word))foreground_run<=0;
   else if(x_d<8)foreground_run<=1;
   else if(foreground_run!=15)foreground_run<=foreground_run+1'b1;
  end
  if(frame_start || invalidate)begin accept_d<=0;cap_write<=0;border_left<=0;foreground_run<=0;end
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
 wire [1:0] half_small={block1[9:2]>=SMALL_FOREGROUND,block0[9:2]>=SMALL_FOREGROUND};
 reg [1:0] first_small;wire [3:0] word_small={half_small,first_small};
 wire ignore_word=(&word_small) && (y_d==SMALL_Y0+1 || y_d==SMALL_Y1-1 ||
  x_d<8 || x_d==WIDTH-4 || (y_d>SMALL_Y0+1 && line_q) || (x_d>=8 && left_border) || foreground_run==15);
 reg [3:0] cap_small;reg cap_ignore,cap_inside;
 wire capture=cap_write && cap_inside;
 wire read_inside=mem_addr>=BASE && mem_addr<BASE+DEPTH;
 wire write_enable=(capture || (mem_write && small_pass)) && !invalidate && !frame_start;
 wire [15:0] wa=(capture ? cap_addr : mem_write_addr)-BASE;
 wire [3:0] wd=capture ? cap_small : mem_data[3:0];
 reg [3:0] read_value,forward_value;reg read_ignore,read_inside_d,forward;
 wire [$clog2(DEPTH)-1:0] ra=read_inside ? mem_addr-BASE : 0;
 always @(posedge clk)begin
  line_q<=line_border[pixel_x[10:3]];
  if(capture)begin line_border[cap_column]<=cap_ignore;ignored[cap_addr-BASE]<=cap_ignore;end
  if(write_enable)memory[wa[$clog2(DEPTH)-1:0]]<=wd;
  // Unconditional synchronous RAM read; mask invalid context after the RAM.
  // An else assignment on its output makes TD implement the array in LUTs.
  read_value<=memory[ra];read_ignore<=ignored[ra];read_inside_d<=read_inside;
 end
 always @(posedge clk or negedge rst_n)begin
  if(!rst_n)begin first_small<=0;cap_small<=0;cap_ignore<=0;cap_inside<=0;left_border<=0;foreground_run<=0;forward<=0;forward_value<=0;end
  else begin
   if(accept_d && y_d[0] && !x_d[2])first_small<=half_small;
   cap_small<=ignore_word ? 4'd0 : word_small;cap_ignore<=ignore_word;
   cap_inside<=y_d>=SMALL_Y0 && y_d<SMALL_Y1;
   if(accept_d && y_d[0] && x_d[2])begin
    left_border<=ignore_word;
    if(!(&word_small))foreground_run<=0;
    else if(x_d<8)foreground_run<=1;
    else if(foreground_run!=15)foreground_run<=foreground_run+1'b1;
   end
   forward<=write_enable && wa==mem_addr-BASE;forward_value<=wd;
   if(frame_start || invalidate)begin cap_inside<=0;left_border<=0;foreground_run<=0;forward<=0;end
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
 REF_REQ=15,REF_WAIT=16,REF_CHECK=17,FINISHED=18,SCALE=19,PUBLISH=20,REF_ORIGIN=21,SMALL_INSERT=22;
reg [4:0] phase;
reg [XB-1:0] sx,cx,nx,xmin,xmax;reg [YB-1:0] sy,cy,ny,ymin,ymax;
reg [1:0] direction;
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
wire candidate_region=REGIONS && !in_region0 && in_region1;
wire candidate_allowed=!REGIONS || ((in_region0 || in_region1) && region_supported[candidate_region]);
wire [41:0] candidate_bounds=candidate_region ? region_bounds[83:42] : region_bounds[41:0];
wire [10:0] target_x=REGIONS ? ({1'b0,candidate_bounds[41:31]}+candidate_bounds[30:20])/2 : WIDTH/2;
wire [10:0] target_y=REGIONS ? ({1'b0,candidate_bounds[19:10]}+candidate_bounds[9:0])/2 : HEIGHT/2;
wire [10:0] dx=center_x>target_x ? center_x-target_x : target_x-center_x;
wire [10:0] dy=center_y>target_y ? center_y-target_y : target_y-center_y;
// Distances use source coordinates, avoiding a half-pixel truncation at zone edges.
wire [9:0] legacy_dx=(center_x>>1)>W/2 ? (center_x>>1)-W/2 : W/2-(center_x>>1);
wire [9:0] legacy_dy=(center_y>>1)>H/2 ? (center_y>>1)-H/2 : H/2-(center_y>>1);
wire [11:0] distance=REGIONS ? {1'b0,dx}+dy : {2'b0,legacy_dx}+legacy_dy;
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
 long20>=short21 && long20<=short31 && fg20>=area17;
wire present_review_match=long_side>=p_lmin && long_side<=r_lmax && short_side>=p_smin && short_side<=r_smax &&
 long20>=short21 && long5<=short9 && fg4>=area3;
wire circular=long5<=short7 && fg5>=area3 && fg10<=area9;
wire empty_match=circular && long_side>=e_lmin && long_side<=e_lmax && short_side>=e_smin && short_side<=e_smax &&
 (!SMALL_HOLES || bright_count<=5);
wire sprocket_match=circular && long_side>=h_lmin && long_side<=h_lmax && short_side>=h_smin && short_side<=h_smax;
wire [1:0] candidate_state=SMALL_HOLES ?
 (small_pass ? (sprocket_match ? 0 : empty_match ? 3 : 1) : (present_match || present_review_match) ? 2 : 1) :
 sprocket_match ? 0 : (present_match || present_review_match) ? 2 : empty_match ? 3 : 1;
wire [3:0] candidate_reason={1'b0,fg20<area17,long20<short21 || long20>short31,
 long_side<p_lmin || long_side>p_lmax || short_side<p_smin || short_side>p_smax};
localparam SLOTS=REGIONS ? 4 : 2;
reg found_bank [0:SLOTS-1];reg [11:0] distance_bank [0:SLOTS-1];reg [17:0] count_bank [0:SLOTS-1];
reg [XB-1:0] xmin_bank [0:SLOTS-1],xmax_bank [0:SLOTS-1];
reg [YB-1:0] ymin_bank [0:SLOTS-1],ymax_bank [0:SLOTS-1];
reg [1:0] state_bank [0:SLOTS-1];reg [3:0] reason_bank [0:SLOTS-1];
wire [1:0] bank0=candidate_region ? 2'd2 : 2'd0,bank1=bank0+1'b1;
wire candidate_preferred=candidate_state>=2;
wire before_best=!found_bank[bank0] || (candidate_preferred && state_bank[bank0]<2) ||
 ((candidate_preferred==(state_bank[bank0]>=2)) && (distance<distance_bank[bank0] ||
 (distance==distance_bank[bank0] && component_count>count_bank[bank0])));
wire before_second=!found_bank[bank1] || (candidate_preferred && state_bank[bank1]<2) ||
 ((candidate_preferred==(state_bank[bank1]>=2)) && (distance<distance_bank[bank1] ||
 (distance==distance_bank[bank1] && component_count>count_bank[bank1])));
wire found=found_bank[0] || found_bank[1] || (REGIONS && (found_bank[SLOTS-2] || found_bank[SLOTS-1]));
reg [1:0] ref_index;reg legacy_pair_selected;
reg [8:0] left_dark,right_dark;
reg ref_side;reg [2:0] ref_word;reg [6:0] ref_row;
reg [9:0] origin_x,origin_y;reg [3:0] ref_mask;integer ref_lane_index;
wire [9:0] ref_cx=({1'b0,xmin_bank[ref_index]}+xmax_bank[ref_index])>>1;
wire [9:0] ref_cy=({1'b0,ymin_bank[ref_index]}+ymax_bank[ref_index])>>1;
// Small holes use a local8x8 side strip; legacy8x40 strips can land on
// the next body or outside a tilted carrier. Same75% dark fraction, no stale data.
wire local_empty_ref=SMALL_HOLES && state_bank[ref_index]==3;
wire [7:0] ref_min=local_empty_ref ? 8'd48 : REGIONS ? (ref_index[1] ? region_recipes[239:232] : region_recipes[119:112]) : 8'd240;
wire signed [10:0] strip_start=$signed({1'b0,origin_x})+(local_empty_ref ? (ref_side ? 11'sd4 : -11'sd12) : (ref_side ? 11'sd20 : -11'sd28));
wire signed [10:0] word_x=(strip_start & -11'sd4)+$signed({6'b0,ref_word,2'b0});
wire [9:0] word_y=origin_y-(local_empty_ref ? 10'd4 : 10'd20)+ref_row;
wire ref_last_row=ref_row==(local_empty_ref ? 7'd7 : 7'd39);
reg [2:0] dark_word;integer dark_lane;
always @*begin
 dark_word=0;
 for(dark_lane=0;dark_lane<4;dark_lane=dark_lane+1)
  if(ref_mask[dark_lane])dark_word=dark_word+mem_q[4+dark_lane];
end
wire [SLOTS*76-1:0] records;
genvar slot;
generate for(slot=0;slot<SLOTS;slot=slot+1)begin : packed_records
 wire [10:0] bw=(xmax_bank[slot]-xmin_bank[slot]+1)*2,bh=(ymax_bank[slot]-ymin_bank[slot]+1)*2;
 wire [10:0] bx0=xmin_bank[slot]*2>1 ? xmin_bank[slot]*2-2 : 0;
 wire [10:0] bx1=xmax_bank[slot]*2+4<WIDTH ? xmax_bank[slot]*2+4 : WIDTH;
 wire [9:0] by0=ymin_bank[slot]*2>1 ? ymin_bank[slot]*2-2 : 0;
 wire [9:0] by1=ymax_bank[slot]*2+4<HEIGHT ? ymax_bank[slot]*2+4 : HEIGHT;
 assign records[slot*76+:76]=found_bank[slot] ?
  {1'b1,state_bank[slot],reason_bank[slot],(count_bank[slot]>2047 ? 13'd8191 : {count_bank[slot][10:0],2'b0}),
   (bw>127 ? 7'd127 : bw[6:0]),(bh>127 ? 7'd127 : bh[6:0]),bx0,bx1,by0,by1} : 76'd0;
end endgenerate
wire [151:0] sorted0=found_bank[1] && xmin_bank[1]<xmin_bank[0] ?
 {records[75:0],records[151:76]} : records[151:0];
wire [151:0] sorted1;
generate if(REGIONS)begin
 assign sorted1=found_bank[3] && xmin_bank[3]<xmin_bank[2] ?
 {records[227:152],records[303:228]} : records[303:152];
end else assign sorted1=0;endgenerate
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
wire [3:0] seed_word=mem_q[3:0] & seed_mask;
// Do not duplicate a body with a small low-threshold fragment. Conversely,
// remove T100 fragments contained in a measured T80 empty/feed contour.
wire covers_body=(found_bank[bank0] && state_bank[bank0]==2 && xmin<=xmax_bank[bank0] && xmax>=xmin_bank[bank0] && ymin<=ymax_bank[bank0] && ymax>=ymin_bank[bank0]) ||
 (found_bank[bank1] && state_bank[bank1]==2 && xmin<=xmax_bank[bank1] && xmax>=xmin_bank[bank1] && ymin<=ymax_bank[bank1] && ymax>=ymin_bank[bank1]);
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
     scan_region<=1;sx<=(region_bounds[83:73]>>3)<<2;sy<=region_bounds[61:52]>>1;phase<=SCAN_REQ;
    end else begin
    if(SMALL_HOLES && !small_pass)begin
     small_pass<=1;scan_region<=0;sx<=(region_bounds[41:31]>>3)<<2;sy<=region_bounds[19:10]>>1;phase<=SCAN_REQ;
    end else if(found)begin legacy_pair_selected<=found_bank[1] && state_bank[0]!=0 && state_bank[1]!=0;
     ref_index<=0;ref_side<=0;ref_word<=0;ref_row<=0;left_dark<=0;right_dark<=0;phase<=REF_ORIGIN;end
    else begin ready<=1;sample_new<=1;located<=0;state<=0;phase<=FINISHED;end
    end
   end else begin sy<=sy+1'b1;phase<=SCAN_REQ;end
  end else begin sx<=(sx & ~3)+4;phase<=SCAN_REQ;end
 end
endtask
task retain_candidate;
 begin
     if(before_best)begin
      if(found_bank[bank0])begin
       found_bank[bank1]<=1;distance_bank[bank1]<=distance_bank[bank0];count_bank[bank1]<=count_bank[bank0];
       xmin_bank[bank1]<=xmin_bank[bank0];xmax_bank[bank1]<=xmax_bank[bank0];ymin_bank[bank1]<=ymin_bank[bank0];ymax_bank[bank1]<=ymax_bank[bank0];
       state_bank[bank1]<=state_bank[bank0];reason_bank[bank1]<=reason_bank[bank0];
      end
      found_bank[bank0]<=1;distance_bank[bank0]<=distance;count_bank[bank0]<=component_count;
      xmin_bank[bank0]<=xmin;xmax_bank[bank0]<=xmax;ymin_bank[bank0]<=ymin;ymax_bank[bank0]<=ymax;
      state_bank[bank0]<=candidate_state;reason_bank[bank0]<=small_pass ? 0 : candidate_reason;
     end else if(before_second)begin
      found_bank[bank1]<=1;distance_bank[bank1]<=distance;count_bank[bank1]<=component_count;
      xmin_bank[bank1]<=xmin;xmax_bank[bank1]<=xmax;ymin_bank[bank1]<=ymin;ymax_bank[bank1]<=ymax;
      state_bank[bank1]<=candidate_state;reason_bank[bank1]<=small_pass ? 0 : candidate_reason;
     end
 end
endtask
always @(posedge clk or negedge rst_n)begin
 if(!rst_n)begin
  small_pass<=0;ready<=0;sample_new<=0;located<=0;state<=1;review_required<=0;objects<=0;region_objects<=0;foreground_count<=0;box_width<=0;box_height<=0;
  box_x0<=0;box_x1<=0;box_y0<=0;box_y1<=0;seen<=0;cap_count<=0;capture_foreground<=0;phase<=IDLE;
  mem_addr<=0;mem_write_addr<=0;mem_data<=0;mem_write<=0;q_read<=0;q_write_addr<=0;q_data<=0;q_write<=0;
  scan_region<=0;sx<=0;sy<=0;cx<=0;cy<=0;nx<=0;ny<=0;xmin<=0;xmax<=0;ymin<=0;ymax<=0;direction<=0;
  q_head<=0;q_tail<=0;q_count<=0;component_count<=0;bright_count<=0;border<=0;component_area<=0;long_side<=0;short_side<=0;fg20<=0;area17<=0;fg5<=0;area3<=0;fg10<=0;area9<=0;fg4<=0;long20<=0;short21<=0;short31<=0;long5<=0;short7<=0;short9<=0;
  for(bi=0;bi<SLOTS;bi=bi+1)begin
   found_bank[bi]<=0;distance_bank[bi]<=4095;count_bank[bi]<=0;xmin_bank[bi]<=0;xmax_bank[bi]<=0;
   ymin_bank[bi]<=0;ymax_bank[bi]<=0;state_bank[bi]<=1;reason_bank[bi]<=0;
  end
  ref_index<=0;legacy_pair_selected<=0;ref_side<=0;ref_word<=0;ref_row<=0;
  origin_x<=0;origin_y<=0;ref_mask<=0;
  left_dark<=0;right_dark<=0;
 end else begin
  sample_new<=0;mem_write<=0;q_write<=0;
  if(frame_start || invalidate)begin small_pass<=0;ready<=0;located<=0;state<=1;review_required<=0;objects<=0;region_objects<=0;phase<=IDLE;seen<=0;cap_count<=0;capture_foreground<=0;end
  else if(pixel_sof)begin
   small_pass<=0;scan_region<=0;seen<=1;cap_count<=0;capture_foreground<=0;ready<=0;located<=0;state<=1;review_required<=0;objects<=0;region_objects<=0;phase<=IDLE;
   foreground_count<=0;box_width<=0;box_height<=0;
   for(bi=0;bi<SLOTS;bi=bi+1)begin
    found_bank[bi]<=0;distance_bank[bi]<=4095;count_bank[bi]<=0;reason_bank[bi]<=0;
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
    if(mem_q[nx[1:0]])begin
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
    if(!(mem_q[nx[1:0]] && (q_count==1024 || component_count==W*H)))begin
     if(direction==3)begin
      if(q_count==0 && !mem_q[nx[1:0]])phase<=AREA_CALC;else phase<=POP_REQ;
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
   AREA_CALC:begin component_area<=width_now*height_now;
    long_side<=width_now>height_now ? width_now : height_now;short_side<=width_now<height_now ? width_now : height_now;phase<=SCALE;end
   SCALE:begin
    fg20<={4'b0,component_count}*23'd20;area17<={4'b0,component_area}*23'd17;
    fg5<={4'b0,component_count}*23'd5;area3<={4'b0,component_area}*23'd3;
    fg10<={4'b0,component_count}*23'd10;area9<={4'b0,component_area}*23'd9;
    fg4<={2'b0,component_count,2'b0};
    long20<={4'b0,long_side}*14'd20;short21<={4'b0,short_side}*14'd21;short31<={4'b0,short_side}*14'd31;
    long5<={4'b0,long_side}*14'd5;short7<={4'b0,short_side}*14'd7;short9<={4'b0,short_side}*14'd9;phase<=COMPARE;
   end
   COMPARE:begin
    phase<=SCAN_REQ;
    if(candidate_allowed && (!REGIONS || candidate_state!=0 || small_pass) && !border && component_count>=8 && width_now>=3 && height_now>=3)begin
     if(!small_pass)retain_candidate;
     else if((empty_match || sprocket_match) && !covers_body)begin
      for(bi=0;bi<SLOTS;bi=bi+1)if(found_bank[bi] && state_bank[bi]!=2 && bi/2==candidate_region &&
       xmin_bank[bi]>=xmin && xmax_bank[bi]<=xmax && ymin_bank[bi]>=ymin && ymax_bank[bi]<=ymax)found_bank[bi]<=0;
      if(empty_match && !sprocket_match)phase<=SMALL_INSERT;
     end
    end
   end
   SMALL_INSERT:begin retain_candidate;phase<=SCAN_REQ;end
   // Separate bbox-center arithmetic from dark-pixel counting and thresholds.
   REF_ORIGIN:begin
    if(!REGIONS && ref_index==1 && !legacy_pair_selected)phase<=PUBLISH;
    else if(!found_bank[ref_index])begin
     if(ref_index==SLOTS-1)phase<=PUBLISH;else ref_index<=ref_index+1'b1;
    end else begin origin_x<=ref_cx;origin_y<=ref_cy;phase<=REF_REQ;end
   end
   REF_REQ:begin
    mem_addr<=address(word_x[XB-1:0],word_y[YB-1:0]);
    for(ref_lane_index=0;ref_lane_index<4;ref_lane_index=ref_lane_index+1)ref_mask[ref_lane_index]<=word_x>=0 && word_x<W && word_y<H &&
     (ref_word==1 || (ref_word==0 && ref_lane_index>=origin_x[1:0]) || (ref_word==2 && ref_lane_index<origin_x[1:0]));
    phase<=REF_WAIT;
   end
   REF_WAIT:phase<=REF_CHECK;
   REF_CHECK:begin
    if(ref_side)right_dark<=right_dark+dark_word;else left_dark<=left_dark+dark_word;
    if(ref_side && ref_word==2 && ref_last_row)begin
     // Neighboring parts or a tape end may contaminate the side strips.
     // Preserve a recognized 3528 body, but do not assert quality is normal.
     if(state_bank[ref_index]==2)reason_bank[ref_index][3]<=left_dark<ref_min || right_dark+dark_word<ref_min;
     else begin
      reason_bank[ref_index]<=0;
      if(left_dark<ref_min || right_dark+dark_word<ref_min)state_bank[ref_index]<=REGIONS ? 1 : 0;
     end
     if(ref_index==SLOTS-1)phase<=PUBLISH;
     else begin ref_index<=ref_index+1'b1;ref_side<=0;ref_word<=0;ref_row<=0;left_dark<=0;right_dark<=0;phase<=REF_ORIGIN;end
    end else begin
     if(ref_word==2)begin ref_word<=0;if(ref_last_row)begin ref_row<=0;ref_side<=1;end else ref_row<=ref_row+1'b1;end
     else ref_word<=ref_word+1'b1;
     phase<=REF_REQ;
    end
   end
   PUBLISH:begin
     ready<=1;sample_new<=1;located<=primary_record[75];state<=primary_record[74:73];
     review_required<=primary_record[74:73]==2 && |primary_record[72:69];
     objects<=(!REGIONS && !legacy_pair_selected) ? {76'd0,records[75:0]} : sorted0;
     region_objects<={sorted1,sorted0};
     foreground_count<=primary_record[68:56];box_width<=primary_record[55:49];box_height<=primary_record[48:42];
     box_x0<=primary_record[41:31];box_x1<=primary_record[30:20];box_y0<=primary_record[19:10];box_y1<=primary_record[9:0];phase<=FINISHED;
   end
   default:begin end
  endcase
 end
end
endmodule
