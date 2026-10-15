from pathlib import Path
import hashlib,json,shutil
r=Path.cwd();p=r/'fpga/component_inspector';build=r/'tmp/video_first_v10_r4_20261015'
sha=lambda f:hashlib.sha256(f.read_bytes()).hexdigest()
load=lambda f:json.loads(f.read_text(encoding='utf-8-sig'))
audit=load(build/'build_audit.json');assert audit['status']=='PASS_SOFTWARE_EXPERIMENT_ONSITE_PENDING'
assert len(audit['tests'])==20 and audit['independent_reference_images']==24
inputs=load(build/'inputs.json')
for item in inputs:assert sha(build/item['path'])==item['sha256']==sha(p/item['path'])
old={'continuous_frame_v9_20261015':'b954f61ae317896169ae6b7607369d7752a7248a4dd4832c5e9db49b25d26268','fullframe_dual_v8_20261014':'2f5bd322d3243443adb5437c7b2ff6aaab4074207aa8e633f780b812477b7852','presence_review_v7_20261014':'a3d1164e41690a93c9113c6620cc081c63954f0191bffe3d445bcab91d0dfc2c'}
for name,digest in old.items():assert sha(p/'release'/name/'camera_to_dsi_display.bit')==digest
name='20261015_A_V10视频优先发布_轮次1';e=r/'开发实施/验收记录'/name
assert not (e/'archive_sha256.json').exists();e.mkdir(exist_ok=True)
release=p/'release/video_first_v10_20261015';release.mkdir(exist_ok=True)
assert not (release/'SHA256.txt').exists()
bit=build/'td_project/camera_to_dsi_display_Runs/phy_1/camera_to_dsi_display.bit'
assert sha(bit)==audit['bit']['sha256'];digest=sha(bit);tm=audit['timing'];res=audit['resources']
guide=r/'开发实施/60_A3528视频优先发布_V10黑屏修复与上板说明.md'
guide.write_text(f'''# 同一3528视频优先发布 V10 实验版

V9现场RAW仍黑，已记FAIL_BLACK。V10针对其中已经复现的一处发布阻塞：完整视频不再等待识别结果。画面先显示；晚到结果只允许补到同一源帧/同一completed slot一次，显示端仍在VS边界一起选择像素槽和结果。没有结果时显示待检测，不能冒充空穴；短帧/坏帧仍拒绝。

同一3528白色LED、同一载带，曝光2244、增益48、R100/B100和原灰度/形状阈值保持。全1024×600处理，最多两个独立目标；绿色/虚线算法区域框保持去掉。SIZE/ASP/FILL/REF仍是模型诊断，不代表已经标定的偏移、旋转、立起、翻面。

## 上板文件

镜像：`fpga/component_inspector/release/video_first_v10_20261015/camera_to_dsi_display.bit`

顶部应为 **DB FRAME EXP V10**。镜像{bit.stat().st_size}字节，SHA-256 `{digest}`。

先确认RAW有实时画面，再检查GRAY、EDGE、GRAY+EDGE、复位及移动载带。两个有件/有件加空穴应各自显示；识别没结果时画面也应存在。P的最高位见到1代表发布过；M字段是无结果时的epoch诊断，不是写入字数，迟到结果补全后可回到W1C200。VF可保留启动拒帧累计值，但不应像V9一样每帧增长；OF/UF不应持续增加。若仍黑，请保留整个画面上的DB版本、P/W或M、LP/WS、FPS/CFG、VF/OF/UF。

AI未操作JTAG/Flash。**本版软件与布局布线通过，实板恢复仍待复测**；不宣称所有物理黑屏原因已闭合。

## 复现与验证

V9原生产输入在小型发布回归复现P5B；更接近照片的真实RAW10/ISP/DDR夹具也复现完整W1C200、good/done正确却整帧不发布：26FPS起点、native LP738有效时钟及行间停钟、连续域LP0CF2，缺结果时22.5ms等待超过约18.6ms空档。该夹具通过WB变更取消识别来制造缺结果，只证明阻塞路径，不推定现场一定发生了WB变更。照片LP0CF0与FPS26支持同一时间预算风险；P自身是累计条件，不能当作同拍完整证明。

V10最终同轮冻结215生产输入、20项ModelSim通过。新7帧实ISP回归保持26FPS和行间停钟，覆盖四模式、大面积亮背景、WB无结果视频、原生帧证明、迟到双元组和竞争DDR读写，显示像素逐个与所选DDR槽比较；单独384精确RGB像素测试验证迟到结果不改变当前栅格、仅下个显示边界可见、活跃slot保护和一次补全。原短帧/坏帧/epoch等协议检查继续通过。24幅实际RTL掩码/RAW经ISP图由独立两遍连通参考核对双对象面积/框/类别/原因/顺序。这些是仿真图，不是现场准确率。

TD6.2.168116双角Routed：Slice{res['slice']['used']}/21216（{res['slice']['percent']}%），ERAM{res['eram']['used']}/108，DSP{res['dsp']['used']}/40；setup+{tm['setup_wns_ns']:.3f}ns、hold+{tm['hold_wns_ns']:.3f}ns、TNS0、STA{tm['sta_coverage_percent']}%。SDC与V9完全相同，40个max_delay匹配且ignored0；两向20个Gray指针物理路径经路由DB逐位核对，8ns预算全部实际主导。厂商DDR/PLL反馈、部分I/O缺延迟等历史告警仍在完整报告中，不声称告警清零。

## 重放与后续

工程入口：`fpga/component_inspector/td_project/camera_to_dsi_display.al`。完整源码/输入SHA/测试/报告及失败历史见 `开发实施/验收记录/{name}/`；复制source_snapshot到ASCII临时目录重放，不在冻结档案里直接构建。Windows长归档路径需 `git -c core.longpaths=true`。

构建基线36ef39f；当时source_commit=null，随后上传回执再绑定实际提交，不能把后续提交冒充构建时提交。profile JSON只记录编译期实验，不是运行时型号加载器。MEAN/MIN/MAX仍是原中心诊断区，不是两个目标各自的均值。
''',encoding='utf-8',newline='\n')
record=r/'开发实施/验收记录'/f'{name}.md'
prior_record=record.read_text(encoding='utf-8').replace('V10实现与验证中','V10软件/构建通过，现场待测')
prior_record=prior_record.replace('20项冻结回归及完整TD进行中','20项冻结回归及完整TD最终结果见下节')
record.write_text(prior_record+f'''

## 最终软件/构建结果

PASS_SOFTWARE_EXPERIMENT_ONSITE_PENDING，最终r4全部20项PASS、独立参考24图PASS。r4扩大7帧四模式，没有降低r2五帧的帧率/行周期/逐像素/元组隔离标准。旧V9完整cadence反例另冻结215旧生产源，P5B/W1C200/good1/bad0/complete1/metadata_ready0整帧无法发布，功能FAIL原样保留；构建错误与功能失败分开。

TD：{json.dumps(dict(timing=tm,resources=res,warnings=audit['warnings'],max_delays_matched=40,ignored=0,gray_paths=20),ensure_ascii=False)}。SDC未改，所有215输入与现工作区/冻结源一致。镜像DB FRAME EXP V10，SHA {digest}。V9/V8/V7旧bit SHA未变。V9现场FAIL，V10现场PENDING，不用软件结果替代现场。

辅助参考脚本初次内联命令行转义SyntaxError未执行，改独立create_reference_v10.py后生成参考器；未修改生产RTL或测试条件。新r1测试失败因错误使用capture_ok含义，原源码/日志及修正说明保留。当前运行器恢复原EOL/BOM，规范化文本与实际测试冻结文件完全一致；首次修复脚本BOM比较失败时未写文件，修正归一化后恢复。冻结r4文件/全部生产源未因此改动，不重复相同功能测试。上传只以随后独立Git回执为准，无JTAG/Flash操作。
''',encoding='utf-8',newline='\n')
for item in inputs:
 target=e/'source_snapshot'/item['path'];target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(build/item['path'],target)
ignore=shutil.ignore_patterns('modelsim_work','*.log','modelsim.ini','*.wlf','transcript','*.pgm')
shutil.copytree(build/'sim',e/'source_snapshot/sim',dirs_exist_ok=True,ignore=ignore)
for filename in ['inputs.json','simulation_inputs.json','build_audit.json','inspect_gray_budget.tcl','gray_budget_binding_console.log','tests_console.log','tests_exit_code.txt']:
 shutil.copy2(build/filename,e/filename)
for test in audit['tests']:
 target=e/'tests'/test['name'];target.mkdir(parents=True,exist_ok=True)
 for filename in ['compile.log','console.log','transcript.log']:shutil.copy2(build/'sim/modelsim_work'/test['name']/filename,target/filename)
reference=e/'independent_reference';reference.mkdir(exist_ok=True)
for file in (build/'sim').glob('*.pgm'):shutil.copy2(file,reference/file.name)
for filename in ['independent_reference_results.json','reference.log']:shutil.copy2(build/filename,reference/filename)
for stage in ['syn_1','phy_1']:
 source=build/'td_project/camera_to_dsi_display_Runs'/stage;target=e/'td_reports'/stage;target.mkdir(parents=True,exist_ok=True)
 for file in source.iterdir():
  if file.is_file() and (file.suffix in ['.timing','.area','.prj','.cfg','.tcl'] or file.name in ['build_console.log','build_exit_code.txt','constraint_coverage.txt'] or file.name.endswith('.end.f')):shutil.copy2(file,target/file.name)
 target=e/'source_snapshot/td_project/camera_to_dsi_display_Runs'/stage;target.mkdir(parents=True,exist_ok=True)
 for filename in ['build.tcl','settings.cfg','camera_to_dsi_display.prj']:shutil.copy2(source/filename,target/filename)
rounds=['video_first_v10_v9_repro_20261015','video_first_v10_v9_cadence_repro_20261015','video_first_v10_r1_20261015','video_first_v10_r2_20261015','video_first_v10_r3_20261015']
for round_name in rounds:
 source=r/'tmp'/round_name;target=e/'round_history'/round_name;target.mkdir(parents=True,exist_ok=True)
 for filename in ['inputs.json','simulation_inputs.json','repro_console.log','test_console.log','unit_console.log','tests_exit_code.txt']:
  if (source/filename).exists():shutil.copy2(source/filename,target/filename)
 for item in load(source/'inputs.json'):
  dest=target/'source_snapshot'/item['path'];dest.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(source/item['path'],dest)
 shutil.copytree(source/'sim',target/'source_snapshot/sim',dirs_exist_ok=True,ignore=ignore)
 for test in (source/'sim/modelsim_work').glob('*'):
  if test.is_dir():
   for filename in ['compile.log','console.log','transcript.log']:
    file=test/filename
    if file.exists():dest=target/'tests'/test.name;dest.mkdir(parents=True,exist_ok=True);shutil.copy2(file,dest/filename)
helpers=e/'verification_tools';helpers.mkdir(exist_ok=True)
for filename in ['audit_video_first_v10.py','check_video_first_reference.py','create_cadence_v10.py','create_late_display_v10.py','create_v9_cadence_repro.py','freeze_process_final.py','run_video_first_v10_build.ps1','finish_video_first_v10.py','restore_runner_eol_v10.py']:
 shutil.copy2(r/'tmp'/filename,helpers/filename)
profile=load(p/'tools/shape3528/3528w_continuous_v9_trial.json')
profile['version']='DB FRAME EXP V10'
profile['metadata'].update(wait_limit_ddr_cycles=0,wait_limit_ms=0,video_first=True,late_result='one attachment to the same completed slot/writer epoch; canceled by next FS or bad frame; active reader tuple changes only at VS')
profile['validation']='20 frozen simulations and 24 independent actual-image references plus routed TD passed; onsite V10 pending, V9 failed black'
profile_path=p/'tools/shape3528/3528w_video_first_v10_trial.json'
profile_path.write_text(json.dumps(profile,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
shutil.copy2(bit,release/'camera_to_dsi_display.bit');shutil.copy2(guide,release/'README.md');shutil.copy2(build/'build_audit.json',release/'build_audit.json');shutil.copy2(profile_path,release/profile_path.name)
(release/'SHA256.txt').write_text(digest+'  camera_to_dsi_display.bit\n',encoding='ascii')
pointer=dict(purpose='3528_VIDEO_FIRST_V10',td_version='6.2.168116',base_head=audit['base_head'],source_commit=None,
 source_snapshot=(e/'source_snapshot').relative_to(r).as_posix(),build_root=build.relative_to(r).as_posix(),
 release=dict(path=(release/'camera_to_dsi_display.bit').relative_to(r).as_posix(),bytes=bit.stat().st_size,sha256=digest),
 validation_record=record.relative_to(r).as_posix(),fresh_tests=[t['name'] for t in audit['tests']],test_round=build.relative_to(r).as_posix(),
 onsite='PENDING_V10',previous_v9_onsite='FAIL_BLACK',previous_v8_onsite='FAIL_BLACK')
(p/'td_project/current_codex_build.json').write_text(json.dumps(pointer,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
manifest=[dict(path=file.relative_to(e).as_posix(),bytes=file.stat().st_size,sha256=sha(file)) for file in sorted(e.rglob('*')) if file.is_file()]
(e/'archive_sha256.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
for item in manifest:assert sha(e/item['path'])==item['sha256']
print(json.dumps(dict(status='PASS_PACKAGED_V10',files=len(manifest),archive_bytes=sum(item['bytes'] for item in manifest),bit_sha256=digest),ensure_ascii=False))
