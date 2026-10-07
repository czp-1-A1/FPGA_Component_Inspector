$ErrorActionPreference='Stop'
$modelBin='D:/modelsim/win64'
foreach($licenseName in @('MGLS_LICENSE_FILE','LM_LICENSE_FILE')) {
 if(![Environment]::GetEnvironmentVariable($licenseName,'Process')) {
  $licenseValue=[Environment]::GetEnvironmentVariable($licenseName,'User')
  if(!$licenseValue) {$licenseValue=[Environment]::GetEnvironmentVariable($licenseName,'Machine')}
  if($licenseValue) {[Environment]::SetEnvironmentVariable($licenseName,$licenseValue,'Process')}
 }
}
$fullEvidence=@((Join-Path $PSScriptRoot 'tb_isp_full_epoch.v'),(Join-Path $PSScriptRoot 'run_full.ps1'))
$fullManifest=@($fullEvidence | ForEach-Object {@{Path=$_;SHA256=(Get-FileHash -LiteralPath $_ -Algorithm SHA256).Hash.ToLower()} })
$fullManifest | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $PSScriptRoot 'full_inputs_manifest.json') -Encoding UTF8
Push-Location $PSScriptRoot
try {
 & "$modelBin/vlog.exe" -sv -work life_proof_work tb_isp_full_epoch.v *> full_compile.log
 if($LASTEXITCODE -ne 0){throw 'Full epoch TB compile failed'}
 & "$modelBin/vsim.exe" -c -L life_proof_vendor '-voptargs=+acc=rn+/tb_isp_full_epoch' -onfinish exit -l full_transcript.log -wlf full_diagnostic.wlf -do 'run -all; quit -code 1 -force' life_proof_work.tb_isp_full_epoch life_proof_vendor.glbl life_proof_vendor.PH1P_PHY_GSR *> full_console.log
 $result=Get-Content -LiteralPath full_console.log -Raw
 if($LASTEXITCODE -ne 0 -or !$result.Contains('PASS actual ISP full epoch:') -or $result -match '(?m)^#?\s*\*\* (Fatal|Error):'){throw 'Full epoch did not pass'}
 $result.Split("`n") | Where-Object {$_ -match 'PASS|OBS|Errors:'}
} finally {Pop-Location}
