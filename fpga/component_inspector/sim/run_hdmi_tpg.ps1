param([string]$ModelSimBin='D:/modeltech64_10.5/win64',[string]$TdSimRoot='D:/td6.2.1/sim_release',[switch]$UseIdealClocks)
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
 & "$ModelSimBin/vmap.exe" -c *> setup.log
 & "$ModelSimBin/vlib.exe" vendor >> setup.log 2>&1
 & "$ModelSimBin/vmap.exe" anlogic_sim vendor >> setup.log 2>&1
 $vendor=@('common/al_map_basic.v','common/al_map_lut.v','common/al_map_adder.v','common/al_phy_glbl.v',
 'ph1p/ph1p_logic_eram.v','ph1p/ph1p_phy_gsr.v','ph1p/ph1p_logic_bufg.v','ph1p/ph1p_phy_pll_v2.v',
 'ph1p/ph1p_logic_hrio.v','ph1p/ph1p_logic_ramfifo.v','ph1p/ph1p_phy_hr_pad.v') | ForEach-Object { "$TdSimRoot/$_" }
 & "$ModelSimBin/vlog.exe" -work anlogic_sim @vendor *> vendor_compile.log
 if($LASTEXITCODE -ne 0){throw 'TPG vendor compile failed'}
 & "$ModelSimBin/vlib.exe" work >> setup.log 2>&1
 $pllSources=@()
 if($UseIdealClocks){$pllSources+='hdmi_ideal_pll.v'}else{$pllSources+=@('../user_source/hdl_source/native_hdmi_pll.v','../user_source/ip_source/PLL/RTL/ph1p_phy_pll_wrapper_25a56e5ce2f9.v')}
 & "$ModelSimBin/vlog.exe" ../diagnostics/hdmi_1080p30_tpg/hdmi_tpg_top.v @pllSources ../user_source/hdl_source/hdmi_1_4b_transmitter_core_wrapper.enc.v ../user_source/hdl_source/hdmi_phy_warpper.v ../user_source/hdl_source/lane_lvds_10_1.v *> compile.log
 if($LASTEXITCODE -ne 0){throw 'TPG RTL compile failed'}
 $defines=@()
 if($UseIdealClocks){$defines+='+define+HDMI_TPG_IDEAL_PLL'}
 & "$ModelSimBin/vlog.exe" -sv @defines tb_hdmi_tpg.v >> compile.log 2>&1
 if($LASTEXITCODE -ne 0){throw 'TPG RTL compile failed'}
 # Analog PLL functional model quantization requires disabling specify checks;
 # this run proves functional counts, never routed/board timing.
 $simOptions=@()
 if(!$UseIdealClocks){$simOptions+='+notimingchecks'}
 & "$ModelSimBin/vsim.exe" -c @simOptions -L anlogic_sim '-voptargs=+acc=rn+/tb_hdmi_tpg+/tb_hdmi_tpg/dut' -onfinish exit -l transcript.log -wlf wave.wlf -do 'run -all; quit -code 1 -force' work.tb_hdmi_tpg anlogic_sim.glbl anlogic_sim.PH1P_PHY_GSR *> console.log
 $text=Get-Content console.log -Raw
 if($LASTEXITCODE -ne 0 -or !$text.Contains('PASS TPG transport counts:') -or $text -match '(?m)^#?\s*\*\* (Fatal|Error):'){throw 'TPG simulation failed; see console.log'}
 Get-Content console.log | Where-Object {$_ -match '(OBS |PASS )'}
} finally {Pop-Location}
