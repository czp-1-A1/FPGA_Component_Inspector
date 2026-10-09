param([string]$ModelSimBin='D:/modeltech64_10.5/win64')
$ErrorActionPreference='Stop'
foreach($name in @('MGLS_LICENSE_FILE','LM_LICENSE_FILE')){
 if(![Environment]::GetEnvironmentVariable($name,'Process')){
  $value=[Environment]::GetEnvironmentVariable($name,'User')
  if(!$value){$value=[Environment]::GetEnvironmentVariable($name,'Machine')}
  if($value){[Environment]::SetEnvironmentVariable($name,$value,'Process')}
 }
}
Push-Location $PSScriptRoot
try{
 & "$ModelSimBin/vmap.exe" -c *> native_pins.setup.log
 & "$ModelSimBin/vlib.exe" vendor >> native_pins.setup.log 2>&1
 & "$ModelSimBin/vmap.exe" anlogic_sim vendor >> native_pins.setup.log 2>&1
 $models=@('common/al_map_basic.v','common/al_map_lut.v','common/al_map_adder.v','common/al_phy_glbl.v',
 'ph1p/ph1p_phy_gsr.v','ph1p/ph1p_logic_bufg.v','ph1p/ph1p_phy_pll_v2.v','ph1p/ph1p_logic_hrio.v','ph1p/ph1p_phy_hr_pad.v') | ForEach-Object {"D:/td6.2.1/sim_release/$_"}
 & "$ModelSimBin/vlog.exe" -work anlogic_sim @models *> native_pins.vendor.log
 if($LASTEXITCODE -ne 0){throw 'Vendor compile failed'}
 & "$ModelSimBin/vlib.exe" work >> native_pins.setup.log 2>&1
 & "$ModelSimBin/vlog.exe" -sv ../user_source/ip_source/PLL/RTL/ph1p_phy_pll_wrapper_25a56e5ce2f9.v ../user_source/hdl_source/native_hdmi_pll.v ../diagnostics/hdmi_positive/avi_fhd30_top.v ../diagnostics/hdmi_positive/hdmi_avi_insert.v ../diagnostics/hdmi_positive/dvi_encoder.v ../user_source/hdl_source/hdmi_phy_warpper.v ../user_source/hdl_source/lane_lvds_10_1.v tb_native_pll_pins.v *> native_pins.compile.log
 if($LASTEXITCODE -ne 0){throw 'Native PLL pin compile failed'}
 & "$ModelSimBin/vsim.exe" -c -L anlogic_sim '-voptargs=+acc=rn' -onfinish exit -l native_pins.transcript.log -wlf native_pins.wave.wlf -do 'run -all; quit -code 1 -force' work.tb_native_pll_pins anlogic_sim.glbl anlogic_sim.PH1P_PHY_GSR *> native_pins.console.log
 $text=Get-Content native_pins.console.log -Raw
 if($LASTEXITCODE -ne 0 -or !$text.Contains('PASS native PLL pins:16') -or $text -match '(?m)^#?\s*\*\* (Fatal|Error):'){throw 'Native PLL pin probe failed; preserve logs'}
 Get-Content native_pins.console.log | Where-Object {$_ -match 'OBS |PASS '}
}finally{Pop-Location}
