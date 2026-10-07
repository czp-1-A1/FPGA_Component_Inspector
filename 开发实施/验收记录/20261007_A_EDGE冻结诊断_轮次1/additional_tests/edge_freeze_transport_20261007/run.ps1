param([int[]]$Gaps=@(0,16,64,128,256,512),[int[]]$Competes=@(0,1),[int[]]$FirstModes=@(0,2),[switch]$SkipCompile)
$ErrorActionPreference='Stop'
$root=$PSScriptRoot
$model='D:/modelsim/win64'
foreach($name in @('MGLS_LICENSE_FILE','LM_LICENSE_FILE')) {
 if(![Environment]::GetEnvironmentVariable($name,'Process')) {
  $value=[Environment]::GetEnvironmentVariable($name,'User')
  if(!$value) {$value=[Environment]::GetEnvironmentVariable($name,'Machine')}
  if($value) {[Environment]::SetEnvironmentVariable($name,$value,'Process')}
 }
}
Push-Location $root
try {
 if(!$SkipCompile) {
  & "$model/vmap.exe" -c *> setup.log
  & "$model/vlib.exe" work >> setup.log 2>&1
  & "$model/vmap.exe" work work >> setup.log 2>&1
  & "$model/vlog.exe" -work work tested_rtl/roi_sobel_view.v tested_rtl/data96_128.v tested_rtl/video_in.v tested_rtl/video_out.v tested_rtl/soft_fifo_al_4057d6b76aa6.v tested_rtl/w128_d512_fifo.v *> compile.log
  if($LASTEXITCODE -ne 0){throw 'RTL compile failed'}
  & "$model/vlog.exe" -sv -work work tb_edge_freeze_transport.v >> compile.log 2>&1
  if($LASTEXITCODE -ne 0){throw 'Probe compile failed'}
 }
 foreach($first in $FirstModes) {foreach($compete in $Competes) {foreach($gap in $Gaps) {
  $second=2-$first
  $case="switch_${first}_${second}_gap_${gap}_compete_${compete}"
  if(Test-Path -LiteralPath $case){throw "Preserve existing evidence: $case"}
  New-Item -ItemType Directory -Path $case | Out-Null
  & "$model/vsim.exe" -c -onfinish exit -l "$case/transcript.log" -wlf "$case/diagnostic.wlf" -do 'run -all; quit -code 1 -force' work.tb_edge_freeze_transport "+FIRST=$first" "+SECOND=$second" "+GAP=$gap" "+COMPETE=$compete" "+TRACE=$case/trace.csv" *> "$case/console.log"
  $exitCode=$LASTEXITCODE
  $content=Get-Content -Raw -LiteralPath "$case/console.log"
  $summary=@($content.Split("`n") | Where-Object {$_ -match '(PASS|FAIL): SWITCH_TRANSPORT'})
  $status=if($summary.Count -eq 1 -and $summary[0] -match 'PASS:'){'PASS'}else{'FAIL'}
  @{case=$case;exit_code=$exitCode;functional_status=$status;summary=$summary} | ConvertTo-Json | Set-Content -Encoding UTF8 -LiteralPath "$case/result.json"
  $content.Split("`n") | Where-Object {$_ -match 'CASE |CAPTURE_RESULT|FIRST_CACHE|FREEZE_REPRO|SWITCH_TRANSPORT|Fatal|Errors:'}
  if($exitCode -ne 0 -or $summary.Count -ne 1 -or $content -match '\*\* (Fatal|Error):'){throw "Probe incomplete or simulator error: $case"}
 }}}
} finally {Pop-Location}
