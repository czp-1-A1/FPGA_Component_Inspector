param([string]$Source='baseline_roi_sobel_view.v',[string]$Case='before')
$ErrorActionPreference='Stop'
foreach($name in @('MGLS_LICENSE_FILE','LM_LICENSE_FILE')) {
 if(![Environment]::GetEnvironmentVariable($name,'Process')) {
  $value=[Environment]::GetEnvironmentVariable($name,'User')
  if(!$value){$value=[Environment]::GetEnvironmentVariable($name,'Machine')}
  if($value){[Environment]::SetEnvironmentVariable($name,$value,'Process')}
 }
}
Push-Location $PSScriptRoot
try {
 if(Test-Path -LiteralPath $Case){throw 'Preserve existing result'}
 New-Item -ItemType Directory -Path $Case | Out-Null
 $m='D:/modelsim/win64'
 & "$m/vmap.exe" -c *> "$Case/setup.log"
 & "$m/vlib.exe" "$Case/work" >> "$Case/setup.log" 2>&1
 & "$m/vmap.exe" gap_work "$Case/work" >> "$Case/setup.log" 2>&1
 & "$m/vlog.exe" -work gap_work $Source data96_128.v *> "$Case/compile.log"
 if($LASTEXITCODE -ne 0){throw 'RTL compilation failed'}
 & "$m/vlog.exe" -sv -work gap_work tb_sobel_view.v >> "$Case/compile.log" 2>&1
 if($LASTEXITCODE -ne 0){throw 'TB compilation failed'}
 & "$m/vsim.exe" -c -onfinish exit -l "$Case/transcript.log" -wlf "$Case/wave.wlf" -do 'run -all; quit -code 1 -force' gap_work.tb_sobel_view *> "$Case/console.log"
 $text=Get-Content -LiteralPath "$Case/console.log" -Raw
 $text.Split("`n") | Where-Object {$_ -match 'PASS|Fatal|Errors:|OBS Sobel'}
 if($text -match 'PASS Sobel view:' -and $text -notmatch '\*\* (Fatal|Error):'){ 'PASS' | Set-Content -LiteralPath "$Case/result.txt" }
 else { 'FAIL' | Set-Content -LiteralPath "$Case/result.txt" }
} finally {Pop-Location}
