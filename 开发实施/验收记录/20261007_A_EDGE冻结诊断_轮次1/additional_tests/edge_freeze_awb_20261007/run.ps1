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
$sources=@("$hdl/awb.v","$hdl/signal_delay.v","$hdl/roi_sobel_view.v","$hdl/isp/data96_128/data96_128.v","$ip/divider/divider_gate.v","$ip/blk_mem_gen_awb_delay_signal/blk_mem_gen_awb_delay_signal.v","$ip/blk_mem_gen_awb_delay_signal/ram_f84573da5ab5.v")
$evidenceSources=$sources+@("$diagnosticRoot/tb_dense_awb.v","$diagnosticRoot/run.ps1")
$records=@($evidenceSources | ForEach-Object { @{Path=$_;SHA256=(Get-FileHash -LiteralPath $_ -Algorithm SHA256).Hash.ToLower()} })
$records | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath "$diagnosticRoot/inputs.json" -Encoding UTF8
Copy-Item -LiteralPath "$hdl/roi_sobel_view.v" -Destination "$diagnosticRoot/compiled_roi_sobel_view.v"
Push-Location $diagnosticRoot
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
 & "$modelBin/vlog.exe" -sv -work work tb_dense_awb.v >> compile.log 2>&1
 if($LASTEXITCODE -ne 0) {throw 'TB compile failed'}
 & "$modelBin/vsim.exe" -c -L anlogic_sim '-voptargs=+acc' -onfinish exit -l transcript.log -wlf diagnostic.wlf -do 'run -all; quit -code 1 -force' work.tb_dense_awb anlogic_sim.glbl anlogic_sim.PH1P_PHY_GSR *> console.log
 $result=Get-Content -LiteralPath console.log -Raw
 if($LASTEXITCODE -ne 0 -or !$result.Contains('PASS dense actual AWB diagnosis:') -or $result -match '(?m)^#?\s*\*\* (Fatal|Error):') {throw 'Dense AWB diagnosis lacked PASS or had Fatal/Error'}
 $result.Split("`n") | Where-Object {$_ -match 'PASS|OBS|Errors:'}
} finally {Pop-Location}
