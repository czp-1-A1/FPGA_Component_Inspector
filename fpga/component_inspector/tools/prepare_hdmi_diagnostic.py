"""Freeze and prepare an independent HDMI-only diagnostic TD project.

Never replaces any existing directory, candidate, AL or board contents.
"""
from pathlib import Path
import argparse,hashlib,json,re,shutil,subprocess

engine=Path(__file__).resolve().parents[1]
repo=engine.parents[1]
ap=argparse.ArgumentParser()
ap.add_argument('destination',type=Path)
ap.add_argument('--td',default='D:/td6.2.1')
args=ap.parse_args()
dest=args.destination.resolve()
if dest.exists():raise SystemExit('Refusing to replace existing diagnostic directory')
sources=[
 'diagnostics/hdmi_1080p30_tpg/hdmi_tpg_top.v',
 'user_source/hdl_source/native_hdmi_pll.v',
 'user_source/ip_source/PLL/RTL/ph1p_phy_pll_wrapper_25a56e5ce2f9.v',
 'user_source/hdl_source/hdmi_1_4b_transmitter_core_wrapper.enc.v',
 'user_source/hdl_source/hdmi_phy_warpper.v',
 'user_source/hdl_source/lane_lvds_10_1.v']
inputs=sources+['tools/prepare_hdmi_diagnostic.py','sim/tb_hdmi_tpg.v',
 'sim/hdmi_decode.vh','sim/hdmi_ideal_pll.v','sim/run_hdmi_tpg.ps1']
manifest=[]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
for rel in inputs:
 src,out=engine/rel,dest/rel
 out.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(src,out)
 manifest.append(dict(path=rel,sha256=sha(out),bytes=out.stat().st_size))
project_dir=dest/'td_project';project_dir.mkdir()
pin=(engine/'user_source/constraints_source/pin.adc').read_text()
pins='\n'.join(line for line in pin.splitlines()
 if re.search(r'\{\s*(I_sys_clk|I_rst_n|O_tmds_ch[012]_p|O_tmds_clk_p)\s*\}',line))+'\n'
assert len(pins.splitlines())==6
(project_dir/'pin.adc').write_text(pins)
sdc='''create_clock -name sys_clk_50m -period 20 [get_ports I_sys_clk]
derive_clocks
derive_clock_uncertainty
# User reset is an asynchronous control; release is synchronized in pixel.
set_false_path -from [get_ports I_rst_n]
# This diagnostic does not claim a board-level TMDS external timing budget.
# Four TMDS outputs remain explicitly open in check_timing coverage.
'''
(project_dir/'hdmi_tpg.sdc').write_text(sdc)
base=(engine/'td_project/camera_to_dsi_display.al').read_text()
def section(tag,files):
 return '<'+tag+'>\n'+''.join(
  '<File Path="'+p+'">\n<FileInfo>\n<Attr Name="UsedInSyn" Val="true"/>\n'
  '<Attr Name="UsedInP&amp;R" Val="true"/>\n<Attr Name="BelongTo" Val="'+
  ('design_1' if tag=='Verilog' else 'constraint_1')+'"/>\n'
  '<Attr Name="CompileOrder" Val="'+str(i)+'"/>\n</FileInfo>\n</File>\n'
  for i,p in enumerate(files,1))+'</'+tag+'>\n'
source_section='<Source_Files>\n'+section('Verilog',['../'+r for r in sources])+section('System_Verilog',[])+section('ADC_FILE',['pin.adc'])+section('SDC_FILE',['hdmi_tpg.sdc'])+section('IP_FILE',[])+'</Source_Files>'
project=re.sub(r'<Source_Files>.*?</Source_Files>',lambda _:source_section,base,flags=re.S)
project=project.replace('camera_to_dsi_display','hdmi_tpg').replace('design_top_wrapper','hdmi_tpg_top')
project=re.sub(r'(<Project[^>]* Path=")[^"]+',lambda m:m[1]+project_dir.as_posix(),project,count=1)
project=re.sub(r'<TD_Version>.*?</TD_Version>','<TD_Version>6.2.178840</TD_Version>',project)
(project_dir/'hdmi_tpg.al').write_text(project)
runs=project_dir/'hdmi_tpg_Runs'
for run,settings in [('syn_1','set run_type syn\nset start_step read_design\nset end_step opt_gate\n'),
 ('phy_1','set run_type phy\nset parent ../syn_1\nset arr_filter false\nset drHoldFix on\nset start_step opt_place\nset end_step bitgen\n')]:
 d=runs/run;d.mkdir(parents=True)
 def relocated(m):
  p=m[1];resolved=(project_dir/p).resolve()
  assert resolved.is_relative_to(dest) and resolved.exists(),p
  return '<File Path="../../'+p+'"'
 (d/'hdmi_tpg.prj').write_text(re.sub(r'<File Path="([^"]+)"',relocated,project))
 common='''set ADCList {"../../pin.adc"}
set IpADCList {}
set IpSDCList {}
set SDCList {"../../hdmi_tpg.sdc"}
set area_option -packarea
set device_name ph1_35p.db
set package_name PH1P35MDG324
set prj_name {hdmi_tpg}
set speed 3
set top_model_name {hdmi_tpg_top}
'''
 (d/'settings.cfg').write_text(common+settings)
 (d/'build.tcl').write_text('source {'+args.td+'/scripts/DefaultFlow.tcl}\ncheck_timing -file constraint_coverage.txt -verbose\nexit\n')
for p in (project_dir/'pin.adc',project_dir/'hdmi_tpg.sdc',project_dir/'hdmi_tpg.al'):
 manifest.append(dict(path=p.relative_to(dest).as_posix(),sha256=sha(p),bytes=p.stat().st_size))
(dest/'freeze.json').write_text(json.dumps(dict(
 branch=subprocess.check_output(['git','branch','--show-current'],cwd=repo,text=True).strip(),
 head=subprocess.check_output(['git','rev-parse','HEAD'],cwd=repo,text=True).strip(),
 purpose='HDMI-only1080p30 internalTPG diagnostic; no camera/DDR; not accepted',
 inputs=manifest),indent=2)+'\n')
print('Frozen diagnostic at '+str(dest))
