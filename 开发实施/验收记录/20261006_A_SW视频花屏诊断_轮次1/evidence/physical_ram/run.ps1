$ErrorActionPreference='Stop'
$bin='D:/modelsim/win64'
$sim='D:/AAA/FPGA.....YZW/sim_release'
foreach ($name in @('MGLS_LICENSE_FILE','LM_LICENSE_FILE')) {
 if (![Environment]::GetEnvironmentVariable($name,'Process')) {
  $value=[Environment]::GetEnvironmentVariable($name,'User')
  if (!$value) {$value=[Environment]::GetEnvironmentVariable($name,'Machine')}
  if ($value) {[Environment]::SetEnvironmentVariable($name,$value,'Process')}
 }
}
Push-Location $PSScriptRoot
try {
 & "$bin/vmap.exe" -c *> setup.log
 if ($LASTEXITCODE -ne 0) {throw 'vmap -c failed'}
 & "$bin/vlib.exe" work >> setup.log 2>&1
 if ($LASTEXITCODE -ne 0) {throw 'vlib failed'}
 & "$bin/vmap.exe" work work >> setup.log 2>&1
 & "$bin/vlog.exe" -work work "$sim/common/al_phy_glbl.v" "$sim/ph1p/ph1p_phy_gsr.v" "$sim/ph1p/ph1p_phy_eram_v2.v" *> compile.log
 if ($LASTEXITCODE -ne 0) {throw 'vendor compile failed'}
 & "$bin/vlog.exe" -sv -work work mapped_rgb_ram.v tb_ram_map.v >> compile.log 2>&1
 if ($LASTEXITCODE -ne 0) {throw 'TB compile failed'}
 & "$bin/vsim.exe" -c -voptargs=+acc -onfinish exit -l transcript.log -wlf wave.wlf -do 'log /tb_ram_map/*; run -all; quit -code 1 -force' work.tb_ram_map work.glbl work.PH1P_PHY_GSR *> console.log
 if ($LASTEXITCODE -ne 0) {throw 'simulation failed'}
 Get-Content -LiteralPath console.log | Select-Object -Last 30
} finally {Pop-Location}
