$ErrorActionPreference='Stop'
foreach ($licenseName in @('MGLS_LICENSE_FILE','LM_LICENSE_FILE')) {
 if (![Environment]::GetEnvironmentVariable($licenseName,'Process')) {
  $licenseValue=[Environment]::GetEnvironmentVariable($licenseName,'User')
  if (!$licenseValue) { $licenseValue=[Environment]::GetEnvironmentVariable($licenseName,'Machine') }
  if ($licenseValue) { [Environment]::SetEnvironmentVariable($licenseName,$licenseValue,'Process') }
 }
}
$outDir=Join-Path $PSScriptRoot ('replay_'+[DateTime]::Now.ToString('yyyyMMdd_HHmmss_fff'))
New-Item -ItemType Directory -Path $outDir | Out-Null
Push-Location $outDir
try {
 & 'D:/modelsim/win64/vmap.exe' -c *> setup.log
 if ($LASTEXITCODE -ne 0) { throw 'vmap failed' }
 & 'D:/modelsim/win64/vlib.exe' work *> library.log
 if ($LASTEXITCODE -ne 0) { throw 'vlib failed' }
 & 'D:/modelsim/win64/vlog.exe' -sv -work work "$PSScriptRoot/tape_hole_tracker.v" "$PSScriptRoot/tb_hole_boundary.v" "$PSScriptRoot/tb_hole_soft_requirement.v" *> compile.log
 if ($LASTEXITCODE -ne 0) { throw 'vlog failed' }
 & 'D:/modelsim/win64/vsim.exe' -c work.tb_hole_boundary -l transcript.log -do 'onbreak {quit -code 1}; onerror {quit -code 1}; run -all; quit -code 0' *> console.log
 if ($LASTEXITCODE -ne 0 -or !(Select-String -LiteralPath console.log -Pattern 'PASS frozen D3 hole boundary characterization: 22 cases' -Quiet) -or (Select-String -LiteralPath console.log -Pattern '\*\* Fatal:|\*\* Error:' -Quiet)) { throw 'Characterization failed' }
 & 'D:/modelsim/win64/vsim.exe' -c work.tb_hole_soft_requirement -l soft_requirement_transcript.log -do 'onbreak {quit -code 1}; onerror {quit -code 1}; run -all; quit -code 0' *> soft_requirement_console.log
 if (!(Select-String -LiteralPath soft_requirement_console.log -Pattern '\*\* Fatal: characterization mismatch case 0 expected 1' -Quiet)) { throw 'Known soft-hole rejection not reproduced; inspect logs' }
 Write-Output 'Characterization PASS; soft-hole acceptance FAILED and retained as unresolved.'
} finally { Pop-Location }
