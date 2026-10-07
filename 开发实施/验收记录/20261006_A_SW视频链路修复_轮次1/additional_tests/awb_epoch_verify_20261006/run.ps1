param([ValidateSet('legacy','fixed','legacy_contract')][string]$Case='fixed')
$ErrorActionPreference='Stop'
$diagnosticRoot=$PSScriptRoot
$repoRoot=(Resolve-Path (Join-Path $diagnosticRoot '../..')).Path
$hdl=Join-Path $repoRoot 'fpga/component_inspector/user_source/hdl_source'
$ip=Join-Path $repoRoot 'fpga/component_inspector/user_source/ip_source'
$modelBin='D:/modelsim/win64'
$vendorRoot='D:/AAA/FPGA.....YZW/sim_release'
foreach($licenseName in @('MGLS_LICENSE_FILE','LM_LICENSE_FILE')) {
 if(![Environment]::GetEnvironmentVariable($licenseName,'Process')) {
  $licenseValue=[Environment]::GetEnvironmentVariable($licenseName,'User')
  if(!$licenseValue) {$licenseValue=[Environment]::GetEnvironmentVariable($licenseName,'Machine')}
  if($licenseValue) {[Environment]::SetEnvironmentVariable($licenseName,$licenseValue,'Process')}
 }
}
$caseDirectory=Join-Path $diagnosticRoot $Case
New-Item -ItemType Directory -Path $caseDirectory -Force | Out-Null
$sobel=Join-Path $hdl 'roi_sobel_view.v'
$defines=@()
$pass='PASS real AWB epoch isolation:'
if($Case -in @('legacy','legacy_contract')) {
 $sobel=Join-Path $repoRoot 'tmp/video_fix_td_final_20261006/user_source/hdl_source/roi_sobel_view.v'
 if($Case -eq 'legacy') {$defines=@('+define+EXPECT_LEGACY');$pass='PASS legacy defect reproduced:'}
 else {$defines=@('+define+LEGACY_CONTRACT')}
}
$sources=@("$hdl/awb.v","$hdl/signal_delay.v",$sobel,"$hdl/isp/data96_128/data96_128.v","$ip/divider/divider_gate.v","$ip/blk_mem_gen_awb_delay_signal/blk_mem_gen_awb_delay_signal.v","$ip/blk_mem_gen_awb_delay_signal/ram_f84573da5ab5.v")
$evidenceSources=$sources+@("$diagnosticRoot/tb_awb_epoch.v","$diagnosticRoot/run.ps1")
$sourceRecords=@($evidenceSources | ForEach-Object { @{Path=$_;SHA256=(Get-FileHash -Algorithm SHA256 -LiteralPath $_).Hash.ToLower()} })
$sourceRecords | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath "$caseDirectory/inputs.json" -Encoding UTF8
Copy-Item -LiteralPath $sobel -Destination "$caseDirectory/compiled_roi_sobel_view.v"
Push-Location $caseDirectory
try {
 & "$modelBin/vmap.exe" -c *> setup.log
 & "$modelBin/vlib.exe" vendor >> setup.log 2>&1
 & "$modelBin/vmap.exe" anlogic_sim vendor >> setup.log 2>&1
 & "$modelBin/vlib.exe" work >> setup.log 2>&1
 & "$modelBin/vmap.exe" work work >> setup.log 2>&1
 $vendor=@("$vendorRoot/common/al_map_basic.v","$vendorRoot/common/al_map_lut.v","$vendorRoot/common/al_map_adder.v","$vendorRoot/common/al_phy_glbl.v","$vendorRoot/ph1p/ph1p_logic_eram.v","$vendorRoot/ph1p/ph1p_phy_gsr.v")
 & "$modelBin/vlog.exe" -work anlogic_sim @vendor *> vendor_compile.log
 if($LASTEXITCODE -ne 0) {throw 'Vendor compile failed'}
 & "$modelBin/vlog.exe" -work work @sources *> compile.log
 if($LASTEXITCODE -ne 0) {throw 'RTL compile failed'}
 & "$modelBin/vlog.exe" -sv -work work @defines ../tb_awb_epoch.v >> compile.log 2>&1
 if($LASTEXITCODE -ne 0) {throw 'TB compile failed'}
 & "$modelBin/vsim.exe" -c -L anlogic_sim '-voptargs=+acc' -onfinish exit -l transcript.log -wlf diagnostic.wlf -do 'run -all; quit -code 1 -force' work.tb_awb_epoch anlogic_sim.glbl anlogic_sim.PH1P_PHY_GSR *> console.log
 $result=Get-Content -LiteralPath console.log -Raw
 if($Case -eq 'legacy_contract') {
  if(!$result.Contains('** Fatal: new early epoch accepts old AWB tail mode=0')) {throw 'Expected old-RTL contract failure did not occur'}
  Write-Output 'EXPECTED FAIL legacy contract: original Sobel accepts real AWB old-valid tail after its new early FS'
 } elseif($LASTEXITCODE -ne 0 -or !$result.Contains($pass) -or $result -match '(?m)^#?\s*\*\* (Fatal|Error):') {throw "Simulation lacked PASS or had Fatal/Error: $Case"}
 $result.Split("`n") | Where-Object {$_ -match 'PASS|OBS|Errors:'}
} finally {Pop-Location}
