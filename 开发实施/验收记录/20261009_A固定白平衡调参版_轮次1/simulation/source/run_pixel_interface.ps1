param(
    [string]$IcarusBin = "",
    [string]$TdSimRoot = "D:/AAA/FPGA.....YZW/sim_release"
)
$ErrorActionPreference = "Stop"
if (!$IcarusBin) {
    $localTool = Join-Path $PSScriptRoot "../../../tmp/tools/iverilog/bin"
    if (Test-Path "$localTool/iverilog.exe") { $IcarusBin = $localTool }
    else { $IcarusBin = Split-Path (Get-Command iverilog -ErrorAction Stop).Source }
}
Push-Location $PSScriptRoot
try {
    $hdl = "../user_source/hdl_source"
    $ip = "../user_source/ip_source"
    $sources = @(
        "$hdl/awb.v", "$hdl/signal_delay.v",
        "$hdl/isp/data128_96/data128_96.v", "$hdl/isp/data96_128/data96_128.v",
        "$hdl/isp/demosaic_4x_2_0/bilinear_interpolation.v",
        "$ip/divider/divider_gate.v",
        "awb_ram_model.v",
        "tb_pixel_interface.v"
    )
    # Icarus cannot parse protected blocks. Compile the vendor's existing plain
    # primitive definitions; encrypted blocks are unused and are not decrypted.
    $plainDir = Join-Path $PSScriptRoot "pixel_interface_lib"
    New-Item -ItemType Directory -Path $plainDir -Force | Out-Null
    foreach ($name in @("al_map_basic.v", "al_map_lut.v", "al_map_adder.v", "al_phy_glbl.v")) {
        $source = Join-Path "$TdSimRoot/common" $name
        $content = [IO.File]::ReadAllText($source)
        $content = [regex]::Replace($content, '(?s)`pragma protect begin_protected.*?`pragma protect end_protected', '')
        $target = Join-Path $plainDir $name
        [IO.File]::WriteAllText($target, $content, [Text.UTF8Encoding]::new($false))
        $sources += $target
    }
    foreach ($path in $sources) {
        if (!(Test-Path -LiteralPath $path)) { throw "Missing simulation input: $path" }
    }
    & "$IcarusBin/iverilog.exe" -g2012 -s tb_pixel_interface -s glbl -o pixel_interface.vvp @sources 2> pixel_interface_compile.log
    if ($LASTEXITCODE -ne 0) {
        Get-Content pixel_interface_compile.log -Tail 20
        throw "Compile failed: pixel_interface"
    }
    & "$IcarusBin/vvp.exe" pixel_interface.vvp
    if ($LASTEXITCODE -ne 0) { throw "Simulation failed: pixel_interface" }
    & "$IcarusBin/iverilog.exe" -g2012 -s tb_pack_boundary -o pack_boundary.vvp "$hdl/isp/data96_128/data96_128.v" tb_pack_boundary.v
    if ($LASTEXITCODE -ne 0) { throw "Compile failed: pack_boundary" }
    & "$IcarusBin/vvp.exe" pack_boundary.vvp
    if ($LASTEXITCODE -ne 0) { throw "Simulation failed: pack_boundary" }
} finally { Pop-Location }
