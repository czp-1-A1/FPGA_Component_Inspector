$ErrorActionPreference='Stop'
$testDir=$PSScriptRoot
$model='D:/modelsim/win64'
foreach($name in @('MGLS_LICENSE_FILE','LM_LICENSE_FILE')) {
 if(![Environment]::GetEnvironmentVariable($name,'Process')) {
  $value=[Environment]::GetEnvironmentVariable($name,'User')
  if(!$value) { $value=[Environment]::GetEnvironmentVariable($name,'Machine') }
  if($value) { [Environment]::SetEnvironmentVariable($name,$value,'Process') }
 }
}
Push-Location $testDir
try {
 & "$model/vlog.exe" -sv -work work tb_transport_faults.v *> faults.compile.log
 if($LASTEXITCODE -ne 0) { throw 'Fault TB compile failed' }
 & "$model/vsim.exe" -c -onfinish exit -l faults.transcript.log -wlf faults.wlf -do 'run -all; quit -code 1 -force' work.tb_transport_faults *> faults.console.log
 Select-String -LiteralPath faults.console.log -Pattern 'CAPTURE|DISPLAY|STOP_CSI|UNDERFLOW|CROSS_VS|CACHE_OVERRUN|ERROR|PASS|Fatal|Errors:' | ForEach-Object { $_.Line }
 if($LASTEXITCODE -ne 0 -or !(Select-String -LiteralPath faults.console.log -Pattern 'PASS: TRANSPORT_FAULTS' -Quiet)) { throw 'Fault simulation failed' }
} finally { Pop-Location }
