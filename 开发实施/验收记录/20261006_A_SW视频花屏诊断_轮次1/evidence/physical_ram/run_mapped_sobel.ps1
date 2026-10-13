$ErrorActionPreference='Stop'
$bin='D:/modelsim/win64'
foreach ($name in @('MGLS_LICENSE_FILE','LM_LICENSE_FILE')) {
 if (![Environment]::GetEnvironmentVariable($name,'Process')) {
  $value=[Environment]::GetEnvironmentVariable($name,'User')
  if (!$value) {$value=[Environment]::GetEnvironmentVariable($name,'Machine')}
  if ($value) {[Environment]::SetEnvironmentVariable($name,$value,'Process')}
 }
}
Push-Location $PSScriptRoot
try {
 & "$bin/vlib.exe" mapped_sobel *> mapped_sobel_setup.log
 & "$bin/vmap.exe" mapped_sobel mapped_sobel >> mapped_sobel_setup.log 2>&1
 & "$bin/vlog.exe" -work mapped_sobel roi_sobel_view_mapped.v '../../fpga/component_inspector/user_source/hdl_source/isp/data96_128/data96_128.v' *> mapped_sobel_compile.log
 if ($LASTEXITCODE -ne 0) {throw 'RTL compile failed'}
 & "$bin/vlog.exe" -sv -work mapped_sobel mapped_rgb_ram.v tb_sobel_view.v >> mapped_sobel_compile.log 2>&1
 if ($LASTEXITCODE -ne 0) {throw 'compile failed'}
 & "$bin/vsim.exe" -c -L work -voptargs=+acc -onfinish exit -l mapped_sobel_transcript.log -wlf mapped_sobel_wave.wlf -do 'log /tb_sobel_view/*; run -all; quit -code 1 -force' mapped_sobel.tb_sobel_view work.glbl work.PH1P_PHY_GSR *> mapped_sobel_console.log
 if ($LASTEXITCODE -ne 0) {throw 'simulation failed'}
 Get-Content -LiteralPath mapped_sobel_console.log | Select-Object -Last 30
} finally {Pop-Location}
