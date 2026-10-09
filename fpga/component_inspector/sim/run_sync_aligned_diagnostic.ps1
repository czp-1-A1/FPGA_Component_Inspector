param([switch]$LegacyA,[string]$ModelSimBin='D:/modeltech64_10.5/win64')
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
 $tag=if($LegacyA){'legacy_negative'}else{'aligned_pins'}
 & "$ModelSimBin/vmap.exe" -c *> "$tag.setup.log"
 & "$ModelSimBin/vlib.exe" vendor >> "$tag.setup.log" 2>&1
 & "$ModelSimBin/vmap.exe" anlogic_sim vendor >> "$tag.setup.log" 2>&1
 $models=@('common/al_map_basic.v','common/al_map_lut.v','common/al_map_adder.v','common/al_phy_glbl.v',
 'ph1p/ph1p_phy_gsr.v','ph1p/ph1p_logic_bufg.v','ph1p/ph1p_phy_pll_v2.v',
 'ph1p/ph1p_logic_hrio.v','ph1p/ph1p_phy_hr_pad.v') | ForEach-Object {"D:/td6.2.1/sim_release/$_"}
 & "$ModelSimBin/vlog.exe" -work anlogic_sim @models *> "$tag.vendor.log"
 if($LASTEXITCODE -ne 0){throw 'Vendor compile failed'}
 & "$ModelSimBin/vlib.exe" work >> "$tag.setup.log" 2>&1
 & "$ModelSimBin/vlog.exe" -sv hdmi_ideal_pll.v ../diagnostics/hdmi_positive/positive_top.v ../diagnostics/hdmi_positive/sync_aligned_top.v ../diagnostics/hdmi_positive/dvi_encoder.v ../user_source/hdl_source/hdmi_phy_warpper.v ../user_source/hdl_source/lane_lvds_10_1.v tb_sync_aligned_pins.v *> "$tag.compile.log"
 if($LASTEXITCODE -ne 0){throw 'Diagnostic compile failed'}
 $options=@();if($LegacyA){$options+='-gLEGACY_A=1'}
 & "$ModelSimBin/vsim.exe" -c @options -L anlogic_sim '-voptargs=+acc=rn' -onfinish exit -l "$tag.transcript.log" -wlf "$tag.wave.wlf" -do 'run -all; quit -code 1 -force' work.tb_sync_aligned_pins anlogic_sim.glbl anlogic_sim.PH1P_PHY_GSR *> "$tag.console.log"
 $exitStatus=$LASTEXITCODE;$s=Get-Content "$tag.console.log" -Raw
 if($LegacyA){
  # This ModelSim -onfinish exit returns 0 for $fatal too. Classify the
  # intentionally failing control from its exact raw diagnostic, not exit 0.
  if(!$s.Contains('** Fatal: VS leading edge does not coincide with HS leading edge') -or $s.Contains('PASS aligned pin frame:') -or $s -match '(?m)^#?\s*\*\* Error:'){throw 'Legacy negative test did not detect the intended phase error'}
  'PASS negative control: original A fails frozen HS/VS coincidence reference; raw Fatal log preserved.'
 }else{
  if($exitStatus -ne 0 -or !$s.Contains('PASS aligned pin frame:') -or $s -match '(?m)^#?\s*\*\* (Fatal|Error):'){throw "Diagnostic failed: $tag.console.log"}
  Get-Content "$tag.console.log" | Where-Object {$_ -match 'OBS |PASS '}
 }
}finally{Pop-Location}
