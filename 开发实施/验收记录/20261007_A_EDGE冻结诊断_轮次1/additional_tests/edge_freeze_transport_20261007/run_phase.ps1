param([int[]]$Pauses=@(1400),[int[]]$FirstModes=@(0,2),[int[]]$Competes=@(1),[int[]]$Gaps=@(384),[int[]]$Phases=@(4517,4553,4611),[switch]$SkipCompile)
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
  & "$model/vlib.exe" phase_work *> phase_setup.log
  & "$model/vmap.exe" phase_work phase_work >> phase_setup.log 2>&1
  & "$model/vlog.exe" -work phase_work tested_rtl/roi_sobel_view.v tested_rtl/data96_128.v tested_rtl/video_in.v tested_rtl/video_out.v tested_rtl/soft_fifo_al_4057d6b76aa6.v tested_rtl/w128_d512_fifo.v tested_rtl/mc_to_user_interface.v tested_rtl/soft_fifo_al_f58e8b3e1f3d.v tested_rtl/w155_d512_fifo.v *> phase_compile.log
  if($LASTEXITCODE -ne 0){throw 'Phase RTL compile failed'}
  & "$model/vlog.exe" -sv -work phase_work tb_edge_freeze_phase.v >> phase_compile.log 2>&1
  if($LASTEXITCODE -ne 0){throw 'Phase probe compile failed'}
 }
 foreach($first in $FirstModes) {foreach($compete in $Competes) {foreach($gap in $Gaps) {foreach($pause in $Pauses) {foreach($phase in $Phases) {
  $second=2-$first
  $case="mc_switch_${first}_${second}_gap_${gap}_compete_${compete}_pause_${pause}_phase_${phase}"
  if(Test-Path -LiteralPath $case){throw "Preserve existing evidence: $case"}
  New-Item -ItemType Directory -Path $case | Out-Null
  & "$model/vsim.exe" -c -onfinish exit -l "$case/transcript.log" -wlf "$case/diagnostic.wlf" -do 'run -all; quit -code 1 -force' phase_work.tb_edge_freeze_phase "+FIRST=$first" "+SECOND=$second" "+GAP=$gap" "+COMPETE=$compete" "+MC_PAUSE=$pause" "+PHASE=$phase" "+TRACE=$case/trace.csv" *> "$case/console.log"
  $exitCode=$LASTEXITCODE
  $content=Get-Content -Raw -LiteralPath "$case/console.log"
  $summary=@($content.Split("`n") | Where-Object {$_ -match '(PASS|FAIL): SWITCH_TRANSPORT'})
  $status=if($summary.Count -eq 1 -and $summary[0] -match 'PASS:'){'PASS'}else{'FAIL'}
  @{case=$case;exit_code=$exitCode;functional_status=$status;summary=$summary} | ConvertTo-Json | Set-Content -Encoding UTF8 -LiteralPath "$case/result.json"
  $content.Split("`n") | Where-Object {$_ -match 'CASE |CAPTURE_RESULT|FIRST_CACHE|FREEZE_REPRO|SWITCH_TRANSPORT|MC_DIAGNOSTIC|MC_PAUSE|SOURCE_PHASE|Fatal|Errors:'}
  if($exitCode -ne 0 -or $summary.Count -ne 1 -or $content -match '\*\* (Fatal|Error):'){throw "MC probe incomplete or simulator error: $case"}
 }}}}}
} finally {Pop-Location}
