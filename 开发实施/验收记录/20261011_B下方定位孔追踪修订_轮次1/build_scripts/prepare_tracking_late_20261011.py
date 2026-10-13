from pathlib import Path
import hashlib, json, shutil, sys, re
root=Path(__file__).resolve().parent.parent
project=root/'fpga/component_inspector'
prior=root/'tmp/dynamic_tracking_v1_r5_td_20261010'
build=root/('tmp/tracking_late_'+(sys.argv[1] if len(sys.argv)>1 else 'r1')+'_td_20261011')
assert not build.exists()
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
inputs=json.loads((prior/'inputs.json').read_text(encoding='utf-8-sig'))
for e in inputs:
 src=project/e['path'];dst=build/e['path'];dst.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(src,dst)
 e.update(sha256=sha(dst),bytes=dst.stat().st_size)
for stage in ['syn_1','phy_1']:
 rel=Path('td_project/camera_to_dsi_display_Runs')/stage;dst=build/rel;dst.mkdir(parents=True)
 for name in ['settings.cfg','build.tcl','camera_to_dsi_display.prj']:
  shutil.copy2(prior/rel/name,dst/name)
 for src in re.findall(r'<File Path="([^"]+)"',(dst/'camera_to_dsi_display.prj').read_text(encoding='utf-8-sig')):
  assert (dst/src).is_file(),src
sim=build/'sim';sim.mkdir()
for p in (project/'sim').iterdir():
 if p.is_file() and p.suffix in {'.v','.py','.ps1','.md','.do'}:shutil.copy2(p,sim/p.name)
shutil.copytree(project/'sim/osd_assets',sim/'osd_assets')
for name,data in [('inputs.json',inputs),('simulation_inputs.json',[dict(path=p.relative_to(build).as_posix(),sha256=sha(p)) for p in sim.rglob('*') if p.is_file()]),('stage_inputs.json',[dict(path=p.relative_to(build).as_posix(),sha256=sha(p)) for stage in ['syn_1','phy_1'] for p in (build/'td_project/camera_to_dsi_display_Runs'/stage).iterdir() if p.is_file()])]:
 (build/name).write_text(json.dumps(data,indent=2)+'\n',encoding='utf-8')
print(str(build))
