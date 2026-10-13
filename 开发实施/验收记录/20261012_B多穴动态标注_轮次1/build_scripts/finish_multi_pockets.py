from pathlib import Path
from collections import Counter
import json,hashlib,re,shutil,subprocess
r=Path(__file__).resolve().parent.parent;p=r/'fpga/component_inspector'
final=r/'tmp/multi_pocket_r5_td_20261012';record=r/'开发实施/验收记录/20261012_B多穴动态标注_轮次1'
release=p/'release/multi_pocket_experiment_v1_20261012'
read=lambda p:p.read_text(encoding='utf-8-sig',errors='replace')
load=lambda p:json.loads(read(p));sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
def dump(p,d):p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
audit=load(final/'build_audit.json')
inputs=load(final/'inputs.json');assert len(inputs)==211
for e in inputs:assert sha(final/e['path'])==e['sha256']==sha(p/e['path'])
for f in ['stage_inputs.json','simulation_inputs.json']:
 for e in load(final/f):assert sha(final/e['path'])==e['sha256']
assert audit['max_delays_matched']==37 and audit['max_delays_ignored']==0
assert not audit['warning_deltas']['phy_1']['added']
assert audit['warning_deltas']['syn_1']['added']==['HDL-5001 WARNING: Contains anonymous inst(s) and/or net(s) that have not been renamed']
tests={
 'multi_pockets':'multi_pocket_r4_td_20261012',
 'isp_multi':'multi_pocket_r1_td_20261012',
 'multi_metadata':'multi_pocket_r1_td_20261012',
 'multi_writer':'multi_pocket_r3_td_20261012',
 'multi_osd':'multi_pocket_r5_td_20261012',
 'tracking_osd':'multi_pocket_r5_td_20261012'}
regression=['tracking_late','tracking_status','tracking_age','tracking','dynamic_sobel','frame_metadata','wb_controls','manual_wb','wb_epoch','presence_modes','sobel_tail','sobel_view','roi_chain','isp_metadata_stop','isp_writer_stop']
tests.update({n:'multi_pocket_r2_td_20261012' for n in regression})
accepted=[]
for name,b in tests.items():
 root=r/'tmp'/b;d=root/'sim/modelsim_work'/name
 log=read(d/'console.log');comp=read(d/'compile.log')
 assert 'PASS ' in log and not re.search(r'(?m)^#?\s*\*\* (Fatal|Error):',log+comp),name
 # Bench files are identical to the final frozen suite. Each accepted feature
 # input is identical; older OSD tests are superseded by both fresh OSD runs.
 assert sha(root/'sim'/('tb_'+name+'.v'))==sha(final/'sim'/('tb_'+name+'.v')),name
 old={e['path']:e['sha256'] for e in load(root/'inputs.json')}
 differences=[e['path'] for e in inputs if old[e['path']]!=e['sha256']]
 assert not differences or differences==['user_source/hdl_source/experiment_osd.v'],(name,differences)
 accepted.append(dict(test=name,root=root.relative_to(r).as_posix(),passes=[l.strip('# ') for l in log.splitlines() if 'PASS ' in l],production_differences=differences))
assert 'PASS ModelSim: all 17 tests' in read(r/'tmp/multi_pocket_r2_td_20261012/sim/regression_console.log')
assert 'PASS ModelSim: all 2 tests' in read(final/'sim/display_console.log')
head=subprocess.check_output(['git','rev-parse','HEAD'],cwd=r,text=True).strip()
assert head=='3be3967f2457622566fb20b7cef3aa5038e7d885'
assert not subprocess.check_output(['git','diff','--cached','--name-only'],cwd=r,text=True).strip()
assert not release.exists() and not (record/'manifest.json').exists()
audit.update(status='PASS_source_simulation_and_routed_build',onsite='PENDING',tests=accepted,
 resource_review=dict(slice_used=audit['resources']['slice']['used'],baseline_slice_used=13508,
  slice_increment=audit['resources']['slice']['used']-13508,remaining_slices=21216-audit['resources']['slice']['used'],
  assessment='Within experimentally reviewed70-75% band; above preferred70%, reduced timing headroom. Keep four pockets for this trial; optimize before adding algorithms/NG/recipe controls.'))
dump(final/'audit.json',audit)
release.mkdir();bit=final/'td_project/camera_to_dsi_display_Runs/phy_1/camera_to_dsi_display.bit'
assert sha(bit)==audit['bit']['sha256']
shutil.copy2(bit,release/bit.name);shutil.copy2(final/'inputs.json',release/'build_inputs.json');shutil.copy2(final/'audit.json',release/'audit.json')
(release/'SHA256.txt').write_text(sha(bit)+'  '+bit.name+'\n',encoding='ascii')
resources=audit['resources'];timing=audit['timing']
stats=f"Slice{resources['slice']['used']}/21216={resources['slice']['percent']:.2f}%，ERAM48/108，DSP8/40；Routed慢/快角建立余量+{timing['setup_wns_ns']:.3f}ns、保持+{timing['hold_wns_ns']:.3f}ns、TNS0、STA覆盖{timing['sta_coverage_percent']:.2f}%。"
identity=f"{audit['bit']['bytes']}字节；SHA-256 `{sha(bit)}`。"
guide=r/'开发实施/46_B3528四穴动态标注_实验版上板说明.md'
s=read(guide).replace('镜像与最终构建数据在发布完成后补入。',f"镜像：[camera_to_dsi_display.bit](../{(release/bit.name).relative_to(r).as_posix()})。{identity} {stats}")
s+='\n最终21项独立测试/回归PASS，含四穴358断言、627072像素标签比对、完整AUTO4真实ISP/写入/短帧拒绝、四视图及原停钟检查。211生产输入逐项散列一致；37条max_delay全部匹配、ignored0，SDC原样保留。综合/物理告警为'+str(audit['warnings']['syn_1'])+'/'+str(audit['warnings']['phy_1'])+'；物理告警与基线相同，新增一项TD匿名实例/网络命名提示经审查不改变接口或约束。未上板验收。\n'
guide.write_text(s,encoding='utf-8')
(release/'README.md').write_text(f'''# AUTO4 3528 多穴动态标注实验 v1

{identity}

{stats} 同时最多4个独立穴位框/中文结果，共享1条Sobel，无新增ERAM/DSP。高于优先70%面积目标，尚余约25%物理Slice；本次仅作为四穴实验，继续扩功能前先优化。

顶部AUTO4 EXP V1；默认曝光2244、增益48、R100/B100。孔列内部搜索X[128,896)、Y340～443，孔距96±24，孔→穴中心(+48,-80)，框80×80；几何和分类门限仍待实物配对确认。见开发实施/46说明。

21项独立仿真/回归、慢快角布局布线和37条max_delay检查通过。源码及bit散列绑定，现场未验收。未执行JTAG/Flash、提交或推送。
''',encoding='utf-8')
with record.with_suffix('.md').open('a',encoding='utf-8') as f:
 f.write(f'''\n最终发布：`{(release/bit.name).relative_to(r).as_posix()}`，{identity} {stats}

相对基线+{resources['slice']['used']-13508}个Slice，处于冻结要求的70～75%审查区；共享Sobel/无额外ERAM和DSP，全部约束时序通过，允许当前四穴实验，正式扩功能前优化。没有放宽门控或时钟约束。

测试关联21项见audit。r1矩形孔纵向16px失锁断言失败，圆孔输入保留原预期后通过；r3边界进出fixture最左孔缺少搜索内暗边，误假设有3个完整孔，失败保留。r4将同一3穴预期的fixture移至带内，并先重新获取，358断言PASS；目标未降级。测试台变更和生产变更分开冻结。

r1构建的AUTO4文字覆盖原发布诊断，综合删掉旧显示payload，导致原37个声明约束中的1个无对象。r1有36条有效约束/12条新增无对象提示，镜像未发布。恢复原D3发布诊断，把AUTO4移到旁边后r5重新构建，37条均匹配、ignored0，无新增物理告警。物理告警仍为基线10条；综合新增TD匿名实例/网络命名提示，不涉及漏接端口或未约束跨域。r1位流和全部失败证据保留在tmp。

21项仿真/回归均PASS；旧r2回归中的OSD由r5两项重跑覆盖，其余相关RTL与最终冻结逐字节相同。真实AUTO4完整600行115200打包词、518位元数据/实际writer/短帧撤销PASS。没有宣称现场正确率或永久身份。现场待核对孔→穴偏移/框尺寸、跟随及有件/空穴真值。
''')
def copy(src,rel):
 dst=record/rel;assert not dst.exists(),rel;dst.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(src,dst)
for e in inputs:copy(final/e['path'],Path('source_snapshot')/e['path'])
for fn in ['inputs.json','simulation_inputs.json','stage_inputs.json','build_audit.json','audit.json']:copy(final/fn,fn)
for stage in ['syn_1','phy_1']:
 for q in (final/'td_project/camera_to_dsi_display_Runs'/stage).iterdir():
  if q.is_file() and q.suffix.lower() in {'.log','.logw','.rpt','.txt','.status','.qor','.area','.tcl','.prj','.cfg','.timing','.bit','.f'}:copy(q,Path('td_reports')/stage/q.name)
for e in load(final/'simulation_inputs.json'):copy(final/e['path'],Path('simulation/source')/Path(e['path']).relative_to('sim'))
for name,b in tests.items():
 for fn in ['console.log','compile.log','transcript.log']:copy(r/'tmp'/b/'sim/modelsim_work'/name/fn,Path('simulation/results')/name/fn)
for b,names in [('multi_pocket_r1_td_20261012',['multi_pockets']),('multi_pocket_r3_td_20261012',['multi_pockets'])]:
 for name in names:
  for fn in ['console.log','compile.log']:copy(r/'tmp'/b/'sim/modelsim_work'/name/fn,Path('failed_tests')/b/name/fn)
  copy(r/'tmp'/b/'sim'/('tb_'+name+'.v'),Path('failed_tests')/b/('tb_'+name+'.v'))
copy(r/'tmp/multi_pocket_r1_td_20261012/build_audit.json','failed_tests/r1_build_audit.json')
for name in ['integrate_multi_pockets.py','prepare_multi_tests.py','extend_multi_tests.py','freeze_multi_pockets.py','audit_multi_build.py','audit_multi_final.py','finish_multi_pockets.py','run_multi_pocket_r5_td_20261012.ps1']:
 copy(r/'tmp'/name,Path('build_scripts')/name)
copy(guide,Path('documents')/guide.name)
metadata=dict(purpose='3528_AUTO4_multi_pocket_experiment_v1',td_version='6.2.168116',base_head=head,source_commit=None,
 source_snapshot=(record.relative_to(r)/'source_snapshot').as_posix(),build_root=final.relative_to(r).as_posix(),
 release=dict(path=(release/bit.name).relative_to(r).as_posix(),**audit['bit']),validation_record=record.with_suffix('.md').relative_to(r).as_posix(),
 fresh_tests=list(tests),onsite='PENDING')
dump(p/'td_project/current_codex_build.json',metadata);copy(p/'td_project/current_codex_build.json','current_build_after.json')
manifest=[dict(path=q.relative_to(record).as_posix(),bytes=q.stat().st_size,sha256=sha(q)) for q in record.rglob('*') if q.is_file()]
dump(record/'manifest.json',manifest)
for e in manifest:assert sha(record/e['path'])==e['sha256']
assert sha(release/bit.name)==sha(bit)
# Replace the resumable checkpoint only; historical findings live in the records.
a=r/'AGENTS.md';s=read(a);index=s.index('## 当前断点')
s=s[:index]+f'''## 当前断点（2026-10-12，AUTO4四穴动态标注实验v1已完成源码/仿真/构建，待现场）

- **目标/断点**：用户授权“先实验一下，开始写代码”，已实现3528宽带自动孔列获取、最多4个独立80×80框/中文有件空穴待检测、共享灰度/Sobel及帧槽绑定；无需X464单孔人工对准。上板说明开发实施/46_B3528四穴动态标注_实验版上板说明.md；独立记录开发实施/验收记录/20261012_B多穴动态标注_轮次1.md。
- **分支/基线**：lj4747-contest-work，HEAD{head}，暂存空；保留原WIP。基于hole_transition_fix_v1，211生产输入冻结tmp/multi_pocket_r5_td_20261012，6项变化、205项原样；SDC/视频writer/reader/相机/WB及旧孔修复未改。
- **改动**：新增multi_pocket_detector.v，改isp_top/roi_sobel_view被动梯度tap/design_top_wrapper518位元数据/experiment_osd标签及.al源登记；新增4穴/真实ISP/实际writer/元数据/OSD测试并登记runner。原单穴分支保留，AUTO4中旧统计综合优化掉。曝光2244/增益48/R100B100、MEAN58与原EC/GS试用门限保留。
- **验证/证据**：21项独立仿真/回归PASS，四穴358断言、标签627072像素比对、RAW10原厂ERAM/full600行115200词、实际518位writer/短帧撤销、四视图/停钟/旧epoch等。冻结源码散列、manifest、对应测试RTL一致；r5显示两项新跑覆盖旧OSD。{stats} 37max_delay均匹配/ignored0，SDC原样；综合{audit['warnings']['syn_1']}、物理{audit['warnings']['phy_1']}告警，物理与基线相同，综合新增TD匿名实例/网络命名提示已审查。
- **镜像**：{(release/bit.name).relative_to(r).as_posix()}；{audit['bit']['bytes']}字节；SHA {sha(bit)}。顶部AUTO4 EXP V1及原D3发布诊断。现场未验收，不能称分类/运动实物通过。
- **未决/限制**：几何孔距96±24、孔→穴(+48,-80)、80×80和阈值未现场配对；固定机位倍率/方向、孔排Y340～443、慢移X复核≤4/Y≤8、一帧滞后，无永久ID/NG/置信度。面积高于优先70%但在已审查75%内，后续扩功能先优化。r1矩形孔/纵向测试失败、r3搜索边界暗边不足fixture失败和r1诊断payload无对象构建保留；圆孔/带内3穴原目标及恢复诊断后复测通过。旧TAIL0黑屏根因仍未定，记录保留。
- **下一条操作**：由用户下载本镜像，确认AUTO4标记，先停稳核对多个框落正确穴位，再慢左/慢右、遮孔恢复、进出边界、全空穴/混排真值；若框偏位先实测孔到穴偏移/倍率，若NO HOLE采实际亮暗/宽距/暗边，不取消门控或继续猜阈值。
- **进程/设备/提交**：主线程唯一写入；所有本轮ModelSim/TD已完成，无代理/JTAG/Flash操作；未提交未推送。原镜像和失败证据均保留。
'''
a.write_text(s,encoding='utf-8')
print(json.dumps(dict(release=str(release/bit.name),tests=len(tests),resources=resources,timing=timing,bit=audit['bit'],manifest_files=len(manifest)),ensure_ascii=False,indent=2))
