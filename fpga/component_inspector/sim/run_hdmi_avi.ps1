param([string]$ModelSimBin='D:/modeltech64_10.5/win64',[string]$TdSimRoot='D:/td6.2.1/sim_release')
$ErrorActionPreference='Stop'
foreach($name in @('MGLS_LICENSE_FILE','LM_LICENSE_FILE')) {
 if(![Environment]::GetEnvironmentVariable($name,'Process')) {
  $licenseValue=[Environment]::GetEnvironmentVariable($name,'User')
  if(!$licenseValue){$licenseValue=[Environment]::GetEnvironmentVariable($name,'Machine')}
  if($licenseValue){[Environment]::SetEnvironmentVariable($name,$licenseValue,'Process')}
 }
}
Push-Location $PSScriptRoot
try {
 & "$ModelSimBin/vmap.exe" -c *> avi.setup.log
 & "$ModelSimBin/vlib.exe" vendor >> avi.setup.log 2>&1
 & "$ModelSimBin/vmap.exe" anlogic_sim vendor >> avi.setup.log 2>&1
 $vendor=@('common/al_map_basic.v','common/al_map_lut.v','common/al_map_adder.v','common/al_phy_glbl.v',
 'ph1p/ph1p_logic_eram.v','ph1p/ph1p_phy_gsr.v','ph1p/ph1p_logic_bufg.v',
 'ph1p/ph1p_logic_hrio.v','ph1p/ph1p_logic_ramfifo.v','ph1p/ph1p_phy_hr_pad.v') | ForEach-Object { "$TdSimRoot/$_" }
 & "$ModelSimBin/vlog.exe" -work anlogic_sim @vendor *> avi.vendor.log
 if($LASTEXITCODE -ne 0){throw 'AVI vendor compile failed'}
 & "$ModelSimBin/vlib.exe" work >> avi.setup.log 2>&1
 & "$ModelSimBin/vlog.exe" ../diagnostics/hdmi_1080p30_tpg/hdmi_tpg_top.v hdmi_ideal_pll.v ../user_source/hdl_source/hdmi_1_4b_transmitter_core_wrapper.enc.v ../user_source/hdl_source/hdmi_phy_warpper.v ../user_source/hdl_source/lane_lvds_10_1.v *> avi.compile.log
 if($LASTEXITCODE -ne 0){throw 'AVI RTL compile failed'}
 & "$ModelSimBin/vlog.exe" -sv tb_hdmi_avi.v >> avi.compile.log 2>&1
 if($LASTEXITCODE -ne 0){throw 'AVI receiver compile failed'}
 & "$ModelSimBin/vsim.exe" -c -L anlogic_sim '-voptargs=+acc=rn+/tb_hdmi_avi+/tb_hdmi_avi/dut' -onfinish exit -l avi.transcript.log -wlf avi.wave.wlf -do 'run -all; quit -code 1 -force' work.tb_hdmi_avi anlogic_sim.glbl anlogic_sim.PH1P_PHY_GSR *> avi.console.log
 $text=Get-Content avi.console.log -Raw
 if($LASTEXITCODE -ne 0 -or !$text.Contains('PASS AVI actual encrypted core:') -or $text -match '(?m)^#?\s*\*\* (Fatal|Error):'){throw 'AVI simulation failed; preserve logs'}
 Get-Content avi.console.log | Where-Object {$_ -match '(OBS |PASS )'}
} finally {Pop-Location}
