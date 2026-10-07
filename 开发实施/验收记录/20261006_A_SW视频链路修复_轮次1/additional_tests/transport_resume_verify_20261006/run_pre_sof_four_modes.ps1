$ErrorActionPreference='Stop'
$testDir=$PSScriptRoot
$repo=(Resolve-Path (Join-Path $testDir '../..')).Path
$rtl=Join-Path $repo 'fpga/component_inspector/user_source/hdl_source'
$model='D:/modelsim/win64'
foreach($name in @('MGLS_LICENSE_FILE','LM_LICENSE_FILE')) {
 if(![Environment]::GetEnvironmentVariable($name,'Process')) {
  $value=[Environment]::GetEnvironmentVariable($name,'User')
  if(!$value) { $value=[Environment]::GetEnvironmentVariable($name,'Machine') }
  if($value) { [Environment]::SetEnvironmentVariable($name,$value,'Process') }
 }
}
Push-Location $testDir
try {
 & "$model/vlib.exe" early_work *> pre_sof_four_modes.setup.log
 & "$model/vmap.exe" early_work early_work >> pre_sof_four_modes.setup.log 2>&1
 & "$model/vlog.exe" -work early_work "$rtl/roi_sobel_view.v" "$rtl/isp/data96_128/data96_128.v" *> pre_sof_four_modes.compile.log
 if($LASTEXITCODE -ne 0) { throw 'Early boundary RTL compile failed' }
 & "$model/vlog.exe" -sv -work early_work tb_pre_sof_four_modes.v >> pre_sof_four_modes.compile.log 2>&1
 if($LASTEXITCODE -ne 0) { throw 'Early boundary TB compile failed' }
 & "$model/vsim.exe" -c -onfinish exit -l pre_sof_four_modes.transcript.log -wlf pre_sof_four_modes.wlf -do 'run -all; quit -code 1 -force' early_work.tb_pre_sof_four_modes *> pre_sof_four_modes.console.log
 $code=$LASTEXITCODE
 Select-String -LiteralPath pre_sof_four_modes.console.log -Pattern 'PASS|Fatal|Errors:' | ForEach-Object { $_.Line }
 if($code -ne 0 -or !(Select-String -LiteralPath pre_sof_four_modes.console.log -Pattern 'PASS: PRE_SOF_FOUR_MODES' -Quiet) -or (Select-String -LiteralPath pre_sof_four_modes.console.log -Pattern '\*\* Fatal:' -Quiet)) { throw 'Early boundary simulation failed' }
} finally { Pop-Location }
