$ErrorActionPreference='Stop'
$sim=Join-Path $PSScriptRoot 'hole_transition_r1_td_20261012/sim'
try {
 & "$sim/run_modelsim.ps1" -OnlyTests @('tracking_late','tracking','tracking_status','tracking_age','isp_tracking_late','isp_tracking','isp_metadata_stop','isp_writer_stop','roi_chain') *> "$sim/regression_console.log"
 Set-Content -LiteralPath "$sim/regression_exit_code.txt" -Value 0
 Get-Content -LiteralPath "$sim/regression_console.log" | Where-Object {$_ -match 'PASS '}
} catch {
 Set-Content -LiteralPath "$sim/regression_exit_code.txt" -Value 1
 throw
}
