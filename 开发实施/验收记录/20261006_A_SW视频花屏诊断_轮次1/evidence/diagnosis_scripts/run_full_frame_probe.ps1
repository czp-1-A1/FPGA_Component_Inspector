$ErrorActionPreference = 'Stop'
$probeRoot = $PSScriptRoot
$repoRoot = (Resolve-Path (Join-Path $probeRoot '../..')).Path
$diagnosticDir = Join-Path $probeRoot 'full_frame_20261006'
$rtlRoot = Join-Path $repoRoot 'fpga/component_inspector/user_source'
$modelBin = 'D:/modelsim/win64'
New-Item -ItemType Directory -Path $diagnosticDir -Force | Out-Null
foreach ($licenseName in @('MGLS_LICENSE_FILE', 'LM_LICENSE_FILE')) {
    if (![Environment]::GetEnvironmentVariable($licenseName, 'Process')) {
        $licenseValue = [Environment]::GetEnvironmentVariable($licenseName, 'User')
        if (!$licenseValue) { $licenseValue = [Environment]::GetEnvironmentVariable($licenseName, 'Machine') }
        if ($licenseValue) { [Environment]::SetEnvironmentVariable($licenseName, $licenseValue, 'Process') }
    }
}
$tbText = [IO.File]::ReadAllText((Join-Path $probeRoot 'ddr_review/tb_ddr_capacity.v'))
$tbText = $tbText.Replace('module tb_ddr_capacity;', 'module tb_ddr_full;').Replace('W=1024,H=20;', 'W=1024,H=600;')
[IO.File]::WriteAllText((Join-Path $diagnosticDir 'tb_ddr_full.v'), $tbText)
$tailText = $tbText.Replace('module tb_ddr_full;', 'module tb_ddr_full_tailgap;').Replace('roi_sobel_view #', 'roi_sobel_view_tailgap #')
[IO.File]::WriteAllText((Join-Path $diagnosticDir 'tb_ddr_full_tailgap.v'), $tailText)
Push-Location $diagnosticDir
try {
    & "$modelBin/vmap.exe" -c *> setup.log
    if ($LASTEXITCODE -ne 0) { throw 'vmap setup failed' }
    & "$modelBin/vlib.exe" work >> setup.log 2>&1
    if ($LASTEXITCODE -ne 0) { throw 'vlib failed' }
    & "$modelBin/vmap.exe" work work >> setup.log 2>&1
    if ($LASTEXITCODE -ne 0) { throw 'work mapping failed' }
    & "$modelBin/vlog.exe" -work work `
        "$rtlRoot/hdl_source/roi_sobel_view.v" `
        "$rtlRoot/hdl_source/isp/data96_128/data96_128.v" `
        "$rtlRoot/hdl_source/video_in.v" `
        "$rtlRoot/ip_source/w128_d512_fifo/soft_fifo_al_4057d6b76aa6.v" `
        "$rtlRoot/ip_source/w128_d512_fifo/w128_d512_fifo.v" `
        "$probeRoot/ddr_review/roi_sobel_view_tailgap.v" *> compile.log
    if ($LASTEXITCODE -ne 0) { throw 'RTL compilation failed' }
    & "$modelBin/vlog.exe" -sv -work work tb_ddr_full.v tb_ddr_full_tailgap.v >> compile.log 2>&1
    if ($LASTEXITCODE -ne 0) { throw 'diagnostic compilation failed' }
    foreach ($case in @(
        @{ Name = 'old_control'; Module = 'tb_ddr_full'; Bypass = 1; Stall = 300 },
        @{ Name = 'new_no_stall'; Module = 'tb_ddr_full'; Bypass = 0; Stall = 0 },
        @{ Name = 'new_stall'; Module = 'tb_ddr_full'; Bypass = 0; Stall = 300 },
        @{ Name = 'tailgap_probe'; Module = 'tb_ddr_full_tailgap'; Bypass = 0; Stall = 300 }
    )) {
        $logFile = "$($case.Name).console.log"
        & "$modelBin/vsim.exe" -c -onfinish exit -l "$($case.Name).transcript.log" `
            -wlf "$($case.Name).wlf" -do 'run -all; quit -code 1 -force' `
            "work.$($case.Module)" "+BYPASS=$($case.Bypass)" "+STALL=$($case.Stall)" *> $logFile
        if ($LASTEXITCODE -ne 0) { throw "diagnostic simulation failed: $($case.Name)" }
        Select-String -LiteralPath $logFile -Pattern 'CAPACITY|MISMATCH|Errors:' | ForEach-Object { "$($case.Name): $($_.Line)" }
    }
} finally { Pop-Location }
