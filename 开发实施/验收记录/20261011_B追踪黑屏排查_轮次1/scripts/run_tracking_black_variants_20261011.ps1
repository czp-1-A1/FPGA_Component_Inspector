$ErrorActionPreference='Stop'
$sim=Join-Path $PSScriptRoot 'tracking_black_fix_r2_td_20261011/sim'
Set-Location -LiteralPath $sim
foreach ($licenseName in @('MGLS_LICENSE_FILE','LM_LICENSE_FILE')) {
 if (![Environment]::GetEnvironmentVariable($licenseName,'Process')) {
  $licenseValue=[Environment]::GetEnvironmentVariable($licenseName,'User')
  if (!$licenseValue) {$licenseValue=[Environment]::GetEnvironmentVariable($licenseName,'Machine')}
  if ($licenseValue) {[Environment]::SetEnvironmentVariable($licenseName,$licenseValue,'Process')}
 }
}
# Wait until the last regression library is loaded; variants only read the
# already compiled metadata-stop library and use separate logs/wave files.
$ready=$false
for ($attempt=0;$attempt -lt 180;$attempt++) {
 $path='modelsim_work/roi_chain/console.log'
 if ((Test-Path -LiteralPath $path) -and (Get-Content -LiteralPath $path -Raw).Contains('run -all')) {$ready=$true;break}
 if ((Test-Path -LiteralPath 'regression_console.log') -and (Get-Content -LiteralPath 'regression_console.log' -Raw) -match 'Simulation failed:|Missing successful completion|Compile failed:') {throw 'Regression failed before variants'}
 Start-Sleep -Seconds 5
}
if (!$ready) {throw 'Last regression library did not start'}
foreach ($viewMode in @(0,1,2)) {
 & 'D:/modelsim/win64/vsim.exe' -c -L anlogic_sim '-voptargs=+acc=rn+/tb_isp_metadata_stop' -onfinish exit -l "metadata_mode${viewMode}_transcript.log" -wlf "metadata_mode${viewMode}.wlf" -do 'run -all; quit -code 1 -force' test_isp_metadata_stop.tb_isp_metadata_stop anlogic_sim.glbl anlogic_sim.PH1P_PHY_GSR "+MODE=$viewMode" *> "metadata_mode${viewMode}_console.log"
 $resultCode=$LASTEXITCODE
 Set-Content -LiteralPath "metadata_mode${viewMode}_exit_code.txt" -Value $resultCode
 if ($resultCode -ne 0) {throw "Metadata stop variant $viewMode failed"}
 $output=Get-Content -LiteralPath "metadata_mode${viewMode}_console.log" -Raw
 if (!$output.Contains('PASS actual ISP metadata stop:') -or $output -match '(?m)^#?\s*\*\* (Fatal|Error):') {throw "Metadata stop variant $viewMode did not pass"}
 Write-Output "PASS metadata stop view=$viewMode"
}
Set-Content -LiteralPath variants_exit_code.txt -Value 0
