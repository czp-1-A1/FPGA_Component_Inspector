// Sampling UI. Three pixel clocks for RGB, DE, HS, VS and ENABLE bypass.
module experiment_osd #(
 parameter COMPACT_UI=1,WIDTH=1024,HEIGHT=600,DIAG_BITS=26,RESOLUTION_V11=0,REGIONS=0,CALIBRATION=0,
 parameter LOCAL_SEARCH=0,SHAPE_MODEL=0,TRACKING=0,MULTI_POCKETS=0,DIRECT_DETECTION=0,CLASS_THRESHOLD=58,ENABLE=1,ROI_X0=256,ROI_X1=768,ROI_Y0=172,ROI_Y1=428,
 parameter SAMPLE_X0=472,SAMPLE_X1=552,SAMPLE_Y0=260,SAMPLE_Y1=340,HOLE_Y=220,FRAME_OBJECTS=0
)(
 input wire clk,rst_n,vs,hs,de,input wire [23:0] rgb,
 input wire [15:0] exposure,gain,
 input wire [7:0] wb_r,wb_b,input wire wb_tune,wb_pending,
 input wire [1:0] view_mode,input wire [12:0] edge_count,input wire [23:0] edge_sum,
 input wire local_box_valid,input wire [10:0] local_x0,local_x1,input wire [9:0] local_y0,local_y1,
 input wire roi_valid,input wire [7:0] roi_mean,roi_min,roi_max,input wire [1:0] roi_state,
 input wire [15:0] width,height,fps,lane_errors,format_errors,i2c_errors,gaps,
 input wire [31:0] frames,uptime,input wire cfg_done,
 input wire [15:0] overflow_frames,lost_frames,underflow_frames,
 input wire [35:0] diagnostics,
 input wire [DIAG_BITS-1:0] publish_diagnostic,
 input wire [339:0] pocket_records,input wire pocket_enable,
 input wire track_valid,input wire [10:0] track_x0,track_x1,
 input wire [3:0] track_reason,input wire [2:0] track_rows,
 output wire out_vs,out_hs,out_de,output wire [23:0] out_rgb,
 input wire [(REGIONS ? 304 : 152)-1:0] frame_objects,
 input wire [127:0] calibration_record,input wire calibration_valid,
 input wire [3:0] local_wait_reason
);
generate if(REGIONS && FRAME_OBJECTS && COMPACT_UI)begin : compact_ui
 compact_lane_osd #(.WIDTH(WIDTH),.HEIGHT(HEIGHT),.ENABLE(ENABLE)) ui(
.clk(clk),.rst_n(rst_n),.vs(vs),.hs(hs),.de(de),.rgb(rgb),.exposure(exposure),.gain(gain),.fps(fps),.view_mode(view_mode),.roi_valid(roi_valid),.cfg_done(cfg_done),.frame_objects(frame_objects),.out_vs(out_vs),.out_hs(out_hs),.out_de(out_de),.out_rgb(out_rgb),
 .error(|lane_errors || |format_errors || |i2c_errors || |gaps || |overflow_frames || |lost_frames || |underflow_frames));
end else begin : legacy_ui
 experiment_osd_legacy #(.WIDTH(WIDTH),.HEIGHT(HEIGHT),.DIAG_BITS(DIAG_BITS),.RESOLUTION_V11(RESOLUTION_V11),.REGIONS(REGIONS),.CALIBRATION(CALIBRATION),.LOCAL_SEARCH(LOCAL_SEARCH),.SHAPE_MODEL(SHAPE_MODEL),.TRACKING(TRACKING),.MULTI_POCKETS(MULTI_POCKETS),.DIRECT_DETECTION(DIRECT_DETECTION),.CLASS_THRESHOLD(CLASS_THRESHOLD),.ENABLE(ENABLE),.ROI_X0(ROI_X0),.ROI_X1(ROI_X1),.ROI_Y0(ROI_Y0),.ROI_Y1(ROI_Y1),.SAMPLE_X0(SAMPLE_X0),.SAMPLE_X1(SAMPLE_X1),.SAMPLE_Y0(SAMPLE_Y0),.SAMPLE_Y1(SAMPLE_Y1),.HOLE_Y(HOLE_Y),.FRAME_OBJECTS(FRAME_OBJECTS)) ui(
.clk(clk),.rst_n(rst_n),.vs(vs),.hs(hs),.de(de),.rgb(rgb),.exposure(exposure),.gain(gain),.wb_r(wb_r),.wb_b(wb_b),.wb_tune(wb_tune),.wb_pending(wb_pending),.view_mode(view_mode),.edge_count(edge_count),.edge_sum(edge_sum),.local_box_valid(local_box_valid),.local_x0(local_x0),.local_x1(local_x1),.local_y0(local_y0),.local_y1(local_y1),.roi_valid(roi_valid),.roi_mean(roi_mean),.roi_min(roi_min),.roi_max(roi_max),.roi_state(roi_state),.width(width),.height(height),.fps(fps),.lane_errors(lane_errors),.format_errors(format_errors),.i2c_errors(i2c_errors),.gaps(gaps),.frames(frames),.uptime(uptime),.cfg_done(cfg_done),.overflow_frames(overflow_frames),.lost_frames(lost_frames),.underflow_frames(underflow_frames),.diagnostics(diagnostics),.publish_diagnostic(publish_diagnostic),.pocket_records(pocket_records),.pocket_enable(pocket_enable),.track_valid(track_valid),.track_x0(track_x0),.track_x1(track_x1),.track_reason(track_reason),.track_rows(track_rows),.out_vs(out_vs),.out_hs(out_hs),.out_de(out_de),.out_rgb(out_rgb),.frame_objects(frame_objects),.calibration_record(calibration_record),.calibration_valid(calibration_valid),.local_wait_reason(local_wait_reason));
end endgenerate
endmodule

// Sampling UI. Three pixel clocks for RGB, DE, HS, VS and ENABLE bypass.
module experiment_osd_legacy #(
 parameter WIDTH=1024,HEIGHT=600,DIAG_BITS=26,RESOLUTION_V11=0,REGIONS=0,CALIBRATION=0,
 parameter LOCAL_SEARCH=0,SHAPE_MODEL=0,TRACKING=0,MULTI_POCKETS=0,DIRECT_DETECTION=0,CLASS_THRESHOLD=58,ENABLE=1,ROI_X0=256,ROI_X1=768,ROI_Y0=172,ROI_Y1=428,
 parameter SAMPLE_X0=472,SAMPLE_X1=552,SAMPLE_Y0=260,SAMPLE_Y1=340,HOLE_Y=220,FRAME_OBJECTS=0
)(
 input wire clk,rst_n,vs,hs,de,input wire [23:0] rgb,
 input wire [15:0] exposure,gain,
 input wire [7:0] wb_r,wb_b,input wire wb_tune,wb_pending,
 input wire [1:0] view_mode,input wire [12:0] edge_count,input wire [23:0] edge_sum,
 input wire local_box_valid,input wire [10:0] local_x0,local_x1,input wire [9:0] local_y0,local_y1,
 input wire roi_valid,input wire [7:0] roi_mean,roi_min,roi_max,input wire [1:0] roi_state,
 input wire [15:0] width,height,fps,lane_errors,format_errors,i2c_errors,gaps,
 input wire [31:0] frames,uptime,input wire cfg_done,
 input wire [15:0] overflow_frames,lost_frames,underflow_frames,
 input wire [35:0] diagnostics,
 input wire [DIAG_BITS-1:0] publish_diagnostic,
 input wire [339:0] pocket_records,input wire pocket_enable,
 input wire track_valid,input wire [10:0] track_x0,track_x1,
 input wire [3:0] track_reason,input wire [2:0] track_rows,
 output reg out_vs,out_hs,out_de,output reg [23:0] out_rgb,
 input wire [(REGIONS ? 304 : 152)-1:0] frame_objects,
 input wire [127:0] calibration_record,input wire calibration_valid,
 input wire [3:0] local_wait_reason
);
localparam [199:0] calibration_text="180MM THRESH R1          ";
reg [339:0] pockets_s;reg pockets_enabled_s;
reg local_box_s;reg [10:0] local_x0_s,local_x1_s;reg [9:0] local_y0_s,local_y1_s;
localparam OBJECTS=REGIONS ? 4 : 2;
reg [OBJECTS*76-1:0] frame_objects_s;
reg vs_d,de_d;reg [10:0] x;reg [9:0] y;
wire [9:0] y_ui=(y>=HEIGHT-96) ? y-(HEIGHT-600) : y;
// DDR slot selection follows VS. Wait until its metadata has crossed during blanking.
wire start=(TRACKING || LOCAL_SEARCH) ? de && !de_d && y==0 : vs && !vs_d;
wire cal_panel;wire [7:0] cal_glyph;
wire [3:0] cal_col,cal_row;wire [23:0] cal_color;
generate if(CALIBRATION && !FRAME_OBJECTS)begin : calibration_ui
 calibration_osd #(.WIDTH(WIDTH),.HEIGHT(HEIGHT)) ui(
  .clk(clk),.rst_n(rst_n),.start(start),.record(calibration_record),.eligible(calibration_valid),
  .reason(local_wait_reason),.x(x),.y(y),.panel(cal_panel),.border(),.core(),
  .glyph(cal_glyph),.col(cal_col),.row(cal_row),.color(cal_color));
end else begin : no_calibration_ui
 assign cal_panel=0;assign cal_glyph=0;assign cal_col=0;assign cal_row=0;assign cal_color=0;
end endgenerate
reg track_valid_s;reg [10:0] track_x0_s,track_x1_s;
reg [3:0] track_reason_s;reg [2:0] track_rows_s;
reg [127:0] track_message;
always @* begin
 case(track_reason_s)
  0:track_message="OK              ";1:track_message="SCAN WAIT       ";
  2:track_message="NO HOLE         ";3:track_message="HOLE SHAPE      ";
  4:track_message="OUT OF RANGE    ";5:track_message="ACQUIRING       ";
  6:track_message="MOVE TOO FAST   ";7:track_message="CAPTURE BAD     ";
  8:track_message="FRAME STALE     ";9:track_message="CONFIG WAIT     ";
  10:track_message="NO INPUT FPS    ";11:track_message="VIDEO WAIT      ";
  12:track_message="PARAM CHANGED   ";13:track_message="ROI INCOMPLETE  ";
  14:track_message="CHECK CORE ROI  ";15:track_message="METADATA WAIT   ";default:track_message="UNKNOWN         ";
 endcase
end
wire [19:0] exp_bcd,gain_bcd,mean_bcd,min_bcd,max_bcd,w_bcd,h_bcd,fps_bcd;
bin16_bcd b0(clk,rst_n,start,exposure,exp_bcd);
bin16_bcd b1(clk,rst_n,start,gain,gain_bcd);
bin16_bcd b2(clk,rst_n,start,{8'd0,roi_mean},mean_bcd);
bin16_bcd b3(clk,rst_n,start,{8'd0,roi_min},min_bcd);
bin16_bcd b4(clk,rst_n,start,{8'd0,roi_max},max_bcd);
bin16_bcd b5(clk,rst_n,start,width,w_bcd);
bin16_bcd b6(clk,rst_n,start,height,h_bcd);
bin16_bcd b7(clk,rst_n,start,fps,fps_bcd);
wire [19:0] wb_r_bcd,wb_b_bcd;
bin16_bcd b8(clk,rst_n,start,{8'd0,wb_r},wb_r_bcd);
bin16_bcd b9(clk,rst_n,start,{8'd0,wb_b},wb_b_bcd);
reg wb_tune_s,wb_pending_s;
reg [15:0] lane_s,format_s,i2c_s,gap_s,overflow_s,lost_s,underflow_s;
reg [31:0] frames_s,uptime_s;
reg [35:0] diagnostics_s;
reg [DIAG_BITS-1:0] publish_s;
wire [7:0] publish_flags=publish_s[DIAG_BITS-2 -:8];
wire [19:0] publish_count={{(29-DIAG_BITS){1'b0}},publish_s[DIAG_BITS-10:0]};
reg sample_s,cfg_s,error_s,edge_sample_s;reg [1:0] class_s,reason_s,mode_s,gray_state_s,edge_state_s;
reg [15:0] edge_count_s;reg [23:0] edge_sum_s;
// Freeze the raw current tuple at the first active pixel. Match its display
// slots in four short steps, well before the earliest card at image row80.
// Doubled centers keep the32 processing-pixel Manhattan gate exact.
reg [2:0] display_phase;
reg [11:0] current_x[0:3],previous_x[0:3],match_dx[0:7];
reg [10:0] current_y[0:3],previous_y[0:3],match_dy[0:7];
reg [3:0] current_valid,previous_valid;
reg [8:0] match_cost[0:7];
reg [1:0] display_swap,acquisition_swap;
wire [12:0] match_distance[0:7];
genvar match_index;
generate for(match_index=0;match_index<8;match_index=match_index+1)begin : display_distances
 assign match_distance[match_index]={1'b0,match_dx[match_index]}+{2'b0,match_dy[match_index]};
end endgenerate
wire [OBJECTS*76-1:0] display_objects;
generate if(REGIONS)begin : stable_display_ids
 assign display_objects[151:0]=display_swap[0] ? {frame_objects_s[75:0],frame_objects_s[151:76]} : frame_objects_s[151:0];
 assign display_objects[303:152]=display_swap[1] ? {frame_objects_s[227:152],frame_objects_s[303:228]} : frame_objects_s[303:152];
end else begin : spatial_display_ids
 assign display_objects=frame_objects_s;
end endgenerate
integer match_i,match_current,match_previous;
reg [9:0] straight_cost,crossed_cost;reg any_match;
always @(posedge clk or negedge rst_n)begin
 if(!rst_n)begin
  display_phase<=0;current_valid<=0;previous_valid<=0;display_swap<=0;acquisition_swap<=0;
  for(match_i=0;match_i<4;match_i=match_i+1)begin current_x[match_i]<=0;current_y[match_i]<=0;previous_x[match_i]<=0;previous_y[match_i]<=0;end
  for(match_i=0;match_i<8;match_i=match_i+1)begin match_dx[match_i]<=0;match_dy[match_i]<=0;match_cost[match_i]<=0;end
 end else if(REGIONS && start)begin
  display_phase<=1;
  if(!sample_s)previous_valid<=0;
  for(match_i=0;match_i<4;match_i=match_i+1)begin
   current_x[match_i]<={1'b0,frame_objects[match_i*76+31+:11]}+frame_objects[match_i*76+20+:11];
   current_y[match_i]<={1'b0,frame_objects[match_i*76+10+:10]}+frame_objects[match_i*76+:10];
   current_valid[match_i]<=roi_valid && cfg_done && fps!=0 && frame_objects[match_i*76+75];
  end
 end else case(display_phase)
  1:begin
   for(match_i=0;match_i<8;match_i=match_i+1)begin
    match_current=(match_i/4)*2+(match_i%4)/2;match_previous=(match_i/4)*2+match_i%2;
    match_dx[match_i]<=current_x[match_current]>previous_x[match_previous] ? current_x[match_current]-previous_x[match_previous] : previous_x[match_previous]-current_x[match_current];
    match_dy[match_i]<=current_y[match_current]>previous_y[match_previous] ? current_y[match_current]-previous_y[match_previous] : previous_y[match_previous]-current_y[match_current];
   end
   for(match_i=0;match_i<2;match_i=match_i+1)begin
    if(!current_valid[match_i*2])acquisition_swap[match_i]<=current_valid[match_i*2+1];
    else acquisition_swap[match_i]<=current_valid[match_i*2+1] &&
     ((current_x[match_i*2]>current_x[match_i*2+1] ? current_x[match_i*2]-current_x[match_i*2+1] : current_x[match_i*2+1]-current_x[match_i*2])<=32 ?
       current_y[match_i*2+1]<current_y[match_i*2] : current_x[match_i*2+1]<current_x[match_i*2]);
   end
   display_phase<=2;
  end
  2:begin
   for(match_i=0;match_i<8;match_i=match_i+1)begin
    match_current=(match_i/4)*2+(match_i%4)/2;match_previous=(match_i/4)*2+match_i%2;
    if(!current_valid[match_current] && !previous_valid[match_previous])match_cost[match_i]<=0;
    else if(current_valid[match_current] && previous_valid[match_previous] && match_distance[match_i]<=64)match_cost[match_i]<=match_distance[match_i][8:0];
    else match_cost[match_i]<=9'd256;
   end
   display_phase<=3;
  end
  3:begin
   for(match_i=0;match_i<2;match_i=match_i+1)begin
    straight_cost={1'b0,match_cost[match_i*4]}+{1'b0,match_cost[match_i*4+3]};
    crossed_cost={1'b0,match_cost[match_i*4+1]}+{1'b0,match_cost[match_i*4+2]};
    any_match=(current_valid[match_i*2] && previous_valid[match_i*2] && !match_cost[match_i*4][8]) ||
     (current_valid[match_i*2] && previous_valid[match_i*2+1] && !match_cost[match_i*4+1][8]) ||
     (current_valid[match_i*2+1] && previous_valid[match_i*2] && !match_cost[match_i*4+2][8]) ||
     (current_valid[match_i*2+1] && previous_valid[match_i*2+1] && !match_cost[match_i*4+3][8]);
    display_swap[match_i]<=any_match ? crossed_cost<straight_cost : acquisition_swap[match_i];
   end
   display_phase<=4;
  end
  4:begin
   for(match_i=0;match_i<4;match_i=match_i+1)begin
    previous_x[match_i]<=display_swap[match_i/2] ? current_x[match_i^1] : current_x[match_i];
    previous_y[match_i]<=display_swap[match_i/2] ? current_y[match_i^1] : current_y[match_i];
    previous_valid[match_i]<=display_swap[match_i/2] ? current_valid[match_i^1] : current_valid[match_i];
   end
   display_phase<=0;
  end
  default:begin end
 endcase
end
always @(posedge clk or negedge rst_n) begin
 if(!rst_n) begin
  frame_objects_s<=0;local_box_s<=0;local_x0_s<=0;local_x1_s<=0;local_y0_s<=0;local_y1_s<=0;
  pockets_s<=0;pockets_enabled_s<=0;
  track_valid_s<=0;track_reason_s<=1;track_rows_s<=0;track_x0_s<=SAMPLE_X0;track_x1_s<=SAMPLE_X1;vs_d<=0;de_d<=0;x<=0;y<=0;sample_s<=0;cfg_s<=0;error_s<=0;wb_tune_s<=0;wb_pending_s<=0;
  overflow_s<=0;lost_s<=0;underflow_s<=0;diagnostics_s<=0;publish_s<=0;
  mode_s<=0;edge_sample_s<=0;edge_count_s<=0;edge_sum_s<=0;
  class_s<=1;gray_state_s<=1;edge_state_s<=1;reason_s<=0;lane_s<=0;format_s<=0;i2c_s<=0;gap_s<=0;frames_s<=0;uptime_s<=0;
 end else begin
  vs_d<=vs;de_d<=de;
  if(vs) begin x<=0;y<=0;end
  else if(de) x<=x+1'b1;
  else if(de_d) begin x<=0;y<=y+1'b1;end
  if(REGIONS && display_phase==4)frame_objects_s<=display_objects;
  if(start) begin
   frame_objects_s<=roi_valid ? frame_objects : {OBJECTS*76{1'b0}};
   local_box_s<=local_box_valid;local_x0_s<=local_x0;local_x1_s<=local_x1;local_y0_s<=local_y0;local_y1_s<=local_y1;
   pockets_s<=pocket_records;pockets_enabled_s<=pocket_enable;
   track_valid_s<=track_valid;track_x0_s<=track_x0;track_x1_s<=track_x1;
   track_reason_s<=track_reason;track_rows_s<=track_rows;
   wb_tune_s<=wb_tune;wb_pending_s<=wb_pending;
   overflow_s<=overflow_frames;lost_s<=lost_frames;underflow_s<=underflow_frames;diagnostics_s<=diagnostics;publish_s<=publish_diagnostic;
   mode_s<=view_mode;edge_count_s<={3'd0,edge_count};edge_sum_s<=edge_sum;
   edge_sample_s<=roi_valid && cfg_done && fps!=0 && view_mode[1];
   sample_s<=roi_valid && cfg_done && fps!=0;
   class_s<=!cfg_done || fps==0 || !roi_valid ? 2'd1 : roi_state;
   // Both labels use the same recent, complete observation and display snapshot.
   // GRAY+EDGE shows independent tests; it does not fuse or require agreement.
   gray_state_s<=!cfg_done || fps==0 || !roi_valid ? 2'd1 : SHAPE_MODEL ? roi_state : roi_mean>=CLASS_THRESHOLD ? 2'd2 : 2'd3;
   edge_state_s<=SHAPE_MODEL || !cfg_done || fps==0 || !roi_valid || !view_mode[1] ? 2'd1 :
    edge_count>=96 && edge_sum>=32768 ? 2'd2 : edge_count<=48 && edge_sum<=16384 ? 2'd3 : 2'd1;
   reason_s<=!cfg_done ? 2'd0 : fps==0 ? 2'd1 : !roi_valid ? 2'd2 : 2'd3;
   lane_s<=lane_errors;format_s<=format_errors;i2c_s<=i2c_errors;gap_s<=gaps;
   frames_s<=frames;uptime_s<=uptime;cfg_s<=cfg_done;
   error_s<=|lane_errors || |format_errors || |i2c_errors || |gaps;
  end
 end
end
function [6:0] decimal;
 input [19:0] value;input [2:0] position;
 reg [3:0] nibble;reg blank;
 begin
  case(position)
   0: begin nibble=value[19:16];blank=value[19:16]==0;end
   1: begin nibble=value[15:12];blank=value[19:12]==0;end
   2: begin nibble=value[11:8];blank=value[19:8]==0;end
   3: begin nibble=value[7:4];blank=value[19:4]==0;end
   default: begin nibble=value[3:0];blank=0;end
  endcase
  decimal=blank ? 7'd32 : 7'd48+nibble;
 end
endfunction
function [6:0] hexchar;
 input [3:0] value;begin hexchar=value<10 ? 7'd48+value : 7'd55+value;end
endfunction
// English labels avoid confusing non-target with the legacy UNCAL state.
function [7:0] shape_status_char;
 input [1:0] status;input integer pos;
 begin
  if(status==0) case(pos)
   0:shape_status_char="N";1:shape_status_char="O";2:shape_status_char=" ";3:shape_status_char="T";
   4:shape_status_char="A";5:shape_status_char="R";6:shape_status_char="G";7:shape_status_char="E";8:shape_status_char="T";default:shape_status_char=" ";endcase
  else case(pos)
   0:shape_status_char="U";1:shape_status_char="N";2:shape_status_char="C";3:shape_status_char="E";
   4:shape_status_char="R";5:shape_status_char="T";6:shape_status_char="A";7:shape_status_char="I";8:shape_status_char="N";default:shape_status_char=" ";endcase
 end
endfunction
wire [36:0] model_features_s={edge_sum_s,edge_count_s[12:0]};
wire local_review=LOCAL_SEARCH && sample_s && class_s==2 && model_features_s[35];
function [5:0] result_glyph;
 input [1:0] code;input [2:0] position;
 begin
  result_glyph=0;
  case(code)
   0: case(position)
    0: result_glyph=6'd13;
    1: result_glyph=6'd14;
    2: result_glyph=6'd15;
    default: result_glyph=0;
   endcase
   1: case(position)
    0: result_glyph=6'd17;
    1: result_glyph=6'd34;
    2: result_glyph=6'd35;
    default: result_glyph=0;
   endcase
   2: case(position)
    0: result_glyph=6'd18;
    1: result_glyph=6'd19;
    default: result_glyph=0;
   endcase
   3: case(position)
    0: result_glyph=6'd20;
    1: result_glyph=6'd21;
    default: result_glyph=0;
   endcase
  endcase
 end
endfunction
function [5:0] reason_glyph;
 input [1:0] code;input [2:0] position;
 begin
  reason_glyph=0;
  case(code)
   0: case(position)
    0: reason_glyph=6'd22;
    1: reason_glyph=6'd23;
    2: reason_glyph=6'd24;
    default: reason_glyph=0;
   endcase
   1: case(position)
    0: reason_glyph=6'd25;
    1: reason_glyph=6'd26;
    2: reason_glyph=6'd27;
    default: reason_glyph=0;
   endcase
   2: case(position)
    0: reason_glyph=6'd16;
    1: reason_glyph=6'd17;
    2: reason_glyph=6'd18;
    3: reason_glyph=6'd28;
    4: reason_glyph=6'd29;
    default: reason_glyph=0;
   endcase
   3: case(position)
    0: reason_glyph=6'd11;
    1: reason_glyph=6'd12;
    2: reason_glyph=6'd18;
    3: reason_glyph=6'd28;
    default: reason_glyph=0;
   endcase
  endcase
 end
endfunction
function [6:0] mode_glyph;
 input [1:0] code;input [3:0] position;
 begin
 mode_glyph=7'd32;
 case(code)
 0: case(position)
 0: mode_glyph=7'd82;
 1: mode_glyph=7'd65;
 2: mode_glyph=7'd87;
 default: mode_glyph=7'd32;
 endcase
 1: case(position)
 0: mode_glyph=7'd71;
 1: mode_glyph=7'd82;
 2: mode_glyph=7'd65;
 3: mode_glyph=7'd89;
 default: mode_glyph=7'd32;
 endcase
 2: case(position)
 0: mode_glyph=7'd69;
 1: mode_glyph=7'd68;
 2: mode_glyph=7'd71;
 3: mode_glyph=7'd69;
 default: mode_glyph=7'd32;
 endcase
 3: case(position)
 0: mode_glyph=7'd71;
 1: mode_glyph=7'd82;
 2: mode_glyph=7'd65;
 3: mode_glyph=7'd89;
 4: mode_glyph=7'd43;
 5: mode_glyph=7'd69;
 6: mode_glyph=7'd68;
 7: mode_glyph=7'd71;
 8: mode_glyph=7'd69;
 default: mode_glyph=7'd32;
 endcase
 endcase
 end
endfunction
wire [23:0] result_color=local_review ? 24'hffcc55 : class_s==0 ? 24'hf7b955 : class_s==2 ? 24'h74dbc7 : class_s==3 ? 24'hffae64 : 24'hb0c0d4;
wire [10:0] label_x=LOCAL_SEARCH ? (local_box_s ? local_x0_s : 11'd416) : SAMPLE_X0;
wire [9:0] label_y=LOCAL_SEARCH ? (local_box_s ? local_y0_s : 10'd228) : SAMPLE_Y0;
wire direct_label=!FRAME_OBJECTS && DIRECT_DETECTION && x>=label_x && x<label_x+112 && y>=label_y-56 && y<label_y-4;
wire direct_gray_row=y<label_y-30;
wire [1:0] direct_state=direct_gray_row ? gray_state_s : edge_state_s;
reg pocket_border,pocket_label;reg [23:0] pocket_color;
reg [1:0] pocket_state;reg [10:0] pocket_label_x;reg [9:0] pocket_label_y;
integer pi;reg [10:0] px;reg [9:0] py;reg [1:0] ps;
always @* begin
 pocket_border=0;pocket_label=0;pocket_color=24'hffff00;pocket_state=1;pocket_label_x=0;pocket_label_y=0;px=0;py=0;ps=0;
 for(pi=0;pi<4;pi=pi+1) begin
  px=pockets_s[pi*85+74+:11];py=pockets_s[pi*85+64+:10];ps=pockets_s[pi*85+61+:2];
  if(MULTI_POCKETS && pockets_enabled_s && pockets_s[pi*85+63]) begin
   if((x>=px && x<px+80 && y>=py && y<py+80 && (x==px || x==px+79 || y==py || y==py+79)) ||
      (x>=px && x<px+72 && y>=py-26 && y<py-2)) begin
    pocket_color=ps==2 ? 24'h74dbc7 : ps==3 ? 24'hffae64 : 24'hffff00;
    if(y>=py) pocket_border=1;
    else begin pocket_label=1;pocket_state=ps;pocket_label_x=px;pocket_label_y=py-26;end
   end
  end
 end
end
// Freeze all records at the first active pixel of the selected DDR frame.
// Each zone keeps its display slots while targets match the previous frame.
// Only current records are reordered; missing targets are never held on screen.
reg frame_border,frame_label;reg [23:0] frame_color;
reg [1:0] frame_state;reg [3:0] frame_reason;reg [1:0] frame_number;
localparam CARD_WIDTH=REGIONS ? 104 : 88,CARD_PREFIX=REGIONS ? 24 : 16;
reg [10:0] frame_lx;reg [9:0] frame_ly;
integer fi;reg [75:0] object_value;reg [10:0] fx0,fx1,flx;reg [9:0] fy0,fy1,fly;
always @*begin
 frame_border=0;frame_label=0;frame_color=24'hb0c0d4;frame_state=1;frame_reason=0;frame_number=0;frame_lx=0;frame_ly=0;
 object_value=0;fx0=0;fx1=0;fy0=0;fy1=0;flx=0;fly=0;
 for(fi=0;fi<OBJECTS;fi=fi+1)begin
  object_value=frame_objects_s[fi*76+:76];
  fx0=object_value[41:31];fx1=object_value[30:20];fy0=object_value[19:10];fy1=object_value[9:0];
  flx=fx0>WIDTH-CARD_WIDTH ? WIDTH-CARD_WIDTH : fx0;
  // Stagger neighboring cards so adjacent pockets do not share one label.
  fly=fi%2==1 && fy1<HEIGHT-152 ? fy1+4 : fy0>=136 ? fy0-56 : fy1+4;
  if(fly>HEIGHT-152)fly=HEIGHT-152;
  if(FRAME_OBJECTS && sample_s && object_value[75])begin
   if(x>=fx0 && x<fx1 && y>=fy0 && y<fy1 && (x==fx0 || x==fx1-1 || y==fy0 || y==fy1-1))begin
    frame_border=1;
    frame_color=object_value[74:73]==2 ? (|object_value[72:69] ? 24'hffcc55 : 24'h74dbc7) : object_value[74:73]==3 ? 24'hffae64 : 24'hb0c0d4;
   end
   if(x>=flx && x<flx+CARD_WIDTH && y>=fly && y<fly+56)begin
    frame_label=1;frame_lx=flx;frame_ly=fly;frame_number=fi;frame_state=object_value[74:73];frame_reason=object_value[72:69];
    frame_color=frame_state==2 ? (|frame_reason ? 24'hffcc55 : 24'h74dbc7) : frame_state==3 ? 24'hffae64 : 24'hb0c0d4;
   end
  end
 end
end
wire [83:0] region_bounds;wire [31:0] region_models;wire [239:0] unused_recipes;wire [1:0] region_supported;
generate if(REGIONS)begin : regions
 inspection_region_config #(.WIDTH(WIDTH),.HEIGHT(HEIGHT)) cfg(region_bounds,region_models,unused_recipes,region_supported);
end else begin
 assign region_bounds=0;assign region_models=0;assign unused_recipes=0;assign region_supported=0;
end endgenerate
reg region_border,region_label;reg [23:0] region_color;
reg [127:0] region_text;reg [10:0] region_lx;reg [9:0] region_ly;
integer ri;reg [41:0] rb;reg [9:0] rly;reg region_has_objects;
always @*begin
 region_border=0;region_label=0;region_color=24'h00ffff;region_text=0;region_lx=0;region_ly=0;rb=0;rly=0;region_has_objects=0;
 for(ri=0;ri<2;ri=ri+1)begin
  rb=region_bounds[ri*42+:42];rly=rb[19:10]>=100 ? rb[19:10]-20 : 80;
  if(REGIONS && x>=rb[41:31] && x<rb[30:20] && y>=rb[19:10] && y<rb[9:0] &&
   (((x==rb[41:31] || x==rb[30:20]-1) && !y[2]) || ((y==rb[19:10] || y==rb[9:0]-1) && !x[2])))begin
   region_border=1;region_color=ri==0 ? 24'h00ffff : 24'hc6a0ff;
  end
  if(REGIONS && x>=rb[41:31] && x<rb[41:31]+128 && y>=rly && y<rly+16)begin
   region_label=1;region_lx=rb[41:31];region_ly=rly;region_color=ri==0 ? 24'h00ffff : 24'hc6a0ff;
   region_has_objects=frame_objects_s[ri*152+75] || frame_objects_s[ri*152+151];
   region_text={ri==0 ? "R1 " : "R2 ",region_supported[ri] ? "3528 " : "---- ",
    !region_supported[ri] ? "UNBOUND " : !sample_s ? "WAIT    " : region_has_objects ? "READY   " : "NO TGT  "};
  end
 end
end
reg [63:0] frame_text;
always @*begin
 if(frame_state==2 && |frame_reason)begin
  if(frame_reason==4'hf)frame_text=y<frame_ly+40 ? "FIT CHK " : "REVIEW  ";
  else if(y<frame_ly+40)frame_text={frame_reason[0] ? "SIZE" : "----",8'd32,frame_reason[1] ? "ASP" : "---"};
  else frame_text={frame_reason[2] ? "FILL" : "----",8'd32,frame_reason[3] ? "REF" : "---"};
 end else frame_text=y<frame_ly+40 ? (frame_state>=2 ? "MODEL OK" : "CHECK   ") : mode_s[1] ? "EDGE ON " : "EDGE OFF";
end
reg [6:0] glyph;reg glyph_cjk;reg [4:0] glyph_col,glyph_row;reg [23:0] ink_color;
always @* begin
 glyph=0;glyph_cjk=0;glyph_col=0;glyph_row=0;ink_color=24'hffffff;
 if(x>=128 && x<240 && y>=24 && y<56) begin
  glyph_cjk=0;ink_color=24'hffffff;
  glyph_row=(y-24)/2;
  if(x>=128 && x<144) begin glyph=7'd65;glyph_col=(x-128)/2;end
  if(x>=144 && x<160) begin glyph=7'd78;glyph_col=(x-144)/2;end
  if(x>=160 && x<176) begin glyph=7'd76;glyph_col=(x-160)/2;end
  if(x>=176 && x<192) begin glyph=7'd79;glyph_col=(x-176)/2;end
  if(x>=192 && x<208) begin glyph=7'd71;glyph_col=(x-192)/2;end
  if(x>=208 && x<224) begin glyph=7'd73;glyph_col=(x-208)/2;end
  if(x>=224 && x<240) begin glyph=7'd67;glyph_col=(x-224)/2;end
 end
 if(x>=528 && x<584 && y>=8 && y<24) begin
  glyph_cjk=0;ink_color=24'hffffff;
  glyph_row=(y-8)/1;
  if(x>=528 && x<536) begin glyph=7'd87;glyph_col=(x-528)/1;end
  if(x>=536 && x<544) begin glyph=7'd66;glyph_col=(x-536)/1;end
  if(x>=544 && x<552) begin glyph=7'd32;glyph_col=(x-544)/1;end
  if(x>=552 && x<560) begin glyph=wb_tune_s ? 7'd84 : 7'd76;glyph_col=(x-552)/1;end
  if(x>=560 && x<568) begin glyph=wb_tune_s ? 7'd85 : 7'd79;glyph_col=(x-560)/1;end
  if(x>=568 && x<576) begin glyph=wb_tune_s ? 7'd78 : 7'd67;glyph_col=(x-568)/1;end
  if(x>=576 && x<584) begin glyph=wb_tune_s ? 7'd69 : 7'd75;glyph_col=(x-576)/1;end
 end
 if(x>=528 && x<616 && y>=32 && y<48) begin
  glyph_cjk=0;ink_color=24'hffffff;
  glyph_row=(y-32)/1;
  if(x>=528 && x<536) begin glyph=7'd82;glyph_col=(x-528)/1;end
  if(x>=536 && x<544) begin glyph=7'd32;glyph_col=(x-536)/1;end
  if(x>=544 && x<552) begin glyph=7'd48+wb_r_bcd[8+:4];glyph_col=(x-544)/1;end
  if(x>=552 && x<560) begin glyph=7'd48+wb_r_bcd[4+:4];glyph_col=(x-552)/1;end
  if(x>=560 && x<568) begin glyph=7'd48+wb_r_bcd[0+:4];glyph_col=(x-560)/1;end
  if(x>=568 && x<576) begin glyph=7'd32;glyph_col=(x-568)/1;end
  if(x>=576 && x<584) begin glyph=7'd66;glyph_col=(x-576)/1;end
  if(x>=584 && x<592) begin glyph=7'd32;glyph_col=(x-584)/1;end
  if(x>=592 && x<600) begin glyph=7'd48+wb_b_bcd[8+:4];glyph_col=(x-592)/1;end
  if(x>=600 && x<608) begin glyph=7'd48+wb_b_bcd[4+:4];glyph_col=(x-600)/1;end
  if(x>=608 && x<616) begin glyph=7'd48+wb_b_bcd[0+:4];glyph_col=(x-608)/1;end
 end
 if(x>=528 && x<568 && y>=56 && y<72) begin
  glyph_cjk=0;ink_color=24'hffffff;
  glyph_row=(y-56)/1;
  if(x>=528 && x<536) begin glyph=7'd47;glyph_col=(x-528)/1;end
  if(x>=536 && x<544) begin glyph=7'd54;glyph_col=(x-536)/1;end
  if(x>=544 && x<552) begin glyph=7'd52;glyph_col=(x-544)/1;end
  if(x>=552 && x<560) begin glyph=7'd32;glyph_col=(x-552)/1;end
  if(x>=560 && x<568) begin glyph=wb_pending_s ? 7'd42 : 7'd32;glyph_col=(x-560)/1;end
 end
 if(x>=360 && x<408 && y>=8 && y<32) begin
  glyph_cjk=1;ink_color=24'hffffff;
  glyph_row=(y-8)/1;
  if(x>=360 && x<384) begin glyph=6'd1;glyph_col=(x-360)/1;end
  if(x>=384 && x<408) begin glyph=6'd2;glyph_col=(x-384)/1;end
 end
 if(x>=424 && x<472 && y>=8 && y<40) begin
  glyph_cjk=0;ink_color=24'hffffff;
  glyph_row=(y-8)/2;
  if(x>=424 && x<440) begin glyph=7'd69;glyph_col=(x-424)/2;end
  if(x>=440 && x<456) begin glyph=7'd88;glyph_col=(x-440)/2;end
  if(x>=456 && x<472) begin glyph=7'd80;glyph_col=(x-456)/2;end
 end
 if(x>=360 && x<440 && y>=40 && y<72) begin
  glyph_cjk=0;ink_color=24'hffffff;
  glyph_row=(y-40)/2;
  if(x>=360 && x<376) begin glyph=decimal(exp_bcd,0);glyph_col=(x-360)/2;end
  if(x>=376 && x<392) begin glyph=decimal(exp_bcd,1);glyph_col=(x-376)/2;end
  if(x>=392 && x<408) begin glyph=decimal(exp_bcd,2);glyph_col=(x-392)/2;end
  if(x>=408 && x<424) begin glyph=decimal(exp_bcd,3);glyph_col=(x-408)/2;end
  if(x>=424 && x<440) begin glyph=decimal(exp_bcd,4);glyph_col=(x-424)/2;end
 end
 if(x>=456 && x<504 && y>=44 && y<68) begin
  glyph_cjk=1;ink_color=24'hffffff;
  glyph_row=(y-44)/1;
  if(x>=456 && x<480) begin glyph=6'd5;glyph_col=(x-456)/1;end
  if(x>=480 && x<504) begin glyph=6'd6;glyph_col=(x-480)/1;end
 end
 if(x>=688 && x<736 && y>=8 && y<32) begin
  glyph_cjk=1;ink_color=24'hffffff;
  glyph_row=(y-8)/1;
  if(x>=688 && x<712) begin glyph=6'd3;glyph_col=(x-688)/1;end
  if(x>=712 && x<736) begin glyph=6'd4;glyph_col=(x-712)/1;end
 end
 if(x>=752 && x<816 && y>=8 && y<40) begin
  glyph_cjk=0;ink_color=24'hffffff;
  glyph_row=(y-8)/2;
  if(x>=752 && x<768) begin glyph=7'd71;glyph_col=(x-752)/2;end
  if(x>=768 && x<784) begin glyph=7'd65;glyph_col=(x-768)/2;end
  if(x>=784 && x<800) begin glyph=7'd73;glyph_col=(x-784)/2;end
  if(x>=800 && x<816) begin glyph=7'd78;glyph_col=(x-800)/2;end
 end
 if(x>=688 && x<768 && y>=40 && y<72) begin
  glyph_cjk=0;ink_color=24'hffffff;
  glyph_row=(y-40)/2;
  if(x>=688 && x<704) begin glyph=decimal(gain_bcd,0);glyph_col=(x-688)/2;end
  if(x>=704 && x<720) begin glyph=decimal(gain_bcd,1);glyph_col=(x-704)/2;end
  if(x>=720 && x<736) begin glyph=decimal(gain_bcd,2);glyph_col=(x-720)/2;end
  if(x>=736 && x<752) begin glyph=decimal(gain_bcd,3);glyph_col=(x-736)/2;end
  if(x>=752 && x<768) begin glyph=decimal(gain_bcd,4);glyph_col=(x-752)/2;end
 end
 if(x>=784 && x<832 && y>=44 && y<68) begin
  glyph_cjk=1;ink_color=24'hffffff;
  glyph_row=(y-44)/1;
  if(x>=784 && x<808) begin glyph=6'd7;glyph_col=(x-784)/1;end
  if(x>=808 && x<832) begin glyph=6'd8;glyph_col=(x-808)/1;end
 end
 if(x>=864 && x<928 && y>=8 && y<40) begin
  glyph_cjk=0;ink_color=24'hb0c0d4;
  glyph_row=(y-8)/2;
  if(x>=864 && x<880) begin glyph=7'd77;glyph_col=(x-864)/2;end
  if(x>=880 && x<896) begin glyph=7'd79;glyph_col=(x-880)/2;end
  if(x>=896 && x<912) begin glyph=7'd68;glyph_col=(x-896)/2;end
  if(x>=912 && x<928) begin glyph=7'd69;glyph_col=(x-912)/2;end
 end
 if(x>=864 && x<1008 && y>=40 && y<72) begin
  glyph_cjk=0;ink_color=24'hffffff;
  glyph_row=(y-40)/2;
  if(x>=864 && x<880) begin glyph=mode_glyph(mode_s,0);glyph_col=(x-864)/2;end
  if(x>=880 && x<896) begin glyph=mode_glyph(mode_s,1);glyph_col=(x-880)/2;end
  if(x>=896 && x<912) begin glyph=mode_glyph(mode_s,2);glyph_col=(x-896)/2;end
  if(x>=912 && x<928) begin glyph=mode_glyph(mode_s,3);glyph_col=(x-912)/2;end
  if(x>=928 && x<944) begin glyph=mode_glyph(mode_s,4);glyph_col=(x-928)/2;end
  if(x>=944 && x<960) begin glyph=mode_glyph(mode_s,5);glyph_col=(x-944)/2;end
  if(x>=960 && x<976) begin glyph=mode_glyph(mode_s,6);glyph_col=(x-960)/2;end
  if(x>=976 && x<992) begin glyph=mode_glyph(mode_s,7);glyph_col=(x-976)/2;end
  if(x>=992 && x<1008) begin glyph=mode_glyph(mode_s,8);glyph_col=(x-992)/2;end
 end
 if(!REGIONS && x>=16 && x<112 && y_ui>=510 && y_ui<534) begin
  glyph_cjk=1;ink_color=24'hb0c0d4;
  glyph_row=(y_ui-510)/1;
  if(x>=16 && x<40) begin glyph=6'd9;glyph_col=(x-16)/1;end
  if(x>=40 && x<64) begin glyph=6'd10;glyph_col=(x-40)/1;end
  if(x>=64 && x<88) begin glyph=6'd11;glyph_col=(x-64)/1;end
  if(x>=88 && x<112) begin glyph=6'd12;glyph_col=(x-88)/1;end
 end
 if(!REGIONS && x>=16 && x<208 && y_ui>=540 && y_ui<588) begin
  glyph_cjk=1;ink_color=result_color;
  glyph_row=(y_ui-540)/2;
  if(x>=16 && x<64) begin glyph=result_glyph(class_s,0);glyph_col=(x-16)/2;end
  if(x>=64 && x<112) begin glyph=result_glyph(class_s,1);glyph_col=(x-64)/2;end
  if(x>=112 && x<160) begin glyph=result_glyph(class_s,2);glyph_col=(x-112)/2;end
  if(x>=160 && x<208) begin glyph=result_glyph(class_s,3);glyph_col=(x-160)/2;end
 end
 if(!FRAME_OBJECTS && x>=304 && x<368 && y_ui>=510 && y_ui<542) begin
  glyph_cjk=0;ink_color=24'hb0c0d4;
  glyph_row=(y_ui-510)/2;
  if(x>=304 && x<320) begin glyph=7'd77;glyph_col=(x-304)/2;end
  if(x>=320 && x<336) begin glyph=7'd69;glyph_col=(x-320)/2;end
  if(x>=336 && x<352) begin glyph=7'd65;glyph_col=(x-336)/2;end
  if(x>=352 && x<368) begin glyph=7'd78;glyph_col=(x-352)/2;end
 end
 if(!FRAME_OBJECTS && x>=384 && x<432 && y_ui>=510 && y_ui<542) begin
  glyph_cjk=0;ink_color=24'hffffff;
  glyph_row=(y_ui-510)/2;
  if(x>=384 && x<400) begin glyph=sample_s ? decimal(mean_bcd,2) : 7'd45;glyph_col=(x-384)/2;end
  if(x>=400 && x<416) begin glyph=sample_s ? decimal(mean_bcd,3) : 7'd45;glyph_col=(x-400)/2;end
  if(x>=416 && x<432) begin glyph=sample_s ? decimal(mean_bcd,4) : 7'd45;glyph_col=(x-416)/2;end
 end
 if(!FRAME_OBJECTS && x>=464 && x<512 && y_ui>=510 && y_ui<542) begin
  glyph_cjk=0;ink_color=24'hb0c0d4;
  glyph_row=(y_ui-510)/2;
  if(x>=464 && x<480) begin glyph=7'd77;glyph_col=(x-464)/2;end
  if(x>=480 && x<496) begin glyph=7'd73;glyph_col=(x-480)/2;end
  if(x>=496 && x<512) begin glyph=7'd78;glyph_col=(x-496)/2;end
 end
 if(!FRAME_OBJECTS && x>=528 && x<576 && y_ui>=510 && y_ui<542) begin
  glyph_cjk=0;ink_color=24'hffffff;
  glyph_row=(y_ui-510)/2;
  if(x>=528 && x<544) begin glyph=sample_s ? decimal(min_bcd,2) : 7'd45;glyph_col=(x-528)/2;end
  if(x>=544 && x<560) begin glyph=sample_s ? decimal(min_bcd,3) : 7'd45;glyph_col=(x-544)/2;end
  if(x>=560 && x<576) begin glyph=sample_s ? decimal(min_bcd,4) : 7'd45;glyph_col=(x-560)/2;end
 end
 if(!FRAME_OBJECTS && x>=624 && x<672 && y_ui>=510 && y_ui<542) begin
  glyph_cjk=0;ink_color=24'hb0c0d4;
  glyph_row=(y_ui-510)/2;
  if(x>=624 && x<640) begin glyph=7'd77;glyph_col=(x-624)/2;end
  if(x>=640 && x<656) begin glyph=7'd65;glyph_col=(x-640)/2;end
  if(x>=656 && x<672) begin glyph=7'd88;glyph_col=(x-656)/2;end
 end
 if(!FRAME_OBJECTS && x>=688 && x<736 && y_ui>=510 && y_ui<542) begin
  glyph_cjk=0;ink_color=24'hffffff;
  glyph_row=(y_ui-510)/2;
  if(x>=688 && x<704) begin glyph=sample_s ? decimal(max_bcd,2) : 7'd45;glyph_col=(x-688)/2;end
  if(x>=704 && x<720) begin glyph=sample_s ? decimal(max_bcd,3) : 7'd45;glyph_col=(x-704)/2;end
  if(x>=720 && x<736) begin glyph=sample_s ? decimal(max_bcd,4) : 7'd45;glyph_col=(x-720)/2;end
 end
 if(!FRAME_OBJECTS && x>=768 && x<864 && y_ui>=514 && y_ui<538) begin
  glyph_cjk=1;ink_color=24'h74dbc7;
  glyph_row=(y_ui-514)/1;
  if(x>=768 && x<792) begin glyph=sample_s ? 6'd11 : 6'd0;glyph_col=(x-768)/1;end
  if(x>=792 && x<816) begin glyph=sample_s ? 6'd12 : 6'd0;glyph_col=(x-792)/1;end
  if(x>=816 && x<840) begin glyph=sample_s ? 6'd18 : 6'd0;glyph_col=(x-816)/1;end
  if(x>=840 && x<864) begin glyph=sample_s ? 6'd28 : 6'd0;glyph_col=(x-840)/1;end
 end
 if(x>=304 && x<800 && y_ui>=548 && y_ui<564) begin
  glyph_cjk=0;ink_color=24'hffffff;
  glyph_row=(y_ui-548)/1;
  if(x>=304 && x<312) begin glyph=7'd73;glyph_col=(x-304)/1;end
  if(x>=312 && x<320) begin glyph=7'd78;glyph_col=(x-312)/1;end
  if(x>=320 && x<328) begin glyph=7'd32;glyph_col=(x-320)/1;end
  if(x>=328 && x<336) begin glyph=decimal(w_bcd,0);glyph_col=(x-328)/1;end
  if(x>=336 && x<344) begin glyph=decimal(w_bcd,1);glyph_col=(x-336)/1;end
  if(x>=344 && x<352) begin glyph=decimal(w_bcd,2);glyph_col=(x-344)/1;end
  if(x>=352 && x<360) begin glyph=decimal(w_bcd,3);glyph_col=(x-352)/1;end
  if(x>=360 && x<368) begin glyph=decimal(w_bcd,4);glyph_col=(x-360)/1;end
  if(x>=368 && x<376) begin glyph=7'd88;glyph_col=(x-368)/1;end
  if(x>=376 && x<384) begin glyph=decimal(h_bcd,0);glyph_col=(x-376)/1;end
  if(x>=384 && x<392) begin glyph=decimal(h_bcd,1);glyph_col=(x-384)/1;end
  if(x>=392 && x<400) begin glyph=decimal(h_bcd,2);glyph_col=(x-392)/1;end
  if(x>=400 && x<408) begin glyph=decimal(h_bcd,3);glyph_col=(x-400)/1;end
  if(x>=408 && x<416) begin glyph=decimal(h_bcd,4);glyph_col=(x-408)/1;end
  if(x>=416 && x<424) begin glyph=7'd32;glyph_col=(x-416)/1;end
  if(x>=424 && x<432) begin glyph=7'd70;glyph_col=(x-424)/1;end
  if(x>=432 && x<440) begin glyph=7'd80;glyph_col=(x-432)/1;end
  if(x>=440 && x<448) begin glyph=7'd83;glyph_col=(x-440)/1;end
  if(x>=448 && x<456) begin glyph=7'd32;glyph_col=(x-448)/1;end
  if(x>=456 && x<464) begin glyph=decimal(fps_bcd,0);glyph_col=(x-456)/1;end
  if(x>=464 && x<472) begin glyph=decimal(fps_bcd,1);glyph_col=(x-464)/1;end
  if(x>=472 && x<480) begin glyph=decimal(fps_bcd,2);glyph_col=(x-472)/1;end
  if(x>=480 && x<488) begin glyph=decimal(fps_bcd,3);glyph_col=(x-480)/1;end
  if(x>=488 && x<496) begin glyph=decimal(fps_bcd,4);glyph_col=(x-488)/1;end
  if(x>=496 && x<504) begin glyph=7'd32;glyph_col=(x-496)/1;end
  if(x>=504 && x<512) begin glyph=7'd67;glyph_col=(x-504)/1;end
  if(x>=512 && x<520) begin glyph=7'd70;glyph_col=(x-512)/1;end
  if(x>=520 && x<528) begin glyph=7'd71;glyph_col=(x-520)/1;end
  if(x>=528 && x<536) begin glyph=7'd32;glyph_col=(x-528)/1;end
  if(x>=536 && x<544) begin glyph=cfg_s ? 7'd49 : 7'd48;glyph_col=(x-536)/1;end
  if(x>=544 && x<552) begin glyph=7'd32;glyph_col=(x-544)/1;end
  if(x>=552 && x<560) begin glyph=7'd76;glyph_col=(x-552)/1;end
  if(x>=560 && x<568) begin glyph=7'd32;glyph_col=(x-560)/1;end
  if(x>=568 && x<576) begin glyph=hexchar(lane_s[12+:4]);glyph_col=(x-568)/1;end
  if(x>=576 && x<584) begin glyph=hexchar(lane_s[8+:4]);glyph_col=(x-576)/1;end
  if(x>=584 && x<592) begin glyph=hexchar(lane_s[4+:4]);glyph_col=(x-584)/1;end
  if(x>=592 && x<600) begin glyph=hexchar(lane_s[0+:4]);glyph_col=(x-592)/1;end
  if(x>=600 && x<608) begin glyph=7'd32;glyph_col=(x-600)/1;end
  if(x>=608 && x<616) begin glyph=7'd70;glyph_col=(x-608)/1;end
  if(x>=616 && x<624) begin glyph=7'd32;glyph_col=(x-616)/1;end
  if(x>=624 && x<632) begin glyph=hexchar(format_s[12+:4]);glyph_col=(x-624)/1;end
  if(x>=632 && x<640) begin glyph=hexchar(format_s[8+:4]);glyph_col=(x-632)/1;end
  if(x>=640 && x<648) begin glyph=hexchar(format_s[4+:4]);glyph_col=(x-640)/1;end
  if(x>=648 && x<656) begin glyph=hexchar(format_s[0+:4]);glyph_col=(x-648)/1;end
  if(x>=656 && x<664) begin glyph=7'd32;glyph_col=(x-656)/1;end
  if(x>=664 && x<672) begin glyph=7'd73;glyph_col=(x-664)/1;end
  if(x>=672 && x<680) begin glyph=7'd32;glyph_col=(x-672)/1;end
  if(x>=680 && x<688) begin glyph=hexchar(i2c_s[12+:4]);glyph_col=(x-680)/1;end
  if(x>=688 && x<696) begin glyph=hexchar(i2c_s[8+:4]);glyph_col=(x-688)/1;end
  if(x>=696 && x<704) begin glyph=hexchar(i2c_s[4+:4]);glyph_col=(x-696)/1;end
  if(x>=704 && x<712) begin glyph=hexchar(i2c_s[0+:4]);glyph_col=(x-704)/1;end
  if(x>=712 && x<720) begin glyph=7'd32;glyph_col=(x-712)/1;end
  if(x>=720 && x<728) begin glyph=7'd71;glyph_col=(x-720)/1;end
  if(x>=728 && x<736) begin glyph=7'd32;glyph_col=(x-728)/1;end
  if(x>=736 && x<744) begin glyph=hexchar(gap_s[12+:4]);glyph_col=(x-736)/1;end
  if(x>=744 && x<752) begin glyph=hexchar(gap_s[8+:4]);glyph_col=(x-744)/1;end
  if(x>=752 && x<760) begin glyph=hexchar(gap_s[4+:4]);glyph_col=(x-752)/1;end
  if(x>=760 && x<768) begin glyph=hexchar(gap_s[0+:4]);glyph_col=(x-760)/1;end
  if(x>=768 && x<776) begin glyph=7'd32;glyph_col=(x-768)/1;end
  if(x>=776 && x<784) begin glyph=7'd72;glyph_col=(x-776)/1;end
  if(x>=784 && x<792) begin glyph=7'd69;glyph_col=(x-784)/1;end
  if(x>=792 && x<800) begin glyph=7'd88;glyph_col=(x-792)/1;end
 end
 if(x>=808 && x<984 && y_ui>=548 && y_ui<564) begin
  glyph_cjk=0;ink_color=24'hffae64;
  glyph_row=(y_ui-548)/1;
  if(x>=808 && x<816) begin glyph=7'd69;glyph_col=(x-808)/1;end
  if(x>=816 && x<824) begin glyph=7'd67;glyph_col=(x-816)/1;end
  if(x>=824 && x<832) begin glyph=7'd32;glyph_col=(x-824)/1;end
  if(x>=832 && x<840) begin glyph=edge_sample_s ? hexchar(edge_count_s[12+:4]) : 7'd45;glyph_col=(x-832)/1;end
  if(x>=840 && x<848) begin glyph=edge_sample_s ? hexchar(edge_count_s[8+:4]) : 7'd45;glyph_col=(x-840)/1;end
  if(x>=848 && x<856) begin glyph=edge_sample_s ? hexchar(edge_count_s[4+:4]) : 7'd45;glyph_col=(x-848)/1;end
  if(x>=856 && x<864) begin glyph=edge_sample_s ? hexchar(edge_count_s[0+:4]) : 7'd45;glyph_col=(x-856)/1;end
  if(x>=864 && x<872) begin glyph=7'd32;glyph_col=(x-864)/1;end
  if(x>=872 && x<880) begin glyph=7'd71;glyph_col=(x-872)/1;end
  if(x>=880 && x<888) begin glyph=7'd83;glyph_col=(x-880)/1;end
  if(x>=888 && x<896) begin glyph=7'd32;glyph_col=(x-888)/1;end
  if(x>=896 && x<904) begin glyph=edge_sample_s ? hexchar(edge_sum_s[20+:4]) : 7'd45;glyph_col=(x-896)/1;end
  if(x>=904 && x<912) begin glyph=edge_sample_s ? hexchar(edge_sum_s[16+:4]) : 7'd45;glyph_col=(x-904)/1;end
  if(x>=912 && x<920) begin glyph=edge_sample_s ? hexchar(edge_sum_s[12+:4]) : 7'd45;glyph_col=(x-912)/1;end
  if(x>=920 && x<928) begin glyph=edge_sample_s ? hexchar(edge_sum_s[8+:4]) : 7'd45;glyph_col=(x-920)/1;end
  if(x>=928 && x<936) begin glyph=edge_sample_s ? hexchar(edge_sum_s[4+:4]) : 7'd45;glyph_col=(x-928)/1;end
  if(x>=936 && x<944) begin glyph=edge_sample_s ? hexchar(edge_sum_s[0+:4]) : 7'd45;glyph_col=(x-936)/1;end
  if(x>=944 && x<952) begin glyph=7'd32;glyph_col=(x-944)/1;end
  if(x>=952 && x<960) begin glyph=7'd84;glyph_col=(x-952)/1;end
  if(x>=960 && x<968) begin glyph=7'd32;glyph_col=(x-960)/1;end
  if(x>=968 && x<976) begin glyph=7'd56;glyph_col=(x-968)/1;end
  if(x>=976 && x<984) begin glyph=7'd48;glyph_col=(x-976)/1;end
 end
 if(x>=304 && x<528 && y_ui>=576 && y_ui<592) begin
  glyph_cjk=0;ink_color=24'hffffff;
  glyph_row=(y_ui-576)/1;
  if(x>=304 && x<312) begin glyph=7'd70;glyph_col=(x-304)/1;end
  if(x>=312 && x<320) begin glyph=7'd82;glyph_col=(x-312)/1;end
  if(x>=320 && x<328) begin glyph=7'd32;glyph_col=(x-320)/1;end
  if(x>=328 && x<336) begin glyph=hexchar(frames_s[28+:4]);glyph_col=(x-328)/1;end
  if(x>=336 && x<344) begin glyph=hexchar(frames_s[24+:4]);glyph_col=(x-336)/1;end
  if(x>=344 && x<352) begin glyph=hexchar(frames_s[20+:4]);glyph_col=(x-344)/1;end
  if(x>=352 && x<360) begin glyph=hexchar(frames_s[16+:4]);glyph_col=(x-352)/1;end
  if(x>=360 && x<368) begin glyph=hexchar(frames_s[12+:4]);glyph_col=(x-360)/1;end
  if(x>=368 && x<376) begin glyph=hexchar(frames_s[8+:4]);glyph_col=(x-368)/1;end
  if(x>=376 && x<384) begin glyph=hexchar(frames_s[4+:4]);glyph_col=(x-376)/1;end
  if(x>=384 && x<392) begin glyph=hexchar(frames_s[0+:4]);glyph_col=(x-384)/1;end
  if(x>=392 && x<400) begin glyph=7'd32;glyph_col=(x-392)/1;end
  if(x>=400 && x<408) begin glyph=7'd83;glyph_col=(x-400)/1;end
  if(x>=408 && x<416) begin glyph=7'd69;glyph_col=(x-408)/1;end
  if(x>=416 && x<424) begin glyph=7'd67;glyph_col=(x-416)/1;end
  if(x>=424 && x<432) begin glyph=7'd32;glyph_col=(x-424)/1;end
  if(x>=432 && x<440) begin glyph=hexchar(uptime_s[28+:4]);glyph_col=(x-432)/1;end
  if(x>=440 && x<448) begin glyph=hexchar(uptime_s[24+:4]);glyph_col=(x-440)/1;end
  if(x>=448 && x<456) begin glyph=hexchar(uptime_s[20+:4]);glyph_col=(x-448)/1;end
  if(x>=456 && x<464) begin glyph=hexchar(uptime_s[16+:4]);glyph_col=(x-456)/1;end
  if(x>=464 && x<472) begin glyph=hexchar(uptime_s[12+:4]);glyph_col=(x-464)/1;end
  if(x>=472 && x<480) begin glyph=hexchar(uptime_s[8+:4]);glyph_col=(x-472)/1;end
  if(x>=480 && x<488) begin glyph=hexchar(uptime_s[4+:4]);glyph_col=(x-480)/1;end
  if(x>=488 && x<496) begin glyph=hexchar(uptime_s[0+:4]);glyph_col=(x-488)/1;end
  if(x>=496 && x<504) begin glyph=7'd32;glyph_col=(x-496)/1;end
  if(x>=504 && x<512) begin glyph=7'd72;glyph_col=(x-504)/1;end
  if(x>=512 && x<520) begin glyph=7'd69;glyph_col=(x-512)/1;end
  if(x>=520 && x<528) begin glyph=7'd88;glyph_col=(x-520)/1;end
 end
 if(!FRAME_OBJECTS && x>=624 && x<744 && y_ui>=572 && y_ui<596) begin
  glyph_cjk=1;ink_color=reason_s==1 ? 24'hef7186 : 24'hb0c0d4;
  glyph_row=(y_ui-572)/1;
  if(x>=624 && x<648) begin glyph=reason_glyph(reason_s,0);glyph_col=(x-624)/1;end
  if(x>=648 && x<672) begin glyph=reason_glyph(reason_s,1);glyph_col=(x-648)/1;end
  if(x>=672 && x<696) begin glyph=reason_glyph(reason_s,2);glyph_col=(x-672)/1;end
  if(x>=696 && x<720) begin glyph=reason_glyph(reason_s,3);glyph_col=(x-696)/1;end
  if(x>=720 && x<744) begin glyph=reason_glyph(reason_s,4);glyph_col=(x-720)/1;end
 end
 if(x>=920 && x<1016 && y_ui>=572 && y_ui<596) begin
  glyph_cjk=1;ink_color=24'hf7b955;
  glyph_row=(y_ui-572)/1;
  if(x>=920 && x<944) begin glyph=error_s ? 6'd30 : 6'd0;glyph_col=(x-920)/1;end
  if(x>=944 && x<968) begin glyph=error_s ? 6'd31 : 6'd0;glyph_col=(x-944)/1;end
  if(x>=968 && x<992) begin glyph=error_s ? 6'd32 : 6'd0;glyph_col=(x-968)/1;end
  if(x>=992 && x<1016) begin glyph=error_s ? 6'd33 : 6'd0;glyph_col=(x-992)/1;end
 end
 if(x>=536 && x<592 && y_ui>=576 && y_ui<592) begin
  glyph_cjk=0;ink_color=24'hffae64;
  glyph_row=(y_ui-576)/1;
  if(x>=536 && x<544) begin glyph=7'd79;glyph_col=(x-536)/1;end
  if(x>=544 && x<552) begin glyph=7'd70;glyph_col=(x-544)/1;end
  if(x>=552 && x<560) begin glyph=7'd32;glyph_col=(x-552)/1;end
  if(x>=560 && x<568) begin glyph=hexchar(overflow_s[12+:4]);glyph_col=(x-560)/1;end
  if(x>=568 && x<576) begin glyph=hexchar(overflow_s[8+:4]);glyph_col=(x-568)/1;end
  if(x>=576 && x<584) begin glyph=hexchar(overflow_s[4+:4]);glyph_col=(x-576)/1;end
  if(x>=584 && x<592) begin glyph=hexchar(overflow_s[0+:4]);glyph_col=(x-584)/1;end
 end
 if(x>=752 && x<808 && y_ui>=576 && y_ui<592) begin
  glyph_cjk=0;ink_color=24'hffae64;
  glyph_row=(y_ui-576)/1;
  if(x>=752 && x<760) begin glyph=7'd86;glyph_col=(x-752)/1;end
  if(x>=760 && x<768) begin glyph=7'd70;glyph_col=(x-760)/1;end
  if(x>=768 && x<776) begin glyph=7'd32;glyph_col=(x-768)/1;end
  if(x>=776 && x<784) begin glyph=hexchar(lost_s[12+:4]);glyph_col=(x-776)/1;end
  if(x>=784 && x<792) begin glyph=hexchar(lost_s[8+:4]);glyph_col=(x-784)/1;end
  if(x>=792 && x<800) begin glyph=hexchar(lost_s[4+:4]);glyph_col=(x-792)/1;end
  if(x>=800 && x<808) begin glyph=hexchar(lost_s[0+:4]);glyph_col=(x-800)/1;end
 end
 if(x>=832 && x<888 && y_ui>=576 && y_ui<592) begin
  glyph_cjk=0;ink_color=24'hffae64;
  glyph_row=(y_ui-576)/1;
  if(x>=832 && x<840) begin glyph=7'd85;glyph_col=(x-832)/1;end
  if(x>=840 && x<848) begin glyph=7'd70;glyph_col=(x-840)/1;end
  if(x>=848 && x<856) begin glyph=7'd32;glyph_col=(x-848)/1;end
  if(x>=856 && x<864) begin glyph=hexchar(underflow_s[12+:4]);glyph_col=(x-856)/1;end
  if(x>=864 && x<872) begin glyph=hexchar(underflow_s[8+:4]);glyph_col=(x-864)/1;end
  if(x>=872 && x<880) begin glyph=hexchar(underflow_s[4+:4]);glyph_col=(x-872)/1;end
  if(x>=880 && x<888) begin glyph=hexchar(underflow_s[0+:4]);glyph_col=(x-880)/1;end
 end
 if(x>=128 && x<288 && y>=56 && y<72) begin
  glyph_cjk=0;ink_color=24'hffae64;
  glyph_row=(y-56)/1;
  if(x>=128 && x<136) begin glyph=7'd69;glyph_col=(x-128)/1;end
  if(x>=136 && x<144) begin glyph=7'd82;glyph_col=(x-136)/1;end
  if(x>=144 && x<152) begin glyph=7'd32;glyph_col=(x-144)/1;end
  if(x>=152 && x<160) begin glyph=hexchar(diagnostics_s[35:32]);glyph_col=(x-152)/1;end
  if(x>=160 && x<168) begin glyph=7'd32;glyph_col=(x-160)/1;end
  if(x>=168 && x<176) begin glyph=7'd76;glyph_col=(x-168)/1;end
  if(x>=176 && x<184) begin glyph=7'd80;glyph_col=(x-176)/1;end
  if(x>=184 && x<192) begin glyph=7'd32;glyph_col=(x-184)/1;end
  if(x>=192 && x<200) begin glyph=hexchar(diagnostics_s[28+:4]);glyph_col=(x-192)/1;end
  if(x>=200 && x<208) begin glyph=hexchar(diagnostics_s[24+:4]);glyph_col=(x-200)/1;end
  if(x>=208 && x<216) begin glyph=hexchar(diagnostics_s[20+:4]);glyph_col=(x-208)/1;end
  if(x>=216 && x<224) begin glyph=hexchar(diagnostics_s[16+:4]);glyph_col=(x-216)/1;end
  if(x>=224 && x<232) begin glyph=7'd32;glyph_col=(x-224)/1;end
  if(x>=232 && x<240) begin glyph=7'd87;glyph_col=(x-232)/1;end
  if(x>=240 && x<248) begin glyph=7'd83;glyph_col=(x-240)/1;end
  if(x>=248 && x<256) begin glyph=7'd32;glyph_col=(x-248)/1;end
  if(x>=256 && x<264) begin glyph=hexchar(diagnostics_s[12+:4]);glyph_col=(x-256)/1;end
  if(x>=264 && x<272) begin glyph=hexchar(diagnostics_s[8+:4]);glyph_col=(x-264)/1;end
  if(x>=272 && x<280) begin glyph=hexchar(diagnostics_s[4+:4]);glyph_col=(x-272)/1;end
  if(x>=280 && x<288) begin glyph=hexchar(diagnostics_s[0+:4]);glyph_col=(x-280)/1;end
 end
 if(TRACKING && y>=148 && y<164 && x>=256 && x<336) begin
  glyph_cjk=0;glyph_row=y-148;glyph_col=(x-256)%8;
  case((x-256)/8)
   0:glyph="T";1:glyph="R";2:glyph="A";3:glyph="C";4:glyph="K";5:glyph=" ";
   6:glyph=track_valid_s ? "L" : "W";7:glyph=track_valid_s ? "O" : "A";
   8:glyph=track_valid_s ? "C" : "I";9:glyph=track_valid_s ? "K" : "T";
  endcase
 end
 if(TRACKING && y>=148 && y<164 && x>=352 && x<480) begin
  glyph_cjk=0;glyph_row=y-148;glyph_col=(x-352)%8;
  glyph=track_message[127-((x-352)/8)*8-:8];
 end
 if(TRACKING && y>=148 && y<164 && x>=496 && x<544) begin
  glyph_cjk=0;glyph_row=y-148;glyph_col=(x-496)%8;
  case((x-496)/8)
   0:glyph="R";1:glyph="O";2:glyph="W";3:glyph=" ";4:glyph=hexchar({1'b0,track_rows_s});5:glyph=" ";
  endcase
 end
 if((TRACKING || DIRECT_DETECTION) && y>=8 && y<24 && x>=128 && x<232) begin
  glyph_cjk=0;glyph_row=y-8;glyph_col=(x-128)%8;
  case((x-128)/8)
   0:glyph="D";1:glyph=FRAME_OBJECTS ? (REGIONS ? "D" : RESOLUTION_V11 ? "C" : "B") : LOCAL_SEARCH ? "8" : SHAPE_MODEL ? "6" : DIRECT_DETECTION ? "5" : MULTI_POCKETS ? "4" : "3";2:glyph=" ";3:glyph="P";
   4:glyph=hexchar(publish_flags[7:4]);5:glyph=hexchar(publish_flags[3:0]);
   6:glyph=" ";7:glyph=publish_s[DIAG_BITS-1] ? "M" : "W";8:glyph=hexchar(publish_count[19:16]);
   9:glyph=hexchar(publish_count[15:12]);10:glyph=hexchar(publish_count[11:8]);
   11:glyph=hexchar(publish_count[7:4]);12:glyph=hexchar(publish_count[3:0]);
  endcase
 end
 if(MULTI_POCKETS && y>=8 && y<24 && x>=240 && x<344) begin
  glyph_cjk=0;glyph_row=y-8;glyph_col=(x-240)%8;
  case((x-240)/8)
   0:glyph="A";1:glyph="U";2:glyph="T";3:glyph="O";4:glyph="4";5:glyph=" ";
   6:glyph="E";7:glyph="X";8:glyph="P";9:glyph=" ";10:glyph="V";11:glyph="3";default:glyph=" ";
  endcase
 end
 if(DIRECT_DETECTION && y>=8 && y<24 && x>=240 && x<344) begin
  glyph_cjk=0;glyph_row=y-8;glyph_col=(x-240)%8;
  case((x-240)/8)
   0:glyph=FRAME_OBJECTS ? "F" : LOCAL_SEARCH ? "L" : SHAPE_MODEL ? "S" : "F";1:glyph=FRAME_OBJECTS ? "R" : LOCAL_SEARCH ? "O" : SHAPE_MODEL ? "H" : "I";
   2:glyph=FRAME_OBJECTS ? "A" : LOCAL_SEARCH ? "C" : SHAPE_MODEL ? "A" : "X";3:glyph=FRAME_OBJECTS ? "M" : LOCAL_SEARCH ? "A" : SHAPE_MODEL ? "P" : "E";
   4:glyph=FRAME_OBJECTS ? "E" : LOCAL_SEARCH ? "L" : SHAPE_MODEL ? "E" : "D";5:glyph=" ";
   6:glyph="E";7:glyph="X";8:glyph="P";9:glyph=" ";10:glyph="V";11:glyph=FRAME_OBJECTS ? "1" : LOCAL_SEARCH ? "7" : SHAPE_MODEL ? "5" : "4";12:glyph=FRAME_OBJECTS ? (REGIONS ? "2" : RESOLUTION_V11 ? "1" : "0") : " ";default:glyph=" ";
  endcase
 end
 if(!REGIONS && SHAPE_MODEL && sample_s && class_s<2 && y_ui>=540 && y_ui<588 && x>=16 && x<208) begin
  glyph_cjk=0;glyph=shape_status_char(class_s,(x-16)/16);glyph_col=((x-16)/2)%8;glyph_row=(y_ui-540)/2;
  if(y_ui>=572) glyph=" ";
 end
 // FG/W/H are native feature measurements in hex, T is decimal.
 if(SHAPE_MODEL && y_ui>=548 && y_ui<564 && x>=808 && x<1008) begin
  glyph_cjk=0;glyph_col=(x-808)%8;glyph_row=y_ui-548;ink_color=24'hb0c0d4;
  case((x-808)/8)
   0:glyph="F";1:glyph="G";2:glyph=" ";
   3:glyph=sample_s ? hexchar({3'd0,model_features_s[34]}) : "-";
   4:glyph=sample_s ? hexchar(model_features_s[33:30]) : "-";
   5:glyph=sample_s ? hexchar(model_features_s[29:26]) : "-";
   6:glyph=sample_s ? hexchar(model_features_s[25:22]) : "-";
   7:glyph=" ";8:glyph="W";9:glyph=" ";
   10:glyph=sample_s ? hexchar({1'b0,model_features_s[21:19]}) : "-";
   11:glyph=sample_s ? hexchar(model_features_s[18:15]) : "-";
   12:glyph=" ";13:glyph="H";14:glyph=" ";
   15:glyph=sample_s ? hexchar({1'b0,model_features_s[14:12]}) : "-";
   16:glyph=sample_s ? hexchar(model_features_s[11:8]) : "-";
   17:glyph=" ";18:glyph="T";19:glyph=" ";20:glyph="1";21:glyph="0";22:glyph="0";default:glyph=" ";
  endcase
 end
 if(direct_label) begin
  glyph_row=direct_gray_row ? y-(label_y-56) : y-(label_y-30);
  ink_color=local_review ? 24'hffcc55 : direct_state==2 ? 24'h74dbc7 : direct_state==3 ? 24'hffae64 : 24'hb0c0d4;
  if(x<label_x+40) begin
   glyph_cjk=0;glyph_row=(glyph_row>=5 && glyph_row<21) ? glyph_row-5 : 0;glyph_col=(x-label_x)%8;
   case((x-label_x)/8)
    0:glyph=direct_gray_row ? (SHAPE_MODEL ? "M" : "G") : local_review ? "F" : "E";1:glyph=direct_gray_row ? (SHAPE_MODEL ? "O" : "R") : local_review ? "I" : "D";
    2:glyph=direct_gray_row ? (SHAPE_MODEL ? "D" : "A") : local_review ? "T" : "G";3:glyph=direct_gray_row ? (SHAPE_MODEL ? "E" : "Y") : local_review ? " " : "E";
    default:glyph=SHAPE_MODEL && direct_gray_row ? "L" : " ";
   endcase
  end else if(SHAPE_MODEL && direct_gray_row && sample_s && direct_state<2) begin
   glyph_cjk=0;glyph_row=(glyph_row>=5 && glyph_row<21) ? glyph_row-5 : 0;glyph_col=(x-label_x-40)%8;
   glyph=shape_status_char(direct_state,(x-label_x-40)/8);
  end else if(!direct_gray_row && (SHAPE_MODEL || !mode_s[1])) begin
   glyph_cjk=0;glyph_row=(glyph_row>=5 && glyph_row<21) ? glyph_row-5 : 0;glyph_col=(x-label_x-40)%8;
   if(local_review)case((x-label_x-40)/8) 0:glyph="C";1:glyph="H";2:glyph="E";3:glyph="C";4:glyph="K";default:glyph=" ";endcase
   else case((x-label_x-40)/8) 0:glyph="O";1:glyph=SHAPE_MODEL && mode_s[1] ? "N" : "F";2:glyph=SHAPE_MODEL && mode_s[1] ? " " : "F";default:glyph=" ";endcase
  end else begin
   glyph_cjk=1;glyph_col=(x-label_x-40)%24;
   glyph=result_glyph(direct_state,(x-label_x-40)/24);
  end
 end
 if(pocket_label) begin
  glyph_cjk=1;glyph_row=y-pocket_label_y;glyph_col=(x-pocket_label_x)%24;
  glyph=result_glyph(pocket_state,(x-pocket_label_x)/24);ink_color=pocket_color;
 end
 if(frame_label)begin
  ink_color=frame_color;
  if(y<frame_ly+24)begin
   glyph_row=y-frame_ly;
   if(x<frame_lx+CARD_PREFIX)begin
    glyph_cjk=0;glyph_col=(x-frame_lx)%8;glyph_row=(y>=frame_ly+4 && y<frame_ly+20) ? y-frame_ly-4 : 0;
    glyph=" ";
    if(y>=frame_ly+4 && y<frame_ly+20)begin
     if(REGIONS)begin
      case((x-frame_lx)/8)
       0:glyph=frame_number[1] ? "2" : "1";1:glyph=".";2:glyph=frame_number[0] ? "2" : "1";
      endcase
     end else if(x<frame_lx+8)glyph=frame_number[0] ? "2" : "1";
    end
   end
   else if(frame_state<2)begin glyph_cjk=0;glyph_row=(y>=frame_ly+4 && y<frame_ly+20) ? y-frame_ly-4 : 0;glyph_col=(x-frame_lx-CARD_PREFIX)%8;glyph=y>=frame_ly+4 && y<frame_ly+20 ? shape_status_char(frame_state,(x-frame_lx-CARD_PREFIX)/8) : " ";end
   else begin glyph_cjk=1;glyph_col=(x-frame_lx-CARD_PREFIX)%24;glyph=result_glyph(frame_state,(x-frame_lx-CARD_PREFIX)/24);end
  end else begin
   glyph_cjk=0;glyph_row=(y-frame_ly-24)%16;glyph_col=(x-frame_lx)%8;
   glyph=x<frame_lx+64 ? frame_text[63-((x-frame_lx)/8)*8-:8] : " ";
  end
 end
 if(region_label)begin
  glyph_cjk=0;ink_color=region_color;glyph_row=y-region_ly;glyph_col=(x-region_lx)%8;
  glyph=region_text[127-((x-region_lx)/8)*8-:8];
 end
 if(RESOLUTION_V11 && x>=1056 && x<1256 && y>=24 && y<40)begin
  glyph_cjk=0;ink_color=24'hffcc55;glyph_row=y-24;glyph_col=(x-1056)%8;
  glyph=calibration_text[199-((x-1056)/8)*8-:8];
 end
 if(cal_panel)begin
  glyph_cjk=0;glyph=cal_glyph;glyph_col=cal_col;glyph_row=cal_row;ink_color=cal_color;
 end

end
// V11 remains a model experiment until 180 mm samples establish its recipe.
wire calibration_marker=RESOLUTION_V11 && x>=1056 && x<1256 && y>=24 && y<40;

wire roi_inside=x>=ROI_X0 && x<ROI_X1 && y>=ROI_Y0 && y<ROI_Y1;
wire roi_border=roi_inside && (x==ROI_X0 || x==ROI_X1-1 || y==ROI_Y0 || y==ROI_Y1-1);
wire [10:0] sample_x0=TRACKING ? track_x0_s : SAMPLE_X0,sample_x1=TRACKING ? track_x1_s : SAMPLE_X1;
wire [9:0] sample_y0=LOCAL_SEARCH ? local_y0_s : SAMPLE_Y0,sample_y1=LOCAL_SEARCH ? local_y1_s : SAMPLE_Y1;
wire [10:0] box_x0=LOCAL_SEARCH ? local_x0_s : sample_x0,box_x1=LOCAL_SEARCH ? local_x1_s : sample_x1;
wire sample_inside=(LOCAL_SEARCH ? local_box_s : (!TRACKING || track_valid_s)) && x>=box_x0 && x<box_x1 && y>=sample_y0 && y<sample_y1;
wire sample_border=sample_inside && (x==box_x0 || x==box_x1-1 || y==sample_y0 || y==sample_y1-1);
wire local_search_border=LOCAL_SEARCH && x>=416 && x<608 && y>=228 && y<372 &&
 (x==416 || x==607 || y==228 || y==371) && ((x==416 || x==607) ? y[1:0]==0 : x[1:0]==0);
wire [9:0] gray_sum={2'd0,rgb[23:16]}+{1'd0,rgb[15:8],1'b0}+{2'd0,rgb[7:0]};
wire [7:0] gray=gray_sum[9:2];
wire align_border=TRACKING && !track_valid_s && x>=SAMPLE_X0 && x<SAMPLE_X1 && y>=SAMPLE_Y0 && y<SAMPLE_Y1 &&
 (x==SAMPLE_X0 || x==SAMPLE_X1-1 || y==SAMPLE_Y0 || y==SAMPLE_Y1-1) && (x[2:0]==0 || y[2:0]==0);
wire search_guide=TRACKING && ((x>=256 && x<768 && x[3:0]==0 && (y==HOLE_Y-8 || y==HOLE_Y || y==HOLE_Y+8)) || (x==464 && y>=HOLE_Y-12 && y<=HOLE_Y+12));
wire [23:0] picture=FRAME_OBJECTS ? (ENABLE && frame_border ? frame_color : ENABLE && region_border ? region_color : rgb) : MULTI_POCKETS ? (ENABLE && pocket_border ? pocket_color : rgb) :
 ENABLE && (sample_border || local_search_border) ? 24'h00ffff :
 ENABLE && roi_border ? 24'h00ff40 : ENABLE && (search_guide || align_border) ? 24'hffff00 : rgb;
reg [10:0] ascii_address;
reg [10:0] cjk_address;
reg [12:0] logo_address;
wire [5:0] logo_y=y-10'd8;
wire [6:0] logo_x=x-11'd16;
wire [7:0] ascii_row;wire [23:0] cjk_row;wire [1:0] logo_pixel;
osd_ascii_rom u_ascii(clk,ascii_address,ascii_row);
osd_cjk_rom u_cjk(clk,cjk_address,cjk_row);
osd_logo_rom u_logo(clk,logo_address,logo_pixel);
reg [1:0] hs_p,vs_p,de_p,panel_p,logo_p,cjk_p;
reg [4:0] col0,col1;
reg [23:0] rgb0,rgb1,ink0,ink1;
wire ink=cjk_p[1] ? (col1<24 && cjk_row[23-col1]) : (col1<8 && ascii_row[7-col1]);
always @(posedge clk or negedge rst_n) begin
 if(!rst_n) begin
  ascii_address<=0;cjk_address<=0;logo_address<=0;
  hs_p<=0;vs_p<=0;de_p<=0;panel_p<=0;logo_p<=0;cjk_p<=0;
  col0<=0;col1<=0;rgb0<=0;rgb1<=0;ink0<=0;ink1<=0;
  out_vs<=0;out_hs<=0;out_de<=0;out_rgb<=0;
 end else begin
  ascii_address<={glyph,glyph_row[3:0]};
  cjk_address<={glyph[5:0],glyph_row};
  logo_address<={logo_y,logo_x};
  hs_p<={hs_p[0],hs};vs_p<={vs_p[0],vs};de_p<={de_p[0],de};
  panel_p<={panel_p[0],(de && (cal_panel || frame_label || region_label || direct_label || pocket_label || ((y<80 || y>=HEIGHT-96) && !frame_border) || (TRACKING && y>=148 && y<164 && x>=256 && x<544)))};
  logo_p<={logo_p[0],(x>=16 && x<112 && y>=8 && y<72)};
  cjk_p<={cjk_p[0],glyph_cjk};col0<=glyph_col;col1<=col0;
  rgb0<=picture;rgb1<=rgb0;ink0<=ink_color;ink1<=ink0;
  out_vs<=vs_p[1];out_hs<=hs_p[1];out_de<=de_p[1];
  out_rgb<=ENABLE && panel_p[1] ?
   (logo_p[1] ? (logo_pixel==1 ? 24'h204686 : logo_pixel==2 ? 24'hcc253b : 24'hffffff) :
    ink ? ink1 : 24'h142336) : rgb1;
 end
end
endmodule

// Decimal formatting uses ONE shared frame-rate converter. The complete
// measurement is frozen at the first active pixel, before panels at row96.
module calibration_osd #(parameter WIDTH=1280,HEIGHT=720)(
 input wire clk,rst_n,start,input wire [127:0] record,input wire eligible,
 input wire [3:0] reason,input wire [10:0] x,input wire [9:0] y,
 output reg panel,border,core,output reg [7:0] glyph,
 output reg [3:0] col,row,output reg [23:0] color
);
reg [127:0] frozen;reg eligible_s;reg [3:0] reason_s;
reg [15:0] decimal_digits[0:13];reg [3:0] index;
reg [4:0] phase;reg running,digits_ready;
wire convert_start=running && phase==0;
reg [15:0] value;wire [19:0] digits;
wire [63:0] converting=index<7 ? frozen[63:0] : frozen[127:64];
wire [3:0] field=index<7 ? index : index-7;
always @*begin
 case(field)
  0:value={8'd0,converting[59:52]};1:value={8'd0,converting[51:44]};
  2:value={8'd0,converting[43:36]};3:value={7'd0,converting[35:27]};
  4:value={9'd0,converting[13:7]};5:value={9'd0,converting[6:0]};
  default:value={3'd0,converting[26:14]};
 endcase
end
bin16_bcd converter(clk,rst_n,convert_start,value,digits);
always @(posedge clk or negedge rst_n)begin
 if(!rst_n)begin frozen<=0;eligible_s<=0;reason_s<=1;index<=0;phase<=0;running<=0;digits_ready<=0;end
 else if(start)begin frozen<=record;eligible_s<=eligible;reason_s<=reason;index<=0;phase<=0;running<=1;digits_ready<=0;end
 else if(running)begin
  if(phase==17)begin
   decimal_digits[index]<=digits[15:0];phase<=0;
   if(index==13)begin running<=0;digits_ready<=1;end else index<=index+1'b1;
  end else phase<=phase+1'b1;
 end
end
integer probe,line_no,column,base,cx,cy,yy,n;
reg [63:0] selected;reg valid;reg [287:0] text_line;
reg [15:0] bcd;integer digit_position;
always @*begin
 panel=0;border=0;core=0;glyph=" ";col=0;row=0;color=24'h74dbc7;
 probe=0;line_no=0;column=0;base=0;cx=WIDTH/2;cy=0;yy=0;selected=0;valid=0;
 text_line=0;bcd=0;digit_position=0;
 for(n=0;n<2;n=n+1)begin
  cy=n==0 ? HEIGHT*4/9 : HEIGHT*43/60;
  if(x>=cx-16 && x<cx+16 && y>=cy-16 && y<cy+16 &&
   (x==cx-16 || x==cx+15 || y==cy-16 || y==cy+15))border=1;
  if(x>=cx-8 && x<cx+8 && y>=cy-8 && y<cy+8 &&
   (x==cx-8 || x==cx+7 || y==cy-8 || y==cy+7))core=1;
 end
 if(x>=16 && x<304 && ((y>=96 && y<160) || (y>=432 && y<496)))begin
  panel=1;probe=y>=432;base=probe*7;yy=probe ? y-432 : y-96;
  line_no=yy/16;column=(x-16)/8;col=(x-16)%8;row=yy%16;
  selected=probe ? frozen[127:64] : frozen[63:0];valid=eligible_s && selected[63] && digits_ready;
  case(line_no)
   0:text_line="CAL1 T100 OUT32 CORE16              ";
   1:text_line="M000 MIN000 MAX000 SAT000           ";
   2:text_line="W000 H000 A0000 CLIP0               ";
   default:text_line=valid ? (selected[62] ? "CLIP: RECENTER TARGET               " : "SAMPLE OK / ONE TARGET ONLY         ") : "WAIT CURRENT FRAME                  ";
  endcase
  glyph=text_line[287-column*8-:8];
  if(line_no==0)begin
   if(column==3)glyph=probe ? "2" : "1";
   if(column>=6 && column<=8)begin
    case(selected[61:60])
     0:glyph=column==6 ? "1" : "0";
     1:glyph=column==6 ? "0" : column==7 ? "8" : "0";
     2:glyph=column==6 ? "1" : column==7 ? "2" : "0";
     3:glyph=column==6 ? "1" : column==7 ? "4" : "0";
    endcase
   end
  end
  if(line_no==1)begin
   if(column>=1 && column<=3)begin bcd=decimal_digits[base];digit_position=3-column;end
   if(column>=8 && column<=10)begin bcd=decimal_digits[base+1];digit_position=10-column;end
   if(column>=15 && column<=17)begin bcd=decimal_digits[base+2];digit_position=17-column;end
   if(column>=22 && column<=24)begin bcd=decimal_digits[base+3];digit_position=24-column;end
   if((column>=1 && column<=3) || (column>=8 && column<=10) || (column>=15 && column<=17) || (column>=22 && column<=24))
    glyph=valid ? "0"+((bcd>>(digit_position*4))&4'hf) : "-";
  end
  if(line_no==2)begin
   if(column>=1 && column<=3)begin bcd=decimal_digits[base+4];digit_position=3-column;end
   if(column>=6 && column<=8)begin bcd=decimal_digits[base+5];digit_position=8-column;end
   if(column>=11 && column<=14)begin bcd=decimal_digits[base+6];digit_position=14-column;end
   if((column>=1 && column<=3) || (column>=6 && column<=8) || (column>=11 && column<=14))glyph=valid ? "0"+((bcd>>(digit_position*4))&4'hf) : "-";
   if(column==20)glyph=valid ? (selected[62] ? "1" : "0") : "-";
  end
  color=valid ? (selected[62] ? 24'hffcc55 : 24'h74dbc7) : 24'hb0c0d4;
 end
 if(x>=16 && x<304 && y>=176 && y<208)begin
  panel=1;column=(x-16)/8;col=(x-16)%8;row=(y-176)%16;
  text_line=y<192 ? "RAW100 GRAY080 EDGE120 BOTH140      " : "BODY100 HOLE080 / CAL NOT FROZEN    ";
  glyph=text_line[287-column*8-:8];color=24'hb0c0d4;
 end
 if(x>=16 && x<304 && y>=584 && y<600)begin
  panel=1;column=(x-16)/8;col=(x-16)%8;row=y-584;
  case(reason_s)
   0:text_line="PIPE OK / RECIPE NOT CALIBRATED     ";1:text_line="WAIT: NO RESULT METADATA            ";2:text_line="WAIT: FRAME STALE                   ";
   3:text_line="WAIT: CAMERA CONFIG                 ";4:text_line="WAIT: NO INPUT FPS                  ";5:text_line="WAIT: VIDEO TRANSPORT               ";
   6:text_line="WAIT: EXP/GAIN CHANGED              ";7:text_line="WAIT: MODE/WB CHANGED               ";default:text_line="WAIT: SAMPLE INCOMPLETE             ";
  endcase
  glyph=text_line[287-column*8-:8];color=reason_s==0 ? 24'h74dbc7 : 24'hffcc55;
 end
end
endmodule

// Two current-frame lane results. Pixel interface and bypass stay3 clocks.
module compact_lane_osd #(parameter WIDTH=1280,HEIGHT=720,ENABLE=1)(
 input wire clk,rst_n,vs,hs,de,input wire [23:0] rgb,
 input wire [15:0] exposure,gain,fps,input wire [1:0] view_mode,
 input wire roi_valid,cfg_done,error,input wire [303:0] frame_objects,
 output reg out_vs,out_hs,out_de,output reg [23:0] out_rgb
);
reg [10:0] x;reg [9:0] y;reg de_d;
wire start=de && !de_d && y==0;
reg [151:0] records;reg eligible,error_s;reg [1:0] mode_s;
always @(posedge clk or negedge rst_n)begin
 if(!rst_n)begin x<=0;y<=0;de_d<=0;records<=0;eligible<=0;error_s<=0;mode_s<=0;end
 else begin
  de_d<=de;
  if(vs)begin x<=0;y<=0;end
  else if(de)x<=x+1'b1;
  else begin x<=0;if(de_d)y<=y+1'b1;end
  if(start)begin
   records<={frame_objects[227:152],frame_objects[75:0]};
   eligible<=roi_valid && cfg_done && fps!=0;error_s<=error || !cfg_done || fps==0;mode_s<=view_mode;
  end
 end
end
wire [19:0] exp_bcd,gain_bcd,fps_bcd;
bin16_bcd e(clk,rst_n,start,exposure,exp_bcd);
bin16_bcd g(clk,rst_n,start,gain,gain_bcd);
bin16_bcd f(clk,rst_n,start,fps,fps_bcd);
function [39:0] digits;
 input [19:0] value;integer k;reg blank;begin
  blank=1;digits=0;
  for(k=0;k<5;k=k+1)begin
   if(value[19-k*4-:4]!=0 || k==4)blank=0;
   digits[39-k*8-:8]=blank ? " " : 8'd48+value[19-k*4-:4];
  end
 end
endfunction
reg [71:0] mode_text;
always @*case(mode_s)
 0:mode_text="RAW      ";1:mode_text="GRAY     ";2:mode_text="EDGE     ";default:mode_text="GRAY+EDGE";
endcase
// Fixed size header:12+2+5+2+5+4+5+1+9=45 characters.
wire [359:0] header={"ANLOGIC 3528 E",digits(exp_bcd)," G",digits(gain_bcd)," FPS",digits(fps_bcd)," ",mode_text};
wire [103:0] version_text="SMALL DUAL R1";
wire [39:0] run_text=error_s ? "CHECK" : "RUN  ";
wire [83:0] bounds;wire [31:0] unused_models;wire [239:0] unused_recipes;wire [1:0] unused_supported;
inspection_region_config #(.WIDTH(WIDTH),.HEIGHT(HEIGHT),.COMPACT(1)) cfg(bounds,unused_models,unused_recipes,unused_supported);
reg panel,cjk,logo;reg [6:0] glyph;reg [4:0] row,col;reg [23:0] ink_color,picture;
reg [41:0] rb;reg [75:0] rec;reg [23:0] color;reg [1:0] state;reg [3:0] reason;
integer lane,cx,cy,ci;reg [6:0] char_id;
always @*begin
 panel=y<48;cjk=0;logo=x>=16 && x<64 && y>=8 && y<40;
 glyph=" ";row=0;col=0;ink_color=24'hd8e5ed;picture=rgb;
 rb=0;rec=0;color=0;state=0;reason=0;cx=0;cy=0;ci=0;char_id=0;
 if(x>=80 && x<440 && y>=16 && y<32)begin glyph=header[359-((x-80)/8)*8-:8];row=y-16;col=(x-80)%8;end
 if(x>=688 && x<728 && y>=16 && y<32)begin glyph=run_text[39-((x-688)/8)*8-:8];row=y-16;col=(x-688)%8;ink_color=error_s ? 24'hef7186 : 24'h74dbc7;end
 if(x>=WIDTH-120 && x<WIDTH-16 && y>=16 && y<32)begin glyph=version_text[103-((x-(WIDTH-120))/8)*8-:8];row=y-16;col=(x-(WIDTH-120))%8;end
 for(lane=0;lane<2;lane=lane+1)begin
  rb=bounds[lane*42+:42];rec=records[lane*76+:76];state=rec[74:73];reason=rec[72:69];
  color=!(eligible && rec[75]) || state<2 ? 24'h91a4b4 : state==3 ? 24'hffae64 : reason!=0 ? 24'hffcc55 : 24'h74dbc7;
  if(ENABLE && eligible && rec[75] && x>=rec[41:31] && x<rec[30:20] && y>=rec[19:10] && y<rec[9:0] &&
   (x==rec[41:31] || x==rec[30:20]-1 || y==rec[19:10] || y==rec[9:0]-1))picture=color;
  if(ENABLE && x>=rb[41:31] && x<rb[30:20] && y>=rb[19:10] && y<rb[9:0] &&
   (((x==rb[41:31] || x==rb[30:20]-1) && !y[2]) || ((y==rb[19:10] || y==rb[9:0]-1) && !x[2])))picture=24'h6592a7;
  // Valid result labels follow their current-frame rectangle. Only WAIT uses
  // the fixed lane origin; no old label or old box is retained across frames.
  cx=eligible && rec[75] ? (rec[41:31]>WIDTH-160 ? WIDTH-160 : rec[41:31]) : rb[41:31];
  cy=eligible && rec[75] ? (rec[19:10]>=80 ? rec[19:10]-28 : rec[9:0]+4) : rb[19:10]-28;
  if(x>=cx && x<cx+160 && y>=cy && y<cy+24)begin
   panel=1;ink_color=color;glyph=" ";row=y-cy;col=(x-cx)%8;cjk=0;
   if(x<cx+16)begin
    if(x<cx+8 && y>=cy+4 && y<cy+20)begin glyph=lane==0 ? "1" : "2";row=y-cy-4;end
   end else begin
    cjk=1;ci=(x-cx-24)/24;col=(x-cx-24)%24;glyph=0;
    if(x>=cx+24 && ci<5)begin
     if(!(eligible && rec[75]) || state<2)case(ci)0:glyph=5;1:glyph=6;2:glyph=7;default:glyph=0;endcase
     else if(state==3)case(ci)0:glyph=3;1:glyph=4;default:glyph=0;endcase
     else case(ci)0:glyph=1;1:glyph=2;2:glyph=reason!=0 ? 8 : 0;3:glyph=reason!=0 ? 9 : 0;default:glyph=0;endcase
    end
   end
  end
 end
end
reg [10:0] ascii_address;reg [8:0] cjk_address;reg [12:0] logo_address;
wire [7:0] ascii_row;reg [23:0] cjk_row;wire [1:0] logo_pixel;
reg [23:0] cjk_memory[0:511];
initial begin
 cjk_memory[0]=24'h000000;
 cjk_memory[1]=24'h000000;
 cjk_memory[2]=24'h000000;
 cjk_memory[3]=24'h000000;
 cjk_memory[4]=24'h000000;
 cjk_memory[5]=24'h000000;
 cjk_memory[6]=24'h000000;
 cjk_memory[7]=24'h000000;
 cjk_memory[8]=24'h000000;
 cjk_memory[9]=24'h000000;
 cjk_memory[10]=24'h000000;
 cjk_memory[11]=24'h000000;
 cjk_memory[12]=24'h000000;
 cjk_memory[13]=24'h000000;
 cjk_memory[14]=24'h000000;
 cjk_memory[15]=24'h000000;
 cjk_memory[16]=24'h000000;
 cjk_memory[17]=24'h000000;
 cjk_memory[18]=24'h000000;
 cjk_memory[19]=24'h000000;
 cjk_memory[20]=24'h000000;
 cjk_memory[21]=24'h000000;
 cjk_memory[22]=24'h000000;
 cjk_memory[23]=24'h000000;
 cjk_memory[24]=24'h000000;
 cjk_memory[25]=24'h000000;
 cjk_memory[26]=24'h000000;
 cjk_memory[27]=24'h000000;
 cjk_memory[28]=24'h000000;
 cjk_memory[29]=24'h000000;
 cjk_memory[30]=24'h000000;
 cjk_memory[31]=24'h000000;
 cjk_memory[32]=24'h000000;
 cjk_memory[33]=24'h006000;
 cjk_memory[34]=24'h00c000;
 cjk_memory[35]=24'h00c000;
 cjk_memory[36]=24'h7ffffe;
 cjk_memory[37]=24'h7ffffc;
 cjk_memory[38]=24'h038000;
 cjk_memory[39]=24'h030000;
 cjk_memory[40]=24'h07fff0;
 cjk_memory[41]=24'h0ffff0;
 cjk_memory[42]=24'h1e0030;
 cjk_memory[43]=24'h3e0030;
 cjk_memory[44]=24'h77fff0;
 cjk_memory[45]=24'he7fff0;
 cjk_memory[46]=24'h460030;
 cjk_memory[47]=24'h060030;
 cjk_memory[48]=24'h060030;
 cjk_memory[49]=24'h07fff0;
 cjk_memory[50]=24'h07fff0;
 cjk_memory[51]=24'h060030;
 cjk_memory[52]=24'h060030;
 cjk_memory[53]=24'h0607e0;
 cjk_memory[54]=24'h0607c0;
 cjk_memory[55]=24'h000000;
 cjk_memory[56]=24'h000000;
 cjk_memory[57]=24'h000000;
 cjk_memory[58]=24'h000000;
 cjk_memory[59]=24'h000000;
 cjk_memory[60]=24'h000000;
 cjk_memory[61]=24'h000000;
 cjk_memory[62]=24'h000000;
 cjk_memory[63]=24'h000000;
 cjk_memory[64]=24'h000000;
 cjk_memory[65]=24'h060180;
 cjk_memory[66]=24'h063180;
 cjk_memory[67]=24'h0e3180;
 cjk_memory[68]=24'h0c7180;
 cjk_memory[69]=24'h0c6180;
 cjk_memory[70]=24'h187ffc;
 cjk_memory[71]=24'h18fffc;
 cjk_memory[72]=24'h38c180;
 cjk_memory[73]=24'h38c180;
 cjk_memory[74]=24'h798180;
 cjk_memory[75]=24'hf88180;
 cjk_memory[76]=24'hd80180;
 cjk_memory[77]=24'h59fffe;
 cjk_memory[78]=24'h19fffe;
 cjk_memory[79]=24'h180180;
 cjk_memory[80]=24'h180180;
 cjk_memory[81]=24'h180180;
 cjk_memory[82]=24'h180180;
 cjk_memory[83]=24'h180180;
 cjk_memory[84]=24'h180180;
 cjk_memory[85]=24'h180180;
 cjk_memory[86]=24'h180180;
 cjk_memory[87]=24'h000000;
 cjk_memory[88]=24'h000000;
 cjk_memory[89]=24'h000000;
 cjk_memory[90]=24'h000000;
 cjk_memory[91]=24'h000000;
 cjk_memory[92]=24'h000000;
 cjk_memory[93]=24'h000000;
 cjk_memory[94]=24'h000000;
 cjk_memory[95]=24'h000000;
 cjk_memory[96]=24'h000000;
 cjk_memory[97]=24'h003000;
 cjk_memory[98]=24'h003000;
 cjk_memory[99]=24'h001800;
 cjk_memory[100]=24'h7ffffc;
 cjk_memory[101]=24'h7ffffc;
 cjk_memory[102]=24'h60000c;
 cjk_memory[103]=24'h60820c;
 cjk_memory[104]=24'h03c380;
 cjk_memory[105]=24'h0781c0;
 cjk_memory[106]=24'h0e00f0;
 cjk_memory[107]=24'h3c0038;
 cjk_memory[108]=24'h70001c;
 cjk_memory[109]=24'h60000c;
 cjk_memory[110]=24'h1ffff0;
 cjk_memory[111]=24'h0fffe0;
 cjk_memory[112]=24'h003800;
 cjk_memory[113]=24'h003800;
 cjk_memory[114]=24'h003800;
 cjk_memory[115]=24'h003800;
 cjk_memory[116]=24'h003800;
 cjk_memory[117]=24'h7ffffc;
 cjk_memory[118]=24'h7ffffc;
 cjk_memory[119]=24'h000000;
 cjk_memory[120]=24'h000000;
 cjk_memory[121]=24'h000000;
 cjk_memory[122]=24'h000000;
 cjk_memory[123]=24'h000000;
 cjk_memory[124]=24'h000000;
 cjk_memory[125]=24'h000000;
 cjk_memory[126]=24'h000000;
 cjk_memory[127]=24'h000000;
 cjk_memory[128]=24'h000000;
 cjk_memory[129]=24'h003000;
 cjk_memory[130]=24'h003000;
 cjk_memory[131]=24'h001800;
 cjk_memory[132]=24'h001800;
 cjk_memory[133]=24'h7ffffc;
 cjk_memory[134]=24'h7ffffc;
 cjk_memory[135]=24'h60000c;
 cjk_memory[136]=24'h60000c;
 cjk_memory[137]=24'h60060c;
 cjk_memory[138]=24'h018600;
 cjk_memory[139]=24'h018700;
 cjk_memory[140]=24'h018300;
 cjk_memory[141]=24'h038300;
 cjk_memory[142]=24'h030380;
 cjk_memory[143]=24'h030180;
 cjk_memory[144]=24'h0601c0;
 cjk_memory[145]=24'h0e00c0;
 cjk_memory[146]=24'h0c00e0;
 cjk_memory[147]=24'h1c0070;
 cjk_memory[148]=24'h380038;
 cjk_memory[149]=24'h70001e;
 cjk_memory[150]=24'h60000c;
 cjk_memory[151]=24'h000000;
 cjk_memory[152]=24'h000000;
 cjk_memory[153]=24'h000000;
 cjk_memory[154]=24'h000000;
 cjk_memory[155]=24'h000000;
 cjk_memory[156]=24'h000000;
 cjk_memory[157]=24'h000000;
 cjk_memory[158]=24'h000000;
 cjk_memory[159]=24'h000000;
 cjk_memory[160]=24'h000000;
 cjk_memory[161]=24'h060300;
 cjk_memory[162]=24'h060300;
 cjk_memory[163]=24'h0c0300;
 cjk_memory[164]=24'h1cfffc;
 cjk_memory[165]=24'h38fff8;
 cjk_memory[166]=24'h700300;
 cjk_memory[167]=24'he60300;
 cjk_memory[168]=24'h460300;
 cjk_memory[169]=24'h0dfffe;
 cjk_memory[170]=24'h1dfffc;
 cjk_memory[171]=24'h180000;
 cjk_memory[172]=24'h380060;
 cjk_memory[173]=24'h79fffe;
 cjk_memory[174]=24'hf9fffc;
 cjk_memory[175]=24'h586060;
 cjk_memory[176]=24'h186060;
 cjk_memory[177]=24'h183060;
 cjk_memory[178]=24'h183860;
 cjk_memory[179]=24'h181060;
 cjk_memory[180]=24'h180060;
 cjk_memory[181]=24'h180fe0;
 cjk_memory[182]=24'h1807c0;
 cjk_memory[183]=24'h000000;
 cjk_memory[184]=24'h000000;
 cjk_memory[185]=24'h000000;
 cjk_memory[186]=24'h000000;
 cjk_memory[187]=24'h000000;
 cjk_memory[188]=24'h000000;
 cjk_memory[189]=24'h000000;
 cjk_memory[190]=24'h000000;
 cjk_memory[191]=24'h000000;
 cjk_memory[192]=24'h000000;
 cjk_memory[193]=24'h080300;
 cjk_memory[194]=24'h080780;
 cjk_memory[195]=24'h080780;
 cjk_memory[196]=24'h080cc0;
 cjk_memory[197]=24'h081860;
 cjk_memory[198]=24'hff3830;
 cjk_memory[199]=24'h7f7038;
 cjk_memory[200]=24'h18e00e;
 cjk_memory[201]=24'h18c004;
 cjk_memory[202]=24'h3e3ff0;
 cjk_memory[203]=24'h3f1fe0;
 cjk_memory[204]=24'h396600;
 cjk_memory[205]=24'h686610;
 cjk_memory[206]=24'hc86330;
 cjk_memory[207]=24'hc83330;
 cjk_memory[208]=24'h083330;
 cjk_memory[209]=24'h083360;
 cjk_memory[210]=24'h083060;
 cjk_memory[211]=24'h0800c0;
 cjk_memory[212]=24'h08fffc;
 cjk_memory[213]=24'h08fffc;
 cjk_memory[214]=24'h080000;
 cjk_memory[215]=24'h000000;
 cjk_memory[216]=24'h000000;
 cjk_memory[217]=24'h000000;
 cjk_memory[218]=24'h000000;
 cjk_memory[219]=24'h000000;
 cjk_memory[220]=24'h000000;
 cjk_memory[221]=24'h000000;
 cjk_memory[222]=24'h000000;
 cjk_memory[223]=24'h000000;
 cjk_memory[224]=24'h000000;
 cjk_memory[225]=24'h20000c;
 cjk_memory[226]=24'h73fe0c;
 cjk_memory[227]=24'h3bfecc;
 cjk_memory[228]=24'h1f06cc;
 cjk_memory[229]=24'h0b06cc;
 cjk_memory[230]=24'h0326cc;
 cjk_memory[231]=24'h4326cc;
 cjk_memory[232]=24'h6326cc;
 cjk_memory[233]=24'h7326cc;
 cjk_memory[234]=24'h3b26cc;
 cjk_memory[235]=24'h1326cc;
 cjk_memory[236]=24'h0366cc;
 cjk_memory[237]=24'h1366cc;
 cjk_memory[238]=24'h1b66cc;
 cjk_memory[239]=24'h3b66cc;
 cjk_memory[240]=24'h3060cc;
 cjk_memory[241]=24'h30f00c;
 cjk_memory[242]=24'h31d80c;
 cjk_memory[243]=24'h638c0c;
 cjk_memory[244]=24'h6f060c;
 cjk_memory[245]=24'h2c02f8;
 cjk_memory[246]=24'h000078;
 cjk_memory[247]=24'h000000;
 cjk_memory[248]=24'h000000;
 cjk_memory[249]=24'h000000;
 cjk_memory[250]=24'h000000;
 cjk_memory[251]=24'h000000;
 cjk_memory[252]=24'h000000;
 cjk_memory[253]=24'h000000;
 cjk_memory[254]=24'h000000;
 cjk_memory[255]=24'h000000;
 cjk_memory[256]=24'h000000;
 cjk_memory[257]=24'h060000;
 cjk_memory[258]=24'h060000;
 cjk_memory[259]=24'h0ffffc;
 cjk_memory[260]=24'h1ffffc;
 cjk_memory[261]=24'h380000;
 cjk_memory[262]=24'h3ffff0;
 cjk_memory[263]=24'h6ffff0;
 cjk_memory[264]=24'h480030;
 cjk_memory[265]=24'h0ffff0;
 cjk_memory[266]=24'h0c0030;
 cjk_memory[267]=24'h080030;
 cjk_memory[268]=24'h0ffff0;
 cjk_memory[269]=24'h0ffff0;
 cjk_memory[270]=24'h038000;
 cjk_memory[271]=24'h07fff0;
 cjk_memory[272]=24'h0f00f0;
 cjk_memory[273]=24'h1981e0;
 cjk_memory[274]=24'h70e780;
 cjk_memory[275]=24'h403e00;
 cjk_memory[276]=24'h01ffe0;
 cjk_memory[277]=24'h3f81fe;
 cjk_memory[278]=24'h3c001c;
 cjk_memory[279]=24'h000000;
 cjk_memory[280]=24'h000000;
 cjk_memory[281]=24'h000000;
 cjk_memory[282]=24'h000000;
 cjk_memory[283]=24'h000000;
 cjk_memory[284]=24'h000000;
 cjk_memory[285]=24'h000000;
 cjk_memory[286]=24'h000000;
 cjk_memory[287]=24'h000000;
 cjk_memory[288]=24'h000000;
 cjk_memory[289]=24'h0c0300;
 cjk_memory[290]=24'h0c0300;
 cjk_memory[291]=24'h0c0180;
 cjk_memory[292]=24'h0cfffe;
 cjk_memory[293]=24'hfffffe;
 cjk_memory[294]=24'h7f0c00;
 cjk_memory[295]=24'h1c1c30;
 cjk_memory[296]=24'h1c1870;
 cjk_memory[297]=24'h1c3060;
 cjk_memory[298]=24'h3e7fe0;
 cjk_memory[299]=24'h3fffcc;
 cjk_memory[300]=24'h3d038c;
 cjk_memory[301]=24'h6c0718;
 cjk_memory[302]=24'hcc0e30;
 cjk_memory[303]=24'hcc1c70;
 cjk_memory[304]=24'h0c78e0;
 cjk_memory[305]=24'h0ce1e0;
 cjk_memory[306]=24'h0cc3f0;
 cjk_memory[307]=24'h0c0e38;
 cjk_memory[308]=24'h0c3c1c;
 cjk_memory[309]=24'h0c700e;
 cjk_memory[310]=24'h0c6004;
 cjk_memory[311]=24'h000000;
 cjk_memory[312]=24'h000000;
 cjk_memory[313]=24'h000000;
 cjk_memory[314]=24'h000000;
 cjk_memory[315]=24'h000000;
 cjk_memory[316]=24'h000000;
 cjk_memory[317]=24'h000000;
 cjk_memory[318]=24'h000000;
 cjk_memory[319]=24'h000000;
 cjk_memory[320]=24'h000000;
 cjk_memory[321]=24'h000000;
 cjk_memory[322]=24'h000000;
 cjk_memory[323]=24'h000000;
 cjk_memory[324]=24'h000000;
 cjk_memory[325]=24'h000000;
 cjk_memory[326]=24'h000000;
 cjk_memory[327]=24'h000000;
 cjk_memory[328]=24'h000000;
 cjk_memory[329]=24'h000000;
 cjk_memory[330]=24'h000000;
 cjk_memory[331]=24'h000000;
 cjk_memory[332]=24'h000000;
 cjk_memory[333]=24'h000000;
 cjk_memory[334]=24'h000000;
 cjk_memory[335]=24'h000000;
 cjk_memory[336]=24'h000000;
 cjk_memory[337]=24'h000000;
 cjk_memory[338]=24'h000000;
 cjk_memory[339]=24'h000000;
 cjk_memory[340]=24'h000000;
 cjk_memory[341]=24'h000000;
 cjk_memory[342]=24'h000000;
 cjk_memory[343]=24'h000000;
 cjk_memory[344]=24'h000000;
 cjk_memory[345]=24'h000000;
 cjk_memory[346]=24'h000000;
 cjk_memory[347]=24'h000000;
 cjk_memory[348]=24'h000000;
 cjk_memory[349]=24'h000000;
 cjk_memory[350]=24'h000000;
 cjk_memory[351]=24'h000000;
 cjk_memory[352]=24'h000000;
 cjk_memory[353]=24'h000000;
 cjk_memory[354]=24'h000000;
 cjk_memory[355]=24'h000000;
 cjk_memory[356]=24'h000000;
 cjk_memory[357]=24'h000000;
 cjk_memory[358]=24'h000000;
 cjk_memory[359]=24'h000000;
 cjk_memory[360]=24'h000000;
 cjk_memory[361]=24'h000000;
 cjk_memory[362]=24'h000000;
 cjk_memory[363]=24'h000000;
 cjk_memory[364]=24'h000000;
 cjk_memory[365]=24'h000000;
 cjk_memory[366]=24'h000000;
 cjk_memory[367]=24'h000000;
 cjk_memory[368]=24'h000000;
 cjk_memory[369]=24'h000000;
 cjk_memory[370]=24'h000000;
 cjk_memory[371]=24'h000000;
 cjk_memory[372]=24'h000000;
 cjk_memory[373]=24'h000000;
 cjk_memory[374]=24'h000000;
 cjk_memory[375]=24'h000000;
 cjk_memory[376]=24'h000000;
 cjk_memory[377]=24'h000000;
 cjk_memory[378]=24'h000000;
 cjk_memory[379]=24'h000000;
 cjk_memory[380]=24'h000000;
 cjk_memory[381]=24'h000000;
 cjk_memory[382]=24'h000000;
 cjk_memory[383]=24'h000000;
 cjk_memory[384]=24'h000000;
 cjk_memory[385]=24'h000000;
 cjk_memory[386]=24'h000000;
 cjk_memory[387]=24'h000000;
 cjk_memory[388]=24'h000000;
 cjk_memory[389]=24'h000000;
 cjk_memory[390]=24'h000000;
 cjk_memory[391]=24'h000000;
 cjk_memory[392]=24'h000000;
 cjk_memory[393]=24'h000000;
 cjk_memory[394]=24'h000000;
 cjk_memory[395]=24'h000000;
 cjk_memory[396]=24'h000000;
 cjk_memory[397]=24'h000000;
 cjk_memory[398]=24'h000000;
 cjk_memory[399]=24'h000000;
 cjk_memory[400]=24'h000000;
 cjk_memory[401]=24'h000000;
 cjk_memory[402]=24'h000000;
 cjk_memory[403]=24'h000000;
 cjk_memory[404]=24'h000000;
 cjk_memory[405]=24'h000000;
 cjk_memory[406]=24'h000000;
 cjk_memory[407]=24'h000000;
 cjk_memory[408]=24'h000000;
 cjk_memory[409]=24'h000000;
 cjk_memory[410]=24'h000000;
 cjk_memory[411]=24'h000000;
 cjk_memory[412]=24'h000000;
 cjk_memory[413]=24'h000000;
 cjk_memory[414]=24'h000000;
 cjk_memory[415]=24'h000000;
 cjk_memory[416]=24'h000000;
 cjk_memory[417]=24'h000000;
 cjk_memory[418]=24'h000000;
 cjk_memory[419]=24'h000000;
 cjk_memory[420]=24'h000000;
 cjk_memory[421]=24'h000000;
 cjk_memory[422]=24'h000000;
 cjk_memory[423]=24'h000000;
 cjk_memory[424]=24'h000000;
 cjk_memory[425]=24'h000000;
 cjk_memory[426]=24'h000000;
 cjk_memory[427]=24'h000000;
 cjk_memory[428]=24'h000000;
 cjk_memory[429]=24'h000000;
 cjk_memory[430]=24'h000000;
 cjk_memory[431]=24'h000000;
 cjk_memory[432]=24'h000000;
 cjk_memory[433]=24'h000000;
 cjk_memory[434]=24'h000000;
 cjk_memory[435]=24'h000000;
 cjk_memory[436]=24'h000000;
 cjk_memory[437]=24'h000000;
 cjk_memory[438]=24'h000000;
 cjk_memory[439]=24'h000000;
 cjk_memory[440]=24'h000000;
 cjk_memory[441]=24'h000000;
 cjk_memory[442]=24'h000000;
 cjk_memory[443]=24'h000000;
 cjk_memory[444]=24'h000000;
 cjk_memory[445]=24'h000000;
 cjk_memory[446]=24'h000000;
 cjk_memory[447]=24'h000000;
 cjk_memory[448]=24'h000000;
 cjk_memory[449]=24'h000000;
 cjk_memory[450]=24'h000000;
 cjk_memory[451]=24'h000000;
 cjk_memory[452]=24'h000000;
 cjk_memory[453]=24'h000000;
 cjk_memory[454]=24'h000000;
 cjk_memory[455]=24'h000000;
 cjk_memory[456]=24'h000000;
 cjk_memory[457]=24'h000000;
 cjk_memory[458]=24'h000000;
 cjk_memory[459]=24'h000000;
 cjk_memory[460]=24'h000000;
 cjk_memory[461]=24'h000000;
 cjk_memory[462]=24'h000000;
 cjk_memory[463]=24'h000000;
 cjk_memory[464]=24'h000000;
 cjk_memory[465]=24'h000000;
 cjk_memory[466]=24'h000000;
 cjk_memory[467]=24'h000000;
 cjk_memory[468]=24'h000000;
 cjk_memory[469]=24'h000000;
 cjk_memory[470]=24'h000000;
 cjk_memory[471]=24'h000000;
 cjk_memory[472]=24'h000000;
 cjk_memory[473]=24'h000000;
 cjk_memory[474]=24'h000000;
 cjk_memory[475]=24'h000000;
 cjk_memory[476]=24'h000000;
 cjk_memory[477]=24'h000000;
 cjk_memory[478]=24'h000000;
 cjk_memory[479]=24'h000000;
 cjk_memory[480]=24'h000000;
 cjk_memory[481]=24'h000000;
 cjk_memory[482]=24'h000000;
 cjk_memory[483]=24'h000000;
 cjk_memory[484]=24'h000000;
 cjk_memory[485]=24'h000000;
 cjk_memory[486]=24'h000000;
 cjk_memory[487]=24'h000000;
 cjk_memory[488]=24'h000000;
 cjk_memory[489]=24'h000000;
 cjk_memory[490]=24'h000000;
 cjk_memory[491]=24'h000000;
 cjk_memory[492]=24'h000000;
 cjk_memory[493]=24'h000000;
 cjk_memory[494]=24'h000000;
 cjk_memory[495]=24'h000000;
 cjk_memory[496]=24'h000000;
 cjk_memory[497]=24'h000000;
 cjk_memory[498]=24'h000000;
 cjk_memory[499]=24'h000000;
 cjk_memory[500]=24'h000000;
 cjk_memory[501]=24'h000000;
 cjk_memory[502]=24'h000000;
 cjk_memory[503]=24'h000000;
 cjk_memory[504]=24'h000000;
 cjk_memory[505]=24'h000000;
 cjk_memory[506]=24'h000000;
 cjk_memory[507]=24'h000000;
 cjk_memory[508]=24'h000000;
 cjk_memory[509]=24'h000000;
 cjk_memory[510]=24'h000000;
 cjk_memory[511]=24'h000000;
end
always @(posedge clk)cjk_row<=cjk_memory[cjk_address];
osd_ascii_rom u_ascii(clk,ascii_address,ascii_row);
osd_logo_rom u_logo(clk,logo_address,logo_pixel);
reg [1:0] hs_p,vs_p,de_p,panel_p,logo_p,cjk_p;reg [4:0] col0,col1;
reg [23:0] rgb0,rgb1,ink0,ink1;
wire ink=cjk_p[1] ? (col1<24 && cjk_row[23-col1]) : (col1<8 && ascii_row[7-col1]);
wire [5:0] logo_y=(y-8)*2;wire [6:0] logo_x=(x-16)*2;
always @(posedge clk or negedge rst_n)begin
 if(!rst_n)begin
  ascii_address<=0;cjk_address<=0;logo_address<=0;hs_p<=0;vs_p<=0;de_p<=0;panel_p<=0;logo_p<=0;cjk_p<=0;
  col0<=0;col1<=0;rgb0<=0;rgb1<=0;ink0<=0;ink1<=0;out_vs<=0;out_hs<=0;out_de<=0;out_rgb<=0;
 end else begin
  ascii_address<={glyph,row[3:0]};cjk_address<={glyph[3:0],row};logo_address<={logo_y,logo_x};
  hs_p<={hs_p[0],hs};vs_p<={vs_p[0],vs};de_p<={de_p[0],de};panel_p<={panel_p[0],de && panel};logo_p<={logo_p[0],logo};cjk_p<={cjk_p[0],cjk};
  col0<=col;col1<=col0;rgb0<=picture;rgb1<=rgb0;ink0<=ink_color;ink1<=ink0;
  out_vs<=vs_p[1];out_hs<=hs_p[1];out_de<=de_p[1];
  out_rgb<=ENABLE && panel_p[1] ? (logo_p[1] ? (logo_pixel==1 ? 24'h204686 : logo_pixel==2 ? 24'hcc253b : 24'hffffff) : ink ? ink1 : 24'h142336) : rgb1;
 end
end
endmodule
