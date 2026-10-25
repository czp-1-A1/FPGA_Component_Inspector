$ErrorActionPreference = 'Stop'
$env:MGLS_LICENSE_FILE = [Environment]::GetEnvironmentVariable('MGLS_LICENSE_FILE','Machine')
$bin = 'D:/modelsim/win64'
Push-Location $PSScriptRoot
try {
  if (!(Test-Path -LiteralPath modelsim.ini)) {
    & "$bin/vmap.exe" -c *> replay_rgb_count_setup.log
    if ($LASTEXITCODE -ne 0) { throw 'ModelSim local setup failed' }
  }
  $hdl = '../../user_source/hdl_source'
  $common = @("$hdl/inspection_region_config.v", "$hdl/empty_candidate_probe.v", "$hdl/present_review_probe.v", "$hdl/present_surface_check.v", "$hdl/frame_shape_search.v")
  foreach ($name in @('standing_detector','standing_counting')) {
    $lib = 'p03_' + $name
    & "$bin/vlib.exe" $lib *> "$name.setup.log"
    if ($LASTEXITCODE -ne 0) { throw 'library creation failed' }
    & "$bin/vmap.exe" $lib $lib >> "$name.setup.log" 2>&1
    if ($LASTEXITCODE -ne 0) { throw 'library mapping failed' }
    $extra = if ($name -eq 'standing_detector') { @('present_surface_check_p02.v','frame_shape_search_p02.v','../surface/frame_shape_search_p01.v') } else { @("$hdl/classified_pocket_counter.v", "$hdl/classified_count_pipeline.v") }
    & "$bin/vlog.exe" -work $lib @common @extra *> "$name.compile.log"
    if ($LASTEXITCODE -ne 0) { throw "$name RTL compile failed" }
    $tb = if ($name -eq 'standing_detector') { "tb_$name.sv" } else { "tb_$name.v" }
    & "$bin/vlog.exe" -sv -work $lib $tb >> "$name.compile.log" 2>&1
    if ($LASTEXITCODE -ne 0) { throw "$name testbench compile failed" }
    & "$bin/vsim.exe" -c "$lib.tb_$name" -onfinish exit -l "$name.runtime.log" -do 'run -all; quit -code 1 -force' *> "$name.console.log"
    if ($LASTEXITCODE -ne 0) { throw "$name simulation failed" }
    $body = Get-Content -LiteralPath "$name.console.log" -Raw
    if ($body -notmatch 'PASS P03 standing' -or $body -match '\*\* (Fatal|Error):') { throw "$name missing clean completion" }
    Get-Content -LiteralPath "$name.console.log" | Select-String 'PASS P03'
  }
} finally { Pop-Location }
