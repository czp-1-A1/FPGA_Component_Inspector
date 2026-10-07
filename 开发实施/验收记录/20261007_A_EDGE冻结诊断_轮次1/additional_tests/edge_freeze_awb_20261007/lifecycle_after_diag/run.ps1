$ErrorActionPreference = 'Stop'
$diagnosticRoot = $PSScriptRoot
$repoRoot = (Resolve-Path (Join-Path $diagnosticRoot '../../..')).Path
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
    "$hdl/observation_controls.v", "$hdl/status_cdc.v", "$hdl/isp/uial2axis.v", "$hdl/isp/isp_top.v", "$hdl/roi_frame_guard.v", "$hdl/roi_statistics.v", "$hdl/roi_classifier.v", "$hdl/roi_result_snapshot.v", "$hdl/roi_sobel_view.v", "$hdl/roi_observation_snapshot.v",
    "$hdl/awb.v", "$hdl/signal_delay.v", "$hdl/isp/data128_96/data128_96.v", "$hdl/isp/data96_128/data96_128.v",
    "$demosaic/demosaic.v", "$demosaic/raw_matrix_3x3_buffer.v", "$demosaic/zhenghe.v",
    "$demosaic/line_buffer_demosaic.v", "$demosaic/mipi_to_raw_converter.v", "$demosaic/bilinear_interpolation.v",
    "$demosaic/blk_mem_gen_demosaic/blk_mem_gen_demosaic.v", "$demosaic/blk_mem_gen_demosaic/RTL/ram_c36c2ca3b3a7.v",
    "$demosaic/blk_mem_gen_zhenghe/blk_mem_gen_zhenghe.v", "$demosaic/blk_mem_gen_zhenghe/RTL/ram_d32970204f32.v",
    "$ip/divider/divider_gate.v", "$ip/blk_mem_gen_awb_delay_signal/blk_mem_gen_awb_delay_signal.v",
    "$ip/blk_mem_gen_awb_delay_signal/ram_f84573da5ab5.v")
$originRecords=@()
$snapshotSources=@()
$sourceRoot=(Resolve-Path (Join-Path $repoRoot 'fpga/component_inspector/user_source')).Path
foreach($path in $ispSources) {
 $originPath=(Resolve-Path -LiteralPath $path).Path
 $relativePath=$originPath.Substring($sourceRoot.Length+1)
 $snapshotPath=Join-Path (Join-Path $diagnosticRoot 'inputs_snapshot') $relativePath
 New-Item -ItemType Directory -Path (Split-Path -Parent $snapshotPath) -Force | Out-Null
 Copy-Item -LiteralPath $originPath -Destination $snapshotPath
 $sourceHash=(Get-FileHash -LiteralPath $originPath -Algorithm SHA256).Hash.ToLower()
 if((Get-FileHash -LiteralPath $snapshotPath -Algorithm SHA256).Hash.ToLower() -ne $sourceHash) {throw ('Source changed while freezing: '+$originPath)}
 $originRecords+=@{Path=$originPath;SnapshotPath=$snapshotPath;SHA256=$sourceHash}
 $snapshotSources+=$snapshotPath
}
$originRecords | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath "$diagnosticRoot/origin_inputs_manifest.json" -Encoding UTF8
$ispSources=$snapshotSources
$evidence = foreach ($path in ($vendor + $ispSources + @("$diagnosticRoot/tb_isp_lifecycle.v", "$diagnosticRoot/run.ps1"))) {
    $entry = Get-Item -LiteralPath $path
    [pscustomobject]@{Path=$path;Bytes=$entry.Length;SHA256=(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLower()}
}
$evidence | ConvertTo-Json -Depth 3 | Set-Content -LiteralPath "$diagnosticRoot/life_proof_inputs_manifest.json" -Encoding utf8
Push-Location $diagnosticRoot
try {
    & "$modelBin/vmap.exe" -c *> life_setup.log
    if (!(Test-Path -LiteralPath life_proof_vendor/_info)) { & "$modelBin/vlib.exe" life_proof_vendor >> life_setup.log 2>&1 }
    if (!(Test-Path -LiteralPath life_proof_work/_info)) { & "$modelBin/vlib.exe" life_proof_work >> life_setup.log 2>&1 }
    & "$modelBin/vmap.exe" life_proof_vendor life_proof_vendor >> life_setup.log 2>&1
    & "$modelBin/vmap.exe" life_proof_work life_proof_work >> life_setup.log 2>&1
    & "$modelBin/vlog.exe" -work life_proof_vendor @vendor *> life_vendor_compile.log
    if ($LASTEXITCODE -ne 0) { throw 'proof vendor compile failed' }
    & "$modelBin/vlog.exe" -work life_proof_work @ispSources *> life_compile.log
    if ($LASTEXITCODE -ne 0) { throw 'proof ISP compile failed' }
    & "$modelBin/vlog.exe" -sv -work life_proof_work tb_isp_lifecycle.v >> life_compile.log 2>&1
    if ($LASTEXITCODE -ne 0) { throw 'proof TB compile failed' }
    $commands = 'run -all; quit -code 1 -force'
    & "$modelBin/vsim.exe" -c -L life_proof_vendor '-voptargs=+acc=rn+/tb_isp_lifecycle' -onfinish exit -l life_transcript.log -wlf life_diagnostic.wlf -do $commands life_proof_work.tb_isp_lifecycle life_proof_vendor.glbl life_proof_vendor.PH1P_PHY_GSR *> life_console.log
    if ($LASTEXITCODE -ne 0) { throw 'proof simulation failed; see life_console.log' }
    $result = Get-Content -LiteralPath life_console.log -Raw
    if (!$result.Contains('PASS actual ISP lifecycle:') -or $result -match '(?m)^#?\s*\*\* (Fatal|Error):') { throw 'proof did not complete successfully' }
    Select-String -LiteralPath life_console.log -Pattern 'PASS|OBS|Errors:' | ForEach-Object { $_.Line }
} finally { Pop-Location }


