"""Freeze separate positive-sync diagnostics; never overwrite old packages."""
from pathlib import Path
import argparse, hashlib, json, re, shutil, subprocess
engine=Path(__file__).resolve().parents[1]
repo=engine.parents[1]
ap=argparse.ArgumentParser()
ap.add_argument('destination',type=Path)
ap.add_argument('--mode',choices=['fhd30','hd60'],required=True)
args=ap.parse_args()
dest=args.destination.resolve()
if dest.exists():raise SystemExit('Refusing existing freeze destination')
name='positive_'+args.mode
top=name+'_top'
sources=['diagnostics/hdmi_positive/positive_top.v','diagnostics/hdmi_positive/dvi_encoder.v',
 'user_source/hdl_source/native_hdmi_pll.v',
 'user_source/ip_source/PLL/RTL/ph1p_phy_pll_wrapper_25a56e5ce2f9.v',
 'user_source/hdl_source/hdmi_phy_warpper.v','user_source/hdl_source/lane_lvds_10_1.v']
inputs=sources+['sim/tb_positive_pins.v','sim/hdmi_decode.vh','sim/hdmi_ideal_pll.v',
 'sim/tb_native_pll.v','sim/run_positive_diagnostic.ps1','tools/prepare_positive_diagnostic.py']
manifest=[]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
for rel in inputs:
 p=dest/rel;p.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(engine/rel,p)
 manifest.append(dict(path=rel,sha256=sha(p),bytes=p.stat().st_size))
prj=dest/'td_project';prj.mkdir()
pins='\n'.join(line for line in (engine/'user_source/constraints_source/pin.adc').read_text().splitlines()
 if re.search(r'\{\s*(I_sys_clk|I_rst_n|O_tmds_ch[012]_p|O_tmds_clk_p)\s*\}',line))+'\n'
assert len(pins.splitlines())==6
(prj/'pin.adc').write_text(pins)
(prj/(name+'.sdc')).write_text('''create_clock -name sys_clk_50m -period 20 [get_ports I_sys_clk]
derive_clocks
derive_clock_uncertainty
set_false_path -from [get_ports I_rst_n]
# Async user reset releases via three pixel flops. Four TMDS external output
# budgets remain open; internal STA is not physical signal-integrity proof.
''')
def section(tag,files,start):
 return '<'+tag+'>\n'+''.join('<File Path="'+p+'">\n<FileInfo>\n'
  '<Attr Name="UsedInSyn" Val="true"/>\n<Attr Name="UsedInP&amp;R" Val="true"/>\n'
  '<Attr Name="BelongTo" Val="'+('design_1' if tag=='Verilog' else 'constraint_1')+'"/>\n'
  '<Attr Name="CompileOrder" Val="'+str(i)+'"/>\n</FileInfo>\n</File>\n'
  for i,p in enumerate(files,start))+'</'+tag+'>\n'
base=(engine/'td_project/camera_to_dsi_display.al').read_text()
ss='<Source_Files>\n'+section('Verilog',['../'+r for r in sources],1)+section('System_Verilog',[],7)
ss+=section('ADC_FILE',['pin.adc'],7)+section('SDC_FILE',[name+'.sdc'],8)+section('IP_FILE',[],9)+'</Source_Files>'
al=re.sub(r'<Source_Files>.*?</Source_Files>',lambda _:ss,base,flags=re.S)
al=al.replace('camera_to_dsi_display',name).replace('design_top_wrapper',top)
al=re.sub(r'(<Project[^>]* Path=")[^"]+',lambda m:m[1]+prj.as_posix(),al,count=1)
al=re.sub(r'<TD_Version>.*?</TD_Version>','<TD_Version>6.2.178840</TD_Version>',al)
(prj/(name+'.al')).write_text(al)
for run,settings in [('syn_1','set run_type syn\nset start_step read_design\nset end_step opt_gate\n'),
 ('phy_1','set run_type phy\nset parent ../syn_1\nset arr_filter false\nset drHoldFix on\nset start_step opt_place\nset end_step bitgen\n')]:
 d=prj/(name+'_Runs')/run;d.mkdir(parents=True)
 def relocate(m):
  assert (prj/m[1]).resolve().is_relative_to(dest) and (prj/m[1]).exists(),m[1]
  return '<File Path="../../'+m[1]+'"'
 (d/(name+'.prj')).write_text(re.sub(r'<File Path="([^"]+)"',relocate,al))
 common='set ADCList {"../../pin.adc"}\nset IpADCList {}\nset IpSDCList {}\n'
 common+='set SDCList {"../../'+name+'.sdc"}\nset area_option -packarea\nset device_name ph1_35p.db\n'
 common+='set package_name PH1P35MDG324\nset prj_name {'+name+'}\nset speed 3\nset top_model_name {'+top+'}\n'
 (d/'settings.cfg').write_text(common+settings)
 (d/'build.tcl').write_text('source {D:/td6.2.1/scripts/DefaultFlow.tcl}\ncheck_timing -file constraint_coverage.txt -verbose\nexit\n')
for p in (prj/'pin.adc',prj/(name+'.sdc'),prj/(name+'.al')):
 manifest.append(dict(path=p.relative_to(dest).as_posix(),sha256=sha(p),bytes=p.stat().st_size))
(dest/'freeze.json').write_text(json.dumps(dict(mode=args.mode,project=name,
 head=subprocess.check_output(['git','rev-parse','HEAD'],cwd=repo,text=True).strip(),
 purpose='Positive-sync DVI-compatible pin diagnostic; no camera/DDR/AVI; not accepted',inputs=manifest),indent=2)+'\n')
print(dest)
