$ErrorActionPreference='Stop'
$taskBuild=Join-Path $PSScriptRoot 'upper_holes_v3_r2_20261013/td_project/camera_to_dsi_display_Runs'
foreach($stage in @('syn_1','phy_1')) {
 Push-Location (Join-Path $taskBuild $stage)
 try {
  & 'D:/AAA/FPGA.....YZW/bin/td_commands_prompt.exe' build.tcl *> build_console.log
  $taskExit=$LASTEXITCODE
  Set-Content -LiteralPath build_exit_code.txt -Value $taskExit
  if($taskExit -ne 0) {throw "$stage failed; see build_console.log"}
  Write-Output "$stage completed"
 } finally {Pop-Location}
}
