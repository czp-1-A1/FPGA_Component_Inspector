from pathlib import Path
import json,hashlib,shutil,subprocess
r=Path.cwd();p=r/'fpga/component_inspector';build=r/'tmp/process_v9_r8_20261015';tests=r/'tmp/process_v9_r7_20261015'
read=lambda f:f.read_text(encoding='utf-8-sig')
sha=lambda f:hashlib.sha256(f.read_bytes()).hexdigest()
load=lambda f:json.loads(read(f))
audit=load(build/'build_audit.json');assert audit['status']=='PASS_SOFTWARE_EXPERIMENT_ONSITE_PENDING'
assert len(audit['tests'])==17 and audit['independent_reference_images']==19 and audit['gray_pointer_logical_bits']==20 and audit['gray_pointer_dominated']==audit['gray_pointer_paths']
inputs=load(build/'inputs.json')
for e in inputs:assert sha(build/e['path'])==e['sha256']==sha(p/e['path'])
old={'fullframe_dual_v8_20261014':'2f5bd322d3243443adb5437c7b2ff6aaab4074207aa8e633f780b812477b7852','presence_review_v7_20261014':'a3d1164e41690a93c9113c6620cc081c63954f0191bffe3d445bcab91d0dfc2c','local_shape_v6_20261014':'79d63d1878309c0a2fce58f664aa6ac50b5cc0f740b631fcdb492c244a026a9b','shape_detection_v5_20261013':'3afb541a5f219b6a06481512cb8bae6f787a5b03e05d9bed7e284bd8b7788fbe'}
for n,h in old.items():assert sha(p/'release'/n/'camera_to_dsi_display.bit')==h
name='20261015_A_3528连续处理时钟_V9轮次1';e=r/'开发实施/验收记录'/name;assert not (e/'archive_sha256.json').exists();e.mkdir(exist_ok=True)
release=p/'release/continuous_frame_v9_20261015';assert not (release/'SHA256.txt').exists();release.mkdir(exist_ok=True)
guide=r/'开发实施/59_A3528连续处理时钟_V9黑屏修复与上板说明.md';record=r/'开发实施/验收记录'/f'{name}.md'
bit=build/'td_project/camera_to_dsi_display_Runs/phy_1/camera_to_dsi_display.bit';assert sha(bit)==audit['bit']['sha256']
res=audit['resources'];tm=audit['timing'];digest=sha(bit)
guide.write_text(f'''# 同一3528连续处理时钟 V9 实验版

V9修复了停CSI时钟仿真中出现的帧尾不完整和结果无法完成问题。相机采集、原生帧完整证明、去马赛克和白平衡仍在原时钟；AWB后的像素与证明事件通过异步FIFO，进入板上已有的连续100MHz时钟。整幅Sobel、3528全帧搜索、统计、结果快照和视频写入入口在该连续时钟运行。

同一3528白色LED、同一载带，曝光2244、增益48、R100/B100、前景100及原形状规则保持。完整1024×600参与处理，最多两个独立对象，分别显示框和结果。绿色区域框/虚线算法框继续去掉；Sobel仍是处理视图与诊断，SIZE/ASP/FILL/REF是模型检查，不是已标定的偏移/旋转/立起/翻面质量判定。

## 下载与现场确认

镜像：`fpga/component_inspector/release/continuous_frame_v9_20261015/camera_to_dsi_display.bit`。

SHA-256：`{digest}`，{bit.stat().st_size}字节。顶部标记 **DA FRAME EXP V9**。旧V8/V7镜像及现场失败记录保留。

烧录后先确认以下现象：

1. RAW恢复实时画面，再切GRAY、EDGE、GRAY+EDGE，均能显示；按复位、移动载带后能恢复。
2. 同一3528的两个有件、P+E、两个空穴分别有框和结果；移到画面不同位置复核。
3. 稳定后正常帧的W为1C200，CFG为1、FPS正常，OF/UF不持续增长。LP按新处理时钟计数，不要求仍为02E2。请保留版本、P/W、ER、VF及画面现场证据。

完整帧等同源结果最多1500000 DDR周期（22.5ms）；结果超时可显示无标签视频。不能把无结果当空穴。桥接FIFO溢出会拒帧并锁定故障，需要复位，避免丢像素后错误发布结果。

AI未操作JTAG/Flash。本版**软件和构建验证通过，现场待复测**。V8停钟反例能复现EDGE缺帧尾，但RAW仿真能回退显示，与现场RAW仍黑不同；不能据此宣称物理黑屏根因已全部闭合。

## 已验证内容

17项冻结回归PASS，包括真实校正/RAW10/vendor RAM/ISP/DDR，原生LP738、FE后200拍停CSI33ms、四模式、双目标远离旧区域、WB零结果回退、模式取消、帧外多余RAW拒绝和下一帧恢复。完整显示614400次请求、613200非零像素，OF/UF0。新桥接核对6827个精确128位载荷，覆盖突发、气泡、停钟排空、恢复及溢出复位。

独立两遍连通标记/并查集参考核对19幅捕获掩码/实际RTL输出图，两对象面积、框、类、原因、顺序与主对象字段全部匹配。这些图来自合成RAW经真实RTL仿真，不是实机训练或现场准确率证明。

最终生产及仿真同轮冻结215项；显式双时钟FIFO使用两级Gray指针同步、128×512不复位RAM、同步读取、各时钟同步释放复位，17项完整回归在r7重新执行；r8只将SDC集合收窄为精确总线选择器，全部RTL/测试/字体字节同r7，最终TD在r8重新执行。

TD6.2.168116 routed双角：Slice{res['slice']['used']}/21216={res['slice']['percent']}%，ERAM{res['eram']['used']}/108，DSP{res['dsp']['used']}/40；setup+{tm['setup_wns_ns']:.3f}ns、hold+{tm['hold_wns_ns']:.3f}ns、TNS0，STA{tm['sta_coverage_percent']}%。38显式及2厂商共40个max_delay匹配、ignored0；新FIFO的20个逻辑Gray位在路由数据库中逐位绑定核对；对应{audit['gray_pointer_paths']}条匹配物理路径全部由8ns约束实际主导（源/目的集合仅含指针及第一级同步寄存器）。

原DDR→CSI写入返回路径已不存在，移除其0路径约束；恢复原生时钟writer前需恢复此约束。厂商嵌套clkw/clkr查找会给出999.7ns默认值，r6实测该默认约束覆盖了手写项，因此r6约束审计FAIL并保留。本版改用显式指针及独立命名，脱离厂商自动匹配模式，两向10位指针及第一级同步寄存器均逐位匹配，全部匹配物理路径由8ns预算实际主导。声明顺序及新增FIFO端口查找/RAM_STYLE告警已消除。时钟分析保留两组PLL反馈网络告警（原有DDR PLL及主PLL反馈，后者在使用连续100MHz后出现）；存在本地反馈补偿延迟不确定及历史DDR/缺I/O延迟告警，仍需现场复测，不声称所有硬件风险已闭合。

MEAN/MIN/MAX仍是旧中心80×80诊断，不是两个目标各自均值。MODEL OK不等于安装合格。黑色/透明器件及真实质量分类不在本轮范围。

## 代码与重放

源代码及SHA、完整TD报告、17项测试、19参考图与失败历史在 `验收记录/{name}/`。`source_snapshot/`可复制到ASCII临时目录后重放，不在冻结档案内直接构建。主工程入口为 `fpga/component_inspector/td_project/camera_to_dsi_display.al`。

构建基线3c13af36cfd38656a42fb03bf665e4bd922856d2，构建时source_commit=null；后续仓库回执用215输入SHA绑定实际提交，不冒充旧镜像的构建提交。
''',encoding='utf-8')
record.write_text(f'''# 3528连续处理时钟V9验收记录

日期2026-10-15；PASS_SOFTWARE_EXPERIMENT_ONSITE_PENDING。用户授权继续生成代码并上传现有任务分支；本轮唯一实现端接续3c13af3交接WIP，原V8现场黑屏记录保持FAIL。

功能：AWB后跨连续100MHz，完整视频帧及同源双结果；原模型/阈值/同一实物保持。215生产输入与本轮source_snapshot一致。17项回归在process_v9_r7_20261015冻结215生产输入后重新执行；最终r8仅精确化SDC选择器，全部RTL/测试/字体SHA同r7；独立参考19图全部通过，原测试条件与答案保持。

TD和CDC：{json.dumps(dict(timing=tm,resources=res,explicit=audit['explicit_max_delays'],vendor=audit['vendor_fifo_max_delays'],gray_paths=audit['gray_pointer_paths'],warnings=audit['warnings']),ensure_ascii=False)}。

厂商999.7ns预算不得支撑本轮通过；最终20个逻辑指针位经路由数据库绑定核对，20条匹配路径全部由8ns实际主导。无clock/invalid constraint/loop/no-path问题，完整资源与双角STA通过；厂商/历史告警保留并审计。源码与镜像SHA {digest} 一致，实物/端到端恢复未验。

失败历史：V8 r1 RAW可显示但无结果、r2 EDGE缺帧尾；V9r1 UTF8编辑失败后的端口夹具加载失败；r3/r4测试回退等待提前约3.4μs，r5改23ms等待并保持33ms源间隔，全部17项PASS。原失败日志/夹具/生产输入保留，本轮r6新增手写约束被厂商999.7ns项覆盖，审计FAIL；r7改显式Gray FIFO后重跑17项软件及19图独立参考。r7宽匹配集合带入同步附加寄存器，实际约束141路径；r8用转义位总线选择器，仅约束两向20个指针位到第一级同步器，恢复同域自然时序检查，并完成独立路由数据库绑定核对与完整TD。

旧bit SHA全部复核。新发布DA FRAME EXP V9；AI未烧录。现场须复测RAW/四模式/复位/移动/两个有件/P+E/2E/背景/送料孔，不能称硬件黑屏根因闭合。上传结论以随后Git回执为准。打包辅助脚本初次误以为TD-only轮有仿真工作目录，报错和脚本另存packaging_attempts；补充目录缺席处理后重打包，未改变生产源、测试或bit。
''',encoding='utf-8')
# Full production archive plus immutable replay inputs, fonts and TD scripts.
for item in inputs:
 dest=e/'source_snapshot'/item['path'];dest.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(build/item['path'],dest)
shutil.copytree(build/'sim',e/'source_snapshot/sim',dirs_exist_ok=True,ignore=shutil.ignore_patterns('modelsim_work','*.log','modelsim.ini','*.wlf','transcript','*.pgm'))
for n in ['inputs.json','simulation_inputs.json','build_audit.json','gray_budget_binding_console.log','inspect_gray_budget.tcl']:shutil.copy2(build/n,e/n)
for tr in audit['tests']:
 dest=e/'tests'/tr['name'];dest.mkdir(parents=True,exist_ok=True)
 for n in ['compile.log','console.log','transcript.log']:shutil.copy2(tests/'sim/modelsim_work'/tr['name']/n,dest/n)
shutil.copytree(tests/'sim/osd_assets',e/'test_fonts',dirs_exist_ok=True)
dest=e/'independent_reference';dest.mkdir(exist_ok=True)
for f in (tests/'sim').glob('*.pgm'):shutil.copy2(f,dest/f.name)
for n in ['independent_reference_results.json','reference.log']:shutil.copy2(tests/n,dest/n)
for stage in ['syn_1','phy_1']:
 src=build/'td_project/camera_to_dsi_display_Runs'/stage;dest=e/'td_reports'/stage;dest.mkdir(parents=True,exist_ok=True)
 for f in src.iterdir():
  if f.is_file() and (f.suffix in ['.timing','.area','.prj','.cfg','.tcl'] or f.name in ['build_console.log','build_exit_code.txt','constraint_coverage.txt']):shutil.copy2(f,dest/f.name)
 dest=e/'source_snapshot/td_project/camera_to_dsi_display_Runs'/stage;dest.mkdir(parents=True,exist_ok=True)
 for n in ['build.tcl','settings.cfg','camera_to_dsi_display.prj']:shutil.copy2(src/n,dest/n)
for round_name in ['frame_stop_v8_r1_20261014','frame_stop_v8_r2_20261014','process_v9_r1_20261014','process_v9_r2_20261014','process_v9_r3_20261014','process_v9_r4_20261014','process_v9_r5_20261014','process_v9_r6_20261015','process_v9_r7_20261015']:
 src=r/'tmp'/round_name;dest=e/'round_history'/round_name;dest.mkdir(parents=True,exist_ok=True)
 for n in ['inputs.json','simulation_inputs.json','tests_console.log']:
  if (src/n).exists():shutil.copy2(src/n,dest/n)
 for f in (src/'sim').glob('tb_frame*.v'):shutil.copy2(f,dest/f.name)
 for n in ['audit_console.log']:
  if (src/n).exists():shutil.copy2(src/n,dest/n)
 for f in list(src.glob('*binding*.log'))+list(src.glob('inspect_gray*.tcl')):
  shutil.copy2(f,dest/f.name)
 if round_name in ['process_v9_r6_20261015','process_v9_r7_20261015']:
  for item in load(src/'inputs.json'):
   d=dest/'source_snapshot'/item['path'];d.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(src/item['path'],d)
  for stage in ['syn_1','phy_1']:
   q=src/'td_project/camera_to_dsi_display_Runs'/stage;d=dest/'td_reports'/stage;d.mkdir(parents=True,exist_ok=True)
   for f in q.iterdir():
    if f.is_file() and (f.suffix in ['.timing','.area','.tcl','.cfg','.prj'] or f.name in ['build_console.log','build_exit_code.txt','constraint_coverage.txt']):shutil.copy2(f,d/f.name)
 for test in (src/'sim/modelsim_work').glob('*'):
  if test.is_dir():
   for n in ['compile.log','console.log']:
    if (test/n).exists():d=dest/'tests'/test.name;d.mkdir(parents=True,exist_ok=True);shutil.copy2(test/n,d/n)
shutil.copytree(r/'开发实施/验收记录/20261014_A_V8黑屏现场反馈_轮次1',e/'onsite_v8_failure',dirs_exist_ok=True)
for n in ['freeze_process_final.py','audit_process_r8.py','check_process_native.py','finish_process_r8.py']:
 shutil.copy2(r/'tmp'/n,e/n)
shutil.copy2(guide,e/'board_instructions.md');shutil.copy2(record,e/'validation_record.md')
profile=load(p/'tools/shape3528/3528w_fullframe_v8_trial.json')
profile.update(version='DA FRAME EXP V9',processing_clock=dict(frontend='native CSI',post_awb_mhz=100,continuous=True,bridge='explicit 128x512 dual-clock ERAM FIFO with 10-bit Gray pointers and two-stage synchronization',overflow='reject until reset'),validation='software and routed build passed; onsite pending')
pf=p/'tools/shape3528/3528w_continuous_v9_trial.json';pf.write_text(json.dumps(profile,ensure_ascii=False,indent=2),encoding='utf-8')
for d in [release,e]:shutil.copy2(pf,d/pf.name)
shutil.copy2(bit,release/'camera_to_dsi_display.bit');shutil.copy2(guide,release/'README.md');shutil.copy2(build/'build_audit.json',release/'build_audit.json')
(release/'SHA256.txt').write_text(f'{digest}  camera_to_dsi_display.bit\n',encoding='ascii')
pointer=dict(purpose='3528_CONTINUOUS_POST_AWB_V9',td_version='6.2.168116',base_head=audit['base_head'],source_commit=None,source_snapshot=(e/'source_snapshot').relative_to(r).as_posix(),build_root=build.relative_to(r).as_posix(),release=dict(path=(release/'camera_to_dsi_display.bit').relative_to(r).as_posix(),bytes=bit.stat().st_size,sha256=digest),validation_record=record.relative_to(r).as_posix(),fresh_tests=[t['name'] for t in audit['tests']],test_round=tests.name,onsite='PENDING_V9',previous_v8_onsite='FAIL_BLACK')
(p/'td_project/current_codex_build.json').write_text(json.dumps(pointer,ensure_ascii=False,indent=2),encoding='utf-8')
(e/'worktree_diff.patch').write_bytes(subprocess.check_output(['git','diff','--','AGENTS.md','fpga/component_inspector/user_source/hdl_source/design_top_wrapper.v','fpga/component_inspector/td_project/camera_to_dsi_display.sdc'],cwd=r))
pack=e/'packaging_attempts';pack.mkdir(exist_ok=True)
shutil.copy2(r/'tmp/finish_process_r8_pack_attempt1.py',pack/'attempt1.py');shutil.copy2(build/'delivery_attempt1.log',pack/'attempt1.log')
manifest=[dict(path=f.relative_to(e).as_posix(),bytes=f.stat().st_size,sha256=sha(f)) for f in sorted(e.rglob('*')) if f.is_file()]
(e/'archive_sha256.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
for x in manifest:assert sha(e/x['path'])==x['sha256'] and (e/x['path']).stat().st_size==x['bytes']
for x in inputs:assert sha(e/'source_snapshot'/x['path'])==x['sha256']==sha(p/x['path'])
assert sha(release/'camera_to_dsi_display.bit')==digest
print(json.dumps(dict(status='DELIVERY_SHA_VERIFIED_ONSITE_PENDING',archived_files=len(manifest),archived_bytes=sum(x['bytes'] for x in manifest),release=release.relative_to(r).as_posix(),sha256=digest),ensure_ascii=False,indent=2))
