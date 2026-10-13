from pathlib import Path
import hashlib,json,shutil,re
root=Path(__file__).resolve().parent.parent
project=root/'fpga/component_inspector'
before=root/'tmp/fixed_wb_tuning_before_20261009'
prior=root/'tmp/presence_modes_v3_td_20261008'
build=root/'tmp/fixed_wb_tuning_td_20261009'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
dump=lambda p,d:p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
assert not build.exists()
baseline=json.loads((before/'inputs.json').read_text(encoding='utf-8-sig'))
inputs=[]
for e in baseline:
 src=project/e['path'];dst=build/e['path'];dst.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(src,dst)
 inputs.append({'path':e['path'],'bytes':dst.stat().st_size,'sha256':sha(dst)})
changed=[e['path'] for e,b in zip(inputs,baseline) if e['sha256']!=b['sha256']]
assert set(changed)=={'user_source/hdl_source/awb.v','user_source/hdl_source/isp/isp_top.v'}
stages=[]
for stage in ['syn_1','phy_1']:
 rel=Path('td_project/camera_to_dsi_display_Runs')/stage;dst=build/rel;dst.mkdir(parents=True)
 for name in ['settings.cfg','build.tcl','camera_to_dsi_display.prj']:
  shutil.copy2(prior/rel/name,dst/name);stages.append({'path':(rel/name).as_posix(),'sha256':sha(dst/name)})
 paths=re.findall(r'<File Path="([^"]+)"',(dst/'camera_to_dsi_display.prj').read_text(encoding='utf-8-sig'))
 assert len(paths)==69 and all((dst/p).is_file() for p in paths)
sim=build/'sim';sim.mkdir()
for src in (project/'sim').iterdir():
 if src.is_file() and src.suffix in {'.v','.py','.ps1','.md','.do'}:shutil.copy2(src,sim/src.name)
shutil.copytree(project/'sim/osd_assets',sim/'osd_assets')
dump(build/'inputs.json',inputs);dump(build/'stage_inputs.json',stages)
dump(build/'preparation.json',{'baseline':'presence_modes_v3_20261008','inputs':len(inputs),'changed_production_inputs':changed,'project_sources':69,'fixed_red_blue_gain':1.0,'optical_thresholds_unvalidated':True})
print('PASS frozen build:',len(inputs),'inputs, 69 sources; only AWB/ISP changed')
