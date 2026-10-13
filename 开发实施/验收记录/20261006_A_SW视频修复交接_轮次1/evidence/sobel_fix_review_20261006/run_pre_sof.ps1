$ErrorActionPreference = 'Stop'
$diagnosticRoot = $PSScriptRoot
$repoRoot = (Resolve-Path (Join-Path $diagnosticRoot '../..')).Path
$rtlRoot = Join-Path $repoRoot 'fpga/component_inspector/user_source/hdl_source'
$modelBin = 'D:/modelsim/win64'
foreach ($licenseName in @('MGLS_LICENSE_FILE', 'LM_LICENSE_FILE')) {
    if (![Environment]::GetEnvironmentVariable($licenseName, 'Process')) {
        $licenseValue = [Environment]::GetEnvironmentVariable($licenseName, 'User')
        if (!$licenseValue) { $licenseValue = [Environment]::GetEnvironmentVariable($licenseName, 'Machine') }
        if ($licenseValue) { [Environment]::SetEnvironmentVariable($licenseName, $licenseValue, 'Process') }
    }
}
Push-Location $diagnosticRoot
try {
    & "$modelBin/vmap.exe" -c *> pre_sof_setup.log
    & "$modelBin/vlib.exe" work >> pre_sof_setup.log 2>&1
    & "$modelBin/vmap.exe" work work >> pre_sof_setup.log 2>&1
    & "$modelBin/vlog.exe" -work work "$rtlRoot/roi_sobel_view.v" "$rtlRoot/isp/data96_128/data96_128.v" *> pre_sof_compile.log
    if ($LASTEXITCODE -ne 0) { throw 'RTL compile failed' }
    & "$modelBin/vlog.exe" -sv -work work tb_pre_sof_tail.v >> pre_sof_compile.log 2>&1
    if ($LASTEXITCODE -ne 0) { throw 'TB compile failed' }
    & "$modelBin/vsim.exe" -c -onfinish exit -l pre_sof_transcript.log -wlf pre_sof_diagnostic.wlf -do 'run -all; quit -code 1 -force' work.tb_pre_sof_tail *> pre_sof_console.log
    if ($LASTEXITCODE -ne 0) { throw 'diagnostic failed; see pre_sof_console.log' }
    Select-String -LiteralPath pre_sof_console.log -Pattern 'PASS|OBS|Errors:' | ForEach-Object { $_.Line }
} finally { Pop-Location }
