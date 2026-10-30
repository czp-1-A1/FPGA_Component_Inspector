module isp_top #(
    parameter INPUT_WIDTH=1024,INPUT_HEIGHT=600,WIDTH=INPUT_WIDTH,HEIGHT=INPUT_HEIGHT,SCALE_DISPLAY=0,
    parameter ASYNC_PROCESSING=0,TRACKING=0,DIRECT_DETECTION=0,SHAPE_MODEL=0,LOCAL_SEARCH=0,ROI_X0=472,ROI_X1=552,ROI_Y0=260,ROI_Y1=340,
    parameter PRESENT_TRACE=0,
    parameter HOLE_Y=220,LATE_HOLE=0,MULTI_POCKETS=0,REGIONS=0,CALIBRATION=0,LOCAL_EDGE_ASSIST=0,EMPTY_TRACE=0,ROBUST_EMPTY_CONTEXT=0,ROBUST_SMALL_EMPTY=0,STANDING_REVIEW=0,SURFACE_REVIEW=0,REVIEW_PROBE=0,CLASSIFIED_COUNT=0,RESULT_RECORDER=0,LOCAL_RECOVERY=0,MULTITHRESHOLD_EMPTY=0,
    parameter DUAL_REGION_COUNT=0,COUNT_BITS=256*(1+DUAL_REGION_COUNT),
    parameter META_WIDTH=178+340*MULTI_POCKETS+(172+152*REGIONS)*LOCAL_SEARCH+129*CALIBRATION+COUNT_BITS*CLASSIFIED_COUNT
) (
    input processing_clk,
    input [16:0] count_command,output [COUNT_BITS-1:0] count_live,
    // Processing-clock events for a downstream recorder/transport. Two lanes
    // can assert together; a consumer must accept both, with no backpressure.
    output [DUAL_REGION_COUNT:0] count_event_valid,
    output [16*(1+DUAL_REGION_COUNT)-1:0] count_event_run,
    output [9*(1+DUAL_REGION_COUNT)-1:0] count_event_id,
    output [32*(1+DUAL_REGION_COUNT)-1:0] count_event_frame,
    output [2*(1+DUAL_REGION_COUNT)-1:0] count_event_kind,
    output [4*(1+DUAL_REGION_COUNT)-1:0] count_event_reason,
    input 			axi4s_video_aclk,
    input 			I_rst_n			,
    input 			I_tlast			,
    input 			I_tuser			,
    input [39:0] 	I_tdata			,
    input 			I_tvalid		,
    input [9:0] 	I_tdest			,
    input 			O_tready		,
    output [127:0] 	O_tdata			,
    output 			O_tlast			,
    output 			O_tuser			,
    output 			O_tvalid		,
    output 			I_tready,
    input view_ready,output reg video_frame_good,output reg video_frame_bad,
    output reg [35:0] video_diagnostics,
    input raw_start,raw_end,hs_valid,raw_valid,config_ok,
    input [1:0] lane_error,
    output sample_valid,
    output [7:0] sample_mean,sample_min,sample_max,
    input calibration_ok,present_high,input [7:0] threshold,
    output [1:0] class_state,
    input [17:0] observation_request,
    input [31:0] wb_request,output [31:0] wb_active,
    output [114:0] observation_record,
    output [27:0] display_record,
    input [31:0] image_config,output reg [META_WIDTH-1:0] frame_metadata,output reg frame_metadata_ready
);
 
wire         m_aixs_tvalid;  //synthesis keep 
  wire [127:0] m_aixs_tdata;  //synthesis keep 
  wire         m_aixs_tuser;  //synthesis keep 
  wire         m_aixs_tlast;  //synthesis keep 
  wire         m_aixs_tready;  //synthesis keep 
  
  wire [ 95:0] m_aixs_tdata_96;  //synthesis keep 


  wire         awb_O_tlast;  //synthesis keep 
  wire         awb_O_tuser;  //synthesis keep 
  wire         awb_pixel_sof;
  wire [ 95:0] awb_O_tdata;  //synthesis keep 
  wire         awb_O_tvalid;  //synthesis keep 
  wire         awb_O_tready;  //synthesis keep 

  wire         awb_O_tuser_128;  //synthesis keep 
  wire         awb_O_tvalid_128;  //synthesis keep 
  wire [127:0] awb_O_tdata_128;  //synthesis keep 
wire view_valid,view_last,view_early,sample_cancel;

  assign awb_O_tready = O_tready;
  assign O_tdata  = awb_O_tdata_128;
  assign O_tlast  = view_last    ;
  assign O_tuser  = awb_O_tuser_128    ;
  assign O_tvalid = awb_O_tvalid_128   ;
  
  //assign m_aixs_tready = O_tready;
  //assign O_tdata  = m_aixs_tdata;
  //assign O_tlast  = m_aixs_tlast    ;
  //assign O_tuser  = m_aixs_tuser    ;
  //assign O_tvalid = m_aixs_tvalid   ;
 
 
demosaic #(
    .IMG_HEIGHT          (INPUT_HEIGHT),  // 图像高度
    .IMG_WIDTH           (INPUT_WIDTH),   // 图像宽度
    .data_complete_delay (50  ),
    .BAYER_MODE          ("BGGR")
)
u_demosaic
(
    .I_clk   			(axi4s_video_aclk)	,   // 时钟信号
    .I_rst_n 			(I_rst_n)	,   // 复位信号，低有效
    .axi4s_video_tdata 	(I_tdata)	,  // AXI4-Stream视频数据
    .axi4s_video_tdest 	(I_tdest)	,
    .axi4s_video_tlast 	(I_tlast)	,  // 行结束信号
    .axi4s_video_tvalid	(I_tvalid)	,  // 数据有效信号
    .axi4s_video_tuser 	(I_tuser)	,  // 帧开始信号
    .axi4s_video_tready	(I_tready)	,  // 从模块准备好接受数据
    .O_tlast  			(m_aixs_tlast)	,  // 输出行结束信号
    .O_tuser  			(m_aixs_tuser)	,  // 输出帧开始信号
    .O_tdata  			(m_aixs_tdata)	,  // 输出数据
    .O_tvalid 			(m_aixs_tvalid)	,  // 输出数据有效信号
    .O_tready   		(m_aixs_tready)	   // 输出数据准备好信号
);
 
data128_96 u_data128_96 (
    .I_tdata(m_aixs_tdata),
    .O_tdata(m_aixs_tdata_96)
);

reg [31:0] wb_frame_request;
always @(posedge axi4s_video_aclk or negedge I_rst_n) begin
 if(!I_rst_n) wb_frame_request<=32'h00006464;
 else if(raw_start) wb_frame_request<=wb_request;
end
wire wb_match=wb_frame_request==wb_request || raw_start;
awb #(
    .IMG_HEIGHT(INPUT_HEIGHT),
    .IMG_WIDTH (INPUT_WIDTH),
    .MANUAL_GAIN(1) // Frame-held Q2.6 red/blue gains; green remains unity.
) u_awb (
    .I_clk   (axi4s_video_aclk),
    .I_rst_n (I_rst_n),
    .I_tlast (m_aixs_tlast),
    .I_tuser (m_aixs_tuser),
    .I_tdata (m_aixs_tdata_96),
    .I_tvalid(m_aixs_tvalid),
    .I_tready(m_aixs_tready),
    .O_tlast (awb_O_tlast ),
    .O_tuser (awb_O_tuser ),
    .O_pixel_sof(awb_pixel_sof),
    .O_tdata (awb_O_tdata ),
    .O_tvalid(awb_O_tvalid),
    .O_tready(awb_O_tready),
    .I_wb_request(wb_frame_request),.O_wb_active(wb_active)
);

reg [17:0] observation_tag;
always @(posedge axi4s_video_aclk or negedge I_rst_n) begin
 if(!I_rst_n) observation_tag<=0;
 else if(raw_start) observation_tag<=observation_request;
end
wire observation_match=observation_tag==observation_request || raw_start;
wire [10:0] track_x0,track_x1;wire [9:0] track_y0,track_y1;wire track_locked;
wire [7:0] track_diagnostic;
wire [95:0] view_rgb;
wire view_frame_bad;
wire [31:0] view_timing;
wire [12:0] edge_pixels,edge_count;
wire [23:0] edge_sum;
wire gradient_valid;wire [10:0] gradient_x;wire [9:0] gradient_y;
wire [43:0] gradient_magnitudes;wire [3:0] gradient_neighborhood;
wire [339:0] pocket_records;wire multi_new;
wire [43:0] pocket_x0;wire [39:0] pocket_y0;wire [3:0] pocket_mask,pocket_verified;
localparam USE_SHAPE=SHAPE_MODEL && DIRECT_DETECTION && !TRACKING && !MULTI_POCKETS;
localparam USE_SEARCH=LOCAL_SEARCH && USE_SHAPE;
wire roi_accept,roi_commit,roi_invalidate,sample_new;
wire [10:0] roi_x;wire [$clog2(INPUT_HEIGHT+1)-1:0] roi_y;
// Once native and processed completeness have both committed, this source
// epoch is closed. The legacy demosaic can emit idle replay beats in long
// vertical blanking; do not let them revoke a proved frame while full-frame
// analysis is running. Native packet/config/error checks remain active.
reg frame_input_closed;
always @(posedge axi4s_video_aclk or negedge I_rst_n)begin
 if(!I_rst_n)frame_input_closed<=0;
 else if(raw_start)frame_input_closed<=0;
 else if(USE_SEARCH && roi_commit)frame_input_closed<=1;
end
wire source_pixel_valid=awb_O_tvalid && !frame_input_closed;
wire source_pixel_sof=awb_pixel_sof && !frame_input_closed;
wire [(REGIONS ? 304 : 152)-1:0] search_objects;
wire [151:0] legacy_search_objects;wire [303:0] region_search_objects;
assign search_objects=REGIONS ? region_search_objects : legacy_search_objects;
wire search_probe_ready;wire [127:0] search_probe_record;
wire search_ready,search_new,search_located,search_review;wire [1:0] search_state;
wire [12:0] search_fg;wire [6:0] search_w,search_h;
wire [10:0] search_x0,search_x1;wire [9:0] search_y0,search_y1;
wire shape_valid;wire [1:0] shape_state;wire [12:0] shape_foreground;wire [6:0] shape_width,shape_height;
wire [36:0] shape_features={1'b0,(USE_SEARCH && search_review),shape_foreground,shape_width,shape_height,8'd100};
wire [1:0] legacy_mode_class;
wire legacy_valid,legacy_new;wire [7:0] legacy_mean,legacy_min,legacy_max;wire [1:0] legacy_class;
// Native packet proof is never inferred from FIFO output or pixel count alone.
roi_frame_guard #(.WIDTH(INPUT_WIDTH),.HEIGHT(INPUT_HEIGHT)) u_roi_guard(
    .clk(axi4s_video_aclk),.rst_n(I_rst_n),
    .raw_start(raw_start),.raw_end(raw_end),.hs_valid(hs_valid),.raw_valid(raw_valid),
    .lane_error(lane_error),.config_ok(config_ok && observation_match),
    .pixel_valid(source_pixel_valid),.pixel_sof(source_pixel_sof),.pixel_last(awb_O_tlast),
    .pixel_x(roi_x),.pixel_y(roi_y),.pixel_accept(roi_accept),
    .frame_commit(roi_commit),.invalidate(roi_invalidate));
wire native_cancel=roi_invalidate || !config_ok || |lane_error || !observation_match || !wb_match;
wire [3:0] native_video_fault={(roi_invalidate && !raw_start),(|lane_error),!config_ok,1'b0};
wire post_clk=ASYNC_PROCESSING ? processing_clk : axi4s_video_aclk;
wire post_start,native_early,native_valid,native_sof,native_last,native_accept,native_commit,post_cancel,post_overflow;
wire [95:0] native_rgb;wire [3:0] post_native_fault;
wire [10:0] native_x;wire [$clog2(INPUT_HEIGHT+1)-1:0] native_y;
wire [17:0] post_tag;wire [31:0] post_wb,post_config;
generate if(ASYNC_PROCESSING)begin : continuous_processing
 reg cancel_d;reg [3:0] fault_d;
 always @(posedge axi4s_video_aclk or negedge I_rst_n)begin
  if(!I_rst_n)begin cancel_d<=0;fault_d<=0;end
  else begin cancel_d<=native_cancel;fault_d<=native_video_fault;end
 end
 wire [127:0] received;wire received_valid;
 wire send_event=raw_start || (awb_O_tuser && !frame_input_closed) || source_pixel_valid || roi_commit ||
  native_cancel!=cancel_d || native_video_fault!=fault_d;
 wire [115:0] payload=raw_start ? {33'd0,image_config,wb_request,observation_request,config_ok} : {20'd0,awb_O_tdata};
 frame_process_bridge bridge(.source_clk(axi4s_video_aclk),.process_clk(processing_clk),.rst_n(I_rst_n),
  .source_data({raw_start,(awb_O_tuser && !frame_input_closed),source_pixel_valid,source_pixel_sof,awb_O_tlast,
   roi_accept,roi_commit,native_cancel,native_video_fault,payload}),.source_valid(send_event),
  .process_data(received),.process_valid(received_valid),.process_overflow(post_overflow));
 assign {post_start,native_early,native_valid,native_sof,native_last,native_accept,native_commit,post_cancel,post_native_fault}=
  received_valid ? received[127:116] : 12'd0;
 assign native_rgb=received[95:0];
 reg [17:0] tag;reg [31:0] wb,cfg;
 reg [10:0] x;reg [$clog2(INPUT_HEIGHT+1)-1:0] y;
 always @(posedge processing_clk or negedge I_rst_n)begin
  if(!I_rst_n)begin tag<=0;wb<=32'h00006464;cfg<=0;x<=0;y<=0;end
  else begin
   if(post_start)begin tag<=received[18:1];wb<=received[50:19];cfg<=received[82:51];x<=0;y<=0;end
   if(native_sof && native_valid)begin x<=4;y<=0;end
   else if(native_valid)begin
    if(native_last)begin x<=0;y<=y+1'b1;end else x<=x+11'd4;
   end
  end
 end
 assign native_x=native_sof ? 11'd0 : x;assign native_y=native_sof ? 10'd0 : y;
 assign post_tag=post_start ? received[18:1] : tag;
 assign post_wb=post_start ? received[50:19] : wb;
 assign post_config=post_start ? received[82:51] : cfg;
end else begin : native_processing
 assign post_start=raw_start;assign native_early=awb_O_tuser && !frame_input_closed;
 assign native_valid=source_pixel_valid;assign native_sof=source_pixel_sof;assign native_last=awb_O_tlast;
 assign native_accept=roi_accept;assign native_commit=roi_commit;assign post_cancel=native_cancel;assign post_overflow=0;
 assign native_rgb=awb_O_tdata;assign post_native_fault=native_video_fault;
 assign native_x=roi_x;assign native_y=roi_y;assign post_tag=observation_tag;assign post_wb=wb_frame_request;assign post_config=image_config;
end endgenerate

wire post_early,post_valid,post_sof,post_last,post_accept,post_commit;
wire [95:0] post_rgb;wire [10:0] post_x;wire [9:0] post_y;
wire scale_bad;
generate if(SCALE_DISPLAY)begin : scaled_processing
 wire scaled_early,scaled_valid,scaled_last;wire [95:0] scaled_rgb;
 wire scale_bad_resize,scale_bad_guard;
 rgb_resize_2_3 #(.WIDTH(INPUT_WIDTH),.HEIGHT(INPUT_HEIGHT)) resize(
  .clk(post_clk),.rst_n(I_rst_n),.early_sof(native_early),
  .valid(native_valid && native_accept),.last(native_last),.rgb(native_rgb),
  .out_early_sof(scaled_early),.out_valid(scaled_valid),.out_last(scaled_last),
  .out_rgb(scaled_rgb),.frame_bad(scale_bad_resize));
 scaled_frame_guard #(.WIDTH(WIDTH),.HEIGHT(HEIGHT)) guard(
  .clk(post_clk),.rst_n(I_rst_n),.early_sof(scaled_early),
  .valid(scaled_valid),.last(scaled_last),.native_commit(native_commit),
  .invalidate((|post_native_fault) || post_overflow || scale_bad_resize),
  .pixel_accept(post_accept),.pixel_sof(post_sof),.x(post_x),.y(post_y),
  .frame_commit(post_commit),.frame_bad(scale_bad_guard));
 assign post_rgb=scaled_rgb;assign post_valid=post_accept;
 assign post_last=scaled_last;assign post_early=scaled_early;
 assign scale_bad=scale_bad_resize || scale_bad_guard;
end else begin : unscaled_processing
 assign post_early=native_early;assign post_valid=native_valid;
 assign post_sof=native_sof;assign post_last=native_last;
 assign post_accept=native_accept;assign post_commit=native_commit;
 assign post_rgb=native_rgb;assign post_x=native_x;assign post_y=native_y;
 assign scale_bad=0;
end endgenerate
roi_sobel_view #(.CACHE_ADDRESS_XOR(RESULT_RECORDER),.WIDTH(WIDTH),.HEIGHT(HEIGHT),.X0(USE_SEARCH ? 0 : MULTI_POCKETS ? 96 : 256),.X1(USE_SEARCH ? WIDTH : MULTI_POCKETS ? 928 : 768),.Y0(USE_SEARCH ? 0 : 172),.Y1(USE_SEARCH ? HEIGHT : MULTI_POCKETS ? 464 : 428),.DYNAMIC_ROI(TRACKING),.CORE_X0(ROI_X0),.CORE_X1(ROI_X1),.CORE_Y0(ROI_Y0),.CORE_Y1(ROI_Y1)) u_roi_sobel_view(
 .dynamic_x0(track_x0),.dynamic_x1(track_x1),.dynamic_y0(track_y0),.dynamic_y1(track_y1),
 .clk(post_clk),.rst_n(I_rst_n),.pixel_valid(post_valid),
 .pixel_sof(post_sof),.pixel_last(post_last),.early_sof(post_early),
 .rgb(post_rgb),.mode(post_tag[1:0]),.invalidate(sample_cancel),
 .view_ready(view_ready),.frame_bad(view_frame_bad),
 .out_valid(view_valid),.out_last(view_last),.out_early_sof(view_early),.out_rgb(view_rgb),
 .gradient_valid(gradient_valid),.gradient_x(gradient_x),.gradient_y(gradient_y),
 .gradient_magnitudes(gradient_magnitudes),.gradient_neighborhood(gradient_neighborhood),
 .out_x(),.out_y(),.core_pixels(edge_pixels),.edge_count(edge_count),.edge_sum(edge_sum),.timing_debug(view_timing));
roi_observation_snapshot #(.SHAPE_MODEL(USE_SHAPE),.CORE_AREA((ROI_X1-ROI_X0)*(ROI_Y1-ROI_Y0))) u_roi_observation_snapshot(
 .clk(post_clk),.rst_n(I_rst_n),.invalidate(sample_cancel),.tag(post_tag),.wb_tag(post_wb),
 .legacy_record(display_record),.core_pixels(edge_pixels),.edge_count(edge_count),.edge_sum(edge_sum),
 .model_valid(shape_valid),.model_features(shape_features),.record(observation_record));
// Finish features while CSI is still clocking rows, not after native FE.
// The upper hole search and the lower core's Sobel neighborhood finish here.
// These are provisional results: the writer still requires the entire frame.
localparam RESULT_ROW=MULTI_POCKETS ? 456 : (HOLE_Y+10>ROI_Y1+2) ? HOLE_Y+10 : ROI_Y1+2;
wire result_commit=USE_SEARCH ? search_new : TRACKING ? (post_accept && post_x==0 && post_y==RESULT_ROW) : post_commit;
wire result_valid;
assign sample_valid=result_valid && (!TRACKING || video_frame_good);
wire [1:0] result_class;
assign class_state=TRACKING && !video_frame_good ? 2'd1 : result_class;
// Cancel pending statistics on native FS, including an old in-flight division.
assign sample_cancel=post_cancel || post_overflow || scale_bad;
// Tracking coordinates become immutable after the hole search and before core Y0.
generate if(MULTI_POCKETS) begin : multi_tracking
 multi_pocket_tracker tracker(
  .clk(post_clk),.rst_n(I_rst_n),.frame_start(post_start),.pixel_sof(post_sof),
  .accept(post_accept),.frame_commit(post_commit),.invalidate(sample_cancel),.x(post_x),.y(post_y),.rgb(post_rgb),
  .sample_x0(pocket_x0),.sample_y0(pocket_y0),.sample_mask(pocket_mask),.verified_mask(pocket_verified),.located(),.diagnostic(track_diagnostic));
 assign track_x0=pocket_x0[10:0];assign track_x1=pocket_x0[10:0]+11'd80;
 assign track_y0=pocket_y0[9:0];assign track_y1=pocket_y0[9:0]+10'd80;assign track_locked=|pocket_verified;
 multi_pocket_statistics statistics(
  .clk(post_clk),.rst_n(I_rst_n),.frame_start(post_start),.pixel_sof(post_sof),.accept(post_accept),
  .commit(result_commit),.invalidate(sample_cancel),.x(post_x),.y(post_y),.rgb(post_rgb),
  .x0(pocket_x0),.y0(pocket_y0),.sample_mask(pocket_mask),.verified_mask(pocket_verified),
  .edge_valid(gradient_valid),.edge_x(gradient_x),.edge_y(gradient_y),.magnitudes(gradient_magnitudes),.edge_neighborhood(gradient_neighborhood),
  .mode(post_tag[1:0]),.calibration_ok(calibration_ok),.present_high(present_high),.threshold(threshold),
  .records(pocket_records),.sample_new(multi_new));
end else begin : legacy_geometry
 assign pocket_records=0;assign multi_new=0;assign pocket_x0=0;assign pocket_y0=0;assign pocket_mask=0;assign pocket_verified=0;
 if(TRACKING) begin : tracking
 tape_hole_tracker #(.HOLE_Y(HOLE_Y),.LATE_HOLE(LATE_HOLE),.ROI_W(ROI_X1-ROI_X0),.ROI_Y0(ROI_Y0),.ROI_Y1(ROI_Y1)) tracker(
  .clk(post_clk),.rst_n(I_rst_n),.frame_start(post_start),.pixel_sof(post_sof),
  .pixel_accept(post_accept),.frame_commit(post_commit),.invalidate(sample_cancel),
  .pixel_x(post_x),.pixel_y(post_y),.rgb(post_rgb),.frame_locked(track_locked),
  .roi_x0(track_x0),.roi_x1(track_x1),.roi_y0(track_y0),.roi_y1(track_y1),.located(),.diagnostic(track_diagnostic));
end else begin : static_roi
 assign track_x0=ROI_X0;assign track_x1=ROI_X1;assign track_y0=ROI_Y0;assign track_y1=ROI_Y1;assign track_locked=1'b1;
 assign track_diagnostic=0;
end
end endgenerate
// The result settles after the ROI/search rows and the 28-cycle divider.
// Freeze it early; frame proof, word count and epoch still gate publication.
wire [COUNT_BITS-1:0] classified_record;wire classified_ready;wire [31:0] search_empty_probe;wire [607:0] recorder_candidates;wire [1:0] recorder_hold_valid;wire [21:0] recorder_hold_x;wire [19:0] recorder_hold_y;
generate if(CLASSIFIED_COUNT)begin : classified_counting
 reg pixels_started;
 always @(posedge post_clk or negedge I_rst_n)begin
  if(!I_rst_n)pixels_started<=0;
  else if(post_start)pixels_started<=0;
  else if(post_early)pixels_started<=1;
 end
 // Empty scenes can finish analysis before the native packet proof arrives.
 // The detector holds its objects until FS/cancel; retain that notification
 // and release it only after proof of this same source epoch.
 reg count_frame_proved,count_result_pending;
 wire count_sample_new=count_frame_proved && search_ready &&
  (search_new || count_result_pending) && !post_start && !post_early &&
  !sample_cancel && !video_frame_bad;
 always @(posedge post_clk or negedge I_rst_n)begin
  if(!I_rst_n)begin count_frame_proved<=0;count_result_pending<=0;end
  else if(post_start || post_early || sample_cancel || (pixels_started && video_frame_bad))begin
   count_frame_proved<=0;count_result_pending<=0;
  end else begin
   if(post_commit && !video_frame_bad)count_frame_proved<=1;
   if(count_sample_new)count_result_pending<=0;
   else if(search_new)count_result_pending<=1;
  end
 end
 wire [152*(RESULT_RECORDER ? 4 : 2)-1:0] count_candidates;
 if(RESULT_RECORDER)assign count_candidates=recorder_candidates;else assign count_candidates=region_search_objects;
 if(DUAL_REGION_COUNT)begin : dual_regions
 dual_region_count_pipeline #(.LINE_X(WIDTH/2),.DIAGNOSTICS(!RESULT_RECORDER),.RECORD_ONLY(RESULT_RECORDER),.MOTION_RECOVERY(RESULT_RECORDER),.TAIL_RECOVERY(RESULT_RECORDER),.OBS_PER_REGION(RESULT_RECORDER ? 4 : 2),.ORDERED_HANDOFF(RESULT_RECORDER),.RECOVERABLE(RESULT_RECORDER),.VELOCITY_ASSOC(RESULT_RECORDER),.LOCAL_RECOVERY(LOCAL_RECOVERY)) pipeline(
  .clk(post_clk),.rst_n(I_rst_n),.source_start(post_start),.frame_commit(post_commit && !video_frame_bad),
  .frame_bad(pixels_started && video_frame_bad && !post_start && !post_early),.sample_new(count_sample_new),
  .config_tag({post_config,post_wb}),.objects(count_candidates),.empty_probe(search_empty_probe),.command(count_command),
  .frame_record(classified_record),.record_ready(classified_ready),.live_record(count_live),
  .event_valid(count_event_valid),.event_run(count_event_run),.event_id(count_event_id),.event_frame(count_event_frame),.event_kind(count_event_kind),.event_reason(count_event_reason),
  .hold_valid(recorder_hold_valid),.hold_x(recorder_hold_x),.hold_y(recorder_hold_y));
 end else begin : single_region
 classified_count_pipeline #(.LINE_X(WIDTH/2),.DIAGNOSTICS(!RESULT_RECORDER),.RECORD_ONLY(RESULT_RECORDER),.MOTION_RECOVERY(RESULT_RECORDER),.TAIL_RECOVERY(RESULT_RECORDER),.OBS_PER_REGION(RESULT_RECORDER ? 4 : 2),.ORDERED_HANDOFF(RESULT_RECORDER),.RECOVERABLE(RESULT_RECORDER),.VELOCITY_ASSOC(RESULT_RECORDER),.LOCAL_RECOVERY(LOCAL_RECOVERY)) pipeline(
  .clk(post_clk),.rst_n(I_rst_n),.source_start(post_start),.frame_commit(post_commit && !video_frame_bad),
  .frame_bad(pixels_started && video_frame_bad && !post_start && !post_early),.sample_new(count_sample_new),
  .config_tag({post_config,post_wb}),.objects(count_candidates),.empty_probe(search_empty_probe),.command(count_command),
  .frame_record(classified_record),.record_ready(classified_ready),.live_record(count_live),
  .event_valid(count_event_valid),.event_run(count_event_run),.event_id(count_event_id),.event_frame(count_event_frame),.event_kind(count_event_kind),.event_reason(count_event_reason),
  .hold_valid(recorder_hold_valid[0]),.hold_x(recorder_hold_x[10:0]),.hold_y(recorder_hold_y[9:0]));
 assign recorder_hold_valid[1]=0;assign recorder_hold_x[21:11]=0;assign recorder_hold_y[19:10]=0;
 end
end else begin : no_classified_counting
 assign classified_record=0;assign classified_ready=1;assign count_live=0;assign recorder_hold_valid=0;assign recorder_hold_x=0;assign recorder_hold_y=0;
 assign count_event_valid=0;assign count_event_run=0;assign count_event_id=0;
 assign count_event_frame=0;assign count_event_kind=0;assign count_event_reason=0;
end endgenerate
localparam ORIGINAL_META_WIDTH=META_WIDTH-COUNT_BITS*CLASSIFIED_COUNT;
reg [7:0] metadata_wait;reg metadata_pending;reg [31:0] frame_config;
wire [127:0] calibration_record;
generate if((PRESENT_TRACE || EMPTY_TRACE || REVIEW_PROBE) && REGIONS)begin : review_calibration_measurement
 assign calibration_record=search_probe_record;
end else if(CALIBRATION)begin : calibration_measurement
 calibration_probes #(.WIDTH(WIDTH),.HEIGHT(HEIGHT)) probes(
  .clk(post_clk),.rst_n(I_rst_n),.frame_start(post_start),.invalidate(sample_cancel),
  .accept(post_accept),.commit(post_commit),.x(post_x),.y(post_y),.rgb(post_rgb),.mode(post_tag[1:0]),.record(calibration_record));
end else begin : no_calibration_measurement
 assign calibration_record=0;
end endgenerate
always @(posedge post_clk or negedge I_rst_n) begin
 if(!I_rst_n) begin frame_metadata<=0;frame_metadata_ready<=0;metadata_wait<=0;metadata_pending<=0;frame_config<=0;end
 else if(post_start) begin frame_metadata_ready<=0;metadata_pending<=0;frame_config<=post_config;end
 else if(sample_cancel) begin frame_metadata_ready<=0;metadata_pending<=0;end
 else if(result_commit) begin metadata_pending<=1;metadata_wait<=MULTI_POCKETS ? 192 : 48;end
 else if(metadata_pending) begin
  if(metadata_wait>1)metadata_wait<=metadata_wait-1'b1;
  if(metadata_wait==1 && (!CLASSIFIED_COUNT || classified_ready) && (!REVIEW_PROBE || search_probe_ready)) begin
   // Frame configuration tags exist even if the first pocket has no valid sample.
   // Other pockets must not be hidden by the first pocket's missing history tag.
   if(MULTI_POCKETS) frame_metadata<={pocket_records,track_diagnostic,frame_config,track_locked,track_x0,track_x1,
    post_wb,observation_record[82:46],post_tag,observation_record[27:0]};
   else if(USE_SEARCH) frame_metadata<={search_objects,search_y0,search_y1,4'd0,4'd0,frame_config,search_located,search_x0,search_x1,observation_record};
   else frame_metadata<={track_diagnostic,frame_config,track_locked,track_x0,track_x1,observation_record};
   // Low metadata fields retain their V12 layout. The extension travels in
   // the SAME slot/epoch/late-attachment/VS snapshot as all four detections.
   if(CALIBRATION)frame_metadata[ORIGINAL_META_WIDTH-1 -:129]<={1'b1,calibration_record};
   if(CLASSIFIED_COUNT)frame_metadata[META_WIDTH-1 -:COUNT_BITS]<=classified_record;
   frame_metadata_ready<=1;metadata_pending<=0;
  end
 end
end
// Capture proof belongs to the AWB early-FS epoch, not the native FS that
// precedes it. A normal next FS must not revoke an old, completed edge tail.
wire [3:0] video_fault=post_native_fault | {3'd0,(view_frame_bad || post_overflow || scale_bad)};
reg [3:0] video_reject_reason;
always @(posedge post_clk or negedge I_rst_n) begin
 if(!I_rst_n) begin video_frame_good<=0;video_frame_bad<=0;video_reject_reason<=0;video_diagnostics<=0;end
 else if(post_early) begin
  video_frame_good<=0;video_frame_bad<=0;video_reject_reason<=0;
  video_diagnostics<={video_reject_reason,view_timing};
 end
 else if(|video_fault) begin
  video_frame_good<=0;video_frame_bad<=1;
  video_reject_reason<=video_reject_reason | video_fault;
 end else if(post_commit && !video_frame_bad) video_frame_good<=1;
end
roi_statistics #(.DYNAMIC_ROI(TRACKING),.X0(ROI_X0),.X1(ROI_X1),.Y0(ROI_Y0),.Y1(ROI_Y1)) u_roi_statistics(
 .dynamic_x0(track_x0),.dynamic_x1(track_x1),.dynamic_y0(track_y0),.dynamic_y1(track_y1),
    .clk(post_clk),.rst_n(I_rst_n),.pixel_accept(post_accept),.pixel_sof(post_sof),
    .pixel_x(post_x),.pixel_y(post_y),.rgb(post_rgb),
    .frame_commit(result_commit),.invalidate(sample_cancel),.sample_valid(legacy_valid),
    .mean(legacy_mean),.minimum(legacy_min),.maximum(legacy_max),.sample_pixels(),.sample_sum(),.sample_new(legacy_new),.frame_start(post_start));
generate if(USE_SEARCH) begin : local_shape_detection
 frame_shape_search #(.SPARSE_ROW_SCAN(DUAL_REGION_COUNT),.DUAL_REGION_COUNT(DUAL_REGION_COUNT),.PRESENT_TRACE(PRESENT_TRACE),.LOCAL_EDGE_ASSIST(LOCAL_EDGE_ASSIST),.EMPTY_TRACE(EMPTY_TRACE),.ROBUST_EMPTY_CONTEXT(ROBUST_EMPTY_CONTEXT),.ROBUST_SMALL_EMPTY(ROBUST_SMALL_EMPTY),.STANDING_REVIEW(STANDING_REVIEW),.SURFACE_REVIEW(SURFACE_REVIEW),.REVIEW_PROBE(REVIEW_PROBE),.WIDTH(WIDTH),.HEIGHT(HEIGHT),.REGIONS(REGIONS),.COUNT_EMPTY_MARGIN(CLASSIFIED_COUNT),.EMPTY_DIAGNOSTICS(CLASSIFIED_COUNT && !RESULT_RECORDER),.ROW_GUARDED_BRIGHT_EMPTY(CLASSIFIED_COUNT),.COUNT_CANDIDATES(RESULT_RECORDER),.MULTITHRESHOLD_EMPTY(MULTITHRESHOLD_EMPTY)) detector(.clk(post_clk),.rst_n(I_rst_n),.frame_start(post_start),.pixel_sof(post_sof),
  .pixel_accept(post_accept),.invalidate(sample_cancel),.pixel_x(post_x),.pixel_y(post_y),.rgb(post_rgb),
  .ready(search_ready),.sample_new(search_new),.located(search_located),.state(search_state),.foreground_count(search_fg),
  .box_width(search_w),.box_height(search_h),.box_x0(search_x0),.box_x1(search_x1),.box_y0(search_y0),.box_y1(search_y1),.review_required(search_review),.objects(legacy_search_objects),.region_objects(region_search_objects),.empty_probe(search_empty_probe),.recorder_objects(recorder_candidates),.recorder_hold_valid(recorder_hold_valid[0]),.recorder_hold_x(recorder_hold_x[10:0]),.recorder_hold_y(recorder_hold_y[9:0]),.recorder_hold_valid2(recorder_hold_valid[1]),.recorder_hold_x2(recorder_hold_x[21:11]),.recorder_hold_y2(recorder_hold_y[19:10]),.probe_record(search_probe_record),.probe_ready(search_probe_ready));
end else begin : no_local_search
 assign search_probe_record=0;assign search_probe_ready=1;
 assign legacy_search_objects=0;assign region_search_objects=0;assign recorder_candidates=0;assign search_empty_probe=0;assign search_ready=0;assign search_new=0;assign search_located=0;assign search_state=1;assign search_review=0;
 assign search_fg=0;assign search_w=0;assign search_h=0;assign search_x0=0;assign search_x1=0;assign search_y0=0;assign search_y1=0;
end
if(USE_SEARCH) begin : search_features
 assign shape_valid=search_ready;assign shape_state=search_state;assign shape_foreground=search_fg;assign shape_width=search_w;assign shape_height=search_h;
end else if(USE_SHAPE) begin : shape_detection
 roi_shape_model #(.X0(ROI_X0),.X1(ROI_X1),.Y0(ROI_Y0),.Y1(ROI_Y1)) detector(
  .clk(post_clk),.rst_n(I_rst_n),.frame_start(post_start),.pixel_accept(post_accept),.pixel_sof(post_sof),
  .pixel_x(post_x),.pixel_y(post_y),.rgb(post_rgb),.frame_commit(result_commit),.invalidate(sample_cancel),
  .valid(shape_valid),.state(shape_state),.foreground_count(shape_foreground),.box_width(shape_width),.box_height(shape_height));
end else begin : no_shape_detection
 assign shape_valid=0;assign shape_state=1;assign shape_foreground=0;assign shape_width=0;assign shape_height=0;
end endgenerate
wire scene_ok;
wire [1:0] gray_class_state;
roi_tape_guard #(.DYNAMIC_ROI(TRACKING),.X0(ROI_X0),.X1(ROI_X1),.Y0(ROI_Y0),.Y1(ROI_Y1)) u_roi_tape_guard(
 .dynamic_x0(track_x0),.dynamic_x1(track_x1),.dynamic_y0(track_y0),.dynamic_y1(track_y1),
    .clk(post_clk),.rst_n(I_rst_n),.pixel_accept(post_accept),.pixel_sof(post_sof),
    .pixel_x(post_x),.pixel_y(post_y),.rgb(post_rgb),.frame_start(post_start),
    .invalidate(sample_cancel),.scene_ok(scene_ok));
roi_classifier u_roi_classifier(
    .clk(post_clk),.rst_n(I_rst_n),.calibration_ok(calibration_ok),
    .frame_start(post_start),.invalidate(sample_cancel),.sample_valid(legacy_valid),.sample_new(legacy_new),
    .mean(legacy_mean),.threshold(threshold),.present_high(present_high),.state(gray_class_state));
// Direct fixed-core trials use the complete sample, independent of hole search
// and dark reference strips. The operator aligns a real pocket in the cyan box.
roi_mode_classifier #(.FUSE_FEATURES(!DIRECT_DETECTION),.CORE_AREA((ROI_X1-ROI_X0)*(ROI_Y1-ROI_Y0))) u_roi_mode_classifier(
    .mode(post_tag[1:0]),.gray_state(gray_class_state),.scene_ok(DIRECT_DETECTION || (scene_ok && (!TRACKING || track_locked))),
    .core_pixels(edge_pixels),.edge_count(edge_count),.edge_sum(edge_sum),.state(legacy_mode_class));
assign legacy_class=USE_SHAPE ? ((post_start || sample_cancel || !calibration_ok || !legacy_valid || !shape_valid) ? 2'd1 : (!USE_SEARCH && !scene_ok) ? 2'd0 : shape_state) : legacy_mode_class;
assign result_valid=MULTI_POCKETS ? pocket_records[63] : legacy_valid;
assign sample_new=MULTI_POCKETS ? multi_new : legacy_new;
assign sample_mean=MULTI_POCKETS ? pocket_records[60:53] : legacy_mean;
assign sample_min=MULTI_POCKETS ? pocket_records[52:45] : legacy_min;
assign sample_max=MULTI_POCKETS ? pocket_records[44:37] : legacy_max;
assign result_class=MULTI_POCKETS ? pocket_records[62:61] : legacy_class;
roi_result_snapshot u_roi_result_snapshot(
    .clk(post_clk),.rst_n(I_rst_n),.frame_start(post_start),.invalidate(sample_cancel),
    .calibration_ok(calibration_ok),.sample_valid(result_valid),.sample_new(sample_new),
    .class_state(result_class),.mean(sample_mean),.minimum(sample_min),.maximum(sample_max),
    .record(display_record));

    generate if(SCALE_DISPLAY)begin : gap_safe_pack
     rgb96_packetizer pack(.clk(post_clk),.rst_n(I_rst_n),.early_sof(view_early),
      .valid(view_valid),.rgb(view_rgb),.frame_start(awb_O_tuser_128),
      .out_valid(awb_O_tvalid_128),.data(awb_O_tdata_128));
    end else begin : legacy_pack
    data_96bit_to_128bit u_data_96bit_to_128bit(
        .I_clk              ( post_clk  ),
        .I_rst_n            ( I_rst_n           ),
	
        .I_96b_frame_start  ( view_early        ),
        .I_96b_valid        ( view_valid        ),
        .I_96b_data         ( view_rgb          ),
	
        .O_128b_frame_start ( awb_O_tuser_128  	),
        .O_128b_valid       ( awb_O_tvalid_128 	),
        .O_128b_data        ( awb_O_tdata_128  	)
    );
    end endgenerate



//data96_128 u_data96_128 (
//    .I_tdata(post_rgb),
//    .O_tdata(awb_O_tdata_128)
//);
	
endmodule
