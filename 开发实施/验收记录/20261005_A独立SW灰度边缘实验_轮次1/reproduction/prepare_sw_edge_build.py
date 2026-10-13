from pathlib import Path
import json,shutil,hashlib
r=Path(__file__).resolve().parents[2];p=r/'fpga/component_inspector'
b=r/'tmp/sw_edge_td_build_20261005';old=r/'tmp/sample_ui_td_build_20261005'
assert not b.exists(), 'Never overwrite a build'
m=json.loads((p/'release/sample_ui_20261005/manifest.json').read_text(encoding='utf-8'))
extra=['user_source/hdl_source/'+n+'.v' for n in ['observation_controls','roi_sobel_view','roi_observation_snapshot']]
paths=[e['path'] for e in m['verified_build_inputs']]+extra+['td_project/camera_to_dsi_display.al']
sha=lambda f:hashlib.sha256(f.read_bytes()).hexdigest()
for rel in paths:
 t=b/rel;t.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(p/rel,t)
for stage in ['syn_1','phy_1']:
 dst=b/'td_project/camera_to_dsi_display_Runs'/stage;dst.mkdir(parents=True)
 for name in ['settings.cfg','build.tcl','camera_to_dsi_display.prj']:
  shutil.copy2(old/'td_project/camera_to_dsi_display_Runs'/stage/name,dst/name)
 prj=dst/'camera_to_dsi_display.prj';data=prj.read_bytes();tag=b'        <Verilog>\r\n'
 project=(p/'td_project/camera_to_dsi_display.al').read_bytes()
 fragment=b''
 for rel in extra:
  filename=rel.rsplit('/',1)[1]
  import re
  match=re.search(rb'            <File Path="[^"\r\n]*'+filename.encode()+rb'">.*?</File>\r\n',project,re.S)
  assert match,filename
  fragment+=match[0].replace(b'../user_source',b'../../../user_source')
 assert data.count(tag)==1
 prj.write_bytes(data.replace(tag,tag+fragment))
(b/'inputs.json').write_text(json.dumps([{'path':rel,'sha256':sha(p/rel),'bytes':(p/rel).stat().st_size} for rel in paths],indent=2)+'\n',encoding='utf-8')
print('Prepared isolated TD build with',len(paths)-1,'inputs.')
