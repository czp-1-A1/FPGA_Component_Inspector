param([string]$IcarusBin = "")
$ErrorActionPreference = "Stop"
if (!$IcarusBin) {
    $localTool = Join-Path $PSScriptRoot "../../../tmp/tools/iverilog/bin"
    if (Test-Path "$localTool/iverilog.exe") { $IcarusBin = $localTool }
    else { $IcarusBin = Split-Path (Get-Command iverilog -ErrorAction Stop).Source }
}
Push-Location $PSScriptRoot
try {
    $hdl = "../user_source/hdl_source"
    $tests = @(
        @{Name="controls"; Sources=@("$hdl/uiisp_beta/ae_set.v", "$hdl/uics500_cfg/uicfgcs500.v", "$hdl/uics500_cfg/uics500reg.v", "$hdl/uics500_cfg/uics500regAE.v", "$hdl/uics500_cfg/SC500GainTbl.v", "tb_controls.v")},
        @{Name="cdc"; Sources=@("$hdl/status_cdc.v", "tb_cdc.v")},
        @{Name="monitor"; Sources=@("$hdl/status_cdc.v", "$hdl/input_monitor.v", "tb_monitor.v")},
        @{Name="csi_monitor"; Sources=@("$hdl/status_cdc.v", "$hdl/input_monitor.v", "$hdl/isp/csi_unpacket_2lane.v", "$hdl/isp/raw10_unpacket_2lane.v", "tb_csi_monitor.v")},
        @{Name="i2c"; Sources=@("$hdl/uics500_cfg/uii2c.v", "tb_i2c.v")},
        @{Name="osd"; Sources=@("$hdl/bin16_bcd.v", "$hdl/osd_ascii_rom.v", "$hdl/osd_cjk_rom.v", "$hdl/osd_logo_rom.v", "$hdl/experiment_osd.v", "tb_osd.v")}
    )
    foreach ($test in $tests) {
        & "$IcarusBin/iverilog.exe" -g2012 -s ("tb_"+$test.Name) -o ($test.Name+".vvp") @($test.Sources)
        if ($LASTEXITCODE -ne 0) { throw "Compile failed: $($test.Name)" }
        & "$IcarusBin/vvp.exe" ($test.Name+".vvp")
        if ($LASTEXITCODE -ne 0) { throw "Simulation failed: $($test.Name)" }
    }
} finally { Pop-Location }
