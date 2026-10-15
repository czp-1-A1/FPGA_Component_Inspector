// One decimated scan line. Centers/widths are in full-resolution pixels.
// A bright run needs dark margins and a neighboring run at the configured pitch.
module hole_scanline #(
 parameter ROW=220,X0=256,X1=768,MIN_WIDTH=20,MAX_WIDTH=64,
 parameter PITCH=96,PITCH_TOLERANCE=24,
 parameter [7:0] BRIGHT=120,DARK=100
)(
 input wire clk,rst_n,sof,accept,input wire [10:0] x,anchor,
 input wire [9:0] y,input wire [7:0] gray,input wire [5:0] radius,
 output reg done,found,output reg [10:0] center,output reg [6:0] width
);
reg running,left_ok,pending,previous_valid,paired,ambiguous;
reg [10:0] first,last,pending_center,previous_center;
reg [6:0] pending_width;
reg [3:0] dark_count;
// At most two decimated samples (8 pixels) of MID on either boundary.
reg [1:0] transition_count;
reg left_margin;
reg [10:0] best_distance;
wire [11:0] run_width={1'b0,last}-{1'b0,first}+12'd4;
wire [11:0] midpoint={1'b0,first}+{1'b0,last}+12'd4;
wire [10:0] distance=pending_center>=anchor ? pending_center-anchor : anchor-pending_center;
wire left_pair=previous_valid && pending_center>previous_center &&
 pending_center-previous_center>=PITCH-PITCH_TOLERANCE && pending_center-previous_center<=PITCH+PITCH_TOLERANCE;
wire right_pair=found && previous_valid && previous_center==center && pending_center>center &&
 pending_center-center>=PITCH-PITCH_TOLERANCE && pending_center-center<=PITCH+PITCH_TOLERANCE;
always @(posedge clk or negedge rst_n) begin
 if(!rst_n) begin
  done<=0;found<=0;center<=0;width<=0;running<=0;left_ok<=0;pending<=0;
  previous_valid<=0;paired<=0;ambiguous<=0;first<=0;last<=0;pending_center<=0;pending_width<=0;
  previous_center<=0;dark_count<=0;transition_count<=0;left_margin<=0;best_distance<=2047;
 end else if(sof) begin
  done<=0;found<=0;running<=0;pending<=0;previous_valid<=0;paired<=0;ambiguous<=0;dark_count<=0;transition_count<=0;left_margin<=0;best_distance<=2047;
 end else if(accept && y==ROW && x>=X0 && x<X1) begin
  if(gray>=BRIGHT) begin
   dark_count<=0;pending<=0;transition_count<=0;left_margin<=0;
   if(!running) begin first<=x;left_ok<=dark_count>=2 || (left_margin && transition_count<=2);end
   last<=x;running<=1;
  end else begin
   running<=0;
   if(gray<=DARK) begin
    transition_count<=0;left_margin<=0;
    if(dark_count!=15) dark_count<=dark_count+1'b1;
   end else begin
    dark_count<=0;
    if(transition_count!=3) transition_count<=transition_count+1'b1;
    if(running || pending) left_margin<=0;
    else if(dark_count>=2) left_margin<=1;
    else if(transition_count>=2) left_margin<=0;
    // MID after a partial right dark margin breaks its continuity.
    if(transition_count>=2 || dark_count!=0) pending<=0;
   end
   if(running) begin
    pending<=left_ok && run_width>=MIN_WIDTH && run_width<=MAX_WIDTH;
    pending_center<=midpoint[11:1];pending_width<=run_width[6:0];
   end else if(pending && gray<=DARK && dark_count>=1) begin
    pending<=0;previous_valid<=1;previous_center<=pending_center;
    if(right_pair) paired<=1;
    if(found && distance<=radius && (distance>=best_distance ? distance-best_distance : best_distance-distance)<=8) ambiguous<=1;
    if(distance<=radius && distance<best_distance) begin
     found<=1;center<=pending_center;width<=pending_width;best_distance<=distance;paired<=left_pair;
    end
   end
   // The search interval deliberately ends on a dark margin.
  end
  if(x==X1-4) begin done<=1;found<=found && paired && !ambiguous;end
end
end
endmodule

// A repeated old DDR slot is an old image, even if its classification was valid.
// The writer never overwrites the active slot, so any new display slot has a
// different index. ~115 ms at the current 52 MHz HDMI pixel clock.
module tracking_frame_age #(parameter LIMIT=6000000)(
 input wire clk,rst_n,valid,input wire [1:0] slot,output wire fresh
);
reg valid_d;reg [1:0] slot_d;reg [22:0] age;
always @(posedge clk or negedge rst_n) begin
 if(!rst_n) begin valid_d<=0;slot_d<=0;age<=0;end
 else begin
  valid_d<=valid;slot_d<=slot;
  if(!valid || !valid_d || slot!=slot_d) age<=0;
  else if(age<LIMIT) age<=age+1'b1;
 end
end
assign fresh=valid && age<LIMIT;
endmodule

// Horizontal tracking. A lower hole band verifies the frame-held ROI after
// sampling; bounded motion is required before publishing that frame's result.
module tape_hole_tracker #(
 parameter HOLE_Y=220,ROW_DELTA=8,ANCHOR_X=464,CORE_ANCHOR_X=512,
 parameter ROI_W=80,ROI_Y0=260,ROI_Y1=340,
 parameter X0=256,X1=768,PITCH=96,PITCH_TOLERANCE=24,MAX_STEP=16,
 parameter LATE_HOLE=0,VERIFY_ERROR=4
)(
 input wire clk,rst_n,frame_start,pixel_sof,pixel_accept,frame_commit,invalidate,
 input wire [10:0] pixel_x,input wire [9:0] pixel_y,input wire [95:0] rgb,
 output reg frame_locked,output reg [10:0] roi_x0,roi_x1,
 output wire [9:0] roi_y0,roi_y1,output reg located,output wire [7:0] diagnostic
);
assign roi_y0=ROI_Y0;assign roi_y1=ROI_Y1;
reg [10:0] anchor,last_center,reference_center;
reg locked,acquired,scan_good;
reg [3:0] reason;
reg accept_d,sof_d;
reg [10:0] x_d;
reg [9:0] y_d;
reg [7:0] gray_d;
wire [9:0] sum={2'd0,rgb[95:88]}+{1'd0,rgb[87:80],1'b0}+{2'd0,rgb[79:72]};
wire [2:0] done,found;
wire [10:0] center [0:2];wire [6:0] width [0:2];
wire [5:0] radius=locked ? MAX_STEP : 24;
genvar r;
generate for(r=0;r<3;r=r+1) begin : row
 hole_scanline #(.ROW(HOLE_Y+(r-1)*ROW_DELTA),.X0(X0),.X1(X1),.PITCH(PITCH),.PITCH_TOLERANCE(PITCH_TOLERANCE)) scan(
  .clk(clk),.rst_n(rst_n),.sof(sof_d || frame_start),.accept(accept_d),.x(x_d),.y(y_d),.gray(gray_d),
  .anchor(anchor),.radius(radius),.done(done[r]),.found(found[r]),.center(center[r]),.width(width[r]));
end endgenerate
wire aligned=(center[0]>=center[1] ? center[0]-center[1] : center[1]-center[0])<=4 &&
             (center[2]>=center[1] ? center[2]-center[1] : center[1]-center[2])<=4;
wire shape=width[0]<=width[1]+4 && width[2]<=width[1]+4 &&
           {1'b0,width[0],1'b0}>=width[1] && {1'b0,width[2],1'b0}>=width[1];
// Initial manual alignment establishes the hole-to-pocket phase. Afterwards
// follow its displacement, rather than assuming a hole lies directly over a part.
wire signed [12:0] target_center=acquired ?
 $signed({2'b0,center[1]})-$signed({2'b0,reference_center})+CORE_ANCHOR_X : CORE_ANCHOR_X;
wire safe=target_center>=X0+ROI_W/2+17 && target_center<=X1-ROI_W/2-17;
wire signed [12:0] sampled_center=$signed({2'b0,roi_x0})+ROI_W/2;
wire [12:0] position_error=target_center>=sampled_center ? target_center-sampled_center : sampled_center-target_center;
wire motion_ok=!LATE_HOLE || !acquired || position_error<=VERIFY_ERROR;
wire candidate=&found && aligned && shape && safe && motion_ok;
assign diagnostic={reason,done==3'b111,found};
always @(posedge clk or negedge rst_n) begin
 if(!rst_n) begin
  accept_d<=0;sof_d<=0;x_d<=0;y_d<=0;gray_d<=0;
  anchor<=ANCHOR_X;last_center<=ANCHOR_X;reference_center<=ANCHOR_X;locked<=0;acquired<=0;scan_good<=0;
  frame_locked<=0;located<=0;reason<=1;roi_x0<=CORE_ANCHOR_X-ROI_W/2;roi_x1<=CORE_ANCHOR_X+ROI_W/2;
 end else begin
  accept_d<=pixel_accept;sof_d<=pixel_sof;x_d<=pixel_x;y_d<=pixel_y;gray_d<=sum[9:2];
  if(frame_start) begin
   anchor<=locked ? last_center : ANCHOR_X;frame_locked<=0;located<=0;scan_good<=0;reason<=1;
   if(LATE_HOLE) begin
    // Freeze before core pixels. These exact coordinates accompany its statistics.
    roi_x0<=acquired ? CORE_ANCHOR_X+last_center-reference_center-ROI_W/2 : CORE_ANCHOR_X-ROI_W/2;
    roi_x1<=acquired ? CORE_ANCHOR_X+last_center-reference_center+ROI_W/2 : CORE_ANCHOR_X+ROI_W/2;
   end
  end else if(invalidate) begin
   locked<=0;acquired<=0;frame_locked<=0;scan_good<=0;located<=1;reason<=7;
  end else begin
   if(&done && !located) begin
    located<=1;scan_good<=candidate;
    frame_locked<=candidate && (locked || acquired);
    reason<=!(&found) ? 2 : !aligned || !shape ? 3 : !safe ? 4 : !motion_ok ? 6 : !(locked || acquired) ? 5 : 0;
    if(candidate && !LATE_HOLE) begin roi_x0<=target_center-ROI_W/2;roi_x1<=target_center+ROI_W/2;end
   end
   if(frame_commit) begin
    if(scan_good) begin
     last_center<=center[1];locked<=locked || acquired;acquired<=1;
     if(!acquired) reference_center<=center[1];
    end else begin locked<=0;acquired<=0;frame_locked<=0;end
   end
  end
end
end
endmodule

// One reason for each display gate, independently testable without a board.
module tracking_display_status(
 input wire active_valid,fresh,config_ok,fps_ok,transport_ok,params_match,
 input wire track_locked,sample_valid,class_wait,input wire [3:0] hole_reason,
 output wire valid,output wire [3:0] reason
);
assign valid=active_valid && fresh && config_ok && fps_ok && transport_ok && params_match && track_locked && sample_valid;
assign reason=!active_valid || !fresh ? 8 : !config_ok ? 9 : !fps_ok ? 10 :
 !transport_ok ? 11 : !params_match ? 12 : !track_locked ? (hole_reason==0 ? 5 : hole_reason) :
 !sample_valid ? 13 : class_wait ? 14 : 0;
endmodule
