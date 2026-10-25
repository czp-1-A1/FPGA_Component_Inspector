$ErrorActionPreference = 'Stop'
$env:MGLS_LICENSE_FILE = [Environment]::GetEnvironmentVariable('MGLS_LICENSE_FILE','Machine')
$bin = 'D:/modelsim/win64'
Push-Location $PSScriptRoot
try {
  if (!(Test-Path -LiteralPath modelsim.ini)) { & "$bin/vmap.exe" -c *> replay_unit_setup.log }
  if (!(Test-Path -LiteralPath replay_unit/_info)) { & "$bin/vlib.exe" replay_unit >> replay_unit_setup.log 2>&1 }
  & "$bin/vmap.exe" p03_unit replay_unit >> replay_unit_setup.log 2>&1
  if ($LASTEXITCODE -ne 0) { throw 'ModelSim library setup failed' }
  & "$bin/vlog.exe" -work p03_unit ../../user_source/hdl_source/present_surface_check.v present_surface_check_p02.v *> replay_unit_compile.log
  if ($LASTEXITCODE -ne 0) { throw 'RTL compile failed' }
  & "$bin/vlog.exe" -sv -work p03_unit tb_present_surface_standing.sv >> replay_unit_compile.log 2>&1
  if ($LASTEXITCODE -ne 0) { throw 'testbench compile failed' }
  & "$bin/vsim.exe" -c p03_unit.tb_present_surface_standing -onfinish exit -l replay_unit_runtime.log -do 'run -all; quit -code 1 -force' *> replay_unit_console.log
  if ($LASTEXITCODE -ne 0) { throw 'unit simulation failed' }
  $text=Get-Content -LiteralPath replay_unit_console.log -Raw
  if ($text -notmatch 'PASS P03 standing surface: 39 requests, 170 exact' -or $text -match '\*\* (Fatal|Error):') { throw 'unit did not complete cleanly' }
  Get-Content -LiteralPath replay_unit_console.log | Select-String 'PASS P03'
} finally { Pop-Location }
