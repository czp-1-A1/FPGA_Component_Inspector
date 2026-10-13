from pathlib import Path
import hashlib, json, shutil

root=Path(__file__).resolve().parent.parent
project=root/'fpga/component_inspector'
prior=root/'tmp/wb100_d3_r1_td_20261012'
build=root/'tmp/hole_transition_r1_td_20261012'
record=root/'开发实施/验收记录/20261012_B定位孔灰度过渡修复_轮次1'
unit=root/'tmp/hole_transition_unit_r1_20261012'
assert not build.exists()
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
dump=lambda p,data:p.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
load=lambda p:json.loads(p.read_text(encoding='utf-8-sig'))
inputs=load(prior/'inputs.json')
changed=[]
for e in inputs:
    src=project/e['path']
    dst=build/e['path']
    if sha(src)!=e['sha256']:changed.append(e['path'])
    dst.parent.mkdir(parents=True,exist_ok=True)
    shutil.copy2(src,dst)
    e.update(sha256=sha(dst),bytes=dst.stat().st_size)
assert changed==['user_source/hdl_source/tape_hole_tracker.v'],changed
for stage in ['syn_1','phy_1']:
    rel=Path('td_project/camera_to_dsi_display_Runs')/stage
    dst=build/rel
    dst.mkdir(parents=True)
    for name in ['settings.cfg','build.tcl','camera_to_dsi_display.prj']:
        shutil.copy2(prior/rel/name,dst/name)
sim=build/'sim'
sim.mkdir()
for p in (project/'sim').iterdir():
    if p.is_file() and p.suffix in {'.v','.py','.ps1','.md','.do'}:shutil.copy2(p,sim/p.name)
shutil.copytree(project/'sim/osd_assets',sim/'osd_assets')
shutil.copytree(unit,build/'hole_unit')
dump(build/'inputs.json',inputs)
dump(build/'simulation_inputs.json',[dict(path=p.relative_to(build).as_posix(),sha256=sha(p)) for p in sim.rglob('*') if p.is_file()])
dump(build/'stage_inputs.json',[dict(path=p.relative_to(build).as_posix(),sha256=sha(p)) for stage in ['syn_1','phy_1'] for p in (build/'td_project/camera_to_dsi_display_Runs'/stage).iterdir() if p.is_file()])
dump(build/'unit_inputs.json',[dict(path='hole_unit/'+p.name,sha256=sha(p)) for p in (build/'hole_unit').iterdir() if p.is_file()])
text=(root/'tmp/run_wb100_build_20261012.ps1').read_bytes()
(root/'tmp/run_hole_transition_build_20261012.ps1').write_bytes(text.replace(b'wb100_d3_r1_td_20261012',b'hole_transition_r1_td_20261012'))
assert sha(build/'user_source/hdl_source/tape_hole_tracker.v')==sha(build/'hole_unit/tape_hole_tracker.v')
old=(record/'before/user_source/hdl_source/tape_hole_tracker.v').read_bytes()
new=(build/'user_source/hdl_source/tape_hole_tracker.v').read_bytes()
assert old.split(b'endmodule',1)[1]==new.split(b'endmodule',1)[1]
p=root/'AGENTS.md'
s=p.read_text(encoding='utf-8')
s=s.replace('准备只改tape_hole_tracker.v的hole_scanline，其他子模块不改。','只改tape_hole_tracker.v的hole_scanline，后续子模块逐字节相同。')
s=s.replace('原FAILED soft requirement原样保留并复制；先冻结新增测试与候选源码验证，再冻结全210输入进行真实ISP回归及TD时序构建。','原FAILED soft requirement原样复制，本次PASS；新增133项过渡/误锁拒绝要求PASS。已冻结tmp/hole_transition_r1_td_20261012全210生产输入，相对WB100只有tracker一个文件变化；真实ISP回归及TD时序构建即将启动。')
s=s.replace('尚无新运行进程','即将启动冻结源码ModelSim/TD')
p.write_text(s,encoding='utf-8')
with record.with_suffix('.md').open('a',encoding='utf-8') as f:
    f.write('\n单元验证：133项新增要求及原模糊孔两帧获取锁定要求PASS。首次准备脚本因换行判断中止、首个run缺少RTL导致编译失败，原日志保留；未发生算法仿真失败或调整测试预期。源码冻结210输入，仅tracker变化，后续模块逐字节未改。\n')
print(f'Frozen {len(inputs)} production inputs; changed: {changed}')
