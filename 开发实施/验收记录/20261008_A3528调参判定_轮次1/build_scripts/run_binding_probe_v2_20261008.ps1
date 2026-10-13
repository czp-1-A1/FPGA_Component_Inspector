$ErrorActionPreference='Stop'
$repo=Split-Path -Parent $PSScriptRoot
$probe=Join-Path $repo 'tmp/led_presence_demo_v2_td_20261008/binding_probe'
$hdl=Join-Path $repo 'tmp/led_presence_demo_v2_td_20261008/user_source/hdl_source'
$bin='D:/modelsim/win64'
foreach ($name in @('MGLS_LICENSE_FILE','LM_LICENSE_FILE')) {
    if (![Environment]::GetEnvironmentVariable($name,'Process')) {
        $configuredValue=[Environment]::GetEnvironmentVariable($name,'User')
        if (!$configuredValue) { $configuredValue=[Environment]::GetEnvironmentVariable($name,'Machine') }
        if ($configuredValue) { [Environment]::SetEnvironmentVariable($name,$configuredValue,'Process') }
    }
}
Push-Location $probe
try {
    & "$bin/vmap.exe" -c *> setup.log
    if ($LASTEXITCODE -ne 0) { throw 'Probe setup failed' }
    foreach ($version in @('v1','v2')) {
        $lib='profile_'+$version
        & "$bin/vlib.exe" $lib >> setup.log 2>&1
        if ($LASTEXITCODE -ne 0) { throw 'Probe library failed' }
        & "$bin/vmap.exe" $lib $lib >> setup.log 2>&1
        if ($LASTEXITCODE -ne 0) { throw 'Probe mapping failed' }
        & "$bin/vlog.exe" -work $lib "$hdl/roi_classifier.v" "$hdl/roi_result_snapshot.v" "$hdl/roi_display_state.v" "$hdl/status_cdc.v" *> "compile_$version.log"
        if ($LASTEXITCODE -ne 0) { throw 'Probe RTL compile failed' }
        & "$bin/vlog.exe" -sv -work $lib "tb_profile_$version.v" >> "compile_$version.log" 2>&1
        if ($LASTEXITCODE -ne 0) { throw 'Probe test compile failed' }
        & "$bin/vsim.exe" -c -voptargs=+acc -onfinish exit -l "transcript_$version.log" -do 'run -all; quit -code 1 -force' "$lib.tb_profile_binding" *> "console_$version.log"
        $probeCode=$LASTEXITCODE
        $resultText=Get-Content "console_$version.log" -Raw
        if ($version -eq 'v1') {
            # This ModelSim -onfinish exit can return zero for $fatal; inspect
            # the exact negative-control assertion and error count instead.
            if ($resultText -notmatch '\*\* Fatal: classifier FS freshness' -or $resultText -notmatch 'Errors: 1, Warnings: 0' -or $resultText -notmatch 'OBS binding tuning ex=\s*2244 gain=\s*47 enabled=1') { throw 'Old binding did not reproduce the expected gain-47 failure' }
            Write-Output 'PASS negative control: extracted v1 bindings reject classification at gain 47'
        } else {
            if ($probeCode -ne 0 -or $resultText -notmatch 'PASS display state:' -or $resultText -match '(?m)^#?\s*\*\* (Fatal|Error):') { throw 'New binding regression failed' }
            Write-Output 'PASS v2 extracted bindings: exposure/gain tuning, waiting and fresh classification'
        }
    }
} finally { Pop-Location }
