from pathlib import Path
import json,shutil,hashlib
r=Path(__file__).resolve().parents[2];p=r/'fpga/component_inspector'
b=r/'tmp/sample_ui_td_build_20261005';old=r/'tmp/roi_core_td_build_20261005'
assert not b.exists(), 'Never overwrite a build'
m=json.loads((p/'release/roi_core_80_20261005/manifest.json').read_text(encoding='utf-8'))
extra=['user_source/hdl_source/'+n+'.v' for n in ['roi_result_snapshot','roi_display_state','osd_ascii_rom','osd_cjk_rom','osd_logo_rom']]
paths=[e['path'] for e in m['verified_build_inputs']]+extra+['td_project/camera_to_dsi_display.al']
sha=lambda f:hashlib.sha256(f.read_bytes()).hexdigest()
for rel in paths:
 t=b/rel;t.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(p/rel,t)
for stage in ['syn_1','phy_1']:
 dst=b/'td_project/camera_to_dsi_display_Runs'/stage;dst.mkdir(parents=True)
 for name in ['settings.cfg','build.tcl','camera_to_dsi_display.prj']:
  shutil.copy2(old/'td_project/camera_to_dsi_display_Runs'/stage/name,dst/name)
 prj=dst/'camera_to_dsi_display.prj';data=prj.read_bytes();tag=b'        <Verilog>\r\n'
 fragment=(p/'td_project/camera_to_dsi_display.al').read_bytes().split(tag)[1].split(b'            <File Path="../user_source/hdl_source/roi_frame_guard.v">')[0]
 data=data.replace(tag,tag+fragment.replace(b'../user_source',b'../../../user_source'))
 prj.write_bytes(data)
(b/'inputs.json').write_text(json.dumps([{'path':rel,'sha256':sha(p/rel),'bytes':(p/rel).stat().st_size} for rel in paths],indent=2)+'\n',encoding='utf-8')
print('Prepared isolated TD build with',len(paths)-1,'inputs; SDC unchanged.')
