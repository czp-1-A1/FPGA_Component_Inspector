param([int[]]$Modes=@(0,1,2,3))
$ErrorActionPreference='Stop'
$testDir=$PSScriptRoot
$repo=(Resolve-Path (Join-Path $testDir '../..')).Path
$rtl=Join-Path $repo 'fpga/component_inspector/user_source'
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
 & "$model/vmap.exe" -c *> setup.log
 & "$model/vlib.exe" work >> setup.log 2>&1
 & "$model/vmap.exe" work work >> setup.log 2>&1
 & "$model/vlog.exe" -work work "$rtl/hdl_source/roi_sobel_view.v" "$rtl/hdl_source/isp/data96_128/data96_128.v" "$rtl/hdl_source/video_in.v" "$rtl/hdl_source/video_out.v" "$rtl/ip_source/w128_d512_fifo/soft_fifo_al_4057d6b76aa6.v" "$rtl/ip_source/w128_d512_fifo/w128_d512_fifo.v" *> compile.log
 if($LASTEXITCODE -ne 0) { throw 'RTL compile failed' }
 & "$model/vlog.exe" -sv -work work tb_full_transport.v >> compile.log 2>&1
 if($LASTEXITCODE -ne 0) { throw 'Testbench compile failed' }
 foreach($mode in $Modes) {
  & "$model/vsim.exe" -c -onfinish exit -l "mode_$mode.transcript.log" -wlf "mode_$mode.wlf" -do 'run -all; quit -code 1 -force' work.tb_full_transport "+MODE=$mode" *> "mode_$mode.console.log"
  $code=$LASTEXITCODE
  Select-String -LiteralPath "mode_$mode.console.log" -Pattern 'CAPTURE|DISPLAY|READY_STALL|ERROR|PASS|Fatal|Errors:' | ForEach-Object { $_.Line }
  if($code -ne 0 -or !(Select-String -LiteralPath "mode_$mode.console.log" -Pattern 'PASS: FULL_TRANSPORT' -Quiet)) { throw "Mode $mode simulation failed" }
 }
} finally { Pop-Location }
