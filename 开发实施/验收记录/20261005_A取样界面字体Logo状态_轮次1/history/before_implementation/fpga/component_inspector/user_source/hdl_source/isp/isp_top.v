module isp_top #(
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
    input raw_start,raw_end,hs_valid,raw_valid,config_ok,
    input [1:0] lane_error,
    output sample_valid,
    output [7:0] sample_mean,sample_min,sample_max,
    input calibration_ok,present_high,input [7:0] threshold,
    output [1:0] class_state
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

  assign awb_O_tready = O_tready;
  assign O_tdata  = awb_O_tdata_128;
  assign O_tlast  = awb_O_tlast    ;
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

awb #(
    .IMG_HEIGHT(600),
    .IMG_WIDTH (1024)
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

wire [10:0] roi_x;
wire [9:0] roi_y;
wire roi_accept,roi_commit,roi_invalidate,sample_new;
// Cancel pending statistics on native FS, including an old in-flight division.
wire sample_cancel=roi_invalidate || !config_ok || |lane_error;
roi_frame_guard u_roi_guard(
    .clk(axi4s_video_aclk),.rst_n(I_rst_n),
    .raw_start(raw_start),.raw_end(raw_end),.hs_valid(hs_valid),.raw_valid(raw_valid),
    .lane_error(lane_error),.config_ok(config_ok),
    .pixel_valid(awb_O_tvalid),.pixel_sof(awb_pixel_sof),.pixel_last(awb_O_tlast),
    .pixel_x(roi_x),.pixel_y(roi_y),.pixel_accept(roi_accept),
    .frame_commit(roi_commit),.invalidate(roi_invalidate));
roi_statistics #(.X0(ROI_X0),.X1(ROI_X1),.Y0(ROI_Y0),.Y1(ROI_Y1)) u_roi_statistics(
    .clk(axi4s_video_aclk),.rst_n(I_rst_n),.pixel_accept(roi_accept),.pixel_sof(awb_pixel_sof),
    .pixel_x(roi_x),.pixel_y(roi_y),.rgb(awb_O_tdata),
    .frame_commit(roi_commit),.invalidate(sample_cancel),.sample_valid(sample_valid),
    .mean(sample_mean),.minimum(sample_min),.maximum(sample_max),.sample_pixels(),.sample_sum(),.sample_new(sample_new),.frame_start(raw_start));
roi_classifier u_roi_classifier(
    .clk(axi4s_video_aclk),.rst_n(I_rst_n),.calibration_ok(calibration_ok),
    .frame_start(raw_start),.invalidate(sample_cancel),.sample_valid(sample_valid),.sample_new(sample_new),
    .mean(sample_mean),.threshold(threshold),.present_high(present_high),.state(class_state));

    data_96bit_to_128bit u_data_96bit_to_128bit(
        .I_clk              ( axi4s_video_aclk  ),
        .I_rst_n            ( I_rst_n           ),
	
        .I_96b_frame_start  ( awb_O_tuser	    ),
        .I_96b_valid        ( awb_O_tvalid 		),
        .I_96b_data         ( awb_O_tdata		),
	
        .O_128b_frame_start ( awb_O_tuser_128  	),
        .O_128b_valid       ( awb_O_tvalid_128 	),
        .O_128b_data        ( awb_O_tdata_128  	)
    );



//data96_128 u_data96_128 (
//    .I_tdata(awb_O_tdata),
//    .O_tdata(awb_O_tdata_128)
//);
	
endmodule
