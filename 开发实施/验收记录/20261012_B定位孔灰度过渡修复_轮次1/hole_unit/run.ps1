$ErrorActionPreference='Stop'
foreach ($licenseName in @('MGLS_LICENSE_FILE','LM_LICENSE_FILE')) {
 if (![Environment]::GetEnvironmentVariable($licenseName,'Process')) {
  $licenseValue=[Environment]::GetEnvironmentVariable($licenseName,'User')
  if (!$licenseValue) { $licenseValue=[Environment]::GetEnvironmentVariable($licenseName,'Machine') }
  if ($licenseValue) { [Environment]::SetEnvironmentVariable($licenseName,$licenseValue,'Process') }
 }
}
$outDir=Join-Path $PSScriptRoot ('run_'+[DateTime]::Now.ToString('yyyyMMdd_HHmmss_fff'))
New-Item -ItemType Directory -Path $outDir | Out-Null
Push-Location $outDir
try {
 & 'D:/modelsim/win64/vmap.exe' -c *> setup.log
 if ($LASTEXITCODE -ne 0) { throw 'vmap failed' }
 & 'D:/modelsim/win64/vlib.exe' work *> library.log
 if ($LASTEXITCODE -ne 0) { throw 'vlib failed' }
 & 'D:/modelsim/win64/vlog.exe' -work work "$PSScriptRoot/tape_hole_tracker.v" *> compile.log
 if ($LASTEXITCODE -ne 0) { throw 'RTL compile failed' }
 & 'D:/modelsim/win64/vlog.exe' -sv -work work "$PSScriptRoot/tb_hole_transition_requirements.v" "$PSScriptRoot/tb_hole_soft_requirement.v" >> compile.log 2>&1
 if ($LASTEXITCODE -ne 0) { throw 'Test compile failed' }
 foreach($test in @('hole_transition_requirements','hole_soft_requirement')) {
  & 'D:/modelsim/win64/vsim.exe' -c "work.tb_$test" -l "${test}_transcript.log" -do 'onbreak {quit -code 1}; onerror {quit -code 1}; run -all; quit -code 1' *> "${test}_console.log"
  $out=Get-Content -LiteralPath "${test}_console.log" -Raw
  if ($LASTEXITCODE -ne 0 -or $out -notmatch 'PASS ' -or $out -match '\*\* (Fatal|Error):') {throw "$test failed; see $outDir"}
  $out -split "`n" | Where-Object {$_ -match 'PASS '}
 }
 Set-Content -LiteralPath unit_exit_code.txt -Value 0
 Write-Output "Results: $outDir"
} finally { Pop-Location }
