$ErrorActionPreference = 'Stop'
$diagnosticRoot = $PSScriptRoot
$repoRoot = (Resolve-Path (Join-Path $diagnosticRoot '../..')).Path
$hdl = Join-Path $repoRoot 'fpga/component_inspector/user_source/hdl_source'
$ip = Join-Path $repoRoot 'fpga/component_inspector/user_source/ip_source'
$demosaic = "$hdl/isp/demosaic_4x_2_0"
$modelBin = 'D:/modelsim/win64'
$tdSimRoot = 'D:/AAA/FPGA.....YZW/sim_release'
foreach ($licenseName in @('MGLS_LICENSE_FILE', 'LM_LICENSE_FILE')) {
    if (![Environment]::GetEnvironmentVariable($licenseName, 'Process')) {
        $licenseValue = [Environment]::GetEnvironmentVariable($licenseName, 'User')
        if (!$licenseValue) { $licenseValue = [Environment]::GetEnvironmentVariable($licenseName, 'Machine') }
        if ($licenseValue) { [Environment]::SetEnvironmentVariable($licenseName, $licenseValue, 'Process') }
    }
}
$vendor = @(
    "$tdSimRoot/common/al_map_basic.v", "$tdSimRoot/common/al_map_lut.v",
    "$tdSimRoot/common/al_map_adder.v", "$tdSimRoot/common/al_phy_glbl.v",
    "$tdSimRoot/ph1p/ph1p_logic_eram.v", "$tdSimRoot/ph1p/ph1p_phy_gsr.v")
$ispSources = @(
    "$hdl/isp/uial2axis.v", "$hdl/isp/isp_top.v", "$hdl/roi_frame_guard.v", "$hdl/roi_statistics.v", "$hdl/roi_classifier.v", "$hdl/roi_result_snapshot.v", "$hdl/roi_sobel_view.v", "$hdl/roi_observation_snapshot.v",
    "$hdl/awb.v", "$hdl/signal_delay.v", "$hdl/isp/data128_96/data128_96.v", "$hdl/isp/data96_128/data96_128.v",
    "$demosaic/demosaic.v", "$demosaic/raw_matrix_3x3_buffer.v", "$demosaic/zhenghe.v",
    "$demosaic/line_buffer_demosaic.v", "$demosaic/mipi_to_raw_converter.v", "$demosaic/bilinear_interpolation.v",
    "$demosaic/blk_mem_gen_demosaic/blk_mem_gen_demosaic.v", "$demosaic/blk_mem_gen_demosaic/RTL/ram_c36c2ca3b3a7.v",
    "$demosaic/blk_mem_gen_zhenghe/blk_mem_gen_zhenghe.v", "$demosaic/blk_mem_gen_zhenghe/RTL/ram_d32970204f32.v",
    "$ip/divider/divider_gate.v", "$ip/blk_mem_gen_awb_delay_signal/blk_mem_gen_awb_delay_signal.v",
    "$ip/blk_mem_gen_awb_delay_signal/ram_f84573da5ab5.v")
$evidence = foreach ($path in ($vendor + $ispSources + @("$diagnosticRoot/tb_roi_transport_proof.v", "$diagnosticRoot/run_roi_proof.ps1"))) {
    $entry = Get-Item -LiteralPath $path
    [pscustomobject]@{Path=$path;Bytes=$entry.Length;SHA256=(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLower()}
}
$evidence | ConvertTo-Json -Depth 3 | Set-Content -LiteralPath "$diagnosticRoot/roi_proof_inputs_manifest.json" -Encoding utf8
Push-Location $diagnosticRoot
try {
    & "$modelBin/vmap.exe" -c *> roi_setup.log
    if (!(Test-Path -LiteralPath roi_proof_vendor/_info)) { & "$modelBin/vlib.exe" roi_proof_vendor >> roi_setup.log 2>&1 }
    if (!(Test-Path -LiteralPath roi_proof_work/_info)) { & "$modelBin/vlib.exe" roi_proof_work >> roi_setup.log 2>&1 }
    & "$modelBin/vmap.exe" roi_proof_vendor roi_proof_vendor >> roi_setup.log 2>&1
    & "$modelBin/vmap.exe" roi_proof_work roi_proof_work >> roi_setup.log 2>&1
    & "$modelBin/vlog.exe" -work roi_proof_vendor @vendor *> roi_vendor_compile.log
    if ($LASTEXITCODE -ne 0) { throw 'proof vendor compile failed' }
    & "$modelBin/vlog.exe" -work roi_proof_work @ispSources *> roi_compile.log
    if ($LASTEXITCODE -ne 0) { throw 'proof ISP compile failed' }
    & "$modelBin/vlog.exe" -sv -work roi_proof_work tb_roi_transport_proof.v >> roi_compile.log 2>&1
    if ($LASTEXITCODE -ne 0) { throw 'proof TB compile failed' }
    $commands = 'log /tb_roi_transport_proof/clk /tb_roi_transport_proof/fs /tb_roi_transport_proof/fe /tb_roi_transport_proof/frame_no /tb_roi_transport_proof/video_good /tb_roi_transport_proof/video_bad /tb_roi_transport_proof/proof_commits /tb_roi_transport_proof/packing_count /tb_roi_transport_proof/packing_words; run -all; quit -code 1 -force'
    & "$modelBin/vsim.exe" -c -L roi_proof_vendor '-voptargs=+acc=rn+/tb_roi_transport_proof' -onfinish exit -l roi_transcript.log -wlf roi_diagnostic.wlf -do $commands roi_proof_work.tb_roi_transport_proof roi_proof_vendor.glbl roi_proof_vendor.PH1P_PHY_GSR *> roi_console.log
    if ($LASTEXITCODE -ne 0) { throw 'proof simulation failed; see roi_console.log' }
    $result = Get-Content -LiteralPath roi_console.log -Raw
    if (!$result.Contains('PASS actual ISP transport proof:') -or $result -match '(?m)^#?\s*\*\* (Fatal|Error):') { throw 'proof did not complete successfully' }
    Select-String -LiteralPath roi_console.log -Pattern 'PASS|OBS|Errors:' | ForEach-Object { $_.Line }
} finally { Pop-Location }
