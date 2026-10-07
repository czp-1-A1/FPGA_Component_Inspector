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
        "$TdSimRoot/ph1p/ph1p_logic_eram.v", "$TdSimRoot/ph1p/ph1p_phy_gsr.v"
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
        "$hdl/isp/uial2axis.v", "$hdl/isp/isp_top.v", "$hdl/roi_frame_guard.v", "$hdl/roi_statistics.v", "$hdl/roi_classifier.v", "$hdl/roi_result_snapshot.v", "$hdl/roi_sobel_view.v", "$hdl/roi_observation_snapshot.v",
        "$hdl/awb.v", "$hdl/signal_delay.v", "$hdl/isp/data128_96/data128_96.v", "$hdl/isp/data96_128/data96_128.v",
        "$demosaic/demosaic.v", "$demosaic/raw_matrix_3x3_buffer.v", "$demosaic/zhenghe.v",
        "$demosaic/line_buffer_demosaic.v", "$demosaic/mipi_to_raw_converter.v", "$demosaic/bilinear_interpolation.v",
        "$demosaic/blk_mem_gen_demosaic/blk_mem_gen_demosaic.v", "$demosaic/blk_mem_gen_demosaic/RTL/ram_c36c2ca3b3a7.v",
        "$demosaic/blk_mem_gen_zhenghe/blk_mem_gen_zhenghe.v", "$demosaic/blk_mem_gen_zhenghe/RTL/ram_d32970204f32.v",
        "$ip/divider/divider_gate.v", "$ip/blk_mem_gen_awb_delay_signal/blk_mem_gen_awb_delay_signal.v",
        "$ip/blk_mem_gen_awb_delay_signal/ram_f84573da5ab5.v")
    $tests = @(
        @{Name="isp_writer_stop"; Pass="PASS actual ISP full epoch:"; Sources=($ispSources + @("$hdl/observation_controls.v", "$hdl/status_cdc.v", "$hdl/video_in.v", "$ip/w128_d512_fifo/w128_d512_fifo.v", "$ip/w128_d512_fifo/soft_fifo_al_4057d6b76aa6.v", "tb_isp_writer_stop.v"))},
        @{Name="sobel_tail"; Pass="PASS Sobel tail:"; Sources=@("$hdl/roi_sobel_view.v", "$hdl/isp/data96_128/data96_128.v", "tb_sobel_tail.v")},
        @{Name="sobel_view"; Pass="PASS Sobel view:"; Sources=@("$hdl/roi_sobel_view.v", "$hdl/isp/data96_128/data96_128.v", "tb_sobel_view.v")},
        @{Name="observation"; Pass="PASS observation:"; Sources=@("$hdl/observation_controls.v", "$hdl/roi_observation_snapshot.v", "$hdl/roi_display_state.v", "$hdl/status_cdc.v", "tb_observation.v")},
        @{Name="stop_recovery"; Pass="PASS stop recovery:"; Sources=@("$hdl/input_monitor.v", "$hdl/roi_result_snapshot.v", "$hdl/roi_display_state.v", "$hdl/status_cdc.v", "tb_stop_recovery.v")},
        @{Name="display_state"; Pass="PASS display state:"; Sources=@("$hdl/roi_classifier.v", "$hdl/roi_result_snapshot.v", "$hdl/roi_display_state.v", "$hdl/status_cdc.v", "tb_display_state.v")},
        @{Name="controls"; Pass="PASS controls:"; Sources=@("$hdl/uiisp_beta/ae_set.v", "$hdl/uics500_cfg/uicfgcs500.v", "$hdl/uics500_cfg/uics500reg.v", "$hdl/uics500_cfg/uics500regAE.v", "$hdl/uics500_cfg/SC500GainTbl.v", "tb_controls.v")},
        @{Name="cdc"; Pass="PASS CDC:"; Sources=@("$hdl/status_cdc.v", "tb_cdc.v")},
        @{Name="monitor"; Pass="PASS monitor:"; Sources=@("$hdl/status_cdc.v", "$hdl/input_monitor.v", "tb_monitor.v")},
        @{Name="csi_monitor"; Pass="PASS actual CSI"; Sources=@("$hdl/status_cdc.v", "$hdl/input_monitor.v", "$hdl/isp/csi_unpacket_2lane.v", "$hdl/isp/raw10_unpacket_2lane.v", "tb_csi_monitor.v")},
        @{Name="i2c"; Pass="PASS I2C actual bus:"; Sources=@("$hdl/uics500_cfg/uii2c.v", "tb_i2c.v")},
        @{Name="osd"; Pass="PASS OSD decimal"; Sources=@("$hdl/bin16_bcd.v", "$hdl/osd_ascii_rom.v", "$hdl/osd_cjk_rom.v", "$hdl/osd_logo_rom.v", "$hdl/experiment_osd.v", "tb_osd.v")},
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
    if ($OnlyTests.Count -gt 0) {
        foreach ($requested in $OnlyTests) {
            if ($requested -notin $tests.Name) { throw "Unknown test: $requested" }
        }
        $tests = @($tests | Where-Object { $_.Name -in $OnlyTests })
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
        if ($test.Name -in @("pixel_interface", "roi_chain", "isp_writer_stop")) { $tops += @("anlogic_sim.glbl", "anlogic_sim.PH1P_PHY_GSR") }
        $commands = "log /tb_$($test.Name)/*; run -all; quit -code 1 -force"
        $access = "+acc"
        if ($test.Name -in @("roi_chain", "isp_writer_stop")) { $access = "+acc=rn+/tb_$($test.Name)" }
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

