param([switch]$FullRaster)
$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$rtlRoot = Join-Path $repoRoot 'fpga/component_inspector/user_source'
$attemptDir = Join-Path $PSScriptRoot ('attempt_' + (Get-Date -Format 'yyyyMMdd_HHmmss'))
New-Item -ItemType Directory -Path $attemptDir | Out-Null
foreach ($licenseName in @('MGLS_LICENSE_FILE', 'LM_LICENSE_FILE')) {
    if (![Environment]::GetEnvironmentVariable($licenseName, 'Process')) {
        $licenseValue = [Environment]::GetEnvironmentVariable($licenseName, 'User')
        if (!$licenseValue) { $licenseValue = [Environment]::GetEnvironmentVariable($licenseName, 'Machine') }
        if ($licenseValue) { [Environment]::SetEnvironmentVariable($licenseName, $licenseValue, 'Process') }
    }
}
Push-Location $PSScriptRoot
try {
    & 'D:/modelsim/win64/vmap.exe' -c *> setup.log
    if ($LASTEXITCODE -ne 0) { throw 'vmap setup failed' }
    & 'D:/modelsim/win64/vlib.exe' work >> setup.log 2>&1
    if ($LASTEXITCODE -ne 0) { throw 'vlib failed' }
    & 'D:/modelsim/win64/vmap.exe' work work >> setup.log 2>&1
    if ($LASTEXITCODE -ne 0) { throw 'work mapping failed' }
    & 'D:/modelsim/win64/vlog.exe' -work work `
        "$rtlRoot/hdl_source/video_in.v" "$rtlRoot/hdl_source/video_out.v" `
        "$rtlRoot/ip_source/w128_d512_fifo/soft_fifo_al_4057d6b76aa6.v" `
        "$rtlRoot/ip_source/w128_d512_fifo/w128_d512_fifo.v" *> compile.log
    if ($LASTEXITCODE -ne 0) { throw 'RTL compilation failed' }
    & 'D:/modelsim/win64/vlog.exe' -sv -work work tb_video_transport.sv >> compile.log 2>&1
    if ($LASTEXITCODE -ne 0) { throw 'TB compilation failed' }
    $extraArgs = @()
    if ($FullRaster) { $extraArgs = @('-gW=1024','-gH=600','+FULL_ONCE') }
    & 'D:/modelsim/win64/vsim.exe' -c -onfinish exit -l transcript.log -wlf wave.wlf `
        -do 'run -all; quit -code 1 -force' work.tb_video_transport @extraArgs *> console.log
    if ($LASTEXITCODE -ne 0) { throw 'Simulation failed; see console.log' }
    $resultText = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'console.log'))
    if ($resultText -match '\*\* Fatal:' -or $resultText -notmatch 'PASS video_transport') {
        throw 'Simulation did not pass; see console.log'
    }
    Get-Content console.log
} finally {
    foreach ($logName in @('setup.log','compile.log','console.log','transcript.log')) {
        $logPath = Join-Path $PSScriptRoot $logName
        if (Test-Path -LiteralPath $logPath) { Copy-Item -LiteralPath $logPath -Destination $attemptDir }
    }
    Pop-Location
}
