from pathlib import Path
import hashlib,json,shutil,subprocess
root=Path(__file__).resolve().parent.parent;project=root/'fpga/component_inspector'
build=root/'tmp/tracking_black_fix_r2_td_20261011';prior=root/'tmp/tracking_late_r3_td_20261011'
record=root/'开发实施/验收记录/20261011_B追踪黑屏排查_轮次1'
release=project/'release/tracking_lower_holes_v2_blackfix_20261011'
guide=root/'开发实施/40_B追踪黑屏修复_上板说明.md'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
load=lambda p:json.loads(p.read_text(encoding='utf-8-sig'))
dump=lambda p,d:p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
tests_root=root/'tmp/tracking_black_fix_r3_td_20261011'
audit=load(tests_root/'audit.json');assert audit['status']=='PASS_logic_and_build_only'
assert len(audit['tests'])==33 and len(audit['variants'])==3
assert not release.exists() and not (record/'manifest.json').exists()
inputs=load(build/'inputs.json')
for e in inputs:assert sha(build/e['path'])==e['sha256']==sha(project/e['path']),e['path']
head=subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip()
branch=subprocess.check_output(['git','branch','--show-current'],cwd=root,text=True).strip()
assert head=='3be3967f2457622566fb20b7cef3aa5038e7d885' and branch=='lj4747-contest-work'
assert not subprocess.check_output(['git','diff','--cached','--name-only'],cwd=root,text=True).strip()
runs=build/'td_project/camera_to_dsi_display_Runs';bit=runs/'phy_1/camera_to_dsi_display.bit'
assert sha(bit)==audit['bit']['sha256']
release.mkdir();shutil.copy2(bit,release/bit.name);shutil.copy2(build/'inputs.json',release/'build_inputs.json')
(release/'SHA256.txt').write_text(sha(bit)+'  '+bit.name+'\n',encoding='ascii')
t=audit['timing'];a=audit['resources']
statistics=f"Routed慢/快角setup+{t['setup_wns_ns']:.3f}ns、hold+{t['hold_wns_ns']:.3f}ns，TNS0、违例终点0；Slice{a['slice_used']}/{a['slice_total']}={a['slice_percent']:.2f}%，LUT6{a['lut6_used']}、REG{a['reg_used']}、ERAM{a['eram_used']}、DSP{a['dsp_used']}；STA覆盖{t['sta_coverage_percent']:.2f}%"
identity=f"{bit.stat().st_size}字节，SHA-256 `{sha(bit)}`"
metadata=dict(syn=str(runs/'syn_1'),phy=str(runs/'phy_1'),flow='D:/AAA/FPGA.....YZW/doc/scripts/DefaultFlow.tcl',tool='D:/AAA/FPGA.....YZW/bin/td_commands_prompt.exe',td_version='6.2.168116',source_commit=None,base_head=head,source_snapshot=record.relative_to(root).as_posix()+'/source_snapshot',simulation_root=tests_root.relative_to(root).as_posix(),release=dict(path=(release/bit.name).relative_to(root).as_posix(),**audit['bit']),validation_record=record.with_suffix('.md').relative_to(root).as_posix(),fresh_regression_tests=6,reused_unchanged_source_tests=27,metadata_stop_views=[0,1,2,3])
(release/'README.md').write_text(f'''# 下方定位孔追踪 v2 — 帧尾黑屏修复

正式镜像：camera_to_dsi_display.bit；{identity}。

修复追踪版把特征计算及48拍结果等待放在原生FE之后的发布阻塞。在真实ISP/DDR仿真中，帧尾仅20个CSI时钟后停钟，旧逻辑完成115200字却metadata未就绪；新逻辑在下方孔扫描结束后的390行完成特征与元数据，完整帧及DDR写完后才发布。未取消坏帧、完整字数、帧号匹配或旧显示槽保护。

相对下方v1仅isp_top.v生产源码变更，孔位、ROI、分类阈值、四视图及EXP/GAIN/WB按键保持。六项受影响/相关回归新跑，短尾真实METADATA视频链路另覆盖RAW/GRAY/EDGE三个视图（GRAY+EDGE在主测试），599行残帧及下一帧恢复；27项旧测试逐项证明全部编译源和测试台哈希未变而复用。不是33项全部重新执行。

{statistics}。34max_delay均匹配/ignored0，SDC未改；124/10警告与v1内容相同。已有PLL/I/O和未覆盖时序限制保留。仿真样本不代表现场分类准确率；现场时钟尾长、板上实际镜像、画面恢复及追踪需人验证。

上板先检查RAW有图、FR增加而VF不持续跟增，再按39对准下方孔和慢速手动横移。见开发实施/40_B追踪黑屏修复_上板说明.md及{metadata['validation_record']}。未提交、未推送、未烧板；原v1和静态可调WB回退保留。
''',encoding='utf-8')
s=guide.read_text(encoding='utf-8')
s=s.replace('正式镜像身份待最终测试与构建核对；中间文件不要当作发布镜像。',f"正式镜像：[camera_to_dsi_display.bit](../{metadata['release']['path']})，{identity}。六项重新执行与四视图短尾补测通过，另27项通过编译源/测试台哈希确认未变而复用；{statistics}。未上板验收。")
guide.write_text(s,encoding='utf-8')
execution_labels={'fresh_R2':'本轮R2新跑','fresh_R3':'本轮R3新跑','prior_R3_unchanged_source_closure':'旧R3/所有编译输入未变'}
table='\n'.join(f"| {e['name']} | {execution_labels[e['execution']]} | PASS |" for e in audit['tests'])
record.with_suffix('.md').write_text(f'''# B追踪黑屏排查与帧尾发布修复 — 轮次1

来源：用户报告黑屏并确认RAW/复位后仍黑。分支{branch}、HEAD{head}；未提交、未推送、未烧板。当前是软件修复候选已通过，现场未验收；板上旧镜像SHA尚未核对。

## 观察与复现

原照片保存onsite_black_screen.jpg：OSD正常，相机区黑；FRAME STALE/ROW0，EXP2244/GAIN48/WB64，FPS27/CFG1，ER0/LP02E2/WS0，FR03F9/VF03F8、OF0/UF0。由计数推断完整帧未发布；不能由照片确定真实CSI尾部时长。

真实RAW10桥、原厂ERAM、demosaic、手动WB、Sobel、ROI/分类、178位元数据邮箱和DDR写入器联合复现。旧生产逻辑尾部200拍测试PASS；尾部20拍停CSI、DDR继续时，AWB/view均153600拍、pack/DDR均115200字、good1/bad0，但ready0/pending1/wait44，completed0/capture0，因metadata门控黑屏。初次直接vsim缺许可环境退出4，设置已有许可环境后得到上述逻辑失败，日志各自保留。

原32项回归有覆盖缺口：isp_writer_stop未启用METADATA，而isp_tracking_late未接writer且给700拍尾部时钟，独立frame_metadata又人为生成ready；没有覆盖真实结果等待和CSI帧尾停钟同时发生。这次补齐，不将旧仿真PASS视为硬件通过。

## 最小修改与完整性

210生产输入中仅user_source/hdl_source/isp/isp_top.v改变。TRACKING时在ROI/Sobel邻域和孔三行完成后启动统计/分类，RESULT_ROW=max(HOLE_Y+10,ROI_Y1+2)，本轮下方390行、旧上方兼容342行。保留原28拍除法和48拍结果稳定等待；它们在后续相机行扫描期间完成。样本/分类外部输出由完整帧video_frame_good门控；提前计算的观察快照/元数据必须经原writer的完整字数、done/good/bad、epoch检查才随DDR槽发布。

未改video_in/out、FIFO、CSI/DDR IP、SDC、孔位/孔亮度/孔距、ROI、MEAN/EDGE阈值及成像按键。坏采集仍撤销metadata，599行即使ROI和孔完整、结果提前ready也不能发布；下一完整帧恢复。测试夹具只按writer_epoch归属判断published，避免把上一帧保持的published标志误判为下一帧早发布。R1修复先成功完整帧，随后夹具误报失败保留；R2修夹具、补恢复帧触及100ms旧测试预算，R3保留20ms间隔并按四帧114ms预期预算设150ms看门狗；生产语义不变（LF统一）。

## 验证边界

本轮六项新跑：真实下方ISP13帧、真实上方ISP、真实停钟writer、ROI整链、178位writer/reader槽原子性及新增真实METADATA停钟测试。新增测试主视图GRAY+EDGE，另对RAW/GRAY/EDGE各独立新跑；每次短前缀→完整600行→599行残帧→完整恢复，FE后20CSI拍停钟，DDR继续，证明提前结果不会放行残帧或混元数据。其余27项沿用旧R3结果，但逐条解析真实vlog命令，证明所有RTL和测试台哈希与本轮冻结源及当前工作区一致。33项覆盖清单并非本轮全33重跑。

| 测试 | 执行来源 | 结果 |
|---|---|---|
{table}

原厂仿真模型、输入PPC4和有效节拍断言未替换；软件合成样本只证明这些逻辑场景，不代表实物识别准确率。现场相机真正停钟时长未测，也可能有额外物理因素，仍需新镜像确认。

## 构建与身份

TD6.2.168116，综合96275/物理38932退出0并完成bitgen，冻结R2的210输入/70工程源。{statistics}。34max_delay均匹配且ignored0，SDC哈希未变；124/10警告标准化后与下方v1完全相同，既有PLL/I/O、STA未覆盖限制保留。正式镜像{metadata['release']['path']}；{identity}。R2三项通过后新增恢复帧触及原100ms测试台预算，38686退出1；保持20ms间隔和断言，仅将四帧测试预算按总时长扩为150ms，R3三项85518及额外视图21003退出0；复现与夹具失败各单独保留。

source_commit=null，来源是本记录source_snapshot，而非已提交Git版本。冻结编译输入、测试源/日志、复现、构建报告、脚本、说明和接力断点；旧v1、上方版、静态可调WB的所有清单副本再次校验未变。current_codex_build绑定本轮。

## 下一步实物验证

按40说明核对SHA下载，先RAW正常更新、固定模式VF不再每帧增加，再回到下方孔静止锁定和慢速手动横移。无孔时相机图仍应显示，状态可以NO HOLE/待检测；先完成图像恢复验证，才判断定位/分类效果。记录现场FR/VF/OF/UF、ER/LP/WS、CFG/FPS及模式。
''',encoding='utf-8')
p=root/'AGENTS.md';s=p.read_text(encoding='utf-8');s=s[:s.index('## 当前断点')]+f'''## 当前断点（2026-10-11，追踪黑屏修复v2软件完成，上板待验）

- **目标/断点**：用户黑屏且RAW/复位仍黑；OSD正常，FR03F9/VF03F8/FPS27/CFG1，FRAME STALE。补齐真实ISP+METADATA+writer停钟覆盖，复现FE后20拍停止时完整115200字/good1却48拍等待剩44，不能发布；旧200拍可发布。现场尾部时长和旧板镜像SHA未核实，不能声称硬件根因已测定。
- **分支/代码**：{branch}，HEAD{head}，source_commit=null、暂存区空、既有WIP保留。相对下方v1仅isp_top.v修改，390行提前特征和元数据，整帧证明/字数/坏帧/epoch/旧槽保护保留。旧孔几何、阈值、四视图、EXP/GAIN/WB不改。冻结{build.relative_to(root).as_posix()}，210输入/70源；正式快照{metadata['source_snapshot']}。
- **验证/证据**：六项受影响/相关回归本轮新跑PASS，新真实metadata停钟在四视图均覆盖20拍尾部、599行残帧拒绝及600行恢复；27项旧R3所有真实编译源/测试台哈希逐项未变而复用，不称33项全部重跑。{statistics}。34max_delay匹配/ignored0、124/10警告与v1相同，SDC未改；既有PLL/I/O及未覆盖限制保留。{metadata['validation_record']}及同名目录冻结照片/复现/夹具失败/复测/源码/TD报告/说明。旧下方538、上方517、静态WB456副本均保持。
- **镜像**：{metadata['release']['path']}，{audit['bit']['bytes']}字节，SHA {sha(bit)}；current_codex_build绑定R2。未烧板，现场黑屏恢复/追踪尚未通过；先按40上板RAW回图再按39对准孔。
- **未决限制**：现场停钟时长、实际SHA、冷启动长稳、同穴有件/空穴、固定光学与阈值精度待测；固定Y/倍率、≤4px/有效帧、周期孔可能串穴，无编号/电机/NG/完整配方/Flash，原限制不变。
- **下一条操作**：下载v2 SHA镜像，静止RAW看相机图更新、FR前进而VF固定模式不持续跟增、OF/UF稳定；画面恢复后静止LOCK→慢左/右/暂停→遮孔/恢复。若仍FRAME STALE保留完整诊断和实际镜像身份，不放宽完整帧证明。
- **进程/设备**：综合96275/物理38932、R2三项PASS、超时失败38686保留；R3三项85518及变体21003退出0，旧变体等待89234退出1；旧复现19029 PASS200，20361预期失败20，R1测试夹具误报6028保留；许可首次失败4保留。无运行进程，无JTAG/Flash/板卡操作，无代理。
- **提交/回退**：未提交未推送。旧下方v1 SHA0c1fe0ded306b532e3cb31310e556387de2d4c6caceeb53d80195b33a380745f保留；上方SHAa93d219750d3d76564a4677895f63c8f3b811277fcc8007a9828f38c4608a379；静态manualWB SHAf71b8d6cc7e8d90c04a84c9ce4916403e2d763c49c5d2c57a1ebf511e8e02800；固定WB/v3历史不改。
''';p.write_text(s,encoding='utf-8')
shutil.copy2(project/'td_project/current_codex_build.json',record/'current_build_before.json')
dump(project/'td_project/current_codex_build.json',metadata)
copies=[]
def copy(src,rel):
 dst=record/rel;assert not dst.exists(),rel;dst.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(src,dst)
for e in inputs:copy(build/e['path'],Path('source_snapshot')/e['path'])
for filename in ['inputs.json','simulation_inputs.json','stage_inputs.json','audit.json','build_audit.json']:copy((build if filename in ['inputs.json','stage_inputs.json','build_audit.json'] else tests_root)/filename,filename)
copy(root/'tmp/tracking_late_r1_td_20261011/user_source/hdl_source/isp/isp_top.v','before/isp_top.v')
for stage in ['syn_1','phy_1']:
 for f in (runs/stage).iterdir():
  if f.is_file() and f.suffix.lower() in {'.log','.logw','.rpt','.txt','.status','.qor','.area','.tcl','.prj','.cfg','.timing','.bit','.f'}:copy(f,Path('td_reports')/stage/f.name)
for e in load(tests_root/'simulation_inputs.json'):copy(tests_root/e['path'],Path('simulation/source')/Path(e['path']).relative_to('sim'))
for e in audit['tests']:
 src=root/e['source']/'sim/modelsim_work'/e['name']
 for filename in ['console.log','compile.log','transcript.log']:
  if (src/filename).is_file():copy(src/filename,Path('simulation/logs')/e['name']/filename)
for pattern in ['*exit_code.txt','metadata_mode*_*.log','regression_console.log']:
 for f in (tests_root/'sim').glob(pattern):
  if not (record/'simulation'/f.name).exists():copy(f,Path('simulation')/f.name)
for label,directory in [('reproduction',root/'tmp/tracking_black_repro_r1_td_20261011'),('fixture_failure_r1',root/'tmp/tracking_black_fix_r1_td_20261011'),('fixture_timeout_r2',build)]:
 for rel in ['sim/tb_isp_writer_stop.v','sim/tb_isp_metadata_stop.v','sim/run_modelsim.ps1','inputs.json','sim/regression_console.log','sim/regression_exit_code.txt']:
  if (directory/rel).is_file():copy(directory/rel,Path(label)/rel)
 for f in (directory/'sim').glob('repro_tail20*'):
  if f.suffix in {'.txt','.log'}:copy(f,Path(label)/'sim'/f.name)
 for test in ['isp_writer_stop','isp_metadata_stop']:
  for filename in ['console.log','transcript.log','compile.log']:
   f=directory/'sim/modelsim_work'/test/filename
   if f.is_file():copy(f,Path(label)/'sim/modelsim_work'/test/filename)
for script in ['prepare_tracking_black_20261011.py','setup_tracking_black_fix_20261011.py','freeze_tracking_black_r2_20261011.py','freeze_tracking_black_r3_20261011.py','audit_tracking_black_20261011.py','publish_tracking_black_20261011.py','verify_tracking_black_release_20261011.py','run_tracking_black_variants_20261011.ps1','run_tracking_black_variants_r3_20261011.ps1']:copy(root/'tmp'/script,Path('scripts')/script)
copy(guide,'40_上板说明.md');copy(record.with_suffix('.md'),'record.md');copy(root/'AGENTS.md','AGENTS_checkpoint.md');copy(project/'td_project/current_codex_build.json','current_codex_build.json')
for f in record.rglob('*'):
 if f.is_file():copies.append(dict(path=f.relative_to(record).as_posix(),bytes=f.stat().st_size,sha256=sha(f)))
dump(record/'manifest.json',dict(metadata=metadata,copies=copies))
dump(release/'manifest.json',dict(metadata=metadata,files=[dict(path=f.name,bytes=f.stat().st_size,sha256=sha(f)) for f in release.iterdir() if f.is_file()]))
print(json.dumps(dict(release=metadata['release'],record_copies=len(copies)),ensure_ascii=False))
