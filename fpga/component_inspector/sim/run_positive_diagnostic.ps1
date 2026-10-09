param([switch]$Hd60,[switch]$NativeProbe,[string]$ModelSimBin='D:/modeltech64_10.5/win64')
$ErrorActionPreference='Stop'
foreach($name in @('MGLS_LICENSE_FILE','LM_LICENSE_FILE')){
 if(![Environment]::GetEnvironmentVariable($name,'Process')){
  $v=[Environment]::GetEnvironmentVariable($name,'User')
  if(!$v){$v=[Environment]::GetEnvironmentVariable($name,'Machine')}
  if($v){[Environment]::SetEnvironmentVariable($name,$v,'Process')}
 }
}
Push-Location $PSScriptRoot
try{
 $tag=if($NativeProbe){'native_probe'}else{'pins'}
 & "$ModelSimBin/vmap.exe" -c *> "$tag.setup.log"
 & "$ModelSimBin/vlib.exe" vendor >> "$tag.setup.log" 2>&1
 & "$ModelSimBin/vmap.exe" anlogic_sim vendor >> "$tag.setup.log" 2>&1
 $models=@('common/al_map_basic.v','common/al_map_lut.v','common/al_map_adder.v','common/al_phy_glbl.v',
 'ph1p/ph1p_phy_gsr.v','ph1p/ph1p_logic_bufg.v','ph1p/ph1p_phy_pll_v2.v',
 'ph1p/ph1p_logic_hrio.v','ph1p/ph1p_phy_hr_pad.v') | ForEach-Object {"D:/td6.2.1/sim_release/$_"}
 & "$ModelSimBin/vlog.exe" -work anlogic_sim @models *> "$tag.vendor.log"
 if($LASTEXITCODE -ne 0){throw 'Vendor compile failed'}
 & "$ModelSimBin/vlib.exe" work >> "$tag.setup.log" 2>&1
 if($NativeProbe){
  & "$ModelSimBin/vlog.exe" ../user_source/hdl_source/native_hdmi_pll.v ../user_source/ip_source/PLL/RTL/ph1p_phy_pll_wrapper_25a56e5ce2f9.v tb_native_pll.v *> "$tag.compile.log"
  $top='tb_native_pll';$pass='PASS native PLL:';$options=@('+notimingchecks')
 }else{
  $defines=@();if($Hd60){$defines+='+define+HDMI720P'}
  & "$ModelSimBin/vlog.exe" -sv @defines hdmi_ideal_pll.v ../diagnostics/hdmi_positive/positive_top.v ../diagnostics/hdmi_positive/dvi_encoder.v ../user_source/hdl_source/hdmi_phy_warpper.v ../user_source/hdl_source/lane_lvds_10_1.v tb_positive_pins.v *> "$tag.compile.log"
  $top='tb_positive_pins';$pass='PASS positive pin frame:';$options=@()
 }
 if($LASTEXITCODE -ne 0){throw 'Diagnostic compile failed'}
 & "$ModelSimBin/vsim.exe" -c @options -L anlogic_sim '-voptargs=+acc=rn' -onfinish exit -l "$tag.transcript.log" -wlf "$tag.wave.wlf" -do 'run -all; quit -code 1 -force' "work.$top" anlogic_sim.glbl anlogic_sim.PH1P_PHY_GSR *> "$tag.console.log"
 $s=Get-Content "$tag.console.log" -Raw
 if($LASTEXITCODE -ne 0 -or !$s.Contains($pass) -or $s -match '(?m)^#?\s*\*\* (Fatal|Error):'){throw "Diagnostic failed: $tag.console.log"}
 Get-Content "$tag.console.log" | Where-Object {$_ -match 'OBS |PASS |PLL measured'}
}finally{Pop-Location}
