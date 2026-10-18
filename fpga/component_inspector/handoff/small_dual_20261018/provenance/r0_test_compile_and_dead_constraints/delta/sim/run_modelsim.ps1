param(
    [string]$ModelSimBin = "D:/modelsim/win64",
    [string]$TdSimRoot = "D:/AAA/FPGA.....YZW/sim_release",
    [switch]$TieUnusedAwbRamInputs,
    [string[]]$OnlyTests = @()
)
$ErrorActionPreference = "Stop"
# A desktop process started before license configuration may not inherit it.
foreach ($name in @("MGLS_LICENSE_FILE", "LM_LICENSE_FILE")) {
    if (![Environment]::GetEnvironmentVariable($name, "Process")) {
        $configuredValue = [Environment]::GetEnvironmentVariable($name, "User")
        if (!$configuredValue) { $configuredValue = [Environment]::GetEnvironmentVariable($name, "Machine") }
        if ($configuredValue) { [Environment]::SetEnvironmentVariable($name, $configuredValue, "Process") }
    }
}
Push-Location $PSScriptRoot
try {
    foreach ($tool in @("vlib", "vmap", "vlog", "vsim")) {
        if (!(Test-Path -LiteralPath "$ModelSimBin/$tool.exe")) { throw "Missing ModelSim tool: $tool" }
    }
    if (!(Test-Path -LiteralPath modelsim.ini)) {
        & "$ModelSimBin/vmap.exe" -c *> modelsim_setup.log
        if ($LASTEXITCODE -ne 0) { throw "ModelSim local setup failed; see modelsim_setup.log" }
    }
    New-Item -ItemType Directory -Path modelsim_work -Force | Out-Null
    $vendor = @(
        "$TdSimRoot/common/al_map_basic.v", "$TdSimRoot/common/al_map_lut.v",
        "$TdSimRoot/common/al_map_adder.v", "$TdSimRoot/common/al_phy_glbl.v",
        "$TdSimRoot/ph1p/ph1p_logic_eram.v", "$TdSimRoot/ph1p/ph1p_phy_gsr.v",
        "$TdSimRoot/ph1p/ph1p_logic_bufg.v", "$TdSimRoot/ph1p/ph1p_phy_pll_v2.v",
        "$TdSimRoot/ph1p/ph1p_logic_hrio.v", "$TdSimRoot/ph1p/ph1p_phy_hr_pad.v"
    )
    foreach ($path in $vendor) {
        if (!(Test-Path -LiteralPath $path)) { throw "Missing vendor simulation library: $path" }
    }
    if (!(Test-Path -LiteralPath modelsim_work/anlogic_sim/_info)) {
        & "$ModelSimBin/vlib.exe" modelsim_work/anlogic_sim *> modelsim_vendor_setup.log
        if ($LASTEXITCODE -ne 0) { throw "Vendor library creation failed" }
    }
    & "$ModelSimBin/vmap.exe" anlogic_sim modelsim_work/anlogic_sim >> modelsim_vendor_setup.log 2>&1
    if ($LASTEXITCODE -ne 0) { throw "Vendor library mapping failed" }
    & "$ModelSimBin/vlog.exe" -work anlogic_sim @vendor *> modelsim_vendor_compile.log
    if ($LASTEXITCODE -ne 0) { throw "Vendor library compile failed; see modelsim_vendor_compile.log" }

    $hdl = "../user_source/hdl_source"
    $ip = "../user_source/ip_source"
    $demosaic = "$hdl/isp/demosaic_4x_2_0"
    $ispSources = @(
        "$hdl/rgb_resize_2_3.v", "$hdl/rgb96_packetizer.v", "$hdl/scaled_frame_guard.v",
        "$hdl/frame_process_bridge.v", "$ip/w128_d512_fifo/w128_d512_fifo.v", "$ip/w128_d512_fifo/soft_fifo_al_4057d6b76aa6.v", "$hdl/inspection_region_config.v", "$hdl/frame_shape_search.v", "$hdl/roi_shape_search.v", "$hdl/roi_shape_model.v", "$hdl/isp/uial2axis.v", "$hdl/isp/isp_top.v", "$hdl/tape_hole_tracker.v", "$hdl/multi_pocket_detector.v", "$hdl/roi_frame_guard.v", "$hdl/roi_statistics.v", "$hdl/roi_classifier.v", "$hdl/roi_mode_classifier.v", "$hdl/roi_tape_guard.v", "$hdl/roi_result_snapshot.v", "$hdl/roi_sobel_view.v", "$hdl/roi_observation_snapshot.v",
        "$hdl/awb.v", "$hdl/signal_delay.v", "$hdl/isp/data128_96/data128_96.v", "$hdl/isp/data96_128/data96_128.v",
        "$demosaic/demosaic.v", "$demosaic/raw_matrix_3x3_buffer.v", "$demosaic/zhenghe.v",
        "$demosaic/line_buffer_demosaic.v", "$demosaic/mipi_to_raw_converter.v", "$demosaic/bilinear_interpolation.v",
        "$demosaic/blk_mem_gen_demosaic/blk_mem_gen_demosaic.v", "$demosaic/blk_mem_gen_demosaic/RTL/ram_c36c2ca3b3a7.v",
        "$demosaic/blk_mem_gen_zhenghe/blk_mem_gen_zhenghe.v", "$demosaic/blk_mem_gen_zhenghe/RTL/ram_d32970204f32.v",
        "$ip/divider/divider_gate.v", "$ip/blk_mem_gen_awb_delay_signal/blk_mem_gen_awb_delay_signal.v",
        "$ip/blk_mem_gen_awb_delay_signal/ram_f84573da5ab5.v")
    $tests = @(
        @{Name="lane_search"; Pass="PASS lane search:"; Sources=@("$hdl/inspection_region_config.v", "$hdl/frame_shape_search.v", "tb_lane_search.v")},
        @{Name="lane_osd"; Pass="PASS lane OSD:"; Sources=@("$hdl/bin16_bcd.v", "$hdl/osd_ascii_rom.v", "$hdl/osd_cjk_rom.v", "$hdl/osd_logo_rom.v", "$hdl/inspection_region_config.v", "$hdl/experiment_osd.v", "tb_lane_osd.v")},
        @{Name="lane_hd_pins"; Pass="PASS lane hd pins:"; Sources=@("hdmi_ideal_pll.v", "$hdl/native_720p60_vtc.v", "$hdl/native_i60_phase.v", "$hdl/native_i60_tx.v", "$hdl/dvi_encoder.v", "$hdl/wide_view_avi.v", "$hdl/hdmi_phy_warpper.v", "$hdl/lane_lvds_10_1.v", "$hdl/video_out.v", "$hdl/bin16_bcd.v", "$hdl/osd_ascii_rom.v", "$hdl/osd_cjk_rom.v", "$hdl/osd_logo_rom.v", "$hdl/inspection_region_config.v", "$hdl/experiment_osd.v", "$ip/w128_d512_fifo/w128_d512_fifo.v", "$ip/w128_d512_fifo/soft_fifo_al_4057d6b76aa6.v", "tb_lane_hd_pins.v")},
        @{Name="threshold180"; Pass="PASS threshold180:"; Sources=@("$hdl/inspection_region_config.v", "$hdl/frame_shape_search.v", "tb_threshold180.v")},
        @{Name="raw_timing_probe"; Pass="PASS raw timing probe:"; Sources=($ispSources + @("tb_raw_timing_probe.v"))},
        @{Name="base_picture_repeatability"; Pass="PASS base picture repeatability:"; Sources=($ispSources + @("$hdl/image_correction.v", "tb_base_picture_repeatability.v"))},
        @{Name="pose180"; Pass="PASS pose180:"; Sources=@("$hdl/inspection_region_config.v", "$hdl/frame_shape_search.v", "tb_pose180.v")},
        @{Name="field180"; Pass="PASS field180:"; Sources=@("$hdl/inspection_region_config.v", "$hdl/frame_shape_search.v", "tb_field180.v")},
        @{Name="cal180_body"; Pass="PASS cal180 body:"; Sources=@("$hdl/inspection_region_config.v", "$hdl/frame_shape_search.v", "tb_cal180_body.v")},
        @{Name="cal180_holes"; Pass="PASS cal180 holes:"; Sources=@("$hdl/inspection_region_config.v", "$hdl/frame_shape_search.v", "tb_cal180_holes.v")},
        @{Name="calibration_late"; Pass="PASS calibration late:"; Sources=@("$hdl/status_cdc.v", "$hdl/video_in.v", "$hdl/video_out.v", "$ip/w128_d512_fifo/w128_d512_fifo.v", "$ip/w128_d512_fifo/soft_fifo_al_4057d6b76aa6.v", "tb_calibration_late.v")},
        @{Name="calibration_probe"; Pass="PASS calibration probe:"; Sources=@("$hdl/roi_statistics.v", "tb_calibration_probe.v")},
        @{Name="local_wait"; Pass="PASS local WAIT:"; Sources=@("$hdl/tape_hole_tracker.v", "tb_local_wait.v")},
        @{Name="calibration_osd"; Pass="PASS calibration OSD:"; Sources=@("$hdl/bin16_bcd.v", "$hdl/osd_ascii_rom.v", "$hdl/osd_cjk_rom.v", "$hdl/osd_logo_rom.v", "$hdl/inspection_region_config.v", "$hdl/experiment_osd.v", "tb_calibration_osd.v")},
        @{Name="field_chain"; Pass="PASS field chain:"; Sources=($ispSources + @("$hdl/image_correction.v", "$hdl/status_cdc.v", "$hdl/video_in.v", "$hdl/video_out.v", "$ip/w128_d512_fifo/w128_d512_fifo.v", "$ip/w128_d512_fifo/soft_fifo_al_4057d6b76aa6.v", "tb_field_chain.v"))},
        @{Name="calibration_chain"; Pass="PASS calibration chain:"; Sources=($ispSources + @("$hdl/image_correction.v", "$hdl/status_cdc.v", "$hdl/video_in.v", "$hdl/video_out.v", "$ip/w128_d512_fifo/w128_d512_fifo.v", "$ip/w128_d512_fifo/soft_fifo_al_4057d6b76aa6.v", "tb_calibration_chain.v"))},
        @{Name="regions_osd"; Pass="PASS regions osd:"; Sources=@("$hdl/bin16_bcd.v", "$hdl/osd_ascii_rom.v", "$hdl/osd_cjk_rom.v", "$hdl/osd_logo_rom.v", "$hdl/inspection_region_config.v", "$hdl/experiment_osd.v", "tb_regions_osd.v")},
        @{Name="stable_ids_osd"; Pass="PASS stable IDs OSD:"; Sources=@("$hdl/bin16_bcd.v", "$hdl/osd_ascii_rom.v", "$hdl/osd_cjk_rom.v", "$hdl/osd_logo_rom.v", "$hdl/inspection_region_config.v", "$hdl/experiment_osd.v", "tb_stable_ids_osd.v")},
        @{Name="regions_chain"; Pass="PASS regions chain:"; Sources=($ispSources + @("$hdl/image_correction.v", "$hdl/status_cdc.v", "$hdl/video_in.v", "$hdl/video_out.v", "$ip/w128_d512_fifo/w128_d512_fifo.v", "$ip/w128_d512_fifo/soft_fifo_al_4057d6b76aa6.v", "tb_regions_chain.v"))},
        @{Name="regions"; Pass="PASS regions:"; Sources=@("$hdl/inspection_region_config.v", "$hdl/frame_shape_search.v", "tb_regions.v")},
        @{Name="hd_pll"; Pass="PASS hd pll:"; Sources=@("$hdl/native_hdmi_pll.v", "$ip/PLL/RTL/ph1p_phy_pll_wrapper_25a56e5ce2f9.v", "tb_hd_pll.v")},
        @{Name="hd_pins"; Pass="PASS hd pins:"; Sources=@("hdmi_ideal_pll.v", "$hdl/native_720p60_vtc.v", "$hdl/native_i60_phase.v", "$hdl/native_i60_tx.v", "$hdl/dvi_encoder.v", "$hdl/wide_view_avi.v", "$hdl/hdmi_phy_warpper.v", "$hdl/lane_lvds_10_1.v", "$hdl/video_out.v", "$hdl/bin16_bcd.v", "$hdl/osd_ascii_rom.v", "$hdl/osd_cjk_rom.v", "$hdl/osd_logo_rom.v", "$hdl/inspection_region_config.v", "$hdl/experiment_osd.v", "$ip/w128_d512_fifo/w128_d512_fifo.v", "$ip/w128_d512_fifo/soft_fifo_al_4057d6b76aa6.v", "tb_hd_pins.v")},
        @{Name="hd_guard"; Pass="PASS hd guard:"; Sources=@("$hdl/roi_frame_guard.v", "tb_hd_guard.v")},
        @{Name="hd_scaled_guard"; Pass="PASS hd scaled guard:"; Sources=@("$hdl/scaled_frame_guard.v", "tb_hd_scaled_guard.v")},
        @{Name="hd_osd"; Pass="PASS hd osd:"; Sources=@("$hdl/bin16_bcd.v", "$hdl/osd_ascii_rom.v", "$hdl/osd_cjk_rom.v", "$hdl/osd_logo_rom.v", "$hdl/inspection_region_config.v", "$hdl/experiment_osd.v", "tb_hd_osd.v")},
        @{Name="hd_resize"; Pass="PASS hd resize:"; Sources=@("$hdl/rgb_resize_2_3.v", "$hdl/rgb96_packetizer.v", "tb_hd_resize.v")},
        @{Name="hd_search"; Pass="PASS hd search:"; Sources=@("$hdl/inspection_region_config.v", "$hdl/frame_shape_search.v", "tb_hd_search.v")},
        @{Name="hd_chain"; Pass="PASS hd chain:"; Sources=($ispSources + @("$hdl/image_correction.v", "$hdl/status_cdc.v", "$hdl/video_in.v", "$hdl/video_out.v", "tb_hd_chain.v"))},
        @{Name="process_bridge"; Pass="PASS process bridge:"; Sources=@("$hdl/frame_process_bridge.v", "$ip/w128_d512_fifo/w128_d512_fifo.v", "$ip/w128_d512_fifo/soft_fifo_al_4057d6b76aa6.v", "tb_process_bridge.v")},
        @{Name="frame_search"; Pass="PASS frame search:"; Sources=@("$hdl/inspection_region_config.v", "$hdl/frame_shape_search.v", "tb_frame_search.v")},
        @{Name="presence_review"; Pass="PASS presence review:"; Sources=@("$hdl/roi_shape_search.v", "tb_presence_review.v")},
        @{Name="frame_osd"; Pass="PASS frame OSD:"; Sources=@("$hdl/bin16_bcd.v", "$hdl/osd_ascii_rom.v", "$hdl/osd_cjk_rom.v", "$hdl/osd_logo_rom.v", "$hdl/inspection_region_config.v", "$hdl/experiment_osd.v", "tb_frame_osd.v")},
        @{Name="local_osd"; Pass="PASS local OSD:"; Sources=@("$hdl/bin16_bcd.v", "$hdl/osd_ascii_rom.v", "$hdl/osd_cjk_rom.v", "$hdl/osd_logo_rom.v", "$hdl/inspection_region_config.v", "$hdl/experiment_osd.v", "tb_local_osd.v")},
        @{Name="local_isp"; Pass="PASS local ISP:"; Sources=($ispSources + @("tb_local_isp.v"))},
        @{Name="local_search"; Pass="PASS local search:"; Sources=@("$hdl/roi_shape_search.v", "tb_local_search.v")},
        @{Name="shape_snapshot"; Pass="PASS shape snapshot:"; Sources=@("$hdl/roi_observation_snapshot.v", "tb_shape_snapshot.v")},
        @{Name="shape_model"; Pass="PASS shape model:"; Sources=@("$hdl/roi_shape_model.v", "tb_shape_model.v")},
        @{Name="shape_isp"; Pass="PASS shape ISP:"; Sources=($ispSources + @("tb_shape_isp.v"))},
        @{Name="direct_modes"; Pass="PASS direct modes:"; Sources=@("$hdl/roi_mode_classifier.v", "tb_direct_modes.v")},
        @{Name="direct_isp"; Pass="PASS direct ISP:"; Sources=($ispSources + @("tb_direct_isp.v"))},
        @{Name="direct_video"; Pass="PASS direct video:"; Sources=($ispSources + @("$hdl/image_correction.v", "$hdl/status_cdc.v", "$hdl/video_in.v", "$hdl/video_out.v", "$ip/w128_d512_fifo/w128_d512_fifo.v", "$ip/w128_d512_fifo/soft_fifo_al_4057d6b76aa6.v", "tb_direct_video.v"))},
        @{Name="shape_video"; Pass="PASS shape video:"; Sources=($ispSources + @("$hdl/image_correction.v", "$hdl/status_cdc.v", "$hdl/video_in.v", "$hdl/video_out.v", "$ip/w128_d512_fifo/w128_d512_fifo.v", "$ip/w128_d512_fifo/soft_fifo_al_4057d6b76aa6.v", "tb_shape_video.v"))},
        @{Name="frame_tailproof"; Pass="PASS frame tail proof:"; Sources=($ispSources + @("$hdl/image_correction.v", "$hdl/status_cdc.v", "$hdl/video_in.v", "$hdl/video_out.v", "$ip/w128_d512_fifo/w128_d512_fifo.v", "$ip/w128_d512_fifo/soft_fifo_al_4057d6b76aa6.v", "tb_frame_tailproof.v"))},
        @{Name="frame_stop"; Pass="PASS frame stop:"; Sources=($ispSources + @("$hdl/image_correction.v", "$hdl/status_cdc.v", "$hdl/video_in.v", "$hdl/video_out.v", "$ip/w128_d512_fifo/w128_d512_fifo.v", "$ip/w128_d512_fifo/soft_fifo_al_4057d6b76aa6.v", "tb_frame_stop.v"))},
        @{Name="frame_cadence"; Pass="PASS frame cadence:"; Sources=($ispSources + @("$hdl/image_correction.v", "$hdl/status_cdc.v", "$hdl/video_in.v", "$hdl/video_out.v", "$ip/w128_d512_fifo/w128_d512_fifo.v", "$ip/w128_d512_fifo/soft_fifo_al_4057d6b76aa6.v", "tb_frame_cadence.v"))},
        @{Name="frame_process"; Pass="PASS frame process:"; Sources=($ispSources + @("$hdl/image_correction.v", "$hdl/status_cdc.v", "$hdl/video_in.v", "$hdl/video_out.v", "$ip/w128_d512_fifo/w128_d512_fifo.v", "$ip/w128_d512_fifo/soft_fifo_al_4057d6b76aa6.v", "tb_frame_process.v"))},
        @{Name="frame_video"; Pass="PASS frame video:"; Sources=($ispSources + @("$hdl/image_correction.v", "$hdl/status_cdc.v", "$hdl/video_in.v", "$hdl/video_out.v", "$ip/w128_d512_fifo/w128_d512_fifo.v", "$ip/w128_d512_fifo/soft_fifo_al_4057d6b76aa6.v", "tb_frame_video.v"))},
        @{Name="local_video"; Pass="PASS local video:"; Sources=($ispSources + @("$hdl/image_correction.v", "$hdl/status_cdc.v", "$hdl/video_in.v", "$hdl/video_out.v", "$ip/w128_d512_fifo/w128_d512_fifo.v", "$ip/w128_d512_fifo/soft_fifo_al_4057d6b76aa6.v", "tb_local_video.v"))},
        @{Name="direct_osd"; Pass="PASS direct OSD:"; Sources=@("$hdl/bin16_bcd.v", "$hdl/osd_ascii_rom.v", "$hdl/osd_cjk_rom.v", "$hdl/osd_logo_rom.v", "$hdl/inspection_region_config.v", "$hdl/experiment_osd.v", "tb_direct_osd.v")},
        @{Name="shape_osd"; Pass="PASS shape OSD:"; Sources=@("$hdl/bin16_bcd.v", "$hdl/osd_ascii_rom.v", "$hdl/osd_cjk_rom.v", "$hdl/osd_logo_rom.v", "$hdl/inspection_region_config.v", "$hdl/experiment_osd.v", "tb_shape_osd.v")},
        @{Name="geometry_polarity"; Pass="PASS geometry polarity:"; Sources=@("$hdl/multi_pocket_detector.v", "tb_geometry_polarity.v")},
        @{Name="rectangular_anchors"; Pass="PASS rectangular anchors:"; Sources=@("$hdl/multi_pocket_detector.v", "tb_rectangular_anchors.v")},
        @{Name="multi_first_invalid"; Pass="PASS multi first invalid:"; Sources=($ispSources + @("tb_multi_first_invalid.v"))},
        @{Name="video_late_display"; Pass="PASS video late display:"; Sources=@("$hdl/status_cdc.v", "$hdl/video_in.v", "$hdl/video_out.v", "$ip/w128_d512_fifo/w128_d512_fifo.v", "$ip/w128_d512_fifo/soft_fifo_al_4057d6b76aa6.v", "tb_video_late_display.v")},
        @{Name="video_fallback_display"; Pass="PASS video fallback display:"; Sources=@("$hdl/status_cdc.v", "$hdl/video_in.v", "$hdl/video_out.v", "$ip/w128_d512_fifo/w128_d512_fifo.v", "$ip/w128_d512_fifo/soft_fifo_al_4057d6b76aa6.v", "tb_video_fallback_display.v")},
        @{Name="multi_video"; Pass="PASS multi video:"; Sources=($ispSources + @("$hdl/image_correction.v", "$hdl/status_cdc.v", "$hdl/video_in.v", "$hdl/video_out.v", "$ip/w128_d512_fifo/w128_d512_fifo.v", "$ip/w128_d512_fifo/soft_fifo_al_4057d6b76aa6.v", "tb_multi_video.v"))},
        @{Name="video_first"; Pass="PASS video first:"; Sources=@("$hdl/status_cdc.v", "$hdl/video_in.v", "$ip/w128_d512_fifo/w128_d512_fifo.v", "$ip/w128_d512_fifo/soft_fifo_al_4057d6b76aa6.v", "tb_video_first.v")},
        @{Name="frame_wait_metadata"; Pass="PASS frame wait metadata:"; Sources=@("$hdl/status_cdc.v", "$hdl/video_in.v", "$ip/w128_d512_fifo/w128_d512_fifo.v", "$ip/w128_d512_fifo/soft_fifo_al_4057d6b76aa6.v", "tb_frame_wait_metadata.v")},
        @{Name="video_metadata_fallback"; Pass="PASS video metadata fallback:"; Sources=@("$hdl/status_cdc.v", "$hdl/video_in.v", "$ip/w128_d512_fifo/w128_d512_fifo.v", "$ip/w128_d512_fifo/soft_fifo_al_4057d6b76aa6.v", "tb_video_metadata_fallback.v")},
        @{Name="writer_epoch"; Pass="PASS writer epoch:"; Sources=@("$hdl/status_cdc.v", "$hdl/video_in.v", "$ip/w128_d512_fifo/w128_d512_fifo.v", "$ip/w128_d512_fifo/soft_fifo_al_4057d6b76aa6.v", "tb_writer_epoch.v")},
        @{Name="multi_writer"; Pass="PASS multi writer:"; Sources=($ispSources + @("$hdl/status_cdc.v", "$hdl/video_in.v", "$ip/w128_d512_fifo/w128_d512_fifo.v", "$ip/w128_d512_fifo/soft_fifo_al_4057d6b76aa6.v", "tb_multi_writer.v"))},
        @{Name="multi_pockets"; Pass="PASS multi pockets:"; Sources=@("$hdl/multi_pocket_detector.v", "$hdl/roi_sobel_view.v", "tb_multi_pockets.v")},
        @{Name="isp_multi"; Pass="PASS actual ISP multi:"; Sources=($ispSources + @("tb_isp_multi.v"))},
        @{Name="multi_osd"; Pass="PASS multi OSD:"; Sources=@("$hdl/bin16_bcd.v", "$hdl/osd_ascii_rom.v", "$hdl/osd_cjk_rom.v", "$hdl/osd_logo_rom.v", "$hdl/inspection_region_config.v", "$hdl/experiment_osd.v", "tb_multi_osd.v")},
        @{Name="multi_metadata"; Pass="PASS multi metadata:"; Sources=@("$hdl/status_cdc.v", "$hdl/video_in.v", "$hdl/video_out.v", "$ip/w128_d512_fifo/w128_d512_fifo.v", "$ip/w128_d512_fifo/soft_fifo_al_4057d6b76aa6.v", "tb_multi_metadata.v")},
        @{Name="publish_diag"; Pass="PASS publish diagnostic:"; Sources=@("$hdl/status_cdc.v", "$hdl/video_in.v", "$ip/w128_d512_fifo/w128_d512_fifo.v", "$ip/w128_d512_fifo/soft_fifo_al_4057d6b76aa6.v", "tb_publish_diag.v")},
        @{Name="tracking_late"; Pass="PASS tracking late:"; Sources=@("$hdl/tape_hole_tracker.v", "$hdl/roi_statistics.v", "tb_tracking_late.v")},
        @{Name="tracking_status"; Pass="PASS tracking status:"; Sources=@("$hdl/tape_hole_tracker.v", "tb_tracking_status.v")},
        @{Name="isp_tracking_late"; Pass="PASS actual ISP tracking late:"; Sources=($ispSources + @("tb_isp_tracking_late.v"))},
        @{Name="tracking_age"; Pass="PASS tracking age:"; Sources=@("$hdl/tape_hole_tracker.v", "tb_tracking_age.v")},
        @{Name="isp_tracking"; Pass="PASS actual ISP tracking:"; Sources=($ispSources + @("tb_isp_tracking.v"))},
        @{Name="tracking_osd"; Pass="PASS tracking OSD:"; Sources=@("$hdl/bin16_bcd.v", "$hdl/osd_ascii_rom.v", "$hdl/osd_cjk_rom.v", "$hdl/osd_logo_rom.v", "$hdl/inspection_region_config.v", "$hdl/experiment_osd.v", "tb_tracking_osd.v")},
        @{Name="tracking"; Pass="PASS tracking:"; Sources=@("$hdl/tape_hole_tracker.v", "$hdl/roi_statistics.v", "tb_tracking.v")},
        @{Name="dynamic_sobel"; Pass="PASS dynamic Sobel:"; Sources=@("$hdl/roi_sobel_view.v", "$hdl/isp/data96_128/data96_128.v", "tb_dynamic_sobel.v")},
        @{Name="frame_metadata"; Pass="PASS frame metadata:"; Sources=@("$hdl/status_cdc.v", "$hdl/video_in.v", "$hdl/video_out.v", "$ip/w128_d512_fifo/w128_d512_fifo.v", "$ip/w128_d512_fifo/soft_fifo_al_4057d6b76aa6.v", "tb_frame_metadata.v")},
        @{Name="wb_controls"; Pass="PASS WB controls:"; Sources=@("$hdl/uiisp_beta/ae_set.v", "tb_wb_controls.v")},
        @{Name="manual_wb"; Pass="PASS manual WB:"; Sources=@("$hdl/awb.v", "$hdl/signal_delay.v", "$ip/divider/divider_gate.v", "$ip/blk_mem_gen_awb_delay_signal/blk_mem_gen_awb_delay_signal.v", "$ip/blk_mem_gen_awb_delay_signal/ram_f84573da5ab5.v", "tb_manual_wb.v")},
        @{Name="wb_epoch"; Pass="PASS WB epoch:"; Sources=@("$hdl/status_cdc.v", "$hdl/roi_observation_snapshot.v", "$hdl/roi_display_state.v", "tb_wb_epoch.v")},
        @{Name="fixed_wb"; Pass="PASS fixed WB:"; Sources=@("$hdl/awb.v", "$hdl/signal_delay.v", "$ip/divider/divider_gate.v", "$ip/blk_mem_gen_awb_delay_signal/blk_mem_gen_awb_delay_signal.v", "$ip/blk_mem_gen_awb_delay_signal/ram_f84573da5ab5.v", "tb_fixed_wb.v")},
        @{Name="presence_modes"; Pass="PASS presence modes:"; Sources=@("$hdl/roi_mode_classifier.v", "$hdl/roi_tape_guard.v", "$hdl/roi_classifier.v", "$hdl/roi_result_snapshot.v", "$hdl/roi_display_state.v", "$hdl/status_cdc.v", "tb_presence_modes.v")},
        @{Name="isp_metadata_stop"; Pass="PASS actual ISP metadata stop:"; Sources=($ispSources + @("$hdl/observation_controls.v", "$hdl/status_cdc.v", "$hdl/video_in.v", "$ip/w128_d512_fifo/w128_d512_fifo.v", "$ip/w128_d512_fifo/soft_fifo_al_4057d6b76aa6.v", "tb_isp_metadata_stop.v"))},
        @{Name="isp_writer_stop"; Pass="PASS actual ISP full epoch:"; Sources=($ispSources + @("$hdl/observation_controls.v", "$hdl/status_cdc.v", "$hdl/video_in.v", "$ip/w128_d512_fifo/w128_d512_fifo.v", "$ip/w128_d512_fifo/soft_fifo_al_4057d6b76aa6.v", "tb_isp_writer_stop.v"))},
        @{Name="sobel_tail"; Pass="PASS Sobel tail:"; Sources=@("$hdl/roi_sobel_view.v", "$hdl/isp/data96_128/data96_128.v", "tb_sobel_tail.v")},
        @{Name="sobel_view"; Pass="PASS Sobel view:"; Sources=@("$hdl/roi_sobel_view.v", "$hdl/isp/data96_128/data96_128.v", "tb_sobel_view.v")},
        @{Name="observation"; Pass="PASS observation:"; Sources=@("$hdl/observation_controls.v", "$hdl/roi_observation_snapshot.v", "$hdl/roi_display_state.v", "$hdl/status_cdc.v", "tb_observation.v")},
        @{Name="stop_recovery"; Pass="PASS stop recovery:"; Sources=@("$hdl/input_monitor.v", "$hdl/roi_result_snapshot.v", "$hdl/roi_display_state.v", "$hdl/status_cdc.v", "tb_stop_recovery.v")},
        @{Name="display_state"; Pass="PASS display state:"; Sources=@("$hdl/roi_classifier.v", "$hdl/roi_result_snapshot.v", "$hdl/roi_display_state.v", "$hdl/status_cdc.v", "tb_display_state.v")},
        @{Name="controls"; Pass="PASS controls:"; Sources=@("$hdl/uiisp_beta/ae_set.v", "$hdl/uics500_cfg/uicfgcs500.v", "$hdl/uics500_cfg/uics500reg.v", "$hdl/uics500_cfg/uics500regAE.v", "$hdl/uics500_cfg/SC500GainTbl.v", "tb_controls.v")},
        @{Name="cdc"; Pass="PASS CDC:"; Sources=@("$hdl/status_cdc.v", "tb_cdc.v")},
        @{Name="monitor"; Pass="PASS monitor:"; Sources=@("$hdl/status_cdc.v", "$hdl/input_monitor.v", "tb_monitor.v")},
        @{Name="hd_monitor"; Pass="PASS HD monitor:"; Sources=@("$hdl/status_cdc.v", "$hdl/input_monitor.v", "tb_hd_monitor.v")},
        @{Name="csi_pixels"; Pass="PASS CSI pixels:"; Sources=@("$hdl/isp/csi_unpacket_2lane.v", "$hdl/isp/raw10_unpacket_2lane.v", "tb_csi_pixels.v")},
        @{Name="csi_monitor"; Pass="PASS actual CSI"; Sources=@("$hdl/status_cdc.v", "$hdl/input_monitor.v", "$hdl/isp/csi_unpacket_2lane.v", "$hdl/isp/raw10_unpacket_2lane.v", "tb_csi_monitor.v")},
        @{Name="hd_csi_monitor"; Pass="PASS actual CSI and RAW10 decoder feeding monitor: 1920 x 1080"; Sources=@("$hdl/status_cdc.v", "$hdl/input_monitor.v", "$hdl/isp/csi_unpacket_2lane.v", "$hdl/isp/raw10_unpacket_2lane.v", "tb_csi_monitor.v", "tb_hd_csi_monitor.v")},
        @{Name="i2c"; Pass="PASS I2C actual bus:"; Sources=@("$hdl/uics500_cfg/uii2c.v", "tb_i2c.v")},
        @{Name="osd"; Pass="PASS OSD decimal"; Sources=@("$hdl/bin16_bcd.v", "$hdl/osd_ascii_rom.v", "$hdl/osd_cjk_rom.v", "$hdl/osd_logo_rom.v", "$hdl/inspection_region_config.v", "$hdl/experiment_osd.v", "tb_osd.v")},
        @{Name="pack_boundary"; Pass="PASS pack boundary characterization:"; Sources=@("$hdl/isp/data96_128/data96_128.v", "tb_pack_boundary.v")},
        @{Name="pixel_interface"; Pass="PASS pixel boundary characterization;"; Sources=@(
            "$hdl/awb.v", "$hdl/signal_delay.v", "$hdl/isp/data128_96/data128_96.v",
            "$hdl/isp/data96_128/data96_128.v", "$hdl/isp/demosaic_4x_2_0/bilinear_interpolation.v",
            "$ip/divider/divider_gate.v", "$ip/blk_mem_gen_awb_delay_signal/blk_mem_gen_awb_delay_signal.v",
            "$ip/blk_mem_gen_awb_delay_signal/ram_f84573da5ab5.v", "tb_pixel_interface.v")},
        @{Name="roi_guard"; Pass="PASS ROI guard:"; Sources=@("$hdl/roi_frame_guard.v", "$hdl/roi_statistics.v", "tb_roi_guard.v")},
        @{Name="roi_core"; Pass="PASS core ROI:"; Sources=@("$hdl/roi_statistics.v", "tb_roi_core.v")},
        @{Name="classifier"; Pass="PASS classifier:"; Sources=@("$hdl/roi_frame_guard.v", "$hdl/roi_statistics.v", "$hdl/roi_classifier.v", "$hdl/status_cdc.v", "tb_classifier.v")},
        @{Name="roi_chain"; Pass="PASS actual ROI chain:"; Sources=($ispSources + @("tb_roi_chain.v"))}
    )
    # Negative investigations stay opt-in while the production issue is open.
    if ($OnlyTests.Count -eq 0) {
        $tests = @($tests | Where-Object { $_.Name -notin @("raw_timing_probe", "base_picture_repeatability") })
    }
    if ($OnlyTests.Count -gt 0) {
        foreach ($requested in $OnlyTests) {
            if ($requested -notin $tests.Name) { throw "Unknown test: $requested" }
        }
        $tests = @($tests | Where-Object { $_.Name -in $OnlyTests })
        if ($tests.Count -eq 0) { throw "Requested tests were not selected" }
    }
    foreach ($test in $tests) {
        $library = "test_" + $test.Name
        $directory = "modelsim_work/" + $test.Name
        if ($test.Name -eq "pixel_interface" -and $TieUnusedAwbRamInputs) {
            $directory += "_tied_inputs"
            $library += "_tied_inputs"
        }
        if (!(Test-Path -LiteralPath "$directory/_info")) {
            & "$ModelSimBin/vlib.exe" $directory *> "$($test.Name)_setup.log"
            if ($LASTEXITCODE -ne 0) { throw "Library creation failed: $($test.Name)" }
        }
        & "$ModelSimBin/vmap.exe" $library $directory >> "$($test.Name)_setup.log" 2>&1
        if ($LASTEXITCODE -ne 0) { throw "Library mapping failed: $($test.Name)" }
        # Keep legacy RTL in its declared Verilog mode; only testbenches use SV.
        $rtlSources = @($test.Sources)[0..($test.Sources.Count-2)]
        $testbench = $test.Sources[-1]
        & "$ModelSimBin/vlog.exe" -work $library @rtlSources *> "$directory/compile.log"
        if ($LASTEXITCODE -ne 0) { throw "Compile failed: $($test.Name); see $directory/compile.log" }
        $defines = @()
        if ($test.Name -eq "pixel_interface" -and $TieUnusedAwbRamInputs) {
            $defines += "+define+MODELSIM_TIE_UNUSED_AWB_RAM_INPUTS"
        }
        & "$ModelSimBin/vlog.exe" -sv -work $library @defines $testbench >> "$directory/compile.log" 2>&1
        if ($LASTEXITCODE -ne 0) { throw "Testbench compile failed: $($test.Name); see $directory/compile.log" }
        $tops = @("$library.tb_$($test.Name)")
        if ($test.Name -in @("raw_timing_probe", "base_picture_repeatability", "fixed_wb", "manual_wb", "pixel_interface", "roi_chain", "isp_writer_stop", "isp_metadata_stop", "isp_tracking", "isp_tracking_late", "isp_multi", "multi_writer", "multi_video", "multi_first_invalid", "direct_isp", "direct_video", "shape_isp", "shape_video", "local_isp", "local_video", "frame_video", "frame_tailproof", "frame_stop", "frame_process", "frame_cadence", "hd_chain", "regions_chain", "calibration_chain", "field_chain", "hd_pins", "hd_pll")) { $tops += @("anlogic_sim.glbl", "anlogic_sim.PH1P_PHY_GSR") }
        $commands = "log /tb_$($test.Name)/*; run -all; quit -code 1 -force"
        if ($test.Name -in @("hd_pins", "hd_pll")) { $commands = "run -all; quit -code 1 -force" }
        if ($test.Name -in @("shape_isp", "local_isp", "frame_video", "frame_tailproof", "frame_stop", "frame_process", "frame_cadence", "hd_chain", "regions_chain", "calibration_chain", "field_chain", "hd_pins", "hd_pll")) { $commands = "log /tb_$($test.Name)/frame_no; run -all; quit -code 1 -force" }
        if ($test.Name -in @("raw_timing_probe", "base_picture_repeatability")) { $commands = "run -all; quit -code 1 -force" }
        $access = "+acc"
        if ($test.Name -in @("raw_timing_probe", "base_picture_repeatability", "roi_chain", "isp_writer_stop", "isp_metadata_stop", "isp_tracking", "isp_tracking_late", "isp_multi", "multi_writer", "multi_video", "multi_first_invalid", "direct_isp", "direct_video", "shape_isp", "shape_video", "local_isp", "local_video", "frame_video", "frame_tailproof", "frame_stop", "frame_process", "frame_cadence", "hd_chain", "regions_chain", "calibration_chain", "field_chain", "hd_pins", "hd_pll")) { $access = "+acc=rn+/tb_$($test.Name)" }
        & "$ModelSimBin/vsim.exe" -c -L anlogic_sim "-voptargs=$access" -onfinish exit -l "$directory/transcript.log" -wlf "$directory/wave.wlf" -do $commands @tops *> "$directory/console.log"
        if ($LASTEXITCODE -ne 0) { throw "Simulation failed: $($test.Name); see $directory/console.log" }
        $output = Get-Content -LiteralPath "$directory/console.log" -Raw
        if (!$output.Contains($test.Pass) -or $output -match '(?m)^#?\s*\*\* (Fatal|Error):') {
            throw "Missing successful completion or fatal diagnostic: $($test.Name); see $directory/console.log"
        }
        Get-Content -LiteralPath "$directory/console.log" | Where-Object { $_ -match '(PASS |OBS )' }
    }
    if ($TieUnusedAwbRamInputs) {
        Write-Output "PASS ModelSim diagnostic: $($tests.Count) tests with AWB RAM unused inputs forced to zero; original RTL is not accepted by this result"
    } else {
        Write-Output "PASS ModelSim: all $($tests.Count) tests, including original vendor ERAM model"
    }
} finally { Pop-Location }

