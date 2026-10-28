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
        "$hdl/classified_pocket_counter.v", "$hdl/classified_count_pipeline.v",
        "$hdl/rgb_resize_2_3.v", "$hdl/rgb96_packetizer.v", "$hdl/scaled_frame_guard.v",
        "$hdl/frame_process_bridge.v", "$ip/w128_d512_fifo/w128_d512_fifo.v", "$ip/w128_d512_fifo/soft_fifo_al_4057d6b76aa6.v", "$hdl/inspection_region_config.v", "$hdl/empty_candidate_probe.v", "$hdl/present_surface_check.v", "$hdl/local_edge_surface_check.v", "$hdl/present_review_probe.v", "$hdl/frame_shape_search.v", "$hdl/roi_shape_search.v", "$hdl/roi_shape_model.v", "$hdl/isp/uial2axis.v", "$hdl/isp/isp_top.v", "$hdl/tape_hole_tracker.v", "$hdl/multi_pocket_detector.v", "$hdl/roi_frame_guard.v", "$hdl/roi_statistics.v", "$hdl/roi_classifier.v", "$hdl/roi_mode_classifier.v", "$hdl/roi_tape_guard.v", "$hdl/roi_result_snapshot.v", "$hdl/roi_sobel_view.v", "$hdl/roi_observation_snapshot.v",
        "$hdl/awb.v", "$hdl/signal_delay.v", "$hdl/isp/data128_96/data128_96.v", "$hdl/isp/data96_128/data96_128.v",
        "$demosaic/demosaic.v", "$demosaic/raw_matrix_3x3_buffer.v", "$demosaic/zhenghe.v",
        "$demosaic/line_buffer_demosaic.v", "$demosaic/mipi_to_raw_converter.v", "$demosaic/bilinear_interpolation.v",
        "$demosaic/blk_mem_gen_demosaic/blk_mem_gen_demosaic.v", "$demosaic/blk_mem_gen_demosaic/RTL/ram_c36c2ca3b3a7.v",
        "$demosaic/blk_mem_gen_zhenghe/blk_mem_gen_zhenghe.v", "$demosaic/blk_mem_gen_zhenghe/RTL/ram_d32970204f32.v",
        "$ip/divider/divider_gate.v", "$ip/blk_mem_gen_awb_delay_signal/blk_mem_gen_awb_delay_signal.v",
        "$ip/blk_mem_gen_awb_delay_signal/ram_f84573da5ab5.v")
    $tests = @(
        @{Name="edge_adversary"; Pass="PASS LOCAL_EDGE_DETECTOR:"; Sources=@("$hdl/inspection_region_config.v", "$hdl/empty_candidate_probe.v", "$hdl/present_surface_check.v", "$hdl/local_edge_surface_check.v", "$hdl/present_review_probe.v", "$hdl/frame_shape_search.v", "local_edge/frame_shape_search_r21.v", "local_edge/tb_edge_adversary.sv")},
        @{Name="edge_legacy_negatives"; Pass="PASS CONTEXT_GUARD32:"; Sources=@("$hdl/inspection_region_config.v", "$hdl/empty_candidate_probe.v", "$hdl/present_surface_check.v", "$hdl/local_edge_surface_check.v", "$hdl/present_review_probe.v", "$hdl/frame_shape_search.v", "context/frame_shape_search_r19.v", "context/tb_context_guard32.sv", "local_edge/tb_edge_legacy_negatives.sv")},
        @{Name="edge_raw_mode1"; Pass="PASS LOCAL_EDGE_RAW_MODE1:"; Sources=($ispSources + @("$hdl/count_record_view.v", "$hdl/image_correction.v", "$hdl/status_cdc.v", "$hdl/video_in.v", "$hdl/video_out.v", "reference/classified_pocket_counter_R9.v", "local_edge/tb_edge_raw_mode1.v"))},
        @{Name="edge_raw_mode2"; Pass="PASS LOCAL_EDGE_RAW_MODE2:"; Sources=($ispSources + @("$hdl/count_record_view.v", "$hdl/image_correction.v", "$hdl/status_cdc.v", "$hdl/video_in.v", "$hdl/video_out.v", "reference/classified_pocket_counter_R9.v", "local_edge/tb_edge_raw_mode2.v"))},
        @{Name="edge_raw_mode3"; Pass="PASS LOCAL_EDGE_RAW_MODE3:"; Sources=($ispSources + @("$hdl/count_record_view.v", "$hdl/image_correction.v", "$hdl/status_cdc.v", "$hdl/video_in.v", "$hdl/video_out.v", "reference/classified_pocket_counter_R9.v", "local_edge/tb_edge_raw_mode3.v"))},
        @{Name="edge_motion_fast"; Pass="PASS LOCAL_EDGE_FINITE_MOTION:"; Sources=@("$hdl/inspection_region_config.v", "$hdl/empty_candidate_probe.v", "$hdl/present_surface_check.v", "$hdl/local_edge_surface_check.v", "$hdl/present_review_probe.v", "$hdl/frame_shape_search.v", "local_edge/frame_shape_search_r21.v", "$hdl/classified_pocket_counter.v", "$hdl/classified_count_pipeline.v", "local_edge/tb_edge_motion_fast.sv")},
        @{Name="edge_motion_left"; Pass="PASS LOCAL_EDGE_FINITE_MOTION:"; Sources=@("$hdl/inspection_region_config.v", "$hdl/empty_candidate_probe.v", "$hdl/present_surface_check.v", "$hdl/local_edge_surface_check.v", "$hdl/present_review_probe.v", "$hdl/frame_shape_search.v", "local_edge/frame_shape_search_r21.v", "$hdl/classified_pocket_counter.v", "$hdl/classified_count_pipeline.v", "local_edge/tb_edge_motion_left.sv")},
        @{Name="edge_raw"; Pass="PASS LOCAL_EDGE_RAW:"; Sources=($ispSources + @("$hdl/count_record_view.v", "$hdl/image_correction.v", "$hdl/status_cdc.v", "$hdl/video_in.v", "$hdl/video_out.v", "reference/classified_pocket_counter_R9.v", "local_edge/tb_edge_raw.v"))},
        @{Name="edge_ui"; Pass="PASS LOCAL_EDGE_UI: four full HD rasters, metadata frozen midframe, page switch, clear and generation guard; independent pixel reference pending"; Sources=@("$hdl/bin16_bcd.v", "$hdl/osd_ascii_rom.v", "$hdl/osd_cjk_rom.v", "$hdl/osd_logo_rom.v", "$hdl/inspection_region_config.v", "$hdl/experiment_osd.v", "$hdl/classified_count_renderer.v", "$hdl/compact_ascii_rom.v", "$hdl/compact_inspector_osd.v", "$hdl/compact_cjk_rom.v", "$hdl/compact_template_rom.v", "$hdl/classified_dual_page_osd.v", "local_edge/tb_edge_ui.sv")},
        @{Name="edge_unit"; Pass="PASS LOCAL_EDGE_UNIT:"; Sources=@("$hdl/local_edge_surface_check.v", "local_edge/tb_edge_unit.sv")},
        @{Name="edge_detector"; Pass="PASS LOCAL_EDGE_DETECTOR:"; Sources=@("$hdl/inspection_region_config.v", "$hdl/empty_candidate_probe.v", "$hdl/present_surface_check.v", "$hdl/local_edge_surface_check.v", "$hdl/present_review_probe.v", "$hdl/frame_shape_search.v", "local_edge/frame_shape_search_r21.v", "local_edge/tb_edge_detector.sv")},
        @{Name="context_guard32"; Pass="PASS CONTEXT_GUARD32:"; Sources=@("$hdl/inspection_region_config.v", "$hdl/empty_candidate_probe.v", "$hdl/present_surface_check.v", "$hdl/present_review_probe.v", "$hdl/frame_shape_search.v", "context/frame_shape_search_r19.v", "context/tb_context_guard32.sv")},
        @{Name="context_edge36"; Pass="PASS CONTEXT_EDGE36:"; Sources=@("$hdl/inspection_region_config.v", "$hdl/empty_candidate_probe.v", "$hdl/present_surface_check.v", "$hdl/present_review_probe.v", "$hdl/frame_shape_search.v", "context/frame_shape_search_r19.v", "context/tb_context_edge36.sv")},
        @{Name="context_no_body4"; Pass="PASS CONTEXT_NO_BODY4:"; Sources=@("$hdl/inspection_region_config.v", "$hdl/empty_candidate_probe.v", "$hdl/present_surface_check.v", "$hdl/present_review_probe.v", "$hdl/frame_shape_search.v", "context/frame_shape_search_r19.v", "context/tb_context_no_body4.sv")},
        @{Name="context_abort"; Pass="PASS CONTEXT_ABORT:"; Sources=@("$hdl/inspection_region_config.v", "$hdl/empty_candidate_probe.v", "$hdl/present_surface_check.v", "$hdl/present_review_probe.v", "$hdl/frame_shape_search.v", "context/frame_shape_search_r19.v", "context/tb_context_abort.sv")},
        @{Name="context_motion_slow"; Pass="PASS CONTEXT_FINITE_MOTION:"; Sources=@("$hdl/inspection_region_config.v", "$hdl/empty_candidate_probe.v", "$hdl/present_surface_check.v", "$hdl/present_review_probe.v", "$hdl/frame_shape_search.v", "context/frame_shape_search_r19.v", "$hdl/classified_pocket_counter.v", "$hdl/classified_count_pipeline.v", "context/tb_context_motion_slow.sv")},
        @{Name="context_motion_normal"; Pass="PASS CONTEXT_FINITE_MOTION:"; Sources=@("$hdl/inspection_region_config.v", "$hdl/empty_candidate_probe.v", "$hdl/present_surface_check.v", "$hdl/present_review_probe.v", "$hdl/frame_shape_search.v", "context/frame_shape_search_r19.v", "$hdl/classified_pocket_counter.v", "$hdl/classified_count_pipeline.v", "context/tb_context_motion_normal.sv")},
        @{Name="context_motion_fast"; Pass="PASS CONTEXT_FINITE_MOTION:"; Sources=@("$hdl/inspection_region_config.v", "$hdl/empty_candidate_probe.v", "$hdl/present_surface_check.v", "$hdl/present_review_probe.v", "$hdl/frame_shape_search.v", "context/frame_shape_search_r19.v", "$hdl/classified_pocket_counter.v", "$hdl/classified_count_pipeline.v", "context/tb_context_motion_fast.sv")},
        @{Name="context_motion_fast_left"; Pass="PASS CONTEXT_FINITE_MOTION:"; Sources=@("$hdl/inspection_region_config.v", "$hdl/empty_candidate_probe.v", "$hdl/present_surface_check.v", "$hdl/present_review_probe.v", "$hdl/frame_shape_search.v", "context/frame_shape_search_r19.v", "$hdl/classified_pocket_counter.v", "$hdl/classified_count_pipeline.v", "context/tb_context_motion_fast_left.sv")},
        @{Name="context_motion_phase19"; Pass="PASS CONTEXT_FINITE_MOTION:"; Sources=@("$hdl/inspection_region_config.v", "$hdl/empty_candidate_probe.v", "$hdl/present_surface_check.v", "$hdl/present_review_probe.v", "$hdl/frame_shape_search.v", "context/frame_shape_search_r19.v", "$hdl/classified_pocket_counter.v", "$hdl/classified_count_pipeline.v", "context/tb_context_motion_phase19.sv")},
        @{Name="context_motion_close_cut"; Pass="PASS CONTEXT_FINITE_MOTION:"; Sources=@("$hdl/inspection_region_config.v", "$hdl/empty_candidate_probe.v", "$hdl/present_surface_check.v", "$hdl/present_review_probe.v", "$hdl/frame_shape_search.v", "context/frame_shape_search_r19.v", "$hdl/classified_pocket_counter.v", "$hdl/classified_count_pipeline.v", "context/tb_context_motion_close_cut.sv")},
        @{Name="context_motion_consecutive"; Pass="PASS CONTEXT_FINITE_MOTION:"; Sources=@("$hdl/inspection_region_config.v", "$hdl/empty_candidate_probe.v", "$hdl/present_surface_check.v", "$hdl/present_review_probe.v", "$hdl/frame_shape_search.v", "context/frame_shape_search_r19.v", "$hdl/classified_pocket_counter.v", "$hdl/classified_count_pipeline.v", "context/tb_context_motion_consecutive.sv")},
        @{Name="context_motion_all_empty"; Pass="PASS CONTEXT_FINITE_MOTION:"; Sources=@("$hdl/inspection_region_config.v", "$hdl/empty_candidate_probe.v", "$hdl/present_surface_check.v", "$hdl/present_review_probe.v", "$hdl/frame_shape_search.v", "context/frame_shape_search_r19.v", "$hdl/classified_pocket_counter.v", "$hdl/classified_count_pipeline.v", "context/tb_context_motion_all_empty.sv")},
        @{Name="context_motion_single_empty"; Pass="PASS CONTEXT_FINITE_MOTION:"; Sources=@("$hdl/inspection_region_config.v", "$hdl/empty_candidate_probe.v", "$hdl/present_surface_check.v", "$hdl/present_review_probe.v", "$hdl/frame_shape_search.v", "context/frame_shape_search_r19.v", "$hdl/classified_pocket_counter.v", "$hdl/classified_count_pipeline.v", "context/tb_context_motion_single_empty.sv")},
        @{Name="context_raw"; Pass="PASS context raw:"; Sources=($ispSources + @("$hdl/count_record_view.v", "$hdl/image_correction.v", "$hdl/status_cdc.v", "$hdl/video_in.v", "$hdl/video_out.v", "reference/classified_pocket_counter_R9.v", "context/tb_context_raw.v"))},
        @{Name="context_tail_raw"; Pass="PASS context_tail_raw:"; Sources=($ispSources + @("$hdl/count_record_view.v", "$hdl/image_correction.v", "$hdl/status_cdc.v", "$hdl/video_in.v", "$hdl/video_out.v", "reference/classified_pocket_counter_R10.v", "context/tb_context_tail_raw.sv"))},
        @{Name="context_ui"; Pass="PASS R20 context UI:"; Sources=@("$hdl/bin16_bcd.v", "$hdl/osd_ascii_rom.v", "$hdl/osd_cjk_rom.v", "$hdl/osd_logo_rom.v", "$hdl/inspection_region_config.v", "$hdl/experiment_osd.v", "$hdl/classified_count_renderer.v", "$hdl/compact_ascii_rom.v", "$hdl/compact_inspector_osd.v", "$hdl/compact_cjk_rom.v", "$hdl/compact_template_rom.v", "$hdl/classified_dual_page_osd.v", "context/tb_context_ui.sv")},
        @{Name="robust_empty_ab"; Pass="PASS MOTION_STUDY_AB:"; Sources=@("$hdl/inspection_region_config.v", "$hdl/empty_candidate_probe.v", "$hdl/present_surface_check.v", "$hdl/present_review_probe.v", "$hdl/frame_shape_search.v", "motion/frame_shape_search_r18.v", "motion/tb_robust_empty_ab.sv")},
        @{Name="robust_empty15_clear"; Pass="PASS EMPTY15_MOTION:"; Sources=@("$hdl/inspection_region_config.v", "$hdl/empty_candidate_probe.v", "$hdl/present_surface_check.v", "$hdl/present_review_probe.v", "$hdl/frame_shape_search.v", "motion/frame_shape_search_r18.v", "$hdl/classified_pocket_counter.v", "$hdl/classified_count_pipeline.v", "motion/tb_robust_empty15_clear.sv")},
        @{Name="robust_empty15_14"; Pass="PASS EMPTY15_MOTION:"; Sources=@("$hdl/inspection_region_config.v", "$hdl/empty_candidate_probe.v", "$hdl/present_surface_check.v", "$hdl/present_review_probe.v", "$hdl/frame_shape_search.v", "motion/frame_shape_search_r18.v", "$hdl/classified_pocket_counter.v", "$hdl/classified_count_pipeline.v", "motion/tb_robust_empty15_14.sv")},
        @{Name="robust_empty15_17"; Pass="PASS EMPTY15_MOTION:"; Sources=@("$hdl/inspection_region_config.v", "$hdl/empty_candidate_probe.v", "$hdl/present_surface_check.v", "$hdl/present_review_probe.v", "$hdl/frame_shape_search.v", "motion/frame_shape_search_r18.v", "$hdl/classified_pocket_counter.v", "$hdl/classified_count_pipeline.v", "motion/tb_robust_empty15_17.sv")},
        @{Name="robust_empty15_25"; Pass="PASS EMPTY15_MOTION:"; Sources=@("$hdl/inspection_region_config.v", "$hdl/empty_candidate_probe.v", "$hdl/present_surface_check.v", "$hdl/present_review_probe.v", "$hdl/frame_shape_search.v", "motion/frame_shape_search_r18.v", "$hdl/classified_pocket_counter.v", "$hdl/classified_count_pipeline.v", "motion/tb_robust_empty15_25.sv")},
        @{Name="robust_empty15_left"; Pass="PASS EMPTY15_MOTION:"; Sources=@("$hdl/inspection_region_config.v", "$hdl/empty_candidate_probe.v", "$hdl/present_surface_check.v", "$hdl/present_review_probe.v", "$hdl/frame_shape_search.v", "motion/frame_shape_search_r18.v", "$hdl/classified_pocket_counter.v", "$hdl/classified_count_pipeline.v", "motion/tb_robust_empty15_left.sv")},
        @{Name="robust_empty_raw"; Pass="PASS robust empty raw:"; Sources=($ispSources + @("$hdl/count_record_view.v", "$hdl/image_correction.v", "$hdl/status_cdc.v", "$hdl/video_in.v", "$hdl/video_out.v", "reference/classified_pocket_counter_R9.v", "motion/tb_robust_empty_raw.v"))},
        @{Name="robust_empty_ui"; Pass="PASS R19 robust empty UI:"; Sources=@("$hdl/bin16_bcd.v", "$hdl/osd_ascii_rom.v", "$hdl/osd_cjk_rom.v", "$hdl/osd_logo_rom.v", "$hdl/inspection_region_config.v", "$hdl/experiment_osd.v", "$hdl/classified_count_renderer.v", "$hdl/compact_ascii_rom.v", "$hdl/compact_inspector_osd.v", "$hdl/compact_cjk_rom.v", "$hdl/compact_template_rom.v", "$hdl/classified_dual_page_osd.v", "motion/tb_robust_empty_ui.sv")},
        @{Name="standing_surface"; Pass="PASS P03 standing surface:"; Sources=@("$hdl/present_surface_check.v", "standing/present_surface_check_p02.v", "standing/tb_standing_surface.sv")},
        @{Name="standing_detector"; Pass="PASS P03 standing detector:"; Sources=@("$hdl/inspection_region_config.v", "$hdl/empty_candidate_probe.v", "$hdl/present_surface_check.v", "$hdl/present_review_probe.v", "$hdl/frame_shape_search.v", "surface/frame_shape_search_p01.v", "standing/frame_shape_search_p02.v", "standing/present_surface_check_p02.v", "standing/tb_standing_detector.sv")},
        @{Name="standing_counting"; Pass="PASS P03 standing counting:"; Sources=@("$hdl/inspection_region_config.v", "$hdl/empty_candidate_probe.v", "$hdl/present_surface_check.v", "$hdl/present_review_probe.v", "$hdl/frame_shape_search.v", "$hdl/classified_count_pipeline.v", "$hdl/classified_pocket_counter.v", "standing/tb_standing_counting.v")},
        @{Name="standing_raw_chain"; Pass="PASS P03 standing raw chain:"; Sources=($ispSources + @("$hdl/image_correction.v", "$hdl/status_cdc.v", "$hdl/video_in.v", "$hdl/video_out.v", "standing/tb_standing_raw_chain.v"))},
        @{Name="standing_class_only_raw"; Pass="PASS R18 standing class only raw:"; Sources=($ispSources + @("$hdl/image_correction.v", "$hdl/status_cdc.v", "$hdl/video_in.v", "$hdl/video_out.v", "standing/tb_standing_class_only_raw.v"))},
        @{Name="standing_ui"; Pass="PASS R18 standing UI:"; Sources=@("$hdl/bin16_bcd.v", "$hdl/osd_ascii_rom.v", "$hdl/osd_cjk_rom.v", "$hdl/osd_logo_rom.v", "$hdl/inspection_region_config.v", "$hdl/experiment_osd.v", "$hdl/classified_count_renderer.v", "$hdl/compact_ascii_rom.v", "$hdl/compact_inspector_osd.v", "$hdl/compact_cjk_rom.v", "$hdl/compact_template_rom.v", "$hdl/classified_dual_page_osd.v", "standing/tb_standing_ui.sv")},
        @{Name="rgb_shared_equivalence"; Pass="PASS RGB shared equivalence:"; Sources=@("$hdl/roi_sobel_view.v", "reference/R17_roi_sobel_view.v", "standing/tb_rgb_shared_equivalence.sv")},
        @{Name="present_surface_check"; Pass="PASS present surface:"; Sources=@("$hdl/present_surface_check.v", "surface/tb_present_surface_check.sv")},
        @{Name="surface_class_only_indexed"; Pass="PASS surface class only indexed:"; Sources=@("$hdl/inspection_region_config.v", "$hdl/empty_candidate_probe.v", "$hdl/present_surface_check.v", "$hdl/present_review_probe.v", "$hdl/frame_shape_search.v", "surface/frame_shape_search_p01.v", "reference/P02_frame_shape_search.v", "r17_surface/tb_surface_class_only_indexed.sv")},
        @{Name="surface_class_only_raw"; Pass="PASS surface class only raw:"; Sources=($ispSources + @("$hdl/image_correction.v", "$hdl/status_cdc.v", "$hdl/video_in.v", "$hdl/video_out.v", "surface/tb_surface_class_only_raw.v"))},
        @{Name="surface_class_only_ui"; Pass="PASS surface class only UI:"; Sources=@("$hdl/bin16_bcd.v", "$hdl/osd_ascii_rom.v", "$hdl/osd_cjk_rom.v", "$hdl/osd_logo_rom.v", "$hdl/inspection_region_config.v", "$hdl/experiment_osd.v", "$hdl/classified_count_renderer.v", "$hdl/compact_ascii_rom.v", "$hdl/compact_inspector_osd.v", "$hdl/compact_cjk_rom.v", "$hdl/compact_template_rom.v", "$hdl/classified_dual_page_osd.v", "surface/tb_surface_class_only_ui.sv")},
        @{Name="surface_indexed"; Pass="PASS surface indexed:"; Sources=@("$hdl/inspection_region_config.v", "$hdl/empty_candidate_probe.v", "$hdl/present_surface_check.v", "$hdl/present_review_probe.v", "$hdl/frame_shape_search.v", "surface/frame_shape_search_p01.v", "reference/P02_frame_shape_search.v", "r17_surface/tb_surface_indexed.sv")},
        @{Name="surface_counting"; Pass="PASS surface counting:"; Sources=@("$hdl/inspection_region_config.v", "$hdl/empty_candidate_probe.v", "$hdl/present_surface_check.v", "$hdl/present_review_probe.v", "$hdl/frame_shape_search.v", "$hdl/classified_count_pipeline.v", "$hdl/classified_pocket_counter.v", "surface/tb_surface_counting.v")},
        @{Name="surface_indexed_counting"; Pass="PASS surface indexed counting:"; Sources=@("$hdl/inspection_region_config.v", "$hdl/empty_candidate_probe.v", "$hdl/present_surface_check.v", "$hdl/present_review_probe.v", "$hdl/frame_shape_search.v", "$hdl/classified_count_pipeline.v", "$hdl/classified_pocket_counter.v", "r17_surface/tb_surface_indexed_counting.v")},
        @{Name="surface_ui"; Pass="PASS surface UI:"; Sources=@("$hdl/bin16_bcd.v", "$hdl/osd_ascii_rom.v", "$hdl/osd_cjk_rom.v", "$hdl/osd_logo_rom.v", "$hdl/inspection_region_config.v", "$hdl/experiment_osd.v", "$hdl/classified_count_renderer.v", "$hdl/compact_ascii_rom.v", "$hdl/compact_inspector_osd.v", "$hdl/compact_cjk_rom.v", "$hdl/compact_template_rom.v", "$hdl/classified_dual_page_osd.v", "surface/tb_surface_ui.sv")},
        @{Name="surface_raw_chain"; Pass="PASS surface raw chain:"; Sources=($ispSources + @("$hdl/image_correction.v", "$hdl/status_cdc.v", "$hdl/video_in.v", "$hdl/video_out.v", "surface/tb_surface_raw_chain.v"))},
        @{Name="text_plane_prefetch"; Pass="PASS text plane prefetch equivalence:"; Sources=@("$hdl/compact_ascii_rom.v", "$hdl/compact_cjk_rom.v", "$hdl/compact_template_rom.v", "$hdl/osd_logo_rom.v", "$hdl/compact_inspector_osd.v", "reference/R16_previous_compact_inspector_osd_r6.v", "tb_text_plane_prefetch.sv")},
        @{Name="center_capture_equivalence"; Pass="PASS center capture equivalence:"; Sources=@("$hdl/classified_pocket_counter.v", "reference/R15_precenter_classified_pocket_counter.v", "tb_center_capture_equivalence.sv")},
        @{Name="format_cache_equivalence"; Pass="PASS format cache equivalence:"; Sources=@("$hdl/compact_ascii_rom.v", "$hdl/compact_cjk_rom.v", "$hdl/compact_template_rom.v", "$hdl/osd_logo_rom.v", "$hdl/compact_inspector_osd.v", "reference/R16_previous_compact_inspector_osd.v", "tb_format_cache_equivalence.sv")},

        @{Name="gray_cache_equivalence"; Pass="PASS gray cache equivalence:"; Sources=@("$hdl/roi_sobel_view.v", "reference/R15_roi_sobel_view.v", "tb_gray_cache_equivalence.sv")},        @{Name="simple_record_view"; Pass="PASS simple_record_view:"; Sources=@("$hdl/count_record_view.v", "tb_simple_record_view.sv")},
        @{Name="simple_recovery_0"; Pass="PASS simple_recovery_0:"; Sources=@("$hdl/count_record_view.v", "$hdl/classified_pocket_counter.v", "$hdl/classified_count_pipeline.v", "reference/R14_classified_count_pipeline.v", "tb_simple_recovery_0.sv")},
        @{Name="simple_recovery_1"; Pass="PASS simple_recovery_1:"; Sources=@("$hdl/count_record_view.v", "$hdl/classified_pocket_counter.v", "$hdl/classified_count_pipeline.v", "reference/R14_classified_count_pipeline.v", "tb_simple_recovery_1.sv")},
        @{Name="simple_recovery_2"; Pass="PASS simple_recovery_2:"; Sources=@("$hdl/count_record_view.v", "$hdl/classified_pocket_counter.v", "$hdl/classified_count_pipeline.v", "reference/R14_classified_count_pipeline.v", "tb_simple_recovery_2.sv")},
        @{Name="simple_recovery_3"; Pass="PASS simple_recovery_3:"; Sources=@("$hdl/count_record_view.v", "$hdl/classified_pocket_counter.v", "$hdl/classified_count_pipeline.v", "reference/R14_classified_count_pipeline.v", "tb_simple_recovery_3.sv")},
        @{Name="simple_recovery_4"; Pass="PASS simple_recovery_4:"; Sources=@("$hdl/count_record_view.v", "$hdl/classified_pocket_counter.v", "$hdl/classified_count_pipeline.v", "reference/R14_classified_count_pipeline.v", "tb_simple_recovery_4.sv")},
        @{Name="simple_recovery_raw"; Pass="PASS simple_recovery_raw:"; Sources=($ispSources + @("$hdl/count_record_view.v", "$hdl/image_correction.v", "$hdl/status_cdc.v", "$hdl/video_in.v", "$hdl/video_out.v", "reference/classified_pocket_counter_R10.v", "tb_simple_recovery_raw.sv"))},
        @{Name="simple_recovery_ui"; Pass="PASS simple_recovery_ui:"; Sources=@("$hdl/bin16_bcd.v", "$hdl/osd_ascii_rom.v", "$hdl/osd_cjk_rom.v", "$hdl/osd_logo_rom.v", "$hdl/inspection_region_config.v", "$hdl/experiment_osd.v", "$hdl/classified_count_renderer.v", "$hdl/compact_ascii_rom.v", "$hdl/compact_inspector_osd.v", "$hdl/compact_cjk_rom.v", "$hdl/compact_template_rom.v", "$hdl/classified_dual_page_osd.v", "tb_simple_recovery_ui.sv")},
        @{Name="compact_ui"; Pass="PASS compact UI:"; Sources=@("$hdl/bin16_bcd.v", "$hdl/osd_ascii_rom.v", "$hdl/osd_cjk_rom.v", "$hdl/osd_logo_rom.v", "$hdl/inspection_region_config.v", "$hdl/experiment_osd.v", "$hdl/classified_count_renderer.v", "$hdl/compact_ascii_rom.v", "$hdl/compact_inspector_osd.v", "$hdl/compact_cjk_rom.v", "$hdl/compact_template_rom.v", "$hdl/classified_dual_page_osd.v", "tb_compact_ui.sv")},
        @{Name="line_ram_equivalence"; Pass="PASS line RAM equivalence:"; Sources=@("$hdl/signal_delay.v", "$demosaic/line_buffer_demosaic.v", "$demosaic/zhenghe.v", "$demosaic/blk_mem_gen_demosaic/blk_mem_gen_demosaic.v", "$demosaic/blk_mem_gen_demosaic/RTL/ram_c36c2ca3b3a7.v", "$demosaic/blk_mem_gen_zhenghe/blk_mem_gen_zhenghe.v", "$demosaic/blk_mem_gen_zhenghe/RTL/ram_d32970204f32.v", "$ip/blk_mem_gen_awb_delay_signal/blk_mem_gen_awb_delay_signal.v", "$ip/blk_mem_gen_awb_delay_signal/ram_f84573da5ab5.v", "reference/resource_R12_signal_delay.v", "reference/resource_R12_line_buffer_demosaic.v", "reference/resource_R12_zhenghe.v", "tb_line_ram_equivalence.sv")},
        @{Name="dual_phase"; Pass="PASS dual phase "; Sources=@("$hdl/inspection_region_config.v", "$hdl/empty_candidate_probe.v", "$hdl/present_surface_check.v", "$hdl/present_review_probe.v", "$hdl/frame_shape_search.v", "tb_dual_phase.v")},
        @{Name="dual_guard"; Pass="PASS dual guard:"; Sources=@("$hdl/inspection_region_config.v", "$hdl/empty_candidate_probe.v", "$hdl/present_surface_check.v", "$hdl/present_review_probe.v", "$hdl/frame_shape_search.v", "tb_dual_guard.v")},
        @{Name="dual_motion"; Pass="PASS dual motion:"; Sources=@("$hdl/inspection_region_config.v", "$hdl/empty_candidate_probe.v", "$hdl/present_surface_check.v", "$hdl/present_review_probe.v", "$hdl/frame_shape_search.v", "$hdl/classified_pocket_counter.v", "reference/frame_shape_search_R11.v", "tb_dual_motion.v")},
        @{Name="dual_raw_motion"; Pass="PASS dual raw motion:"; Sources=($ispSources + @("$hdl/image_correction.v", "$hdl/status_cdc.v", "$hdl/video_in.v", "$hdl/video_out.v", "reference/classified_pocket_counter_R9.v", "tb_dual_raw_motion.v"))},
        @{Name="dual_page"; Pass="PASS dual page:"; Sources=@("$hdl/bin16_bcd.v", "$hdl/osd_ascii_rom.v", "$hdl/osd_cjk_rom.v", "$hdl/osd_logo_rom.v", "$hdl/inspection_region_config.v", "$hdl/experiment_osd.v", "$hdl/classified_count_renderer.v", "$hdl/classified_dual_page_osd.v", "tb_dual_page.v")},
        @{Name="local_stream"; Pass="PASS local stream:"; Sources=@("$hdl/classified_pocket_counter.v", "$hdl/classified_count_pipeline.v", "tb_local_stream.v")},
        @{Name="local_capacity"; Pass="PASS local capacity:"; Sources=@("$hdl/classified_pocket_counter.v", "$hdl/classified_count_pipeline.v", "tb_local_capacity.v")},
        @{Name="local_recovery"; Pass="PASS local recovery case="; Sources=@("$hdl/classified_pocket_counter.v", "tb_local_recovery.v")},
        @{Name="local_short"; Pass="PASS local recovery case="; Sources=@("$hdl/classified_pocket_counter.v", "tb_local_short.v")},
        @{Name="local_missing"; Pass="PASS local recovery case="; Sources=@("$hdl/classified_pocket_counter.v", "tb_local_missing.v")},
        @{Name="local_ambiguity"; Pass="PASS local recovery case="; Sources=@("$hdl/classified_pocket_counter.v", "tb_local_ambiguity.v")},
        @{Name="local_left"; Pass="PASS local recovery case="; Sources=@("$hdl/classified_pocket_counter.v", "tb_local_left.v")},
        @{Name="local_pipeline"; Pass="PASS local pipeline case="; Sources=@("$hdl/classified_pocket_counter.v", "$hdl/classified_count_pipeline.v", "tb_local_pipeline.v")},
        @{Name="local_page"; Pass="PASS local page:"; Sources=@("$hdl/bin16_bcd.v", "$hdl/osd_ascii_rom.v", "$hdl/osd_cjk_rom.v", "$hdl/osd_logo_rom.v", "$hdl/inspection_region_config.v", "$hdl/experiment_osd.v", "$hdl/classified_count_renderer.v", "$hdl/classified_dual_page_osd.v", "tb_local_page.v")},
        @{Name="local_raw_motion"; Pass="PASS local raw motion:"; Sources=($ispSources + @("$hdl/image_correction.v", "$hdl/status_cdc.v", "$hdl/video_in.v", "$hdl/video_out.v", "reference/classified_pocket_counter_R10.v", "tb_local_raw_motion.v"))},
        @{Name="velocity_bootstrap"; Pass="PASS bootstrap:"; Sources=@("$hdl/classified_pocket_counter.v", "tb_velocity_bootstrap.v")},
        @{Name="start_speed"; Pass="PASS start/speed:"; Sources=@("$hdl/classified_pocket_counter.v", "tb_start_speed.v")},
        @{Name="velocity_pipeline"; Pass="PASS velocity pipeline:"; Sources=@("$hdl/classified_pocket_counter.v", "$hdl/classified_count_pipeline.v", "tb_velocity_pipeline.v")},
        @{Name="velocity_recovery"; Pass="PASS hold recovery:"; Sources=@("$hdl/classified_pocket_counter.v", "tb_velocity_recovery.v")},
        @{Name="start_entry_raw"; Pass="PASS start entry raw:"; Sources=($ispSources + @("$hdl/image_correction.v", "$hdl/status_cdc.v", "$hdl/video_in.v", "$hdl/video_out.v", "reference/classified_pocket_counter_R9.v", "tb_start_entry_raw.v"))},
        @{Name="speed_raw"; Pass="PASS speed raw:"; Sources=($ispSources + @("$hdl/image_correction.v", "$hdl/status_cdc.v", "$hdl/video_in.v", "$hdl/video_out.v", "reference/classified_pocket_counter_R9.v", "tb_speed_raw.v"))},
        @{Name="recovery_page"; Pass="PASS recovery page:"; Sources=@("$hdl/bin16_bcd.v", "$hdl/osd_ascii_rom.v", "$hdl/osd_cjk_rom.v", "$hdl/osd_logo_rom.v", "$hdl/inspection_region_config.v", "$hdl/experiment_osd.v", "$hdl/classified_count_renderer.v", "$hdl/classified_dual_page_osd.v", "tb_recovery_page.v")},
        @{Name="recovery_raw_motion"; Pass="PASS recovery raw motion:"; Sources=($ispSources + @("$hdl/image_correction.v", "$hdl/status_cdc.v", "$hdl/video_in.v", "$hdl/video_out.v", "reference/classified_pocket_counter_R8.v", "tb_recovery_raw_motion.v"))},
        @{Name="hold_recovery"; Pass="PASS hold recovery:"; Sources=@("$hdl/classified_pocket_counter.v", "tb_hold_recovery.v")},
        @{Name="recovery_protection"; Pass="PASS recovery protection:"; Sources=@("$hdl/classified_pocket_counter.v", "tb_recovery_protection.v")},
        @{Name="recovery_pipeline"; Pass="PASS recovery pipeline:"; Sources=@("$hdl/classified_pocket_counter.v", "$hdl/classified_count_pipeline.v", "tb_recovery_pipeline.v")},
        @{Name="ordered_handoff"; Pass="PASS ordered handoff:"; Sources=@("$hdl/classified_pocket_counter.v", "tb_ordered_handoff.v")},
        @{Name="ordered_candidates"; Pass="PASS ordered candidates:"; Sources=@("$hdl/inspection_region_config.v", "$hdl/empty_candidate_probe.v", "$hdl/present_surface_check.v", "$hdl/present_review_probe.v", "$hdl/frame_shape_search.v", "reference/frame_shape_search_R7.v", "tb_ordered_candidates.v")},
        @{Name="ordered_pipeline"; Pass="PASS ordered pipeline:"; Sources=@("$hdl/classified_pocket_counter.v", "$hdl/classified_count_pipeline.v", "tb_ordered_pipeline.v")},
        @{Name="ordered_raw_motion"; Pass="PASS ordered raw motion:"; Sources=($ispSources + @("$hdl/image_correction.v", "$hdl/status_cdc.v", "$hdl/video_in.v", "$hdl/video_out.v", "reference/classified_pocket_counter_R7.v", "tb_ordered_raw_motion.v"))},
        @{Name="tail_recovery"; Pass="PASS tail recovery:"; Sources=@("$hdl/classified_pocket_counter.v", "tb_tail_recovery.v")},
        @{Name="tail_recovery_raw"; Pass="PASS tail recovery raw:"; Sources=($ispSources + @("$hdl/image_correction.v", "$hdl/status_cdc.v", "$hdl/video_in.v", "$hdl/video_out.v", "tb_tail_recovery_raw.v"))},
        @{Name="motion_recovery"; Pass="PASS motion recovery:"; Sources=@("$hdl/classified_pocket_counter.v", "tb_motion_recovery.v")},
        @{Name="motion_recovery_raw"; Pass="PASS motion recovery raw:"; Sources=($ispSources + @("$hdl/image_correction.v", "$hdl/status_cdc.v", "$hdl/video_in.v", "$hdl/video_out.v", "tb_motion_recovery_raw.v"))},
        @{Name="result_recorder"; Pass="PASS result recorder:"; Sources=@("$hdl/classified_pocket_counter.v", "tb_result_recorder.v")},
        @{Name="switch_recorder_controls"; Pass="PASS switch recorder controls:"; Sources=@("$hdl/pocket_run_controls.v", "$hdl/uiisp_beta/ae_set.v", "tb_switch_recorder_controls.v")},
        @{Name="result_recorder_pipeline"; Pass="PASS result recorder pipeline:"; Sources=@("$hdl/classified_pocket_counter.v", "$hdl/classified_count_pipeline.v", "tb_result_recorder_pipeline.v")},
        @{Name="result_recorder_raw_motion"; Pass="PASS result recorder raw motion:"; Sources=($ispSources + @("$hdl/image_correction.v", "$hdl/status_cdc.v", "$hdl/video_in.v", "$hdl/video_out.v", "tb_result_recorder_raw_motion.v"))},
        @{Name="result_recorder_page"; Pass="PASS result recorder page:"; Sources=@("$hdl/bin16_bcd.v", "$hdl/osd_ascii_rom.v", "$hdl/osd_cjk_rom.v", "$hdl/osd_logo_rom.v", "$hdl/inspection_region_config.v", "$hdl/experiment_osd.v", "$hdl/classified_count_renderer.v", "$hdl/classified_dual_page_osd.v", "tb_result_recorder_page.v")},
        @{Name="motion_recovery_page"; Pass="PASS motion recovery page:"; Sources=@("$hdl/bin16_bcd.v", "$hdl/osd_ascii_rom.v", "$hdl/osd_cjk_rom.v", "$hdl/osd_logo_rom.v", "$hdl/inspection_region_config.v", "$hdl/experiment_osd.v", "$hdl/classified_count_renderer.v", "$hdl/classified_dual_page_osd.v", "tb_motion_recovery_page.v")},
        @{Name="classified_bright_guard"; Pass="PASS classified bright guard:"; Sources=@("$hdl/inspection_region_config.v", "$hdl/empty_candidate_probe.v", "$hdl/present_surface_check.v", "$hdl/present_review_probe.v", "$hdl/frame_shape_search.v", "tb_classified_bright_guard.v")},
        @{Name="classified_bright_motion"; Pass="PASS classified bright motion:"; Sources=@("$hdl/inspection_region_config.v", "$hdl/empty_candidate_probe.v", "$hdl/present_surface_check.v", "$hdl/present_review_probe.v", "$hdl/frame_shape_search.v", "$hdl/classified_pocket_counter.v", "$hdl/classified_count_pipeline.v", "tb_classified_bright_motion.v")},
        @{Name="empty_candidate_probe"; Pass="PASS EMPTY CANDIDATE PROBE:"; Sources=@("$hdl/inspection_region_config.v", "$hdl/empty_candidate_probe.v", "$hdl/present_surface_check.v", "$hdl/present_review_probe.v", "$hdl/frame_shape_search.v", "tb_empty_candidate_probe.v")},
        @{Name="empty_probe_pipeline"; Pass="PASS empty probe pipeline:"; Sources=@("$hdl/classified_pocket_counter.v", "$hdl/classified_count_pipeline.v", "tb_empty_probe_pipeline.v")},
        @{Name="empty_probe_page"; Pass="PASS empty probe page:"; Sources=@("$hdl/osd_ascii_rom.v", "$hdl/classified_count_renderer.v", "tb_empty_probe_page.v")},
        @{Name="classified_empty_guard"; Pass="PASS classified empty guard:"; Sources=@("$hdl/inspection_region_config.v", "$hdl/empty_candidate_probe.v", "$hdl/present_surface_check.v", "$hdl/present_review_probe.v", "$hdl/frame_shape_search.v", "tb_classified_empty_guard.v")},
        @{Name="classified_empty_leading"; Pass="PASS classified empty leading:"; Sources=@("$hdl/inspection_region_config.v", "$hdl/empty_candidate_probe.v", "$hdl/present_surface_check.v", "$hdl/present_review_probe.v", "$hdl/frame_shape_search.v", "$hdl/classified_pocket_counter.v", "$hdl/classified_count_pipeline.v", "tb_classified_empty_leading.v")},
        @{Name="classified_observed_page"; Pass="PASS classified observed page:"; Sources=@("$hdl/bin16_bcd.v", "$hdl/osd_ascii_rom.v", "$hdl/osd_cjk_rom.v", "$hdl/osd_logo_rom.v", "$hdl/inspection_region_config.v", "$hdl/experiment_osd.v", "$hdl/classified_count_renderer.v", "$hdl/classified_dual_page_osd.v", "tb_classified_observed_page.v")},
        @{Name="classified_raw_motion"; Pass="PASS classified raw motion:"; Sources=($ispSources + @("$hdl/image_correction.v", "$hdl/status_cdc.v", "$hdl/video_in.v", "$hdl/video_out.v", "tb_classified_raw_motion.v"))},
        @{Name="classified_pages"; Pass="PASS classified pages:"; Sources=@("$hdl/classified_pocket_counter.v", "$hdl/classified_count_pipeline.v", "tb_classified_pages.v")},
        @{Name="classified_controls"; Pass="PASS classified controls:"; Sources=@("$hdl/pocket_run_controls.v", "$hdl/uiisp_beta/ae_set.v", "tb_classified_controls.v")},
        @{Name="classified_page"; Pass="PASS classified page:"; Sources=@("$hdl/bin16_bcd.v", "$hdl/osd_ascii_rom.v", "$hdl/osd_cjk_rom.v", "$hdl/osd_logo_rom.v", "$hdl/inspection_region_config.v", "$hdl/experiment_osd.v", "$hdl/classified_count_renderer.v", "$hdl/classified_dual_page_osd.v", "tb_classified_page.v")},
        @{Name="classified_raw_chain"; Pass="PASS classified raw chain:"; Sources=($ispSources + @("$hdl/image_correction.v", "$hdl/status_cdc.v", "$hdl/video_in.v", "$hdl/video_out.v", "tb_classified_raw_chain.v"))},
        @{Name="classified_image"; Pass="PASS classified image:"; Sources=@("$hdl/inspection_region_config.v", "$hdl/empty_candidate_probe.v", "$hdl/present_surface_check.v", "$hdl/present_review_probe.v", "$hdl/frame_shape_search.v", "$hdl/classified_pocket_counter.v", "$hdl/classified_count_pipeline.v", "tb_classified_image.v")},
        @{Name="classified_counter"; Pass="PASS classified counter:"; Sources=@("$hdl/classified_pocket_counter.v", "tb_classified_counter.v")},
        @{Name="raw_timing_probe"; Pass="PASS raw timing probe:"; Sources=($ispSources + @("tb_raw_timing_probe.v"))},
        @{Name="base_picture_repeatability"; Pass="PASS base picture repeatability:"; Sources=($ispSources + @("$hdl/image_correction.v", "tb_base_picture_repeatability.v"))},
        @{Name="pose180"; Pass="PASS pose180:"; Sources=@("$hdl/inspection_region_config.v", "$hdl/empty_candidate_probe.v", "$hdl/present_surface_check.v", "$hdl/present_review_probe.v", "$hdl/frame_shape_search.v", "tb_pose180.v")},
        @{Name="field180"; Pass="PASS field180:"; Sources=@("$hdl/inspection_region_config.v", "$hdl/empty_candidate_probe.v", "$hdl/present_surface_check.v", "$hdl/present_review_probe.v", "$hdl/frame_shape_search.v", "tb_field180.v")},
        @{Name="cal180_body"; Pass="PASS cal180 body:"; Sources=@("$hdl/inspection_region_config.v", "$hdl/empty_candidate_probe.v", "$hdl/present_surface_check.v", "$hdl/present_review_probe.v", "$hdl/frame_shape_search.v", "tb_cal180_body.v")},
        @{Name="cal180_holes"; Pass="PASS cal180 holes:"; Sources=@("$hdl/inspection_region_config.v", "$hdl/empty_candidate_probe.v", "$hdl/present_surface_check.v", "$hdl/present_review_probe.v", "$hdl/frame_shape_search.v", "tb_cal180_holes.v")},
        @{Name="calibration_late"; Pass="PASS calibration late:"; Sources=@("$hdl/status_cdc.v", "$hdl/video_in.v", "$hdl/video_out.v", "$ip/w128_d512_fifo/w128_d512_fifo.v", "$ip/w128_d512_fifo/soft_fifo_al_4057d6b76aa6.v", "tb_calibration_late.v")},
        @{Name="calibration_probe"; Pass="PASS calibration probe:"; Sources=@("$hdl/roi_statistics.v", "tb_calibration_probe.v")},
        @{Name="local_wait"; Pass="PASS local WAIT:"; Sources=@("$hdl/tape_hole_tracker.v", "tb_local_wait.v")},
        @{Name="calibration_osd"; Pass="PASS calibration OSD:"; Sources=@("$hdl/bin16_bcd.v", "$hdl/osd_ascii_rom.v", "$hdl/osd_cjk_rom.v", "$hdl/osd_logo_rom.v", "$hdl/inspection_region_config.v", "$hdl/experiment_osd.v", "tb_calibration_osd.v")},
        @{Name="field_chain"; Pass="PASS field chain:"; Sources=($ispSources + @("$hdl/image_correction.v", "$hdl/status_cdc.v", "$hdl/video_in.v", "$hdl/video_out.v", "$ip/w128_d512_fifo/w128_d512_fifo.v", "$ip/w128_d512_fifo/soft_fifo_al_4057d6b76aa6.v", "tb_field_chain.v"))},
        @{Name="calibration_chain"; Pass="PASS calibration chain:"; Sources=($ispSources + @("$hdl/image_correction.v", "$hdl/status_cdc.v", "$hdl/video_in.v", "$hdl/video_out.v", "$ip/w128_d512_fifo/w128_d512_fifo.v", "$ip/w128_d512_fifo/soft_fifo_al_4057d6b76aa6.v", "tb_calibration_chain.v"))},
        @{Name="regions_osd"; Pass="PASS regions osd:"; Sources=@("$hdl/bin16_bcd.v", "$hdl/osd_ascii_rom.v", "$hdl/osd_cjk_rom.v", "$hdl/osd_logo_rom.v", "$hdl/inspection_region_config.v", "$hdl/experiment_osd.v", "tb_regions_osd.v")},
        @{Name="stable_ids_osd"; Pass="PASS stable IDs OSD:"; Sources=@("$hdl/bin16_bcd.v", "$hdl/osd_ascii_rom.v", "$hdl/osd_cjk_rom.v", "$hdl/osd_logo_rom.v", "$hdl/inspection_region_config.v", "$hdl/experiment_osd.v", "tb_stable_ids_osd.v")},
        @{Name="regions_chain"; Pass="PASS regions chain:"; Sources=($ispSources + @("$hdl/image_correction.v", "$hdl/status_cdc.v", "$hdl/video_in.v", "$hdl/video_out.v", "$ip/w128_d512_fifo/w128_d512_fifo.v", "$ip/w128_d512_fifo/soft_fifo_al_4057d6b76aa6.v", "tb_regions_chain.v"))},
        @{Name="regions"; Pass="PASS regions:"; Sources=@("$hdl/inspection_region_config.v", "$hdl/empty_candidate_probe.v", "$hdl/present_surface_check.v", "$hdl/present_review_probe.v", "$hdl/frame_shape_search.v", "tb_regions.v")},
        @{Name="hd_pll"; Pass="PASS hd pll:"; Sources=@("$hdl/native_hdmi_pll.v", "$ip/PLL/RTL/ph1p_phy_pll_wrapper_25a56e5ce2f9.v", "tb_hd_pll.v")},
        @{Name="hd_pins"; Pass="PASS hd pins:"; Sources=@("hdmi_ideal_pll.v", "$hdl/native_720p60_vtc.v", "$hdl/native_i60_phase.v", "$hdl/native_i60_tx.v", "$hdl/dvi_encoder.v", "$hdl/wide_view_avi.v", "$hdl/hdmi_phy_warpper.v", "$hdl/lane_lvds_10_1.v", "$hdl/video_out.v", "$hdl/bin16_bcd.v", "$hdl/osd_ascii_rom.v", "$hdl/osd_cjk_rom.v", "$hdl/osd_logo_rom.v", "$hdl/inspection_region_config.v", "$hdl/experiment_osd.v", "$ip/w128_d512_fifo/w128_d512_fifo.v", "$ip/w128_d512_fifo/soft_fifo_al_4057d6b76aa6.v", "tb_hd_pins.v")},
        @{Name="hd_guard"; Pass="PASS hd guard:"; Sources=@("$hdl/roi_frame_guard.v", "tb_hd_guard.v")},
        @{Name="hd_scaled_guard"; Pass="PASS hd scaled guard:"; Sources=@("$hdl/scaled_frame_guard.v", "tb_hd_scaled_guard.v")},
        @{Name="hd_osd"; Pass="PASS hd osd:"; Sources=@("$hdl/bin16_bcd.v", "$hdl/osd_ascii_rom.v", "$hdl/osd_cjk_rom.v", "$hdl/osd_logo_rom.v", "$hdl/inspection_region_config.v", "$hdl/experiment_osd.v", "tb_hd_osd.v")},
        @{Name="hd_resize"; Pass="PASS hd resize:"; Sources=@("$hdl/rgb_resize_2_3.v", "$hdl/rgb96_packetizer.v", "tb_hd_resize.v")},
        @{Name="hd_search"; Pass="PASS hd search:"; Sources=@("$hdl/inspection_region_config.v", "$hdl/empty_candidate_probe.v", "$hdl/present_surface_check.v", "$hdl/present_review_probe.v", "$hdl/frame_shape_search.v", "tb_hd_search.v")},
        @{Name="hd_chain"; Pass="PASS hd chain:"; Sources=($ispSources + @("$hdl/image_correction.v", "$hdl/status_cdc.v", "$hdl/video_in.v", "$hdl/video_out.v", "tb_hd_chain.v"))},
        @{Name="process_bridge"; Pass="PASS process bridge:"; Sources=@("$hdl/frame_process_bridge.v", "$ip/w128_d512_fifo/w128_d512_fifo.v", "$ip/w128_d512_fifo/soft_fifo_al_4057d6b76aa6.v", "tb_process_bridge.v")},
        @{Name="frame_search"; Pass="PASS frame search:"; Sources=@("$hdl/inspection_region_config.v", "$hdl/empty_candidate_probe.v", "$hdl/present_surface_check.v", "$hdl/present_review_probe.v", "$hdl/frame_shape_search.v", "tb_frame_search.v")},
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
    $tests += @(
        @{Name="trace_matrix"; Pass="PASS TRACE_MATRIX_EQUIVALENCE:"; Sources=@("$hdl/inspection_region_config.v", "$hdl/empty_candidate_probe.v", "$hdl/present_surface_check.v", "$hdl/present_review_probe.v", "$hdl/frame_shape_search.v", "empty_trace/frame_shape_search_r20.v", "empty_trace/tb_trace_matrix.sv")},
        @{Name="empty_trace_raw"; Pass="PASS empty trace raw:"; Sources=($ispSources + @("$hdl/count_record_view.v", "$hdl/image_correction.v", "$hdl/status_cdc.v", "$hdl/video_in.v", "$hdl/video_out.v", "reference/classified_pocket_counter_R9.v", "empty_trace/tb_empty_trace_raw.v"))},
        @{Name="empty_trace_ui"; Pass="PASS R21 empty trace UI:"; Sources=@("$hdl/bin16_bcd.v", "$hdl/osd_ascii_rom.v", "$hdl/osd_cjk_rom.v", "$hdl/osd_logo_rom.v", "$hdl/inspection_region_config.v", "$hdl/experiment_osd.v", "$hdl/classified_count_renderer.v", "$hdl/compact_ascii_rom.v", "$hdl/compact_inspector_osd.v", "$hdl/compact_cjk_rom.v", "$hdl/compact_template_rom.v", "$hdl/classified_dual_page_osd.v", "empty_trace/tb_empty_trace_ui.sv")},
        @{Name="empty_trace_abort"; Pass="PASS EMPTY_TRACE_ABORT:"; Sources=@("$hdl/inspection_region_config.v", "$hdl/empty_candidate_probe.v", "$hdl/present_surface_check.v", "$hdl/present_review_probe.v", "$hdl/frame_shape_search.v", "context/frame_shape_search_r19.v", "empty_trace/tb_empty_trace_abort.sv")},
        @{Name="empty_trace_unit"; Pass="PASS EMPTY_TRACE_UNIT:"; Sources=@("$hdl/inspection_region_config.v", "$hdl/empty_candidate_probe.v", "$hdl/present_surface_check.v", "$hdl/present_review_probe.v", "$hdl/frame_shape_search.v", "empty_trace/tb_empty_trace_unit.sv")}
    )
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
        if ($test.Name -in @("edge_raw_mode1", "edge_raw_mode2", "edge_raw_mode3", "edge_raw", "empty_trace_raw", "context_raw", "context_tail_raw", "robust_empty_raw", "standing_raw_chain", "standing_class_only_raw", "simple_recovery_raw", "line_ram_equivalence", "surface_raw_chain", "surface_class_only_raw", "dual_raw_motion", "local_raw_motion", "start_entry_raw", "speed_raw", "recovery_raw_motion", "ordered_raw_motion", "tail_recovery_raw", "motion_recovery_raw", "result_recorder_raw_motion", "classified_raw_motion", "classified_raw_chain", "raw_timing_probe", "base_picture_repeatability", "fixed_wb", "manual_wb", "pixel_interface", "roi_chain", "isp_writer_stop", "isp_metadata_stop", "isp_tracking", "isp_tracking_late", "isp_multi", "multi_writer", "multi_video", "multi_first_invalid", "direct_isp", "direct_video", "shape_isp", "shape_video", "local_isp", "local_video", "frame_video", "frame_tailproof", "frame_stop", "frame_process", "frame_cadence", "hd_chain", "regions_chain", "calibration_chain", "field_chain", "hd_pins", "hd_pll")) { $tops += @("anlogic_sim.glbl", "anlogic_sim.PH1P_PHY_GSR") }
        $commands = "log /tb_$($test.Name)/*; run -all; quit -code 1 -force"
        if ($test.Name -in @("hd_pins", "hd_pll")) { $commands = "run -all; quit -code 1 -force" }
        if ($test.Name -in @("standing_counting", "standing_detector", "robust_empty_raw", "standing_raw_chain", "standing_class_only_raw", "rgb_shared_equivalence", "text_plane_prefetch", "center_capture_equivalence", "format_cache_equivalence", "gray_cache_equivalence", "simple_recovery_raw", "surface_raw_chain", "surface_class_only_raw", "dual_raw_motion", "local_raw_motion", "start_entry_raw", "speed_raw", "recovery_raw_motion", "ordered_raw_motion", "tail_recovery_raw", "motion_recovery_raw", "result_recorder_raw_motion", "classified_raw_motion", "classified_raw_chain", "shape_isp", "local_isp", "frame_video", "frame_tailproof", "frame_stop", "frame_process", "frame_cadence", "hd_chain", "regions_chain", "calibration_chain", "field_chain", "hd_pins", "hd_pll")) { $commands = "log /tb_$($test.Name)/frame_no; run -all; quit -code 1 -force" }
        if ($test.Name -in @("standing_counting", "standing_detector", "robust_empty_raw", "standing_raw_chain", "standing_class_only_raw", "rgb_shared_equivalence", "text_plane_prefetch", "center_capture_equivalence", "format_cache_equivalence", "gray_cache_equivalence", "raw_timing_probe", "base_picture_repeatability")) { $commands = "run -all; quit -code 1 -force" }
        $access = "+acc"
        if ($test.Name -in @("standing_counting", "standing_detector", "robust_empty_raw", "standing_raw_chain", "standing_class_only_raw", "rgb_shared_equivalence", "text_plane_prefetch", "center_capture_equivalence", "format_cache_equivalence", "gray_cache_equivalence", "simple_recovery_raw", "surface_raw_chain", "surface_class_only_raw", "dual_raw_motion", "local_raw_motion", "start_entry_raw", "speed_raw", "recovery_raw_motion", "ordered_raw_motion", "tail_recovery_raw", "motion_recovery_raw", "result_recorder_raw_motion", "classified_raw_motion", "classified_raw_chain", "raw_timing_probe", "base_picture_repeatability", "roi_chain", "isp_writer_stop", "isp_metadata_stop", "isp_tracking", "isp_tracking_late", "isp_multi", "multi_writer", "multi_video", "multi_first_invalid", "direct_isp", "direct_video", "shape_isp", "shape_video", "local_isp", "local_video", "frame_video", "frame_tailproof", "frame_stop", "frame_process", "frame_cadence", "hd_chain", "regions_chain", "calibration_chain", "field_chain", "hd_pins", "hd_pll")) { $access = "+acc=rn+/tb_$($test.Name)" }
        if ($test.Name -in @("robust_empty_ab", "robust_empty15_clear", "robust_empty15_14", "robust_empty15_17", "robust_empty15_25", "robust_empty15_left", "robust_empty_raw", "robust_empty_ui")) { $commands = "run -all; quit -code 1 -force"; $access = "+acc=rn+/tb_$($test.Name)" }
        if ($test.Name -in @("context_guard32", "context_edge36", "context_no_body4", "context_abort", "context_motion_slow", "context_motion_normal", "context_motion_fast", "context_motion_fast_left", "context_motion_phase19", "context_motion_close_cut", "context_motion_consecutive", "context_motion_all_empty", "context_motion_single_empty", "context_raw", "context_tail_raw", "context_ui")) { $commands = "run -all; quit -code 1 -force"; $access = "+acc=rn+/tb_$($test.Name)" }
        if ($test.Name -in @("trace_matrix", "empty_trace_unit", "empty_trace_abort", "empty_trace_raw", "empty_trace_ui")) { $commands = "run -all; quit -code 1 -force"; $access = "+acc=rn+/tb_$($test.Name)" }
        if ($test.Name -in @("edge_unit", "edge_detector")) { $commands = "run -all; quit -code 1 -force"; $access = "+acc=rn+/tb_$($test.Name)" }
        if ($test.Name -like "edge_*") { $commands = "run -all; quit -code 1 -force"; $access = "+acc=rn+/tb_$($test.Name)" }
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

