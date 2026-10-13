from pathlib import Path
import hashlib,json,shutil,sys
root=Path(__file__).resolve().parent.parent
project=root/'fpga/component_inspector'
prior=root/'tmp/multi_pocket_r5_td_20261012'
build=root/'tmp'/sys.argv[1]
assert not build.exists()
read=lambda p:p.read_text(encoding='utf-8-sig')
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
def dump(path,data):path.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
inputs=json.loads(read(prior/'inputs.json'));changed=[]
for e in inputs:
 src=project/e['path'];dst=build/e['path'];dst.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(src,dst)
 if e['sha256']!=sha(dst):changed.append(e['path'])
 e.update(sha256=sha(dst),bytes=dst.stat().st_size)
sim=build/'sim';sim.mkdir()
for p in (project/'sim').iterdir():
 if p.is_file() and p.suffix in {'.v','.py','.ps1','.md','.do'}:shutil.copy2(p,sim/p.name)
shutil.copytree(project/'sim/osd_assets',sim/'osd_assets')
for stage in ['syn_1','phy_1']:
 rel=Path('td_project/camera_to_dsi_display_Runs')/stage;dst=build/rel;dst.mkdir(parents=True)
 for name in ['settings.cfg','build.tcl','camera_to_dsi_display.prj']:shutil.copy2(prior/rel/name,dst/name)
dump(build/'inputs.json',inputs);dump(build/'changed_inputs.json',changed)
dump(build/'simulation_inputs.json',[dict(path=p.relative_to(build).as_posix(),sha256=sha(p)) for p in sim.rglob('*') if p.is_file()])
dump(build/'stage_inputs.json',[dict(path=p.relative_to(build).as_posix(),sha256=sha(p)) for stage in ['syn_1','phy_1'] for p in (build/'td_project/camera_to_dsi_display_Runs'/stage).iterdir() if p.is_file()])
builder=read(root/'tmp/run_multi_pocket_r5_td_20261012.ps1').replace('multi_pocket_r5_td_20261012',build.name)
(root/'tmp'/('run_'+build.name+'.ps1')).write_text(builder,encoding='utf-8-sig')
print('Frozen',len(inputs),'production inputs; changed:',changed,'at',build)
