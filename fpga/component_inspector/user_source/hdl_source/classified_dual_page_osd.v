// Original page is the unchanged 5509006 experiment_osd module. Page selection changes only in vertical blank.
// Sampling UI. Three pixel clocks for RGB, DE, HS, VS and ENABLE bypass.
module classified_dual_page_osd #(
 parameter COMPACT_UI=0,CLASSIFIED_COUNT=0,RESULT_RECORDER=0,LOCAL_RECOVERY=0,MULTITHRESHOLD_EMPTY=0,WIDTH=1024,HEIGHT=600,DIAG_BITS=26,RESOLUTION_V11=0,REGIONS=0,CALIBRATION=0,
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
 input wire [3:0] local_wait_reason,
 input wire [255:0] count_live_record,count_frame_record,input wire count_eligible,
 input wire count_page_switch
);
wire lv,lh,ld;wire [23:0] legacy_rgb;
reg page_s,vs_d;
(* async_reg="true" *) reg [1:0] page_sync;
reg [19:0] page_debounce;reg page_stable;
always @(posedge clk or negedge rst_n)begin
 if(!rst_n)begin page_s<=0;vs_d<=0;page_sync<=3;page_debounce<=0;page_stable<=1;end
 else begin
  page_sync<={page_sync[0],count_page_switch};
  if(page_sync[1]==page_stable)page_debounce<=0;
  else if(page_debounce==742499)begin page_stable<=page_sync[1];page_debounce<=0;end
  else page_debounce<=page_debounce+1'b1;
  vs_d<=vs;if(vs && !vs_d)page_s<=CLASSIFIED_COUNT && !page_stable;
 end
end
experiment_osd #(.WIDTH(WIDTH),.HEIGHT(HEIGHT),.DIAG_BITS(DIAG_BITS),.RESOLUTION_V11(RESOLUTION_V11),.REGIONS(REGIONS),.CALIBRATION(CALIBRATION),.LOCAL_SEARCH(LOCAL_SEARCH),.SHAPE_MODEL(SHAPE_MODEL),.TRACKING(TRACKING),.MULTI_POCKETS(MULTI_POCKETS),.DIRECT_DETECTION(DIRECT_DETECTION),.CLASS_THRESHOLD(CLASS_THRESHOLD),.ENABLE(ENABLE),.ROI_X0(ROI_X0),.ROI_X1(ROI_X1),.ROI_Y0(ROI_Y0),.ROI_Y1(ROI_Y1),.SAMPLE_X0(SAMPLE_X0),.SAMPLE_X1(SAMPLE_X1),.SAMPLE_Y0(SAMPLE_Y0),.SAMPLE_Y1(SAMPLE_Y1),.HOLE_Y(HOLE_Y),.FRAME_OBJECTS(FRAME_OBJECTS)) original(
 .clk(clk),
 .rst_n(rst_n),
 .vs(vs),
 .hs(hs),
 .de(de),
 .rgb(rgb),
 .exposure(exposure),
 .gain(gain),
 .wb_r(wb_r),
 .wb_b(wb_b),
 .wb_tune(wb_tune),
 .wb_pending(wb_pending),
 .view_mode(view_mode),
 .edge_count(edge_count),
 .edge_sum(edge_sum),
 .local_box_valid(local_box_valid),
 .local_x0(local_x0),
 .local_x1(local_x1),
 .local_y0(local_y0),
 .local_y1(local_y1),
 .roi_valid(roi_valid),
 .roi_mean(roi_mean),
 .roi_min(roi_min),
 .roi_max(roi_max),
 .roi_state(roi_state),
 .width(width),
 .height(height),
 .fps(fps),
 .lane_errors(lane_errors),
 .format_errors(format_errors),
 .i2c_errors(i2c_errors),
 .gaps(gaps),
 .frames(frames),
 .uptime(uptime),
 .cfg_done(cfg_done),
 .overflow_frames(overflow_frames),
 .lost_frames(lost_frames),
 .underflow_frames(underflow_frames),
 .diagnostics(diagnostics),
 .publish_diagnostic(publish_diagnostic),
 .pocket_records(pocket_records),
 .pocket_enable(pocket_enable),
 .track_valid(track_valid),
 .track_x0(track_x0),
 .track_x1(track_x1),
 .track_reason(track_reason),
 .track_rows(track_rows),
 .out_vs(lv),
 .out_hs(lh),
 .out_de(ld),
 .out_rgb(legacy_rgb),
 .frame_objects(frame_objects),
 .calibration_record(calibration_record),
 .calibration_valid(calibration_valid),
 .local_wait_reason(local_wait_reason));
wire cv,ch,cd,count_logo;wire [23:0] count_rgb;
generate if(CLASSIFIED_COUNT && !COMPACT_UI)begin : counting_page
 classified_count_renderer #(.WIDTH(WIDTH),.HEIGHT(HEIGHT),.RECORD_ONLY(RESULT_RECORDER),.RECOVERABLE(RESULT_RECORDER),.LOCAL_RECOVERY(LOCAL_RECOVERY),.MULTITHRESHOLD_EMPTY(MULTITHRESHOLD_EMPTY)) render(
 .clk(clk),.rst_n(rst_n),.vs(vs),.hs(hs),.de(de),.rgb(rgb),
 .live_record(count_live_record),.frame_record(count_frame_record),.objects(frame_objects),.eligible(count_eligible),
 .exposure(exposure),.gain(gain),.fps(fps),
 .out_vs(cv),.out_hs(ch),.out_de(cd),.original_logo(count_logo),.out_rgb(count_rgb));
end else begin
 assign cv=0;assign ch=0;assign cd=0;assign count_logo=0;assign count_rgb=0;
end endgenerate
generate if(COMPACT_UI)begin : compact_page
 compact_inspector_osd #(.WIDTH(WIDTH),.HEIGHT(HEIGHT),.DIAG_BITS(DIAG_BITS),.ENABLE(ENABLE)) render(
 .clk(clk),.rst_n(rst_n),.vs(vs),.hs(hs),.de(de),.rgb(rgb),.page(page_s),
 .exposure(exposure),.gain(gain),.fps(fps),.width(width),.height(height),
 .wb_r(wb_r),.wb_b(wb_b),.roi_mean(roi_mean),.roi_min(roi_min),.roi_max(roi_max),
 .wb_tune(wb_tune),.wb_pending(wb_pending),.roi_valid(roi_valid),.cfg_done(cfg_done),
 .view_mode(view_mode),.edge_count(edge_count),.lane_errors(lane_errors),.format_errors(format_errors),
 .i2c_errors(i2c_errors),.gaps(gaps),.overflow_frames(overflow_frames),.lost_frames(lost_frames),.underflow_frames(underflow_frames),
 .frames(frames),.diagnostics(diagnostics),.publish_diagnostic(publish_diagnostic),.objects(frame_objects),
 .calibration_record(calibration_record),.calibration_valid(calibration_valid),.local_wait_reason(local_wait_reason),
 .live_record(count_live_record),.frame_record(count_frame_record),.eligible(count_eligible),
 .out_vs(out_vs),.out_hs(out_hs),.out_de(out_de),.out_rgb(out_rgb));
end else begin : unchanged_pages
 assign out_vs=lv;assign out_hs=lh;assign out_de=ld;
 assign out_rgb=page_s && !count_logo ? count_rgb : legacy_rgb;
end endgenerate
endmodule
