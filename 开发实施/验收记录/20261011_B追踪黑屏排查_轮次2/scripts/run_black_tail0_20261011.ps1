$ErrorActionPreference='Stop'
$projectRoot=Split-Path -Parent $PSScriptRoot
$sourceSim=Join-Path $PSScriptRoot 'tracking_black_fix_r3_td_20261011/sim'
$outputDir=Join-Path $PSScriptRoot 'tracking_black_round2_tail0_20261011'
if (Test-Path -LiteralPath $outputDir) {throw 'Output directory already exists'}
New-Item -ItemType Directory -Path $outputDir | Out-Null
$ini=Get-Content -LiteralPath (Join-Path $sourceSim 'modelsim.ini') -Raw
$ini=$ini.Replace('anlogic_sim = modelsim_work/anlogic_sim',('anlogic_sim = '+($sourceSim.Replace('\','/')+'/modelsim_work/anlogic_sim')))
$ini=$ini.Replace('test_isp_metadata_stop = modelsim_work/isp_metadata_stop',('test_isp_metadata_stop = '+($sourceSim.Replace('\','/')+'/modelsim_work/isp_metadata_stop')))
Set-Content -LiteralPath (Join-Path $outputDir 'modelsim.ini') -Value $ini
Set-Location -LiteralPath $outputDir
foreach ($licenseName in @('MGLS_LICENSE_FILE','LM_LICENSE_FILE')) {
 if (![Environment]::GetEnvironmentVariable($licenseName,'Process')) {
  $licenseValue=[Environment]::GetEnvironmentVariable($licenseName,'User')
  if (!$licenseValue) {$licenseValue=[Environment]::GetEnvironmentVariable($licenseName,'Machine')}
  if ($licenseValue) {[Environment]::SetEnvironmentVariable($licenseName,$licenseValue,'Process')}
 }
}
& 'D:/modelsim/win64/vsim.exe' -modelsimini modelsim.ini -c -L anlogic_sim '-voptargs=+acc=rn+/tb_isp_metadata_stop' -onfinish exit -l transcript.log -wlf measured.wlf -do 'run -all; quit -code 1 -force' test_isp_metadata_stop.tb_isp_metadata_stop anlogic_sim.glbl anlogic_sim.PH1P_PHY_GSR '+TAIL=0' *> console.log
$resultCode=$LASTEXITCODE
Set-Content -LiteralPath exit_code.txt -Value $resultCode
Get-Content -LiteralPath console.log -Tail 20
exit $resultCode
