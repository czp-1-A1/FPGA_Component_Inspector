from pathlib import Path
import hashlib,json,re,shutil,subprocess
root=Path(__file__).resolve().parent.parent;project=root/'fpga/component_inspector'
build=root/'tmp/direct_detection_v4_r3_20261013';tests_root=root/'tmp/direct_detection_v4_r2_20261013'
archive=root/'开发实施/验收记录/20261013_A灰度边缘独立检测恢复_V4轮次1'
release=project/'release/direct_detection_v4_20261013'
read=lambda p:p.read_text(encoding='utf-8-sig',errors='replace')
load=lambda p:json.loads(read(p));sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
def dump(path,data):path.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
inputs=load(build/'inputs.json');audit=load(build/'build_audit.json')
assert not release.exists() and not archive.exists()
assert len(inputs)==211 and audit['status']=='PASS_routed_build_tests_pending'
old_tests={e['path']:e['sha256'] for e in load(tests_root/'inputs.json')}
for e in inputs:
 assert sha(build/e['path'])==e['sha256']==sha(project/e['path'])
 if not e['path'].endswith('.sdc'):assert old_tests[e['path']]==e['sha256'],e['path']
for snapshot in [build,tests_root]:
 for name in ['inputs.json','simulation_inputs.json','stage_inputs.json']:
  for e in load(snapshot/name):assert sha(snapshot/e['path'])==e['sha256']
tests=['direct_modes','direct_isp','direct_video','direct_osd','presence_modes','display_state','wb_epoch','writer_epoch','video_fallback_display']
accepted=[]
for name in tests:
 logs=tests_root/'sim/modelsim_work'/name;console=read(logs/'console.log');compile_log=read(logs/'compile.log')
 assert 'PASS ' in console and not re.search(r'(?m)^#?\s*\*\* (Fatal|Error):',console+compile_log),name
 assert sha(tests_root/'sim'/('tb_'+name+'.v'))==sha(build/'sim'/('tb_'+name+'.v'))
 accepted.append(dict(test=name,root=tests_root.relative_to(root).as_posix(),passes=[line.strip('# ') for line in console.splitlines() if 'PASS ' in line]))
assert 'PASS ModelSim: all 9 tests' in read(tests_root/'direct_suite.log')
assert not audit['warning_deltas']['syn_1']['added'] and not audit['warning_deltas']['phy_1']['added'],audit['warning_deltas']
assert audit['max_delays_matched']==31 and audit['max_delays_ignored']==0
head=subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip()
assert not subprocess.check_output(['git','diff','--cached','--name-only'],cwd=root,text=True).strip()
audit.update(status='PASS_source_simulation_and_routed_build',onsite='PENDING',tests=accepted,source_head_at_freeze=head,source_commit=None,
 caveats=['Fixed 80x80 manually aligned real pocket, recent sample not DDR frame-bound object detection',
 'Original provisional MEAN58 and EC96/48 GS32768/16384 require paired physical samples',
 'GRAY+EDGE has independent labels, primary brightness classification, no feature fusion',
 'Restore V3 six metadata mailbox constraints before enabling tracking again'])
dump(build/'audit.json',audit)
bit=build/'td_project/camera_to_dsi_display_Runs/phy_1/camera_to_dsi_display.bit';assert sha(bit)==audit['bit']['sha256']
release.mkdir();shutil.copy2(bit,release/bit.name);shutil.copy2(build/'inputs.json',release/'build_inputs.json');shutil.copy2(build/'audit.json',release/'audit.json')
(release/'SHA256.txt').write_text(sha(bit)+'  '+bit.name+'\n',encoding='ascii')
resources=audit['resources'];timing=audit['timing']
summary=f"Slice{resources['slice']['used']}/{resources['slice']['total']}={resources['slice']['percent']}%，ERAM{resources['eram']['used']}/108、DSP8/40；Routed慢快角建立+{timing['setup_wns_ns']:.3f}ns、保持+{timing['hold_wns_ns']:.3f}ns、TNS0，STA{timing['sta_coverage_percent']}%。"
(release/'README.md').write_text(f'''# 固定框灰度／边缘独立检测 V4

顶部FIXED EXP V4 / D5；默认EXP2244、GAIN48、R100/B100。把真实器件穴位对准80×80青框，不再等待定位孔搜索。

RAW/GRAY：MEAN≥58有件，<58空穴。EDGE：EC≥96且GS≥32768有件；EC≤48且GS≤16384空穴；中间待检测。EC按Sobel G≥80计数，GS累计全部核心梯度。GRAY+EDGE主结果用灰度，框上GRAY/EDGE独立显示，不做融合。

9项冻结测试PASS，含真实RAW10/vendor RAM/Sobel独立参考、14个输入帧、两类冲突、完整600行614400像素读出、坏帧拒绝、672000个OSD检查像素、参数/WB/模式撤销恢复及8种近FS相位。{summary}
29条显式max_delay及2条vendor FIFO约束匹配，ignored0；只移除静态版实际不存在的两个metadata邮箱六条命名约束，其他预算不变。综合/物理告警没有新增。

镜像{audit['bit']['bytes']}字节，SHA-256 `{sha(bit)}`。
源码及日志：开发实施/验收记录/20261013_A灰度边缘独立检测恢复_V4轮次1/；上板说明：开发实施/49_A灰度边缘独立检测_V4上板说明.md。
这是固定框最近采样实验，人工对准与现场有件/真正空穴真值仍需验证；不声称动态追踪、自动全图识别或已测准确率。未执行Git提交/推送或板上操作。
''',encoding='utf-8')
guide=root/'开发实施/49_A灰度边缘独立检测_V4上板说明.md'
guide_text=read(guide).replace('候选镜像：','发布镜像：').replace('发布后以该目录的','以该目录的')
guide_text+=f"\n## 软件发布验证\n\n9项冻结测试与本机完整TD构建通过。{summary} 29条显式与2条vendor FIFO max_delay全部匹配、ignored0；综合/物理告警无增量。\n\n镜像{audit['bit']['bytes']}字节；SHA-256 `{sha(bit)}`。现场尚未验收，不据软件结果填写识别准确率。\n"
guide.write_text(guide_text,encoding='utf-8')
record=archive.with_suffix('.md');record_text=read(record)
record_text=record_text.replace('相对V3生产输入只改 `design_top_wrapper.v`、`isp/isp_top.v`、`roi_mode_classifier.v`、`experiment_osd.v`。','相对V3生产输入改 `design_top_wrapper.v`、`isp/isp_top.v`、`roi_mode_classifier.v`、`experiment_osd.v` 与当前静态版SDC。')
record_text=record_text.replace('当前ModelSim r2和TD r1在运行，尚未发布新镜像。','随后TD r1虽然时序为正，但六条跟踪metadata约束空匹配并产生critical warning，未发布。只移除实际编译掉的两个邮箱约束，在r3重新冻结/构建；29条其他显式约束及2条vendor FIFO约束全部匹配。r2与r3所有210项非SDC生产输入及测试台一致，仿真依据r2，正式镜像依据r3。')
record_text=record_text.replace('## 待完成验证','## 最终验证（9项全部PASS）')
record_text=record_text.replace('- 本机完整综合布局布线、资源、慢快角建立保持、约束匹配审计；通过后冻结镜像散列与源码。','- 本机完整综合布局布线、资源、慢快角建立保持与约束匹配审计通过，正式镜像散列与源码已冻结。')
record_text+=f"\n## 最终发布\n\n{summary}\n\n最终source/audit/bit冻结：{build.relative_to(root).as_posix()}；仿真：{tests_root.relative_to(root).as_posix()}。软件PASS，现场PENDING。\n\n发布路径 `{(release/bit.name).relative_to(root).as_posix()}`；{audit['bit']['bytes']}字节；SHA-256 `{sha(bit)}`。\n\n生产输入211项，其中5项相对V3变化，206项未变。原视频writer/reader、传输完整性、像素时序和相机默认参数未改。源码没有新增RAM/DSP；OSD仍同步ROM，最终ERAM48/DSP8。静态配置的活动预算没有放宽；恢复跟踪必须恢复V3的六条命名约束后完整STA。\n\n独立失败保留：V3轻微倾斜反例、r1新OSD测试台语法失败、r1六条无对象约束告警及报告。未把这些轮次算作最终通过。所有本轮测试/TD已结束；无Git提交推送、无代理写入、无JTAG/Flash。\n"
record.write_text(record_text,encoding='utf-8')
archive.mkdir()
def copy(src,rel):
 dst=archive/rel;assert not dst.exists(),rel;dst.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(src,dst)
for e in inputs:copy(build/e['path'],Path('source_snapshot')/e['path'])
for name in ['inputs.json','build_audit.json','audit.json','simulation_inputs.json','stage_inputs.json']:copy(build/name,name)
for e in load(build/'simulation_inputs.json'):copy(build/e['path'],Path('simulation/source')/Path(e['path']).relative_to('sim'))
copy(tests_root/'direct_suite.log','simulation/direct_suite.log')
for name in tests:
 for fn in ['console.log','compile.log','transcript.log']:copy(tests_root/'sim/modelsim_work'/name/fn,Path('simulation/results')/name/fn)
for stage in ['syn_1','phy_1']:
 for f in (build/'td_project/camera_to_dsi_display_Runs'/stage).iterdir():
  if f.is_file() and f.suffix.lower() in {'.log','.logw','.rpt','.txt','.status','.qor','.area','.tcl','.prj','.cfg','.timing','.bit','.f'}:copy(f,Path('td_reports')/stage/f.name)
r1=root/'tmp/direct_detection_v4_r1_20261013'
for name in ['input_manifest.json','console.log','compile.log','transcript.log','multi_pocket_detector.v','tb_hole_sensitivity.v']:
 copy(root/'tmp/no_hole_characterization_r1_20261013'/name,Path('prior_v3_sensitivity')/name)
for name in ['direct_unit_suite.log','inputs.json']:copy(r1/name,Path('failed_r1')/name)
copy(r1/'sim/tb_direct_osd.v','failed_r1/tb_direct_osd.v')
copy(r1/'sim/modelsim_work/direct_osd/compile.log','failed_r1/direct_osd_compile.log')
copy(r1/'td_project/camera_to_dsi_display.sdc','failed_r1/metadata_constraints.sdc')
for name in ['build_console.log','camera_to_dsi_display_exception.timing','camera_to_dsi_display_pr.timing','camera_to_dsi_display_phy.area']:
 copy(r1/'td_project/camera_to_dsi_display_Runs/phy_1'/name,Path('failed_r1/td_reports')/name)
for fn in ['freeze_multi_video_fix.py','prepare_direct_v4_tests_20261013.py','audit_direct_v4_20261013.py','finish_direct_v4_20261013.py','run_direct_detection_v4_r3_20261013.ps1']:copy(root/'tmp'/fn,Path('build_scripts')/fn)
copy(guide,Path('documents')/guide.name);copy(record,Path('documents')/record.name)
metadata=dict(purpose='3528_FIXED_DIRECT_GRAY_EDGE_INDEPENDENT_V4',td_version='6.2.168116',base_head=head,source_commit=None,
 source_snapshot=(archive.relative_to(root)/'source_snapshot').as_posix(),build_root=build.relative_to(root).as_posix(),
 release=dict(path=(release/bit.name).relative_to(root).as_posix(),**audit['bit']),validation_record=record.relative_to(root).as_posix(),fresh_tests=tests,onsite='PENDING')
dump(project/'td_project/current_codex_build.json',metadata);copy(project/'td_project/current_codex_build.json','current_build_after.json')
manifest=[dict(path=f.relative_to(archive).as_posix(),bytes=f.stat().st_size,sha256=sha(f)) for f in archive.rglob('*') if f.is_file()]
dump(archive/'manifest.json',manifest)
for e in manifest:assert sha(archive/e['path'])==e['sha256']
assert sha(release/bit.name)==sha(bit)
agents=root/'AGENTS.md';text=read(agents).split('## 当前断点')[0]
text+=f'''## 当前断点（2026-10-13，V4固定框灰度／边缘独立检测已发布，待现场）

- **目标/断点**：用户明确直接生成代码、先用旧阈值、融合后续规划。V4恢复固定80×80核心，孔搜索/暗参考条不再阻塞分类；RAW/GRAY用均值，EDGE用EC/GS，GRAY+EDGE主结果灰度、框上两种标签独立。不是动态追踪或全图自动识别。
- **分支/代码基线**：lj4747-contest-work，HEAD{head}，暂存空；V2历史实现由别的同步任务提交，V3与本轮V4为未提交工作区快照。本线程无Git同步。生产211输入相对V3改design_top_wrapper/isp_top/roi_mode_classifier/experiment_osd/SDC五项，其余206项不变。
- **实现**：top默认TRACKING/MULTI=0，直接核心[472,552)×[260,340)。MEAN≥58有件；EDGE G≥80计EC，EC≥96且GS≥32768有件，EC≤48且GS≤16384空穴，中间等待。GRAY+EDGE不融合；OSD完整GRAY/EDGE中文结果与EDGE OFF，顶部FIXED EXP V4/D5。EXP2244、GAIN48、R100B100、视频writer/reader和帧完整性保护不变。固定“最近采样”非DDR逐帧绑定结果。
- **验证/证据**：r2九项冻结测试PASS：23门限/模式断言、真实RAW10/vendor RAM/Sobel独立像素参考、14输入帧、两类特征冲突、无孔及亮参考条不阻塞、四视图、短帧/模式/WB撤销恢复、614400竞争读出(613200非零)/OFUF0、672000 OSD检查像素、WB epoch/显示新鲜度/8种近FS相位/视频fallback回归。r3全部非SDC生产输入和测试台与r2一致。归档{len(manifest)}文件逐项SHA验证。记录开发实施/验收记录/20261013_A灰度边缘独立检测恢复_V4轮次1.md。
- **资源/时序**：TD6.2.168116 r3 {summary} 静态版实际不存在的两个metadata邮箱六条命名约束移除，其他预算/时钟/I/O不改。29显式+2vendor FIFO max_delay全匹配/ignored0，综合{audit['warnings']['syn_1']}/物理{audit['warnings']['phy_1']}告警无新增。恢复跟踪前必须恢复V3对应六条约束后完整重跑STA。
- **镜像**：{(release/bit.name).relative_to(root).as_posix()}；{audit['bit']['bytes']}字节；SHA {sha(bit)}。上板说明开发实施/49_A灰度边缘独立检测_V4上板说明.md。current_codex_build.json指向V4。V3/V2旧镜像与归档保留。
- **失败/未决**：冻结V3水平控制锁定，圆孔中心每96px仅错开1px等8倾斜场景均NO HOLE，确认同时弦宽峰过严；不是现场照片native回放，先前测试漏了轻微倾斜。V4 r1新OSD台多余end编译失败保留，r2修fixture；r1 TD六空约束告警未发布，r3按实际静态电路修SDC后通过。旧门限未完成实物有件/真正空穴配对，软件通过不代表现场准确率。
- **下一条具体操作**：人工上板核对FIXED EXP V4/D5/R100B100，把实际器件穴位对准青框，GRAY记录有件/真正空穴MEAN，EDGE记录EC/GS，两开关查看两行冲突。固定光源/位置/曝光增益后调整配方；边缘融合与动态定位重新接入先讨论计划。
- **进程/设备/提交**：本轮ModelSim/TD均结束；无代理/JTAG/Flash/烧板；未提交未推送。源码、测试、镜像、告警审计与失败证据已归档。不得覆盖旧轮次或拿V3成功水平仿真冒充现场定位已通过。
'''
agents.write_text(text,encoding='utf-8')
print(json.dumps(dict(release=str(release/bit.name),tests=len(tests),manifest_files=len(manifest),bit=audit['bit'],resources=resources,timing=timing,head=head),ensure_ascii=False,indent=2))
