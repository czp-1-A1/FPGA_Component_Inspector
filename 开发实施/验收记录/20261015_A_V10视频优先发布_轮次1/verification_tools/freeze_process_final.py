from pathlib import Path
import json,hashlib,shutil,sys
r=Path.cwd();p=r/'fpga/component_inspector';prior=r/'tmp/presence_v7_r1_20261014';dst=r/'tmp'/sys.argv[1]
assert not dst.exists();dst.mkdir()
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
inputs=json.loads((prior/'inputs.json').read_text(encoding='utf-8'))
inputs.append(dict(path='user_source/hdl_source/frame_shape_search.v'))
inputs.append(dict(path='user_source/hdl_source/frame_process_bridge.v'))
for e in inputs:
 out=dst/e['path'];out.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(p/e['path'],out)
 e.update(sha256=sha(out),bytes=out.stat().st_size)
sim=dst/'sim';sim.mkdir()
for f in (p/'sim').iterdir():
 if f.is_file() and f.suffix in {'.v','.ps1','.py','.do','.md'}:shutil.copy2(f,sim/f.name)
shutil.copytree(p/'sim/osd_assets',sim/'osd_assets')
for stage in ['syn_1','phy_1']:
 base=Path('td_project/camera_to_dsi_display_Runs')/stage;out=dst/base;out.mkdir(parents=True)
 for name in ['build.tcl','settings.cfg','camera_to_dsi_display.prj']:
  shutil.copy2(prior/base/name,out/name)
  if name=='build.tcl' and stage=='phy_1':
   script=(out/name).read_text(encoding='utf-8').replace('check_timing -file','analyze_clock -detail\ncheck_timing -file');(out/name).write_text(script,encoding='utf-8')
  if name.endswith('.prj'):
   t=(out/name).read_text(encoding='utf-8');line=next(l for l in t.splitlines() if 'roi_shape_search.v' in l);t=t.replace(line,line.replace('roi_shape_search','frame_process_bridge').replace('Val="122"','Val="124"')+'\n'+line.replace('roi_shape_search','frame_shape_search').replace('Val="122"','Val="123"')+'\n'+line);(out/name).write_text(t,encoding='utf-8')
(dst/'inputs.json').write_text(json.dumps(inputs,indent=2),encoding='utf-8')
(dst/'simulation_inputs.json').write_text(json.dumps([dict(path=f.relative_to(dst).as_posix(),sha256=sha(f)) for f in sim.rglob('*') if f.is_file()],indent=2),encoding='utf-8')
print('Frozen',len(inputs),dst)
