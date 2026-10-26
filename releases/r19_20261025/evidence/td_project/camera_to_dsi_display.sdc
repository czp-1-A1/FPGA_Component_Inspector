create_clock -name {sys_clk_50m} -period 20.000 -waveform {0.000 10.000} [get_ports {I_sys_clk}]
create_clock -name {mipi_rx_ck_pad} -period 2.222 -waveform {0.000 1.111} [get_nets {IO_rx_clk_pad_p}]

derive_clocks

rename_clock -name {pll_clk_100m} [get_clocks {u_PLL/ph1p_phy_pll_wrapper_25a56e5ce2f9_Inst/u_PH1P_PHY_PLL.clkc[0]}]
rename_clock -name {pll_clk_24m} [get_clocks {u_PLL/ph1p_phy_pll_wrapper_25a56e5ce2f9_Inst/u_PH1P_PHY_PLL.clkc[1]}]
rename_clock -name {HDMI_PIXEL_CLK} [get_clocks {u_hdmi_pll/u_output/ph1p_phy_pll_wrapper_25a56e5ce2f9_Inst/u_PH1P_PHY_PLL.clkc[0]}]
rename_clock -name {HDMI_SERIAL_CLK} [get_clocks {u_hdmi_pll/u_output/ph1p_phy_pll_wrapper_25a56e5ce2f9_Inst/u_PH1P_PHY_PLL.clkc[1]}]

rename_clock -name {MIPI_RX_BYTE_CLK} [get_clocks {u_mipi_dphy_rx_ph1p_mipiio_wrapper/u_ph1p_mipiio_rx_wrapper/u_PH1P_LOGIC_DPHY_MIPI_RX.o_fabric_div4_8_clk}]



# Mechanical asynchronous inputs only feed the first synchronizer stage.
set_false_path -from [get_ports {I_button[*]}]

# Physical bounds for asynchronous DDR crossings. Do not clock-group-cut these
# paths: that would suppress the held transport-status mailbox budgets.
set_max_delay -datapath_only 14.0 -from [get_clocks {mipi_rx_ck_pad MIPI_RX_BYTE_CLK sys_clk_50m pll_clk_100m pll_clk_24m HDMI_PIXEL_CLK HDMI_SERIAL_CLK}] -to [get_clocks {u_ph1p35_324_ddr_wrapper/u_ddr2/ddr_clk u_ph1p35_324_ddr_wrapper/u_ddr2/usr_clk}]
set_max_delay -datapath_only 19.0 -from [get_clocks {u_ph1p35_324_ddr_wrapper/u_ddr2/ddr_clk u_ph1p35_324_ddr_wrapper/u_ddr2/usr_clk}] -to [get_clocks {sys_clk_50m pll_clk_100m pll_clk_24m HDMI_PIXEL_CLK HDMI_SERIAL_CLK}]
# The V9 writer input now uses pll_clk_100m; its return crossings are covered
# by the 19ns DDR-to-system bound above and the explicit metadata ack bound.
# Restore the former 8ns DDR-to-MIPI bound before using the native-clock writer.

# CSI and system clocks are asynchronous. Use physical delay bounds instead of
# a clock-group cut, which would suppress the mailbox constraints below in TD.
# These budgets cover the existing input-monitor mailbox and frame synchronizer
# as well; they do not imply a phase relationship between the clocks.
set_max_delay -datapath_only 19.0 -from [get_clocks {MIPI_RX_BYTE_CLK}] -to [get_clocks {sys_clk_50m pll_clk_100m pll_clk_24m HDMI_PIXEL_CLK HDMI_SERIAL_CLK}]
set_max_delay -datapath_only 8.0 -from [get_clocks {sys_clk_50m pll_clk_100m pll_clk_24m HDMI_PIXEL_CLK HDMI_SERIAL_CLK}] -to [get_clocks {MIPI_RX_BYTE_CLK}]

# Bundled payload is held through two-stage request/capture and until ack.
# 19ns is less than the 38.46ns minimum settling interval to HDMI capture.
set_max_delay -datapath_only 19.0 -from [get_regs {u_monitor_display/payload*}] -to [get_regs {u_monitor_display/D_data*}]
set_max_delay -datapath_only 19.0 -from [get_regs {u_camera_display/payload*}] -to [get_regs {u_camera_display/D_data*}]
# Tokens use two-stage synchronizers; bound the physical crossing as well.
set_max_delay -datapath_only 19.0 -from [get_regs {u_monitor_display/req}] -to [get_regs {u_monitor_display/req_sync[0]}]
set_max_delay -datapath_only 19.0 -from [get_regs {u_monitor_display/ack}] -to [get_regs {u_monitor_display/ack_sync[0]}]
set_max_delay -datapath_only 19.0 -from [get_regs {u_camera_display/req}] -to [get_regs {u_camera_display/req_sync[0]}]
set_max_delay -datapath_only 19.0 -from [get_regs {u_camera_display/ack}] -to [get_regs {u_camera_display/ack_sync[0]}]

# ROI mailboxes: constrain held payload and request/ack crossings physically.
# Receive capture has two 8.888ns stages; 8ns stays below that settling interval.
set_max_delay -datapath_only 8.0 -from [get_regs {u_camera_receive/payload*}] -to [get_regs {u_camera_receive/D_data*}]
set_max_delay -datapath_only 8.0 -from [get_regs {u_camera_receive/req}] -to [get_regs {u_camera_receive/req_sync[0]}]
set_max_delay -datapath_only 8.0 -from [get_regs {u_camera_receive/ack}] -to [get_regs {u_camera_receive/ack_sync[0]}]

# SW levels feed only the first synchronizer in the independent 50MHz domain.
set_false_path -from [get_ports {I_switch[*]}]
set_max_delay -datapath_only 8.0 -from [get_regs {u_observation_receive/payload*}] -to [get_regs {u_observation_receive/D_data*}]
set_max_delay -datapath_only 8.0 -from [get_regs {u_observation_receive/req}] -to [get_regs {u_observation_receive/req_sync[0]}]
set_max_delay -datapath_only 19.0 -from [get_regs {u_observation_receive/ack}] -to [get_regs {u_observation_receive/ack_sync[0]}]
set_max_delay -datapath_only 19.0 -from [get_regs {u_observation_display/payload*}] -to [get_regs {u_observation_display/D_data*}]
set_max_delay -datapath_only 19.0 -from [get_regs {u_observation_display/req}] -to [get_regs {u_observation_display/req_sync[0]}]
set_max_delay -datapath_only 19.0 -from [get_regs {u_observation_display/ack}] -to [get_regs {u_observation_display/ack_sync[0]}]

# New video integrity counters/status: payload stays held until capture/ack.
set_max_delay -datapath_only 19.0 -from [get_regs {u_transport_display/payload*}] -to [get_regs {u_transport_display/D_data*}]
set_max_delay -datapath_only 19.0 -from [get_regs {u_transport_display/req}] -to [get_regs {u_transport_display/req_sync[0]}]
set_max_delay -datapath_only 14.0 -from [get_regs {u_transport_display/ack}] -to [get_regs {u_transport_display/ack_sync[0]}]
set_max_delay -datapath_only 19.0 -from [get_regs {u_overflow_display/payload*}] -to [get_regs {u_overflow_display/D_data*}]
set_max_delay -datapath_only 19.0 -from [get_regs {u_overflow_display/req}] -to [get_regs {u_overflow_display/req_sync[0]}]
set_max_delay -datapath_only 8.0 -from [get_regs {u_overflow_display/ack}] -to [get_regs {u_overflow_display/ack_sync[0]}]

# FIXED EXP V4 disables tracking/frame-metadata transport; these two mailboxes
# are compiled out. Their six named constraints remain in the frozen V3 SDC.
# Restore them before enabling ENABLE_TRACKING again; active CDC budgets above
# and publishing diagnostics below are unchanged.

# Read-only writer publishing diagnostics use the same held-payload mailbox.
set_max_delay -datapath_only 19.0 -from [get_regs {u_publish_display/payload*}] -to [get_regs {u_publish_display/D_data*}]
set_max_delay -datapath_only 19.0 -from [get_regs {u_publish_display/req}] -to [get_regs {u_publish_display/req_sync[0]}]
set_max_delay -datapath_only 14.0 -from [get_regs {u_publish_display/ack}] -to [get_regs {u_publish_display/ack_sync[0]}]

# Local-search boxes are bound to DDR frames: restore metadata mailbox budgets.
set_max_delay -datapath_only 14.0 -from [get_regs {*crossing/payload*}] -to [get_regs {*crossing/D_data*}]
set_max_delay -datapath_only 14.0 -from [get_regs {*crossing/req}] -to [get_regs {*crossing/req_sync[0]}]
set_max_delay -datapath_only 8.0 -from [get_regs {*crossing/ack}] -to [get_regs {*crossing/ack_sync[0]}]
set_max_delay -datapath_only 19.0 -from [get_regs {u_active_frame_display/payload*}] -to [get_regs {u_active_frame_display/D_data*}]
set_max_delay -datapath_only 19.0 -from [get_regs {u_active_frame_display/req}] -to [get_regs {u_active_frame_display/req_sync[0]}]
set_max_delay -datapath_only 14.0 -from [get_regs {u_active_frame_display/ack}] -to [get_regs {u_active_frame_display/ack_sync[0]}]

# Native WB status to continuous 100MHz post-processing. Payload is held until
# acknowledgement; 9ns is below the two-stage 20ns destination settling time.
set_max_delay -datapath_only 9.0 -from [get_regs {u_wb_process/payload*}] -to [get_regs {u_wb_process/D_data*}]
set_max_delay -datapath_only 9.0 -from [get_regs {u_wb_process/req}] -to [get_regs {u_wb_process/req_sync[0]}]
set_max_delay -datapath_only 8.0 -from [get_regs {u_wb_process/ack}] -to [get_regs {u_wb_process/ack_sync[0]}]

# The bridge's two 10-bit Gray pointer buses cross 112.5MHz CSI / 100MHz ISP.
# Keep all pointer-bit route delays below either source period (8.889/10ns).
# The bridge uses explicit pointers, outside the vendor FIFO's automatic
# timing patterns. Both directions must match and dominate all 20 paths.
set_max_delay -datapath_only 8.0 -from [get_regs {*continuous_processing*bridge/write_gray\[*\] *continuous_processing*bridge/read_gray\[*\]}] -to [get_regs {*continuous_processing*bridge/write_gray_sync1\[*\] *continuous_processing*bridge/read_gray_sync1\[*\]}]

# New mechanical SW4 input feeds only page_sync[0].
set_false_path -from [get_ports {I_count_page_switch}]
set_max_delay -datapath_only 9.0 -from [get_regs {u_count_command/payload*}] -to [get_regs {u_count_command/D_data*}]
set_max_delay -datapath_only 9.0 -from [get_regs {u_count_command/req}] -to [get_regs {u_count_command/req_sync[0]}]
set_max_delay -datapath_only 19.0 -from [get_regs {u_count_command/ack}] -to [get_regs {u_count_command/ack_sync[0]}]
set_max_delay -datapath_only 19.0 -from [get_regs {u_count_live_display/payload*}] -to [get_regs {u_count_live_display/D_data*}]
set_max_delay -datapath_only 19.0 -from [get_regs {u_count_live_display/req}] -to [get_regs {u_count_live_display/req_sync[0]}]
set_max_delay -datapath_only 9.0 -from [get_regs {u_count_live_display/ack}] -to [get_regs {u_count_live_display/ack_sync[0]}]

# Mechanical SW3 goes only to the first stage of controls/sw_sync.
set_false_path -from [get_ports {I_count_start_switch}]
