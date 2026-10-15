

module design_top_wrapper #(parameter INPUT_WIDTH=1920,INPUT_HEIGHT=1080,VIDEO_WIDTH=1280,VIDEO_HEIGHT=720,
 parameter ENABLE_TRACKING=0,ENABLE_MULTI_POCKETS=0,ENABLE_SHAPE_MODEL=1,ENABLE_LOCAL_SEARCH=1) (
    input wire        I_sys_clk,
    input wire        I_rst_n,
      
    output wire       O_cam_scl,
    inout  wire       IO_cam_sda,
    output wire       O_cam_24m,
    output wire       O_cam_rst,
      
    input wire [3:0]  I_button,
    input wire [1:0]  I_switch,

    output wire       O_screen_pwm,
    output wire       O_tmds_ch0_p,
    output wire       O_tmds_ch1_p,
    output wire       O_tmds_ch2_p,
    output wire       O_tmds_clk_p,

    inout wire        IO_rx_clk_pad_n, 
    inout wire        IO_rx_clk_pad_p, 
    inout wire[3:0]   IO_rx_data_pad_n,
    inout wire[3:0]   IO_rx_data_pad_p,

    output wire[12:0] ddr_addr,
    output wire[ 1:0] ddr_ba,
    output wire[ 0:0] ddr_cke,
    output wire[ 0:0] ddr_odt,
    output wire[ 0:0] ddr_cs_n,
    output wire       ddr_ras_n,
    output wire       ddr_cas_n,
    output wire       ddr_we_n,
    output wire[ 0:0] ddr_ck_p,
    output wire[ 0:0] ddr_ck_n,
    inout wire[1:0]   ddr_dm,
    inout wire[15:0]  ddr_dq,
    inout wire[1:0]   ddr_dqs_p,
    inout wire[1:0]   ddr_dqs_n   
);


    wire        	S_100m_clk;
    wire        	S_24m_clk;
    wire        	S_aux_50m_clk;
	wire        	S_10m_clk;
	wire            S_process_clk;
		
	wire        	S_pll_lock;
    wire        	S_rst_n;
	
	wire [15:0] 	S_ae;
    wire [15:0] 	S_ag;
    wire 			S_cam_cfg_done;
    wire 			S_ae_cfg_done;
    wire [15:0] S_i2c_errors;
    wire 			S_ae_req; 
	
	wire        	S_csi_rx_clk;  
    wire        	S_hs_rx_valid;  
    wire[15:0]  	S_hs_rx_data;   
	wire[1:0]   	S_lane_error;
	
	wire        	S_csi_frame_start;       
	wire        	S_csi_frame_end;         
	wire        	S_csi_valid;             
	wire[31:0]  	S_csi_data;  
		
	wire        	S_raw10_frame_start; 
	wire        	S_raw10_frame_end;   
	wire        	S_raw10_valid;       
	wire [39:0] 	S_raw10_data;
		
	wire 			S_axis_tlast;  
	wire 			S_axis_tuser;  
	wire [39:0]		S_axis_tdata;  
	wire 			S_axis_tvalid; 
	
	wire [39:0]		S_raw_tdata ;
	wire			S_raw_tlast ;
	wire 			S_raw_tvalid;
	wire 			S_raw_tuser ;
	
	wire			S_ISP_O_tready;
	wire [127:0]	S_ISP_O_tdata ;
	wire 			S_ISP_O_tlast ;
	wire 			S_ISP_O_tuser ;
	wire 			S_ISP_O_tvalid; 
	

    wire        S_ddr_clk;
    wire        S_hdmi_pixel_clk;
    wire        S_hdmi_serial_clk;
    wire        S_hdmi_rst_n;
    wire        S_video_out_rst_n;


    wire        S_vi_128b_frame_start;
    wire        S_vi_128b_valid;      
    wire[127:0] S_vi_128b_data;    
    
    wire        S_video_out_rd_busy;
    wire        S_video_in_wr_busy; 
    wire[1:0]   S_video_out_rp;     

    wire        S_ddr_user_wr_en;       
    wire        S_ddr_user_rd_en;       
    wire[24:0]  S_ddr_user_addr;        
    wire[127:0] S_ddr_user_wr_data;     
    wire        S_ddr_user_ready;       
    wire        S_ddr_user_rd_valid;    
    wire[127:0] S_ddr_user_rd_data;     

    wire        S_vi_ddr_wr_en;   
    wire[24:0]  S_vi_ddr_wr_addr; 
    wire[127:0] S_vi_ddr_wr_data;
    wire        S_vi_ddr_wr_ready;

    wire        S_vo_ddr_rd_en;   
    wire[24:0]  S_vo_ddr_rd_addr; 
    wire        S_vo_ddr_rd_ready;
    wire        S_vo_dbg_fifo_rst;
    wire        S_vo_dbg_ddr_rd_valid;
    wire        S_vo_dbg_fifo_rd_en;
    wire        S_vo_dbg_fifo_empty;

    wire        S_init_calib_complete; 
    wire[24:0]  S_mc_app_addr;          
    wire[2:0]   S_mc_app_cmd;           
    wire        S_mc_app_en;            
    wire[127:0] S_mc_app_wdf_data;      
    wire        S_mc_app_wdf_end;       
    wire[15:0]  S_mc_app_wdf_mask;      
    wire        S_mc_app_wdf_wren;      
    wire[127:0] S_mc_app_rd_data;       
    wire        S_mc_app_rd_data_end;   
    wire        S_mc_app_rd_data_valid; 
    wire        S_mc_app_rdy;           
    wire        S_mc_app_wdf_rdy;       
    wire        S_mc_dbg_fifo_afull;
    wire        S_mc_dbg_app_rdy;
    wire        S_mc_dbg_wdf_rdy;
    wire        S_mc_dbg_cmd_pop;

    wire        S_hdmi_vsync;
    wire        S_hdmi_hsync;
    wire        S_hdmi_de;
    wire        S_hdmi_user;
    wire        S_hdmi_last;
    wire        S_video_out_vsync;
    wire        S_hdmi_window_rd_en;
    wire        S_hdmi_out_vsync;
    wire        S_hdmi_out_hsync;
    wire        S_hdmi_out_de;
    wire[23:0]  S_hdmi_out_data;

    wire[23:0]  S_video_rd_data;
    reg         S_dbg_raw_seen;
    reg         S_dbg_isp_seen;
    reg         S_dbg_ddr_wr_seen;
    reg         S_dbg_ddr_rd_seen;
    reg         S_dbg_cam_cfg_seen;
    reg         S_dbg_hs_seen;
    reg         S_dbg_csi_seen;
    reg         S_dbg_raw10_seen;
    reg         S_dbg_isp_fs_seen;
    reg         S_dbg_isp_valid_seen;
    reg         S_dbg_ddr_req_seen;
    reg         S_dbg_ddr_ready_seen;
    reg [1:0]   S_dbg_raw_seen_sync;
    reg [1:0]   S_dbg_isp_seen_sync;
    reg [1:0]   S_dbg_ddr_wr_seen_sync;
    reg [1:0]   S_dbg_ddr_rd_seen_sync;
    reg [1:0]   S_dbg_cam_cfg_seen_sync;
    reg [1:0]   S_dbg_hs_seen_sync;
    reg [1:0]   S_dbg_csi_seen_sync;
    reg [1:0]   S_dbg_raw10_seen_sync;
    reg [1:0]   S_dbg_isp_fs_seen_sync;
    reg [1:0]   S_dbg_isp_valid_seen_sync;
    reg [1:0]   S_dbg_ddr_req_seen_sync;
    reg [1:0]   S_dbg_ddr_ready_seen_sync;
    reg         S_dbg_video_nonzero_seen;
    reg         S_dbg_rd_req_seen;
    reg         S_dbg_rd_valid_seen;
    reg         S_dbg_rd_nonzero_seen;
    reg [1:0]   S_dbg_rd_req_seen_sync;
    reg [1:0]   S_dbg_rd_valid_seen_sync;
    reg [1:0]   S_dbg_rd_nonzero_seen_sync;
    reg         S_dbg_mc_init_seen;
    reg         S_dbg_mc_app_rdy_seen;
    reg         S_dbg_mc_wdf_rdy_seen;
    reg         S_dbg_mc_cmd_pop_seen;
    reg [1:0]   S_dbg_mc_init_seen_sync;
    reg [1:0]   S_dbg_mc_app_rdy_seen_sync;
    reg [1:0]   S_dbg_mc_wdf_rdy_seen_sync;
    reg [1:0]   S_dbg_mc_cmd_pop_seen_sync;
    wire[3:0]   S_hdmi_debug_status;
    wire        S_lane_error_any;


    assign O_screen_pwm = 1'b1;
    assign S_video_out_vsync = S_hdmi_vsync;
	
	
    assign S_rst_n 		= S_pll_lock;
    wire S_hdmi_pll_lock;
    wire S_hdmi_async_rst_n=S_rst_n && S_hdmi_pll_lock;
    reg [2:0] hdmi_reset_sync;
    always @(posedge S_hdmi_pixel_clk or negedge S_hdmi_async_rst_n)
     if(!S_hdmi_async_rst_n)hdmi_reset_sync<=0;
     else hdmi_reset_sync<={hdmi_reset_sync[1:0],1'b1};
    assign S_hdmi_rst_n=hdmi_reset_sync[2];

    always @(posedge S_csi_rx_clk or negedge S_rst_n) begin
        if(!S_rst_n)
            S_dbg_raw_seen <= 1'b0;
        else if(S_raw10_frame_start | S_axis_tvalid)
            S_dbg_raw_seen <= 1'b1;
    end

    always @(posedge S_process_clk or negedge S_rst_n) begin
        if(!S_rst_n)
            S_dbg_isp_seen <= 1'b0;
        else if(S_ISP_O_tuser | S_ISP_O_tvalid)
            S_dbg_isp_seen <= 1'b1;
    end

    always @(posedge S_ddr_clk or negedge S_rst_n) begin
        if(!S_rst_n)
            S_dbg_ddr_wr_seen <= 1'b0;
        else if(S_vi_ddr_wr_en)
            S_dbg_ddr_wr_seen <= 1'b1;
    end

    always @(posedge S_ddr_clk or negedge S_rst_n) begin
        if(!S_rst_n)
            S_dbg_ddr_rd_seen <= 1'b0;
        else if(S_ddr_user_rd_valid)
            S_dbg_ddr_rd_seen <= 1'b1;
    end

    always @(posedge S_24m_clk or negedge S_rst_n) begin
        if(!S_rst_n)
            S_dbg_cam_cfg_seen <= 1'b0;
        else if(S_cam_cfg_done)
            S_dbg_cam_cfg_seen <= 1'b1;
    end

    always @(posedge S_csi_rx_clk or negedge S_rst_n) begin
        if(!S_rst_n)
            S_dbg_hs_seen <= 1'b0;
        else if(S_hs_rx_valid)
            S_dbg_hs_seen <= 1'b1;
    end

    always @(posedge S_csi_rx_clk or negedge S_rst_n) begin
        if(!S_rst_n)
            S_dbg_csi_seen <= 1'b0;
        else if(S_csi_frame_start | S_csi_valid)
            S_dbg_csi_seen <= 1'b1;
    end

    always @(posedge S_csi_rx_clk or negedge S_rst_n) begin
        if(!S_rst_n)
            S_dbg_raw10_seen <= 1'b0;
        else if(S_raw10_frame_start | S_raw10_valid)
            S_dbg_raw10_seen <= 1'b1;
    end

    always @(posedge S_process_clk or negedge S_rst_n) begin
        if(!S_rst_n)
            S_dbg_isp_fs_seen <= 1'b0;
        else if(S_ISP_O_tuser)
            S_dbg_isp_fs_seen <= 1'b1;
    end

    always @(posedge S_process_clk or negedge S_rst_n) begin
        if(!S_rst_n)
            S_dbg_isp_valid_seen <= 1'b0;
        else if(S_ISP_O_tvalid)
            S_dbg_isp_valid_seen <= 1'b1;
    end

    always @(posedge S_ddr_clk or negedge S_rst_n) begin
        if(!S_rst_n)
            S_dbg_ddr_req_seen <= 1'b0;
        else if(S_vi_ddr_wr_en)
            S_dbg_ddr_req_seen <= 1'b1;
    end

    always @(posedge S_ddr_clk or negedge S_rst_n) begin
        if(!S_rst_n)
            S_dbg_ddr_ready_seen <= 1'b0;
        else if(S_ddr_user_ready)
            S_dbg_ddr_ready_seen <= 1'b1;
    end

    always @(posedge S_ddr_clk or negedge S_video_out_rst_n) begin
        if(!S_video_out_rst_n)
            S_dbg_rd_req_seen <= 1'b0;
        else if(S_video_out_vsync)
            S_dbg_rd_req_seen <= 1'b0;
        else if(S_vo_ddr_rd_en)
            S_dbg_rd_req_seen <= 1'b1;
    end

    always @(posedge S_ddr_clk or negedge S_video_out_rst_n) begin
        if(!S_video_out_rst_n)
            S_dbg_rd_valid_seen <= 1'b0;
        else if(S_video_out_vsync)
            S_dbg_rd_valid_seen <= 1'b0;
        else if(S_ddr_user_rd_valid)
            S_dbg_rd_valid_seen <= 1'b1;
    end

    always @(posedge S_hdmi_pixel_clk or negedge S_video_out_rst_n) begin
        if(!S_video_out_rst_n)
            S_dbg_rd_nonzero_seen <= 1'b0;
        else if(S_video_out_vsync)
            S_dbg_rd_nonzero_seen <= 1'b0;
        else if(S_hdmi_window_rd_en && (S_video_rd_data != 24'd0))
            S_dbg_rd_nonzero_seen <= 1'b1;
    end

    always @(posedge S_ddr_clk or negedge S_rst_n) begin
        if(!S_rst_n)
            S_dbg_mc_init_seen <= 1'b0;
        else if(S_init_calib_complete)
            S_dbg_mc_init_seen <= 1'b1;
    end

    always @(posedge S_ddr_clk or negedge S_rst_n) begin
        if(!S_rst_n)
            S_dbg_mc_app_rdy_seen <= 1'b0;
        else if(S_mc_dbg_app_rdy)
            S_dbg_mc_app_rdy_seen <= 1'b1;
    end

    always @(posedge S_ddr_clk or negedge S_rst_n) begin
        if(!S_rst_n)
            S_dbg_mc_wdf_rdy_seen <= 1'b0;
        else if(S_mc_dbg_wdf_rdy)
            S_dbg_mc_wdf_rdy_seen <= 1'b1;
    end

    always @(posedge S_ddr_clk or negedge S_rst_n) begin
        if(!S_rst_n)
            S_dbg_mc_cmd_pop_seen <= 1'b0;
        else if(S_mc_dbg_cmd_pop)
            S_dbg_mc_cmd_pop_seen <= 1'b1;
    end

    always @(posedge S_hdmi_pixel_clk or negedge S_hdmi_rst_n) begin
        if(!S_hdmi_rst_n) begin
            S_dbg_cam_cfg_seen_sync <= 2'b00;
            S_dbg_hs_seen_sync      <= 2'b00;
            S_dbg_csi_seen_sync     <= 2'b00;
            S_dbg_raw10_seen_sync   <= 2'b00;
            S_dbg_raw_seen_sync    <= 2'b00;
            S_dbg_isp_seen_sync    <= 2'b00;
            S_dbg_ddr_wr_seen_sync <= 2'b00;
            S_dbg_ddr_rd_seen_sync <= 2'b00;
            S_dbg_isp_fs_seen_sync  <= 2'b00;
            S_dbg_isp_valid_seen_sync <= 2'b00;
            S_dbg_ddr_req_seen_sync <= 2'b00;
            S_dbg_ddr_ready_seen_sync <= 2'b00;
            S_dbg_video_nonzero_seen <= 1'b0;
            S_dbg_rd_req_seen_sync <= 2'b00;
            S_dbg_rd_valid_seen_sync <= 2'b00;
            S_dbg_rd_nonzero_seen_sync <= 2'b00;
            S_dbg_mc_init_seen_sync <= 2'b00;
            S_dbg_mc_app_rdy_seen_sync <= 2'b00;
            S_dbg_mc_wdf_rdy_seen_sync <= 2'b00;
            S_dbg_mc_cmd_pop_seen_sync <= 2'b00;
        end
        else begin
            S_dbg_cam_cfg_seen_sync <= {S_dbg_cam_cfg_seen_sync[0], S_dbg_cam_cfg_seen};
            S_dbg_hs_seen_sync      <= {S_dbg_hs_seen_sync[0],      S_dbg_hs_seen};
            S_dbg_csi_seen_sync     <= {S_dbg_csi_seen_sync[0],     S_dbg_csi_seen};
            S_dbg_raw10_seen_sync   <= {S_dbg_raw10_seen_sync[0],   S_dbg_raw10_seen};
            S_dbg_raw_seen_sync    <= {S_dbg_raw_seen_sync[0],    S_dbg_raw_seen};
            S_dbg_isp_seen_sync    <= {S_dbg_isp_seen_sync[0],    S_dbg_isp_seen};
            S_dbg_ddr_wr_seen_sync <= {S_dbg_ddr_wr_seen_sync[0], S_dbg_ddr_wr_seen};
            S_dbg_ddr_rd_seen_sync <= {S_dbg_ddr_rd_seen_sync[0], S_dbg_ddr_rd_seen};
            S_dbg_isp_fs_seen_sync  <= {S_dbg_isp_fs_seen_sync[0],  S_dbg_isp_fs_seen};
            S_dbg_isp_valid_seen_sync <= {S_dbg_isp_valid_seen_sync[0], S_dbg_isp_valid_seen};
            S_dbg_ddr_req_seen_sync <= {S_dbg_ddr_req_seen_sync[0], S_dbg_ddr_req_seen};
            S_dbg_ddr_ready_seen_sync <= {S_dbg_ddr_ready_seen_sync[0], S_dbg_ddr_ready_seen};
            S_dbg_rd_req_seen_sync <= {S_dbg_rd_req_seen_sync[0], S_dbg_rd_req_seen};
            S_dbg_rd_valid_seen_sync <= {S_dbg_rd_valid_seen_sync[0], S_dbg_rd_valid_seen};
            S_dbg_rd_nonzero_seen_sync <= {S_dbg_rd_nonzero_seen_sync[0], S_dbg_rd_nonzero_seen};
            S_dbg_mc_init_seen_sync <= {S_dbg_mc_init_seen_sync[0], S_dbg_mc_init_seen};
            S_dbg_mc_app_rdy_seen_sync <= {S_dbg_mc_app_rdy_seen_sync[0], S_dbg_mc_app_rdy_seen};
            S_dbg_mc_wdf_rdy_seen_sync <= {S_dbg_mc_wdf_rdy_seen_sync[0], S_dbg_mc_wdf_rdy_seen};
            S_dbg_mc_cmd_pop_seen_sync <= {S_dbg_mc_cmd_pop_seen_sync[0], S_dbg_mc_cmd_pop_seen};
            if(S_hdmi_window_rd_en && (S_video_rd_data != 24'd0))
                S_dbg_video_nonzero_seen <= 1'b1;
        end
    end

    assign S_lane_error_any = |S_lane_error;

    assign S_vo_dbg_fifo_rst = 1'b0;
    assign S_vo_dbg_ddr_rd_valid = 1'b0;
    assign S_vo_dbg_fifo_rd_en = 1'b0;
    assign S_vo_dbg_fifo_empty = 1'b0;
    assign S_mc_dbg_fifo_afull = 1'b0;
    assign S_mc_dbg_app_rdy = 1'b0;
    assign S_mc_dbg_wdf_rdy = 1'b0;
    assign S_mc_dbg_cmd_pop = 1'b0;

    assign S_hdmi_debug_status = {
        (|S_ddr_user_rd_data),
        S_ddr_user_rd_valid,
        S_vo_ddr_rd_en,
        S_vi_ddr_wr_en
    };
	
	assign O_cam_rst 	= 1'b1;
    assign O_cam_24m 	= S_24m_clk;
	
	
	
	
    PLL u_PLL(
        .refclk      ( I_sys_clk         ),
        .reset    	 ( ~I_rst_n          ),
        
        .clk0_out    ( S_100m_clk        ),
        .clk1_out    ( S_24m_clk         ),

        .clk4_out    (                   ),
        .clk5_out    (                   ),

        .lock        ( S_pll_lock        )

    );


	

  
    HDMI_PLL u_hdmi_pll(.refclk(I_sys_clk),.reset(~I_rst_n),
     .clk0_out(S_hdmi_pixel_clk),.clk1_out(S_hdmi_serial_clk),.lock(S_hdmi_pll_lock));

  wire wb_tune;
  wire [31:0] wb_request,wb_active;
  ae_set u_ae_set (
      .I_clk(S_24m_clk),
      .I_rst(~S_rst_n),
      .I_btn(I_button),
      .I_cam_cfg_done(S_cam_cfg_done),
      .I_ae_cfg_done(S_ae_cfg_done),
      .O_ae_req(S_ae_req),
      .O_ae(S_ae),
      .O_ag(S_ag),.O_wb_tune(wb_tune),.O_wb_request(wb_request)
  );
  
    uicfgcs500 #(
      .CLK_DIV(24000000 / 100000 - 1)
  ) u_uicfgcs500 (
      .I_clk(S_24m_clk),  //系统时钟输入
      .I_rst_n(S_rst_n),  //系统复位输入
      .I_ae_req(S_ae_req),
      .I_ae(S_ae),
      .I_ag(S_ag),
      .O_cam_scl(O_cam_scl),  //I2C总线，SCL时钟
      .IO_cam_sda(IO_cam_sda),  //I2C总线，SDA数据
      .O_cfg_done(S_cam_cfg_done),  //摄像头寄存器初始化完成
      .O_i2c_errors(S_i2c_errors),
      .O_ae_cfg_done(S_ae_cfg_done)  //AE配置完成
  );
	
    mipi_dphy_rx_ph1p_mipiio_wrapper#(
        .DPHY_RX_LOCATION      ( "DPHY0" ),
        .HS_EQUALIZER          ( "0dB"   ),//"0dB","1.5dB","3dB","4.5dB","6dB","7.5dB","9dB","10.5dB"
        .HS_VGA_GAIN           ( "8dB" ),//"-3dB","-1.5dB","0dB","1.5dB","3dB","4.5dB","6dB","7.5dB"
        .LANE_NUM              ( 2       ),
        .BYTE_NUM              ( 1       )
    )u_mipi_dphy_rx_ph1p_mipiio_wrapper(
        .I_lp_clk              ( S_100m_clk       ),
        .I_rst                 ( ~S_rst_n         ),

        .I_clk_lane_in_delay   ( 6'd0             ),
        .I_data_lane0_in_delay ( 6'd0             ),
        .I_data_lane1_in_delay ( 6'd0             ),
        .I_data_lane2_in_delay ( 6'd0             ),
        .I_data_lane3_in_delay ( 6'd0             ),

        .I_lane_invert         ( 4'b0000          ),
     
        .O_hs_rx_clk           ( S_csi_rx_clk     ),
        .O_hs_rx_valid         ( S_hs_rx_valid    ),
        .O_hs_rx_data          ( S_hs_rx_data     ),
      
        .O_lp_rx_lane0_p       (  ),
        .O_lp_rx_lane0_n       (  ),
      
        .I_lp_tx_en            ( 1'b0             ),
        .I_lp_tx_lane0_p       ( 1'b1             ),
        .I_lp_tx_lane0_n       ( 1'b1             ),
      
        .O_lane_match_error    (                  ),
        .O_lane_error          ( S_lane_error     ),
      
        .IO_rx_clk_pad_n       ( IO_rx_clk_pad_n  ),
        .IO_rx_clk_pad_p       ( IO_rx_clk_pad_p  ),
        .IO_rx_data_pad_n      ( IO_rx_data_pad_n ),
        .IO_rx_data_pad_p      ( IO_rx_data_pad_p )
    );
	
	
 //  cwc cwc_inst
 //(
 //    .probe0(S_hs_rx_valid),
 //    .probe1(S_hs_rx_data),
 //    .probe2(S_lane_error),
 //    .clk(S_csi_rx_clk)
 //);

 //csi 解码为RAW数据
csi_unpacket_2lane u_csi_unpacket(
.I_clk                 ( S_csi_rx_clk       ),
.I_rst_n               ( S_rst_n        	),
.I_hs_valid            ( S_hs_rx_valid     ),
.I_hs_data             ( S_hs_rx_data      ),

.O_csi_frame_start     ( S_csi_frame_start ),
.O_csi_frame_end       ( S_csi_frame_end   ),
.O_csi_valid           ( S_csi_valid       ),
.O_csi_data            ( S_csi_data        )
);


//解码为RAW8
raw10_unpacket_2lane u_raw10_unpacket (
.I_clk  (S_csi_rx_clk),
.I_rst_n(S_rst_n),

.I_csi_frame_start(S_csi_frame_start),
.I_csi_frame_end  (S_csi_frame_end),
.I_csi_valid      (S_csi_valid),
.I_csi_data       (S_csi_data),

.O_raw10_frame_start(S_raw10_frame_start),
.O_raw10_frame_end  (S_raw10_frame_end),
.O_raw10_valid      (S_raw10_valid),
.O_raw10_data       (S_raw10_data)
  );


localparam MULTI_POCKETS=ENABLE_TRACKING && ENABLE_MULTI_POCKETS;
localparam LOCAL_SEARCH=ENABLE_LOCAL_SEARCH && ENABLE_SHAPE_MODEL && !ENABLE_TRACKING && !MULTI_POCKETS;
assign S_process_clk=LOCAL_SEARCH ? S_100m_clk : S_csi_rx_clk;
// Keep out-of-packet RAW data out of the legacy formatter. The native guard
// still sees the unfiltered signal and rejects the offending frame.
reg csi_frame_open;
always @(posedge S_csi_rx_clk or negedge S_rst_n)begin
 if(!S_rst_n)csi_frame_open<=0;
 else if(S_raw10_frame_start)csi_frame_open<=1;
 else if(S_raw10_frame_end)csi_frame_open<=0;
end
//将数据转为stream流
uial2axis #(
.IMG_WIDTH(INPUT_WIDTH),
.IMG_HEIGHT(INPUT_HEIGHT),
.INPUT_DATA_WIDTH(40)
) 
u_uial2axis (
.I_native_clk(S_csi_rx_clk),
.I_rst_n     (S_rst_n),
.I_data      (S_raw10_data       ),
.I_data_valid(S_raw10_valid && (!LOCAL_SEARCH || (csi_frame_open && !S_raw10_frame_end))),
.I_data_start(S_raw10_frame_start),
.I_data_end  (S_raw10_frame_end  ),
.axis_tvalid (S_axis_tvalid),
.axis_tdata  (S_axis_tdata ),
.axis_tuser  (S_axis_tuser ),
.axis_tlast  (S_axis_tlast )
);
	

image_correction #(
    .DATA_WIDTH(40)
)(
    .I_clk   		(S_csi_rx_clk),
    .I_rst_n 		(S_rst_n),
					
    .I_raw_data 	(S_axis_tdata),
    .I_raw_frame_end 	(S_axis_tlast),
    .I_raw_valid	(S_axis_tvalid),
    .I_raw_frame_start 	(S_axis_tuser),
					
    .O_raw_tdata 	(S_raw_tdata ),
    .O_raw_tlast 	(S_raw_tlast ),
    .O_raw_tvalid	(S_raw_tvalid),
    .O_raw_tuser 	(S_raw_tuser )
);


//cwc1 cwc1_Inst
//  (
//      .probe0(S_axis_tuser),
//      .probe1(S_axis_tvalid),
//      .probe2(S_axis_tlast),
//      .probe3(S_axis_tdata),
//      .probe4(S_ISP_O_tuser),
//      .probe5(S_ISP_O_tvalid),
//      .probe6(S_ISP_O_tlast),
//      .probe7(S_ISP_O_tdata),
//      .probe8 (S_raw_tdata ),
//      .probe9 (S_raw_tlast ),
//      .probe10(S_raw_tvalid),
//      .probe11(S_raw_tuser ),
//      .clk(S_csi_rx_clk)
//  );


//ISP算法顶层模块
// One shared set of experimental ROI bounds for statistics and the display.
localparam ROI_X0=(VIDEO_WIDTH-512)/2,ROI_X1=ROI_X0+512,ROI_Y0=(VIDEO_HEIGHT-256)/2,ROI_Y1=ROI_Y0+256;
// One pocket core supplies the statistics; the large ROI remains a viewing aid.
localparam SAMPLE_X0=(VIDEO_WIDTH-80)/2,SAMPLE_X1=SAMPLE_X0+80,SAMPLE_Y0=(VIDEO_HEIGHT-80)/2,SAMPLE_Y1=SAMPLE_Y0+80;
// Temporary black-tape/white-part demo from historical 130 mm samples.
// MEAN >= 58: present; below 58: empty. Recalibrate after fixture alignment.
// Exposure/gain tuning stays enabled; config/fresh-sample guards still apply.
localparam CLASS_CALIBRATED=1'b1;
localparam [7:0] CLASS_THRESHOLD=58;
localparam CLASS_PRESENT_HIGH=1;
wire [1:0] roi_class_state;
wire [27:0] roi_display_record;
wire [114:0] observation_record;
wire [17:0] observation_request,observation_receive,observation_display;
observation_controls u_observation_controls(
 .clk(I_sys_clk),.rst_n(S_rst_n),.switches(I_switch),.request(observation_request));
status_cdc #(.WIDTH(18)) u_observation_receive(
 .S_clk(I_sys_clk),.D_clk(S_csi_rx_clk),.rst_n(S_rst_n),
 .S_data(observation_request),.D_data(observation_receive));
status_cdc #(.WIDTH(18)) u_observation_display(
 .S_clk(I_sys_clk),.D_clk(S_hdmi_pixel_clk),.rst_n(S_rst_n),
 .S_data(observation_request),.D_data(observation_display));
wire roi_sample_valid;
wire [7:0] roi_sample_mean,roi_sample_min,roi_sample_max;
wire [80:0] camera_receive;
reg [47:0] camera_receive_d;
status_cdc #(.WIDTH(81)) u_camera_receive(
    .S_clk(S_24m_clk),.D_clk(S_csi_rx_clk),.rst_n(S_rst_n),
    .S_data({wb_request,S_ae,S_ag,S_i2c_errors,(S_cam_cfg_done && S_ae_cfg_done && !S_ae_req)}),
    .D_data(camera_receive));
always @(posedge S_csi_rx_clk or negedge S_rst_n) begin
    if(!S_rst_n) camera_receive_d<=0;
    else camera_receive_d<=camera_receive[48:1];
end
wire roi_config_ok=camera_receive[0] && camera_receive[48:1]==camera_receive_d;
wire video_frame_good,video_frame_bad,camera_row_ready;
wire [35:0] video_diagnostics;
wire completed_valid,active_valid,capture_ok,display_ok;
wire [1:0] completed_rp,active_rp;
localparam FRAME_BOUND=ENABLE_TRACKING || LOCAL_SEARCH;
localparam FRAME_META_WIDTH=178+340*MULTI_POCKETS+172*LOCAL_SEARCH;
wire [FRAME_META_WIDTH-1:0] camera_metadata,completed_metadata,active_metadata;
wire camera_metadata_ready;
wire [15:0] lost_frames,overflow_frames,underflow_frames;
localparam PUBLISH_BITS=9+$clog2(VIDEO_WIDTH*VIDEO_HEIGHT*3/16+1);
wire [PUBLISH_BITS-1:0] publish_diagnostic,publish_display;
isp_top #(.INPUT_WIDTH(INPUT_WIDTH),.INPUT_HEIGHT(INPUT_HEIGHT),.WIDTH(VIDEO_WIDTH),.HEIGHT(VIDEO_HEIGHT),.SCALE_DISPLAY(1),.ASYNC_PROCESSING(LOCAL_SEARCH),.LOCAL_SEARCH(LOCAL_SEARCH),.SHAPE_MODEL(ENABLE_SHAPE_MODEL && !ENABLE_TRACKING && !MULTI_POCKETS),.DIRECT_DETECTION(!ENABLE_TRACKING),.MULTI_POCKETS(MULTI_POCKETS),.TRACKING(ENABLE_TRACKING),.HOLE_Y(380),.LATE_HOLE(1),.ROI_X0(SAMPLE_X0),.ROI_X1(SAMPLE_X1),.ROI_Y0(SAMPLE_Y0),.ROI_Y1(SAMPLE_Y1)) u_isp_top (
.processing_clk(S_process_clk),
.axi4s_video_aclk(S_csi_rx_clk),
.I_rst_n         (S_rst_n),
.I_tlast         (S_raw_tlast	),
.I_tuser         (S_raw_tuser	),
.I_tdata         (S_raw_tdata	),
.I_tvalid        (S_raw_tvalid	),
.I_tdest         (),
.O_tready        (S_ISP_O_tready),
.O_tdata         (S_ISP_O_tdata ),
.O_tlast         (S_ISP_O_tlast ),
.O_tuser         (S_ISP_O_tuser ),
.O_tvalid        (S_ISP_O_tvalid),
.I_tready        (),
.raw_start(S_raw10_frame_start),.raw_end(S_raw10_frame_end),
.hs_valid(S_hs_rx_valid),.raw_valid(S_raw10_valid),.lane_error(S_lane_error),
.config_ok(roi_config_ok),.sample_valid(roi_sample_valid),
.calibration_ok(CLASS_CALIBRATED),
.threshold(CLASS_THRESHOLD),.present_high(CLASS_PRESENT_HIGH),.class_state(roi_class_state),.display_record(roi_display_record),
.sample_mean(roi_sample_mean),.sample_min(roi_sample_min),.sample_max(roi_sample_max),
.view_ready(camera_row_ready),.video_frame_good(video_frame_good),.video_frame_bad(video_frame_bad),
.video_diagnostics(video_diagnostics),
.observation_request(observation_receive),.observation_record(observation_record),
.wb_request(camera_receive[80:49]),.wb_active(wb_active),
.image_config(camera_receive[48:17]),.frame_metadata(camera_metadata),.frame_metadata_ready(camera_metadata_ready)
  );


    video_in #(.WIDTH(VIDEO_WIDTH),.HEIGHT(VIDEO_HEIGHT),.METADATA(FRAME_BOUND),.META_WIDTH(FRAME_META_WIDTH),.METADATA_REQUIRED(LOCAL_SEARCH ? 0 : !MULTI_POCKETS),.VIDEO_FIRST(LOCAL_SEARCH)) u_video_in(
        .I_frame_metadata(camera_metadata),.I_frame_metadata_ready(camera_metadata_ready),.O_completed_metadata(completed_metadata),
        .O_publish_diagnostic(publish_diagnostic),
        .I_rst_n              (  S_rst_n             ),

        .I_camera_clk         ( S_process_clk         ),
        .I_camera_frame_start ( S_ISP_O_tuser  ),
        .I_camera_valid       ( S_ISP_O_tvalid ),
        .I_camera_data        ( S_ISP_O_tdata  ),
        .I_frame_good(video_frame_good),.I_frame_bad(video_frame_bad),.O_camera_ready(camera_row_ready),
        .I_active_valid(active_valid),.I_active_rp(active_rp),
        .O_completed_valid(completed_valid),.O_completed_rp(completed_rp),
        .O_capture_ok(capture_ok),.O_lost_frames(lost_frames),.O_overflow_frames(overflow_frames),
        .I_mipi_rx_error      ( 1'b0			      ),

        .I_ddr_clk            ( S_ddr_clk             ),
		.I_display_pause      ( 1'b0                  ),
        .I_video_out_rd_busy  ( S_video_out_rd_busy   ),
        .O_video_in_wr_busy   ( S_video_in_wr_busy    ),
        .O_video_out_rp       ( S_video_out_rp        ),

        .O_ddr_user_wr_en     ( S_vi_ddr_wr_en        ),
        .O_ddr_user_addr      ( S_vi_ddr_wr_addr      ),
        .O_ddr_user_wr_data   ( S_vi_ddr_wr_data      ),
        .I_ddr_user_ready     ( S_ddr_user_ready      )
    );



    assign S_ddr_user_wr_en    = S_vi_ddr_wr_en;

    assign S_ddr_user_rd_en    = S_vo_ddr_rd_en;

    assign S_ddr_user_addr     = S_vi_ddr_wr_en ? S_vi_ddr_wr_addr :
                                 S_vo_ddr_rd_en ? S_vo_ddr_rd_addr : 'd0;

    assign S_ddr_user_wr_data  = S_vi_ddr_wr_data;


    assign S_video_out_rst_n = S_hdmi_rst_n;

    video_out #(.WIDTH(VIDEO_WIDTH),.HEIGHT(VIDEO_HEIGHT),.META_WIDTH(FRAME_META_WIDTH)) u_video_out(
        .I_completed_metadata(completed_metadata),.O_active_metadata(active_metadata),
        .I_rst_n             ( S_video_out_rst_n    ),
        .I_ddr_clk           ( S_ddr_clk            ),
 
        .O_video_out_rd_busy ( S_video_out_rd_busy  ),
        .I_video_in_wr_busy  ( S_video_in_wr_busy   ),
        .I_video_out_rp      ( S_video_out_rp       ),
        .I_completed_valid(completed_valid),.I_completed_rp(completed_rp),
        .O_active_valid(active_valid),.O_active_rp(active_rp),
        .O_display_ok(display_ok),.O_underflow_frames(underflow_frames),
 
        .O_ddr_user_rd_en    ( S_vo_ddr_rd_en       ),
        .O_ddr_user_addr     ( S_vo_ddr_rd_addr     ),
        .I_ddr_user_ready    ( S_ddr_user_ready     ),
        .I_ddr_user_rd_valid ( S_ddr_user_rd_valid  ),
        .I_ddr_user_rd_data  ( S_ddr_user_rd_data   ),

        .I_dsi_clk           ( S_hdmi_pixel_clk     ),
        .I_video_vsync       ( S_video_out_vsync    ),
        .I_video_rd_en       ( S_hdmi_window_rd_en  ),
        .O_vdieo_data        ( S_video_rd_data      )
    );



    mc_to_user_interface u_mc_to_user_interface(
        .I_clk                   ( S_ddr_clk               ),
        .I_rst_n                 ( S_rst_n                 ),

        .I_ddr_user_wr_en        ( S_ddr_user_wr_en        ),
        .I_ddr_user_rd_en        ( S_ddr_user_rd_en        ),
        .I_ddr_user_addr         ( S_ddr_user_addr         ),
        .I_ddr_user_wr_data      ( S_ddr_user_wr_data      ),
        .O_ddr_user_ready        ( S_ddr_user_ready        ),
        .O_ddr_user_rd_valid     ( S_ddr_user_rd_valid     ),
        .O_ddr_user_rd_data      ( S_ddr_user_rd_data      ),
            
        .O_mc_app_en             ( S_mc_app_en             ),
        .O_mc_app_addr           ( S_mc_app_addr           ),
        .O_mc_app_cmd            ( S_mc_app_cmd            ),
        .I_mc_app_rdy            ( S_mc_app_rdy            ),
        .O_mc_app_wdf_wren       ( S_mc_app_wdf_wren       ),
        .O_mc_app_wdf_data       ( S_mc_app_wdf_data       ),
        .O_mc_app_wdf_end        ( S_mc_app_wdf_end        ),
        .O_mc_app_wdf_mask       ( S_mc_app_wdf_mask       ),
        .I_mc_app_wdf_rdy        ( S_mc_app_wdf_rdy        ),
        .I_mc_app_rd_data        ( S_mc_app_rd_data        ),
        .I_mc_app_rd_data_end    ( S_mc_app_rd_data_end    ),
        .I_mc_app_rd_data_valid  ( S_mc_app_rd_data_valid  )
    );



    ph1p35_324_ddr_wrapper u_ph1p35_324_ddr_wrapper(
        .I_sys_clk              ( I_sys_clk              ),
        .I_sys_rst_n            ( S_rst_n                ),

        .O_ddr_clk              ( S_ddr_clk              ),
        .O_init_calib_complete  ( S_init_calib_complete  ),
        .I_mc_app_addr          ( S_mc_app_addr          ),
        .I_mc_app_cmd           ( S_mc_app_cmd           ),
        .I_mc_app_en            ( S_mc_app_en            ),
        .I_mc_app_wdf_data      ( S_mc_app_wdf_data      ),
        .I_mc_app_wdf_end       ( S_mc_app_wdf_end       ),
        .I_mc_app_wdf_mask      ( S_mc_app_wdf_mask      ),
        .I_mc_app_wdf_wren      ( S_mc_app_wdf_wren      ),
        .O_mc_app_rd_data       ( S_mc_app_rd_data       ),
        .O_mc_app_rd_data_end   ( S_mc_app_rd_data_end   ),
        .O_mc_app_rd_data_valid ( S_mc_app_rd_data_valid ),
        .O_mc_app_rdy           ( S_mc_app_rdy           ),
        .O_mc_app_wdf_rdy       ( S_mc_app_wdf_rdy       ),

        .ddr_addr               ( ddr_addr               ),
        .ddr_ba                 ( ddr_ba                 ),
        .ddr_cke                ( ddr_cke                ),
        .ddr_odt                ( ddr_odt                ),
        .ddr_cs_n               ( ddr_cs_n               ),
        .ddr_ras_n              ( ddr_ras_n              ),
        .ddr_cas_n              ( ddr_cas_n              ),
        .ddr_we_n               ( ddr_we_n               ),
        .ddr_ck_p               ( ddr_ck_p               ),
        .ddr_ck_n               ( ddr_ck_n               ),
        .ddr_dm                 ( ddr_dm                 ),
        .ddr_dq                 ( ddr_dq                 ),
        .ddr_dqs_p              ( ddr_dqs_p              ),
        .ddr_dqs_n              ( ddr_dqs_n              )
    );



    wire [11:0] native_x,native_tx_x;
    wire [10:0] native_y,native_source_x,native_source_y,native_tx_y;
    wire native_pair,native_field,osd_pair;
    wire [10:0] native_osd_x,native_osd_y;
    native_720p60_vtc u_hdmi_vtc(.clk(S_hdmi_pixel_clk),.rst_n(S_hdmi_rst_n),
     .x(native_x),.y(native_y),.source_x(native_source_x),.source_y(native_source_y),
     .vs(S_hdmi_vsync),.hs(S_hdmi_hsync),.de(S_hdmi_de),.pair_vs(native_pair),.field(native_field));
    assign S_hdmi_user=S_hdmi_de && native_x==0 && native_y==0;
    assign S_hdmi_last=S_hdmi_de && native_x==1279;
    assign S_hdmi_window_rd_en=S_hdmi_de;
    native_i60_phase u_native_phase(.clk(S_hdmi_pixel_clk),.rst_n(S_hdmi_rst_n),
     .x(native_x),.y(native_y),.source_x(native_source_x),.source_y(native_source_y),
     .vs(S_hdmi_vsync),.hs(S_hdmi_hsync),.de(S_hdmi_de),.pair_vs(native_pair),
     .osd_vs(S_hdmi_out_vsync),.osd_hs(S_hdmi_out_hsync),.osd_de(S_hdmi_out_de),.osd_pair_vs(osd_pair),
     .osd_x(native_osd_x),.osd_y(native_osd_y),.tx_x(native_tx_x),.tx_y(native_tx_y));
    assign S_hdmi_out_data=S_video_rd_data;

    wire [15:0] mon_width,mon_height,mon_fps,mon_lane,mon_format,mon_gap;
    wire [31:0] mon_frames,mon_seconds;
    input_monitor u_input_monitor(
        .rx_clk(S_csi_rx_clk),.ref_clk(I_sys_clk),.rst_n(S_rst_n),
        .frame_start(S_raw10_frame_start),.frame_end(S_raw10_frame_end),
        .hs_valid(S_hs_rx_valid),.raw_valid(S_raw10_valid),.lane_error(S_lane_error),
        .width(mon_width),.height(mon_height),.fps(mon_fps),.lane_errors(mon_lane),
        .format_errors(mon_format),.gap_seconds(mon_gap),.frames(mon_frames),.uptime(mon_seconds));
    wire [159:0] mon_display;
    status_cdc #(.WIDTH(160)) u_monitor_display(
        .S_clk(I_sys_clk),.D_clk(S_hdmi_pixel_clk),.rst_n(S_rst_n),
        .S_data({mon_width,mon_height,mon_fps,mon_lane,mon_format,mon_gap,mon_frames,mon_seconds}),
        .D_data(mon_display));
    wire [81:0] cam_display;
    status_cdc #(.WIDTH(82)) u_camera_display(
        .S_clk(S_24m_clk),.D_clk(S_hdmi_pixel_clk),.rst_n(S_rst_n),
        .S_data({wb_tune,wb_request,S_ae,S_ag,S_i2c_errors,(S_cam_cfg_done && S_ae_cfg_done && !S_ae_req)}),
        .D_data(cam_display));
    wire exp_vs,exp_hs,exp_de;
    wire [23:0] exp_rgb;
    wire [FRAME_META_WIDTH+2:0] active_frame_display;
    status_cdc #(.WIDTH(FRAME_META_WIDTH+3)) u_active_frame_display(
     .S_clk(S_ddr_clk),.D_clk(S_hdmi_pixel_clk),.rst_n(S_rst_n),
     .S_data({active_valid,active_rp,active_metadata}),.D_data(active_frame_display));
    wire [114:0] latest_observation_data;
    wire [114:0] observation_data=FRAME_BOUND ? active_frame_display[114:0] : latest_observation_data;
    wire tracking_match=active_frame_display[FRAME_META_WIDTH+2] && active_frame_display[169:138]==cam_display[48:17];
    wire observation_match=observation_data[45:28]==observation_display && observation_data[114:83]==cam_display[80:49];
    wire [27:0] roi_display={observation_data[27:25],(observation_data[24] && observation_match),observation_data[23:0]};
    status_cdc #(.WIDTH(115)) u_roi_display(
        .S_clk(S_process_clk),.D_clk(S_hdmi_pixel_clk),.rst_n(S_rst_n),
        .S_data(observation_record),.D_data(latest_observation_data));
    wire [16:0] transport_display;
    status_cdc #(.WIDTH(PUBLISH_BITS)) u_publish_display(
     .S_clk(S_ddr_clk),.D_clk(S_hdmi_pixel_clk),.rst_n(S_rst_n),
     .S_data(publish_diagnostic),.D_data(publish_display));
    wire [83:0] overflow_display;
    wire [31:0] wb_process;
    status_cdc #(.WIDTH(32)) u_wb_process(
     .S_clk(S_csi_rx_clk),.D_clk(S_process_clk),.rst_n(S_rst_n),.S_data(wb_active),.D_data(wb_process));
    status_cdc #(.WIDTH(17)) u_transport_display(
     .S_clk(S_ddr_clk),.D_clk(S_hdmi_pixel_clk),.rst_n(S_rst_n),
     .S_data({capture_ok,lost_frames}),.D_data(transport_display));
    status_cdc #(.WIDTH(84)) u_overflow_display(
     .S_clk(S_process_clk),.D_clk(S_hdmi_pixel_clk),.rst_n(S_rst_n),
     .S_data({wb_process,video_diagnostics,overflow_frames}),.D_data(overflow_display));
    wire transport_ok=transport_display[16] && display_ok;
    wire tracking_fresh;
    tracking_frame_age u_tracking_age(.clk(S_hdmi_pixel_clk),.rst_n(S_rst_n),.valid(active_frame_display[FRAME_META_WIDTH+2]),.slot(active_frame_display[FRAME_META_WIDTH+1:FRAME_META_WIDTH]),.fresh(tracking_fresh));
    wire legacy_display_valid;wire [1:0] legacy_display_state_code;
    wire tracked_display_valid;wire [3:0] tracking_reason;
    tracking_display_status u_tracking_status(
     .active_valid(active_frame_display[FRAME_META_WIDTH+2]),.fresh(tracking_fresh),.config_ok(cam_display[0]),
     .fps_ok(mon_display[127:112]!=0),.transport_ok(transport_ok),.params_match(tracking_match && observation_match),
     .track_locked(active_frame_display[137]),.sample_valid(observation_data[24]),.class_wait(observation_data[26:25]==1),
     .hole_reason(active_frame_display[177:174]),.valid(tracked_display_valid),.reason(tracking_reason));
    wire local_display_valid=active_frame_display[FRAME_META_WIDTH+2] && tracking_fresh && cam_display[0] &&
     mon_display[127:112]!=0 && transport_ok && tracking_match && observation_match && observation_data[24];
    wire roi_display_valid=LOCAL_SEARCH ? local_display_valid : ENABLE_TRACKING ? tracked_display_valid : legacy_display_valid;
    wire [1:0] roi_display_state_code=LOCAL_SEARCH ? (local_display_valid ? observation_data[26:25] : 2'd1) : ENABLE_TRACKING ? (roi_display_valid ? observation_data[26:25] : 2'd1) : legacy_display_state_code;
    roi_display_state u_roi_display_state(
        .clk(S_hdmi_pixel_clk),.rst_n(S_rst_n),.cfg_done(cam_display[0] && transport_ok),
        .exposure(cam_display[48:33]),.gain(cam_display[32:17]),.fps(mon_display[127:112]),
        .calibration_ok(CLASS_CALIBRATED),
        .record(roi_display),.observation_request(observation_display),.wb_request(cam_display[80:49]),.sample_valid(legacy_display_valid),.state(legacy_display_state_code));
    wire pocket_overlay_ok=tracking_fresh && cam_display[0] && mon_display[127:112]!=0 && transport_ok && tracking_match && observation_match;
    wire [339:0] display_pockets;
    generate if(MULTI_POCKETS) begin : multi_display
     assign display_pockets=active_frame_display[178+:340];
    end else begin : single_display
     assign display_pockets=0;
    end endgenerate
    wire [151:0] display_objects;
    wire local_box_valid;wire [10:0] local_x0,local_x1;wire [9:0] local_y0,local_y1;
    generate if(LOCAL_SEARCH) begin : local_box
     assign display_objects=local_display_valid ? active_frame_display[198+:152] : 152'd0;
     assign local_box_valid=local_display_valid && active_frame_display[137];
     assign local_x0=active_frame_display[136:126];assign local_x1=active_frame_display[125:115];
     assign local_y0=active_frame_display[197:188];assign local_y1=active_frame_display[187:178];
    end else begin : no_local_box
     assign display_objects=0;assign local_box_valid=0;assign local_x0=0;assign local_x1=0;assign local_y0=0;assign local_y1=0;
    end endgenerate
    wire any_pocket_valid=display_pockets[63] || display_pockets[148] || display_pockets[233] || display_pockets[318];
    experiment_osd #(.WIDTH(VIDEO_WIDTH),.HEIGHT(VIDEO_HEIGHT),.DIAG_BITS(PUBLISH_BITS),.RESOLUTION_V11(1),.FRAME_OBJECTS(LOCAL_SEARCH),.LOCAL_SEARCH(LOCAL_SEARCH),.SHAPE_MODEL(ENABLE_SHAPE_MODEL && !ENABLE_TRACKING && !MULTI_POCKETS),.DIRECT_DETECTION(!ENABLE_TRACKING),.CLASS_THRESHOLD(CLASS_THRESHOLD),.MULTI_POCKETS(MULTI_POCKETS),.TRACKING(ENABLE_TRACKING),.HOLE_Y(380),.ROI_X0(ROI_X0),.ROI_X1(ROI_X1),.ROI_Y0(ROI_Y0),.ROI_Y1(ROI_Y1),
 .SAMPLE_X0(SAMPLE_X0),.SAMPLE_X1(SAMPLE_X1),.SAMPLE_Y0(SAMPLE_Y0),.SAMPLE_Y1(SAMPLE_Y1)) u_experiment_osd(
        .clk(S_hdmi_pixel_clk),.rst_n(S_rst_n),
        .vs(S_hdmi_out_vsync),.hs(S_hdmi_out_hsync),.de(S_hdmi_out_de),.rgb(S_hdmi_out_data),
        .exposure(cam_display[48:33]),.gain(cam_display[32:17]),
        .view_mode(observation_display[1:0]),.edge_count(observation_data[58:46]),.edge_sum(observation_data[82:59]),
        .overflow_frames(overflow_display[15:0]),.lost_frames(transport_display[15:0]),.underflow_frames(underflow_frames),
        .diagnostics(overflow_display[51:16]),
        .publish_diagnostic(publish_display),
        .wb_r(overflow_display[67:60]),.wb_b(overflow_display[59:52]),.wb_tune(cam_display[81]),
        .wb_pending(overflow_display[83:52]!=cam_display[80:49]),
        .frame_objects(display_objects),.roi_valid(roi_display_valid),.local_box_valid(local_box_valid),
        .local_x0(local_x0),.local_x1(local_x1),.local_y0(local_y0),.local_y1(local_y1),
        .pocket_records(display_pockets),.pocket_enable(pocket_overlay_ok),
        .track_valid(MULTI_POCKETS ? (pocket_overlay_ok && any_pocket_valid) : (roi_display_valid && active_frame_display[137])),.track_x0(active_frame_display[136:126]),.track_x1(active_frame_display[125:115]),
        .track_reason(MULTI_POCKETS && tracking_reason==12 && active_frame_display[169:138]==0 ? 4'd15 : tracking_reason),.track_rows(active_frame_display[172:170]),
        .roi_state(roi_display_state_code),
        .roi_mean(roi_display[23:16]),.roi_min(roi_display[15:8]),.roi_max(roi_display[7:0]),
        .i2c_errors(cam_display[16:1]),.cfg_done(cam_display[0]),
        .width(mon_display[159:144]),.height(mon_display[143:128]),.fps(mon_display[127:112]),
        .lane_errors(mon_display[111:96]),.format_errors(mon_display[95:80]),.gaps(mon_display[79:64]),
        .frames(mon_display[63:32]),.uptime(mon_display[31:0]),
        .out_vs(exp_vs),.out_hs(exp_hs),.out_de(exp_de),.out_rgb(exp_rgb));

    native_i60_tx #(.INTERLACED(0)) u_hdmi_tx(
     .pixel_clk(S_hdmi_pixel_clk),.serial_clk(S_hdmi_serial_clk),.rst(~S_hdmi_rst_n),
     .vs(exp_vs),.hs(exp_hs),.de(exp_de),.rgb(exp_rgb),.x(native_tx_x),.y(native_tx_y),
     .O_tmds_ch0_p(O_tmds_ch0_p),.O_tmds_ch1_p(O_tmds_ch1_p),
     .O_tmds_ch2_p(O_tmds_ch2_p),.O_tmds_clk_p(O_tmds_clk_p));

endmodule
