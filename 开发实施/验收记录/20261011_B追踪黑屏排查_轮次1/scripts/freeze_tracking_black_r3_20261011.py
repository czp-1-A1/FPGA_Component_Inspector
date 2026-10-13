from pathlib import Path
import json, shutil, hashlib
root=Path(__file__).resolve().parent.parent; project=root/'fpga/component_inspector'
prior=root/'tmp/tracking_black_fix_r2_td_20261011'; build=root/'tmp/tracking_black_fix_r3_td_20261011'
assert not build.exists();sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
inputs=json.loads((prior/'inputs.json').read_text(encoding='utf-8'))
for e in inputs:
 src=project/e['path'];dst=build/e['path'];dst.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(src,dst)
 e.update(sha256=sha(dst),bytes=dst.stat().st_size)
for stage in ['syn_1','phy_1']:
 rel=Path('td_project/camera_to_dsi_display_Runs')/stage;dst=build/rel;dst.mkdir(parents=True)
 for name in ['settings.cfg','build.tcl','camera_to_dsi_display.prj']:shutil.copy2(prior/rel/name,dst/name)
sim=build/'sim';sim.mkdir()
for p in (project/'sim').iterdir():
 if p.is_file() and p.suffix in {'.v','.py','.ps1','.md','.do'}:shutil.copy2(p,sim/p.name)
shutil.copytree(project/'sim/osd_assets',sim/'osd_assets')
for name,data in [('inputs.json',inputs),('simulation_inputs.json',[dict(path=p.relative_to(build).as_posix(),sha256=sha(p)) for p in sim.rglob('*') if p.is_file()]),('stage_inputs.json',[dict(path=p.relative_to(build).as_posix(),sha256=sha(p)) for stage in ['syn_1','phy_1'] for p in (build/'td_project/camera_to_dsi_display_Runs'/stage).iterdir() if p.is_file()])]:
 (build/name).write_text(json.dumps(data,indent=2)+'\n',encoding='utf-8')
p=root/'AGENTS.md'; s=p.read_text(encoding='utf-8').replace('tracking_black_fix_r2_td_20261011','tracking_black_fix_r2_td_20261011')
s=s.replace('在冻结tmp/','R1修复真实完整帧已发布，599帧检查中测试夹具把旧published状态误当新帧（RTL未变），加writer_epoch归属并补残帧后恢复。保持失败记录。 在冻结tmp/')
p.write_text(s,encoding='utf-8');print(build)
