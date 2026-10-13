$ErrorActionPreference = 'Stop'
foreach ($licenseName in @('MGLS_LICENSE_FILE', 'LM_LICENSE_FILE')) {
    if (![Environment]::GetEnvironmentVariable($licenseName, 'Process')) {
        $licenseValue = [Environment]::GetEnvironmentVariable($licenseName, 'User')
        if (!$licenseValue) { $licenseValue = [Environment]::GetEnvironmentVariable($licenseName, 'Machine') }
        if ($licenseValue) { [Environment]::SetEnvironmentVariable($licenseName, $licenseValue, 'Process') }
    }
}
Push-Location $PSScriptRoot
try {
    & 'D:/modelsim/win64/vsim.exe' -c -do run.do -l video_out_underflow.log *> console.log
    if ($LASTEXITCODE -ne 0) { throw 'ModelSim failed; see console.log' }
    Get-Content console.log
} finally { Pop-Location }
