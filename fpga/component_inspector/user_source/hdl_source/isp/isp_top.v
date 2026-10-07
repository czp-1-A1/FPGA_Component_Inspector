module isp_top #(
    parameter WIDTH=1024,HEIGHT=600,ENABLE_EDGE=1,
    parameter VIEW_X0=256,VIEW_X1=768,VIEW_Y0=172,VIEW_Y1=428,
    parameter ROI_X0=472,ROI_X1=552,ROI_Y0=260,ROI_Y1=340
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
    output [82:0] observation_record,
    output [27:0] display_record
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
    .IMG_HEIGHT          (HEIGHT),  // 图像高度
    .IMG_WIDTH           (WIDTH),   // 图像宽度
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

awb #(
    .IMG_HEIGHT(HEIGHT),
    .IMG_WIDTH (WIDTH)
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
    .O_tready(awb_O_tready)
);

reg [17:0] observation_tag;
always @(posedge axi4s_video_aclk or negedge I_rst_n) begin
 if(!I_rst_n) observation_tag<=0;
 else if(raw_start) observation_tag<=observation_request;
end
wire observation_match=observation_tag==observation_request || raw_start;
wire [95:0] view_rgb;
wire view_frame_bad;
wire [31:0] view_timing;
wire [12:0] edge_pixels,edge_count;
wire [23:0] edge_sum;
roi_sobel_view #(.WIDTH(WIDTH),.HEIGHT(HEIGHT),.X0(VIEW_X0),.X1(VIEW_X1),.Y0(VIEW_Y0),.Y1(VIEW_Y1),.CORE_X0(ROI_X0),.CORE_X1(ROI_X1),.CORE_Y0(ROI_Y0),.CORE_Y1(ROI_Y1)) u_roi_sobel_view(
 .clk(axi4s_video_aclk),.rst_n(I_rst_n),.pixel_valid(awb_O_tvalid),
 .pixel_sof(awb_pixel_sof),.pixel_last(awb_O_tlast),.early_sof(awb_O_tuser),
 .rgb(awb_O_tdata),.mode({(observation_tag[1] && ENABLE_EDGE),observation_tag[0]}),.invalidate(sample_cancel),
 .view_ready(view_ready),.frame_bad(view_frame_bad),
 .out_valid(view_valid),.out_last(view_last),.out_early_sof(view_early),.out_rgb(view_rgb),
 .out_x(),.out_y(),.core_pixels(edge_pixels),.edge_count(edge_count),.edge_sum(edge_sum),.timing_debug(view_timing));
roi_observation_snapshot #(.CORE_AREA((ROI_X1-ROI_X0)*(ROI_Y1-ROI_Y0))) u_roi_observation_snapshot(
 .clk(axi4s_video_aclk),.rst_n(I_rst_n),.invalidate(sample_cancel),.tag(observation_tag),
 .legacy_record(display_record),.core_pixels(edge_pixels),.edge_count(edge_count),.edge_sum(edge_sum),
 .record(observation_record));
wire [$clog2(WIDTH+1)-1:0] roi_x;
wire [$clog2(HEIGHT+1)-1:0] roi_y;
wire roi_accept,roi_commit,roi_invalidate,sample_new;
// Cancel pending statistics on native FS, including an old in-flight division.
assign sample_cancel=roi_invalidate || !config_ok || |lane_error || !observation_match;
roi_frame_guard #(.WIDTH(WIDTH),.HEIGHT(HEIGHT)) u_roi_guard(
    .clk(axi4s_video_aclk),.rst_n(I_rst_n),
    .raw_start(raw_start),.raw_end(raw_end),.hs_valid(hs_valid),.raw_valid(raw_valid),
    .lane_error(lane_error),.config_ok(config_ok && observation_match),
    .pixel_valid(awb_O_tvalid),.pixel_sof(awb_pixel_sof),.pixel_last(awb_O_tlast),
    .pixel_x(roi_x),.pixel_y(roi_y),.pixel_accept(roi_accept),
    .frame_commit(roi_commit),.invalidate(roi_invalidate));
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
roi_statistics #(.WIDTH(WIDTH),.HEIGHT(HEIGHT),.X0(ROI_X0),.X1(ROI_X1),.Y0(ROI_Y0),.Y1(ROI_Y1)) u_roi_statistics(
    .clk(axi4s_video_aclk),.rst_n(I_rst_n),.pixel_accept(roi_accept),.pixel_sof(awb_pixel_sof),
    .pixel_x(roi_x),.pixel_y(roi_y),.rgb(awb_O_tdata),
    .frame_commit(roi_commit),.invalidate(sample_cancel),.sample_valid(sample_valid),
    .mean(sample_mean),.minimum(sample_min),.maximum(sample_max),.sample_pixels(),.sample_sum(),.sample_new(sample_new),.frame_start(raw_start));
roi_classifier u_roi_classifier(
    .clk(axi4s_video_aclk),.rst_n(I_rst_n),.calibration_ok(calibration_ok),
    .frame_start(raw_start),.invalidate(sample_cancel),.sample_valid(sample_valid),.sample_new(sample_new),
    .mean(sample_mean),.threshold(threshold),.present_high(present_high),.state(class_state));
roi_result_snapshot u_roi_result_snapshot(
    .clk(axi4s_video_aclk),.rst_n(I_rst_n),.frame_start(raw_start),.invalidate(sample_cancel),
    .calibration_ok(calibration_ok),.sample_valid(sample_valid),.sample_new(sample_new),
    .class_state(class_state),.mean(sample_mean),.minimum(sample_min),.maximum(sample_max),
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
