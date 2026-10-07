$ErrorActionPreference='Stop'
$simBin='D:/modelsim/win64'
& "$simBin/vlib.exe" work | Out-File setup.log
if($LASTEXITCODE -ne 0){throw 'vlib failed'}
& "$simBin/vlog.exe" -work work roi_sobel_view_tested.v roi_sobel_view_no_debug.v tb_timing_debug.v 2>&1 | Out-File compile.log
if($LASTEXITCODE -ne 0){throw 'vlog failed'}
& "$simBin/vopt.exe" +acc=rn work.tb_timing_debug -o timing_debug_opt 2>&1 | Out-File optimize.log
if($LASTEXITCODE -ne 0){throw 'vopt failed'}
& "$simBin/vsim.exe" -c -onfinish exit timing_debug_opt -do "run -all; quit -f" 2>&1 | Tee-Object -FilePath console.log
if($LASTEXITCODE -ne 0){throw 'vsim failed'}
$log=Get-Content -LiteralPath console.log -Raw
if($log -notmatch 'PASS independent timing_debug:' -or $log -match '\*\* Fatal:|\*\* Error:'){throw 'simulation did not satisfy PASS contract'}
