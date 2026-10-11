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
 & "$ModelSimBin/vmap.exe" -c *> clock_probe.setup.log
 & "$ModelSimBin/vlib.exe" vendor >> clock_probe.setup.log 2>&1
 & "$ModelSimBin/vmap.exe" anlogic_sim vendor >> clock_probe.setup.log 2>&1
 $models=@('common/al_map_basic.v','common/al_map_lut.v','common/al_map_adder.v','common/al_phy_glbl.v',
 'ph1p/ph1p_phy_gsr.v','ph1p/ph1p_logic_bufg.v','ph1p/ph1p_phy_pll_v2.v','ph1p/ph1p_logic_hrio.v','ph1p/ph1p_phy_hr_pad.v') | ForEach-Object {"D:/td6.2.1/sim_release/$_"}
 & "$ModelSimBin/vlog.exe" -work anlogic_sim @models *> clock_probe.vendor.log
 if($LASTEXITCODE -ne 0){throw 'Vendor compile failed'}
 & "$ModelSimBin/vlib.exe" work >> clock_probe.setup.log 2>&1
 & "$ModelSimBin/vlog.exe" -sv hdmi_ideal_pll.v ../diagnostics/hdmi_positive/clock_probe_top.v ../diagnostics/hdmi_positive/clock_probe_measure.v ../diagnostics/hdmi_positive/clock_probe_osd.v ../user_source/hdl_source/status_cdc.v ../diagnostics/hdmi_positive/dvi_encoder.v ../user_source/hdl_source/hdmi_phy_warpper.v ../user_source/hdl_source/lane_lvds_10_1.v tb_clock_probe_units.v tb_clock_probe_pins.v *> clock_probe.compile.log
 if($LASTEXITCODE -ne 0){throw 'Clock probe diagnostic compile failed'}
 & "$ModelSimBin/vsim.exe" -c -onfinish exit -l clock_probe_units.transcript.log -wlf clock_probe_units.wave.wlf -do 'run -all; quit -code 1 -force' work.tb_clock_probe_units *> clock_probe_units.console.log
 $unit=Get-Content clock_probe_units.console.log -Raw
 if($LASTEXITCODE -ne 0 -or !$unit.Contains('PASS F units complete') -or $unit -match '(?m)^#?\s*\*\* (Fatal|Error):'){throw 'Probe unit simulation failed; preserve logs'}
 Get-Content clock_probe_units.console.log | Where-Object {$_ -match 'PASS '}
 & "$ModelSimBin/vsim.exe" -c -L anlogic_sim '-voptargs=+acc=rn' -onfinish exit -l clock_probe.transcript.log -wlf clock_probe.wave.wlf -do 'run -all; quit -code 1 -force' work.tb_clock_probe_pins anlogic_sim.glbl anlogic_sim.PH1P_PHY_GSR *> clock_probe.console.log
 $text=Get-Content clock_probe.console.log -Raw
 if($LASTEXITCODE -ne 0 -or !$text.Contains('PASS F dual-mode pins:720p60 to1080p30 to720p60') -or $text -match '(?m)^#?\s*\*\* (Fatal|Error):'){throw 'Clock probe pin simulation failed; preserve logs'}
 Get-Content clock_probe.console.log | Where-Object {$_ -match 'OBS |PASS '}
}finally{Pop-Location}
