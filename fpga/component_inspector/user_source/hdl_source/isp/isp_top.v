module isp_top #(
    parameter TRACKING=0,DIRECT_DETECTION=0,ROI_X0=472,ROI_X1=552,ROI_Y0=260,ROI_Y1=340,
    parameter HOLE_Y=220,LATE_HOLE=0,MULTI_POCKETS=0,
    parameter META_WIDTH=178+340*MULTI_POCKETS
) (
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
    .IMG_HEIGHT          (600),  // 图像高度
    .IMG_WIDTH           (1024),   // 图像宽度
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
    .IMG_HEIGHT(600),
    .IMG_WIDTH (1024),
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
wire legacy_valid,legacy_new;wire [7:0] legacy_mean,legacy_min,legacy_max;wire [1:0] legacy_class;
roi_sobel_view #(.X0(MULTI_POCKETS ? 96 : 256),.X1(MULTI_POCKETS ? 928 : 768),.Y1(MULTI_POCKETS ? 464 : 428),.DYNAMIC_ROI(TRACKING),.CORE_X0(ROI_X0),.CORE_X1(ROI_X1),.CORE_Y0(ROI_Y0),.CORE_Y1(ROI_Y1)) u_roi_sobel_view(
 .dynamic_x0(track_x0),.dynamic_x1(track_x1),.dynamic_y0(track_y0),.dynamic_y1(track_y1),
 .clk(axi4s_video_aclk),.rst_n(I_rst_n),.pixel_valid(awb_O_tvalid),
 .pixel_sof(awb_pixel_sof),.pixel_last(awb_O_tlast),.early_sof(awb_O_tuser),
 .rgb(awb_O_tdata),.mode(observation_tag[1:0]),.invalidate(sample_cancel),
 .view_ready(view_ready),.frame_bad(view_frame_bad),
 .out_valid(view_valid),.out_last(view_last),.out_early_sof(view_early),.out_rgb(view_rgb),
 .gradient_valid(gradient_valid),.gradient_x(gradient_x),.gradient_y(gradient_y),
 .gradient_magnitudes(gradient_magnitudes),.gradient_neighborhood(gradient_neighborhood),
 .out_x(),.out_y(),.core_pixels(edge_pixels),.edge_count(edge_count),.edge_sum(edge_sum),.timing_debug(view_timing));
roi_observation_snapshot #(.CORE_AREA((ROI_X1-ROI_X0)*(ROI_Y1-ROI_Y0))) u_roi_observation_snapshot(
 .clk(axi4s_video_aclk),.rst_n(I_rst_n),.invalidate(sample_cancel),.tag(observation_tag),.wb_tag(wb_frame_request),
 .legacy_record(display_record),.core_pixels(edge_pixels),.edge_count(edge_count),.edge_sum(edge_sum),
 .record(observation_record));
wire [10:0] roi_x;
wire [9:0] roi_y;
wire roi_accept,roi_commit,roi_invalidate,sample_new;
// Finish features while CSI is still clocking rows, not after native FE.
// The upper hole search and the lower core's Sobel neighborhood finish here.
// These are provisional results: the writer still requires the entire frame.
localparam RESULT_ROW=MULTI_POCKETS ? 456 : (HOLE_Y+10>ROI_Y1+2) ? HOLE_Y+10 : ROI_Y1+2;
wire result_commit=TRACKING ? (roi_accept && roi_x==0 && roi_y==RESULT_ROW) : roi_commit;
wire result_valid;
assign sample_valid=result_valid && (!TRACKING || video_frame_good);
wire [1:0] result_class;
assign class_state=TRACKING && !video_frame_good ? 2'd1 : result_class;
// Cancel pending statistics on native FS, including an old in-flight division.
assign sample_cancel=roi_invalidate || !config_ok || |lane_error || !observation_match || !wb_match;
roi_frame_guard u_roi_guard(
    .clk(axi4s_video_aclk),.rst_n(I_rst_n),
    .raw_start(raw_start),.raw_end(raw_end),.hs_valid(hs_valid),.raw_valid(raw_valid),
    .lane_error(lane_error),.config_ok(config_ok && observation_match),
    .pixel_valid(awb_O_tvalid),.pixel_sof(awb_pixel_sof),.pixel_last(awb_O_tlast),
    .pixel_x(roi_x),.pixel_y(roi_y),.pixel_accept(roi_accept),
    .frame_commit(roi_commit),.invalidate(roi_invalidate));
// Tracking coordinates become immutable after the hole search and before core Y0.
generate if(MULTI_POCKETS) begin : multi_tracking
 multi_pocket_tracker tracker(
  .clk(axi4s_video_aclk),.rst_n(I_rst_n),.frame_start(raw_start),.pixel_sof(awb_pixel_sof),
  .accept(roi_accept),.frame_commit(roi_commit),.invalidate(sample_cancel),.x(roi_x),.y(roi_y),.rgb(awb_O_tdata),
  .sample_x0(pocket_x0),.sample_y0(pocket_y0),.sample_mask(pocket_mask),.verified_mask(pocket_verified),.located(),.diagnostic(track_diagnostic));
 assign track_x0=pocket_x0[10:0];assign track_x1=pocket_x0[10:0]+11'd80;
 assign track_y0=pocket_y0[9:0];assign track_y1=pocket_y0[9:0]+10'd80;assign track_locked=|pocket_verified;
 multi_pocket_statistics statistics(
  .clk(axi4s_video_aclk),.rst_n(I_rst_n),.frame_start(raw_start),.pixel_sof(awb_pixel_sof),.accept(roi_accept),
  .commit(result_commit),.invalidate(sample_cancel),.x(roi_x),.y(roi_y),.rgb(awb_O_tdata),
  .x0(pocket_x0),.y0(pocket_y0),.sample_mask(pocket_mask),.verified_mask(pocket_verified),
  .edge_valid(gradient_valid),.edge_x(gradient_x),.edge_y(gradient_y),.magnitudes(gradient_magnitudes),.edge_neighborhood(gradient_neighborhood),
  .mode(observation_tag[1:0]),.calibration_ok(calibration_ok),.present_high(present_high),.threshold(threshold),
  .records(pocket_records),.sample_new(multi_new));
end else begin : legacy_geometry
 assign pocket_records=0;assign multi_new=0;assign pocket_x0=0;assign pocket_y0=0;assign pocket_mask=0;assign pocket_verified=0;
 if(TRACKING) begin : tracking
 tape_hole_tracker #(.HOLE_Y(HOLE_Y),.LATE_HOLE(LATE_HOLE),.ROI_W(ROI_X1-ROI_X0),.ROI_Y0(ROI_Y0),.ROI_Y1(ROI_Y1)) tracker(
  .clk(axi4s_video_aclk),.rst_n(I_rst_n),.frame_start(raw_start),.pixel_sof(awb_pixel_sof),
  .pixel_accept(roi_accept),.frame_commit(roi_commit),.invalidate(sample_cancel),
  .pixel_x(roi_x),.pixel_y(roi_y),.rgb(awb_O_tdata),.frame_locked(track_locked),
  .roi_x0(track_x0),.roi_x1(track_x1),.roi_y0(track_y0),.roi_y1(track_y1),.located(),.diagnostic(track_diagnostic));
end else begin : static_roi
 assign track_x0=ROI_X0;assign track_x1=ROI_X1;assign track_y0=ROI_Y0;assign track_y1=ROI_Y1;assign track_locked=1'b1;
 assign track_diagnostic=0;
end
end endgenerate
// The result settles after the ROI/search rows and the 28-cycle divider.
// Freeze it early; frame proof, word count and epoch still gate publication.
reg [7:0] metadata_wait;reg metadata_pending;reg [31:0] frame_config;
always @(posedge axi4s_video_aclk or negedge I_rst_n) begin
 if(!I_rst_n) begin frame_metadata<=0;frame_metadata_ready<=0;metadata_wait<=0;metadata_pending<=0;frame_config<=0;end
 else if(raw_start) begin frame_metadata_ready<=0;metadata_pending<=0;frame_config<=image_config;end
 else if(sample_cancel) begin frame_metadata_ready<=0;metadata_pending<=0;end
 else if(result_commit) begin metadata_pending<=1;metadata_wait<=MULTI_POCKETS ? 192 : 48;end
 else if(metadata_pending) begin
  metadata_wait<=metadata_wait-1'b1;
  if(metadata_wait==1) begin
   // Frame configuration tags exist even if the first pocket has no valid sample.
   // Other pockets must not be hidden by the first pocket's missing history tag.
   if(MULTI_POCKETS) frame_metadata<={pocket_records,track_diagnostic,frame_config,track_locked,track_x0,track_x1,
    wb_frame_request,observation_record[82:46],observation_tag,observation_record[27:0]};
   else frame_metadata<={track_diagnostic,frame_config,track_locked,track_x0,track_x1,observation_record};
   frame_metadata_ready<=1;metadata_pending<=0;
  end
 end
end
// Capture proof belongs to the AWB early-FS epoch, not the native FS that
// precedes it. A normal next FS must not revoke an old, completed edge tail.
wire [3:0] video_fault={(roi_invalidate && !raw_start),(|lane_error),!config_ok,view_frame_bad};
reg [3:0] video_reject_reason;
always @(posedge axi4s_video_aclk or negedge I_rst_n) begin
 if(!I_rst_n) begin video_frame_good<=0;video_frame_bad<=0;video_reject_reason<=0;video_diagnostics<=0;end
 else if(awb_O_tuser) begin
  video_frame_good<=0;video_frame_bad<=0;video_reject_reason<=0;
  video_diagnostics<={video_reject_reason,view_timing};
 end
 else if(|video_fault) begin
  video_frame_good<=0;video_frame_bad<=1;
  video_reject_reason<=video_reject_reason | video_fault;
 end else if(roi_commit && !video_frame_bad) video_frame_good<=1;
end
roi_statistics #(.DYNAMIC_ROI(TRACKING),.X0(ROI_X0),.X1(ROI_X1),.Y0(ROI_Y0),.Y1(ROI_Y1)) u_roi_statistics(
 .dynamic_x0(track_x0),.dynamic_x1(track_x1),.dynamic_y0(track_y0),.dynamic_y1(track_y1),
    .clk(axi4s_video_aclk),.rst_n(I_rst_n),.pixel_accept(roi_accept),.pixel_sof(awb_pixel_sof),
    .pixel_x(roi_x),.pixel_y(roi_y),.rgb(awb_O_tdata),
    .frame_commit(result_commit),.invalidate(sample_cancel),.sample_valid(legacy_valid),
    .mean(legacy_mean),.minimum(legacy_min),.maximum(legacy_max),.sample_pixels(),.sample_sum(),.sample_new(legacy_new),.frame_start(raw_start));
wire scene_ok;
wire [1:0] gray_class_state;
roi_tape_guard #(.DYNAMIC_ROI(TRACKING),.X0(ROI_X0),.X1(ROI_X1),.Y0(ROI_Y0),.Y1(ROI_Y1)) u_roi_tape_guard(
 .dynamic_x0(track_x0),.dynamic_x1(track_x1),.dynamic_y0(track_y0),.dynamic_y1(track_y1),
    .clk(axi4s_video_aclk),.rst_n(I_rst_n),.pixel_accept(roi_accept),.pixel_sof(awb_pixel_sof),
    .pixel_x(roi_x),.pixel_y(roi_y),.rgb(awb_O_tdata),.frame_start(raw_start),
    .invalidate(sample_cancel),.scene_ok(scene_ok));
roi_classifier u_roi_classifier(
    .clk(axi4s_video_aclk),.rst_n(I_rst_n),.calibration_ok(calibration_ok),
    .frame_start(raw_start),.invalidate(sample_cancel),.sample_valid(legacy_valid),.sample_new(legacy_new),
    .mean(legacy_mean),.threshold(threshold),.present_high(present_high),.state(gray_class_state));
// Direct fixed-core trials use the complete sample, independent of hole search
// and dark reference strips. The operator aligns a real pocket in the cyan box.
roi_mode_classifier #(.FUSE_FEATURES(!DIRECT_DETECTION),.CORE_AREA((ROI_X1-ROI_X0)*(ROI_Y1-ROI_Y0))) u_roi_mode_classifier(
    .mode(observation_tag[1:0]),.gray_state(gray_class_state),.scene_ok(DIRECT_DETECTION || (scene_ok && (!TRACKING || track_locked))),
    .core_pixels(edge_pixels),.edge_count(edge_count),.edge_sum(edge_sum),.state(legacy_class));
assign result_valid=MULTI_POCKETS ? pocket_records[63] : legacy_valid;
assign sample_new=MULTI_POCKETS ? multi_new : legacy_new;
assign sample_mean=MULTI_POCKETS ? pocket_records[60:53] : legacy_mean;
assign sample_min=MULTI_POCKETS ? pocket_records[52:45] : legacy_min;
assign sample_max=MULTI_POCKETS ? pocket_records[44:37] : legacy_max;
assign result_class=MULTI_POCKETS ? pocket_records[62:61] : legacy_class;
roi_result_snapshot u_roi_result_snapshot(
    .clk(axi4s_video_aclk),.rst_n(I_rst_n),.frame_start(raw_start),.invalidate(sample_cancel),
    .calibration_ok(calibration_ok),.sample_valid(result_valid),.sample_new(sample_new),
    .class_state(result_class),.mean(sample_mean),.minimum(sample_min),.maximum(sample_max),
    .record(display_record));

    data_96bit_to_128bit u_data_96bit_to_128bit(
        .I_clk              ( axi4s_video_aclk  ),
        .I_rst_n            ( I_rst_n           ),
	
        .I_96b_frame_start  ( view_early        ),
        .I_96b_valid        ( view_valid        ),
        .I_96b_data         ( view_rgb          ),
	
        .O_128b_frame_start ( awb_O_tuser_128  	),
        .O_128b_valid       ( awb_O_tvalid_128 	),
        .O_128b_data        ( awb_O_tdata_128  	)
    );



//data96_128 u_data96_128 (
//    .I_tdata(awb_O_tdata),
//    .O_tdata(awb_O_tdata_128)
//);
	
endmodule
