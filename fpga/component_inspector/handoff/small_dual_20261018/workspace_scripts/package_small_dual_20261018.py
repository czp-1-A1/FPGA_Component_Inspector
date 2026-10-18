from pathlib import Path
import hashlib,json,shutil,subprocess,sys,zipfile
r=Path.cwd();p=r/'fpga/component_inspector';rd=r/'tmp/small_dual_r3_20261018';w=rd/'work';base=p/'handoff/threshold180_20261018';out=p/'handoff/small_dual_20261018'
sha=lambda q:hashlib.sha256(q.read_bytes()).hexdigest()
load=lambda q:json.loads(q.read_text('utf-8-sig'))
def save(q,d):q.parent.mkdir(parents=True,exist_ok=True);q.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
def write(q,t):q.parent.mkdir(parents=True,exist_ok=True);q.write_text(t,encoding='utf-8')
def copy(a,b):b.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(a,b)
a=load(rd/'final_audit.json');assert a['status']=='PASS_SMALL_DUAL_MOVING_LABELS_SOFTWARE_ROUTED_FIELD_PENDING'
for n,h in load(rd/'baseline.json')['live_before'].items():assert sha(p/n)==h,n
formal=p/'td_project/current_codex_build.json';formal_sha=sha(formal)
out.mkdir(exist_ok=False)
for n in ['source_snapshot','scripts']:shutil.copytree(rd/n,out/n)
save(out/'handoff.json',a);write(out/'.gitattributes','* -text\n')
bit=w/'td_project/camera_to_dsi_display_Runs/phy_1/camera_to_dsi_display.bit';assert sha(bit)==a['bit']['sha256']
short=Path('D:/fpga_download')/f'3528_small_dual_{sha(bit)[:8]}.bit';bitname='V12_SMALL_DUAL_1092_40_20261018.bit';copy(bit,out/'candidate'/bitname)
if short.exists():assert sha(short)==sha(bit)
else:copy(bit,short)
write(out/'candidate/SHA256.txt',sha(bit)+'  '+bitname+'\n')
for n in ['prepare_small_dual_20261018.py','compact_lane_osd.v.txt','small_dual_tests_20261018.py','tb_lane_search.v.txt','tb_lane_handoff.v.txt','start_small_dual_20261018.py','retest_small_dual_20261018.py','refreeze_small_dual_20261018.py','prepare_handoff_negative_20261018.py','add_lane_handoff_20261018.py','run_small_dual_route_audit.py','audit_small_dual_20261018.py','package_small_dual_20261018.py','audit_search_stages.py']:copy(r/'tmp'/n,out/'workspace_scripts'/n)
for n in ['baseline.json','final_audit.json','sim.log','sim.err','build.log','build.err','processes.json']:copy(rd/n,out/'validation'/n)
for n in ['replay_sim.log','replay_sim.result.json','routed_audit.log','routed_audit_exit.txt','REPLAY_ORIGIN.json']:copy(w/n,out/'validation'/n)
for test in a['tests']:
 for n in ['compile.log','console.log']:copy(w/'sim/modelsim_work'/test['name']/n,out/'validation/tests'/test['name']/n)
for stage in ['syn_1','phy_1']:
 for q in (w/'td_project/camera_to_dsi_display_Runs'/stage).iterdir():
  if q.is_file() and q.suffix in ['.log','.logw','.txt','.json','.timing','.area','.rpt','.f','.tcl','.cfg','.prj','.ts']:copy(q,out/'build_evidence'/stage/q.name)
shutil.copytree(w/'audit_v3',out/'build_evidence/audit')
current=load(out/'source_snapshot/inputs.json')
prior=[(base,'selected_21dc'),(r/'tmp/small_dual_r0_20261018','r0_test_compile_and_dead_constraints'),(r/'tmp/small_dual_r1_20261018','r1_vendor_elaboration'),(r/'tmp/small_dual_r2_20261018','r2_nearest_only'),(r/'tmp/small_dual_handoff_negative_20261018','handoff_negative')]
for src,label in prior:
 m=load(src/'source_snapshot/inputs.json');copy(src/'source_snapshot/inputs.json',out/'provenance'/label/'inputs.json')
 for n,h in m.items():
  if h!=current[n]:copy(src/'source_snapshot'/n,out/'provenance'/label/'delta'/n)
  q=out/'provenance'/label/'delta'/n;assert sha(q if q.exists() else out/'source_snapshot'/n)==h,n
 for q in (src/'scripts').iterdir():
  if q.is_file():copy(q,out/'provenance'/label/'scripts'/q.name)
 if label!='selected_21dc':
  for n in ['sim.log','sim.err','build.log','build.err','work/replay_sim.log','work/replay_sim.result.json']:
   q=src/n
   if q.exists():copy(q,out/'validation/prior_rounds'/label/n)
for folder,test,label in [('small_dual_r0_20261018','lane_search','r0_test_compile_and_dead_constraints'),('small_dual_r1_20261018','lane_hd_pins','r1_vendor_elaboration'),('small_dual_handoff_negative_20261018','lane_handoff','handoff_negative')]:
 for name in ['compile.log','console.log']:
  q=r/'tmp'/folder/'work/sim/modelsim_work'/test/name
  if q.exists():copy(q,out/'validation/prior_rounds'/label/test/name)
for i in range(4):copy(r/f'tmp/small_dual_edit_20261018/ui_case_{i}.png',out/f'preview/ui_case_{i}.png')
# Reuse the unchanged28 original sources. The previous source archive remains
# immutable; this copy makes the new full handoff independently reviewable.
source_archive=load(r/'tmp/threshold_delivery_receipt.json')['source_archive'];src=r/source_archive['path'];assert sha(src)==source_archive['sha256']
copy(src,out/'calibration_sources'/src.name);save(out/'calibration_sources/receipt.json',source_archive)

# Only now integrate the exact tested/routed source, preserving preexisting
# CSI tests and all unrelated work. Baseline snapshots are retained for rollback.
names=['user_source/hdl_source/inspection_region_config.v','user_source/hdl_source/frame_shape_search.v','user_source/hdl_source/isp/isp_top.v','user_source/hdl_source/experiment_osd.v','td_project/camera_to_dsi_display.sdc','sim/run_modelsim.ps1','sim/tb_regions_osd.v','sim/tb_lane_search.v','sim/tb_lane_handoff.v','sim/tb_lane_osd.v','sim/tb_lane_hd_pins.v','sim/lane_ui_spec.json','sim/osd_assets/compact_cjk.hex']+[f'sim/lane_ui_{i}.hex' for i in range(4)]
integration=[]
for n in names:
 q=p/n;before=sha(q) if q.exists() else None
 if q.exists():copy(q,out/'integration_before'/n)
 copy(out/'source_snapshot'/n,q);assert sha(q)==current[n];integration.append(dict(path=n,before=before,after=sha(q)))
assert b'Name="csi_pixels"' in (p/'sim/run_modelsim.ps1').read_bytes()
assert sha(p/'sim/tb_csi_pixels.v')==current['sim/tb_csi_pixels.v']
save(out/'integration.json',integration)
q=p/'tools/shape3528/3528w_regions_v12_trial.json';copy(q,out/'integration_before/tools/shape3528/3528w_regions_v12_trial.json');profile=load(q)
profile['status']=a['status'];profile['version']='DD FRAME EXP V12 / SMALL DUAL R1';profile['validation']='PASS14_CURRENT_TESTS_FULL_ROUTED_AUDIT_PHYSICAL_PENDING'
profile['search']['max_displayed_objects']=2;profile['search']['max_objects_per_region']=1
profile['search']['scope']='Two compact160x104 zones, one current measured candidate per lane; full T100 mask/context preserved, T80 vertical cache184..536.'
profile['search']['temporal_hold']=False;profile['search']['selection_preference']=a['handoff_preference']
profile['regions']=[dict(id=x['lane'],bounds_xyxy=x['bounds'],template_id=3528) for x in a['roi']]
profile['display']['stable_local_display_ids']=dict(per_lane_fixed_id=True,target_matching_in_detector=True,persistent_tape_identity=False)
profile['display']['top_bar_height_px']=48;profile['display']['global_debug_panel']=False;profile['display']['result_labels']='Follow current measured target box; one line of Chinese status. WAIT is at empty lane origin.'
profile['small_dual_trial_20261018']=dict(candidate_sha256=a['bit']['sha256'],source_manifest_sha256=a['source_manifest_sha256'],source_archive=source_archive,resources=a['resources'],resource_delta=a['resource_delta'],routed_sta=a['routed_sta'],thresholds_changed=False,physical_validation=False,all_parts_guaranteed=False,labels_follow_box=True)
profile['next_version_gate']['status']='USER_SMALL_WINDOW_AND_MOVING_LABELS_IMPLEMENTED_20261018';profile['next_version_gate']['current_action']='Small dual candidate tested/routed; human aligns both horizontal lanes with new central zones and verifies real speed/coverage. No pending implementation approval for this continuous request.'
save(q,profile);copy(q,out/'threshold_profile.json')
sta=a['routed_sta'];res=a['resources'];d=a['resource_delta']
guide=f'''# 中央小窗口双路单目标版：SMALL DUAL R1

烧录 `{short.as_posix()}`；顶部版本 `SMALL DUAL R1`。SHA256 `{a['bit']['sha256']}`。基于最新21dc549f代码，阈值保持主体100、孔80、边缘80、正常fill85%与原尺寸上下限。

两条水平载带分别对准上、下搜索区。处理/显示仍1280×720：上区[560,720)×[248,352)，下区[560,720)×[368,472)，每区160×104，中心(640,300)/(640,420)。中心在画面中部亮区，不要求器件中心永远精确压一像素。原两区480×160/168，各搜索面积约减到原21%；这是选目标范围变化，不能当成整机资源按面积同比下降。

每路只输出一目标，总2框。结果文字严格跟着当前帧目标框移动，按用户纠正保留动态识别效果；只保留一行有件/空穴/有件复核，空区或无效数据时在该区显示待检测。顶部48像素状态栏保留缩小安路Logo、EXP/GAIN、输入FPS、视图、RUN/CHECK及短版本；删除底部诊断/HEX/流水号、WB常驻细节和MODEL OK/EDGE ON-OFF等大卡片。故障计数的保护逻辑并未按显示文字一起删除。标签只由当前有效结果生成，无旧框/旧结果视觉保持。

在中央±40处理像素带内，若当前测量候选距离前次有效选择曼哈顿≤32像素，则优先延续同件；经过中央带后允许下一件接替，避免旁边器件抢框。不把过去的坐标当当前结果；invalidate清除优先，新帧必须重新测出轮廓。仅用两路各11位x/y和2valid等少量状态，常量消除旧模式，原SCALE/PUBLISH阶段内完成，无新时钟/流水级/回压。不是编码器或整卷持久ID，也没有新增计数事件。

T100完整掩码保留，测量不会简单裁在虚线内；T80缓存184—536保留搜索区上下64像素供完整轮廓与暗参考。原灰度/尺寸/填充/侧立保有件分支不变；现有翻面盲点不因这次精简消失。四视图RAW/GRAY/EDGE/GRAY+EDGE及原Sobel12ERAM完整保留，SW1灰度/SW2边缘。曝光1092/增益40/WB100基准沿用，光源/镜头/180mm条件不变。

## 实际资源与时序

| 资源 | 最新21dc基线 | 本版 | 节省 |
|---|---:|---:|---:|
| Slice | 16442 /77.50% | {res['slice']['used']} /{res['slice']['percent']}% | {d['slice']['saved']}，{d['slice']['percentage_points_saved']}个百分点 |
| ERAM | 104/108 | {res['eram']['used']}/108 | {d['eram']['saved']} |
| DSP | 26/40 | {res['dsp']['used']}/40 | {d['dsp']['saved']} |
| PLL | 5/6 | {res['pll']['used']}/6 | {d['pll']['saved']} |

实际双角路由setup{sta['setup_ns']:+.3f}/hold{sta['hold_ns']:+.3f}ns，TNS0，STA覆盖{sta['sta_percent']}%。32条现有SDC max_delay加2条vendor约束全部匹配、ignored0；20位Gray及实际全部源扇出仍满足8ns原预算。因显示消费者消失，u_publish_display和u_wb_process的6条旧邮箱约束目标被综合删除，本版仅删除这6个失效命令；其他时钟、I/O、有效路径预算和例外均保持。路由网表确认两组D_data目的寄存器已无，不是降低有效约束通过时序。原相机/DDR/IP/PLL/I/O警告按完整报告保留。

## 验证与现场边界

14项全部PASS：新增lane_search24全帧/42结果，双路3个器件正反方向依次经过、每区单槽、侧立/弱灰有件、定位孔剔除、边界完整轮廓和窗外拒绝；lane_handoff7帧14结果，4px前后扰动同件不跳、下一件交接和invalidate重新采集。纯最近中心策略在完全相同7帧oracle的第2帧复现612/676身份切换，修正后通过。旧负例源/日志保留。

lane_osd4全栅格3686400独立像素，文字确实随框、忽略旧第二槽、失效清空、元数据半帧变化到下帧才生效、Logo字库与3-clock同步及ENABLE旁路；lane_hd_pins实际vendor FIFO/DDR地址/整帧RGB/同步/串行PHY核对两完整720p60图。另保留并通过原10测试：threshold180、pose180、field180、cal180_body/holes、旧regions_osd（显式legacyUI0）、旧hd_pins和三Sobel。旧测试目标未删除；生产采用常量compact分支，旧模式不构成运行时重复UI硬件。

早期r0 test声明dist触发SV保留字错误、r1 HDMI台遗漏原厂glbl/GSR、r0失效6约束均保留证据；修正后重新冻结并全测全布线。r2空间最近策略13项通过，但新扰动反例失败，r3是最终稳定交接版本，不能混烧中间轮。

仿真不是现场全检验收。运动流验证16处理像素/帧及4像素往返，真实传送速度、器件节距、曝光拖影、两条载带摆位仍需现场确认；每件在有效位置应有足够完整输入帧，不能用HDMI60Hz代替相机FPS。未声称保证所有器件永不漏检、翻面全部正确或此前整幅RAW抖动已修复。用户操作板卡，助手未JTAG/Flash；未提交或推送。

源快照372输入manifest `{a['source_manifest_sha256']}`，主生产集成逐字节对应且有integration_before备份。provenance含最新21dc、失败轮与扰动负例的清单/精确差异，可恢复旧冻结输入。calibration_sources复用28张原图完整来源包，SHA `{source_archive['sha256']}`；图像真值不按检测输出反标。preview为已逐像素验证的仿真界面，不是现场实拍。scripts/replay.py在新目录复跑；scripts/verify_candidate.py核对全部源/镜像/证据/来源SHA。
'''
write(out/'README.md',guide);write(out/'FIELD_GUIDE.md',guide)
report=r/'开发实施/验收记录/20261018_A_中央小窗口双路单目标精简_轮次20.md';assert not report.exists();write(report,guide);copy(report,out/'validation'/report.name)
verifier='''from pathlib import Path
import hashlib,json
r=Path(__file__).resolve().parents[1];sha=lambda q:hashlib.sha256(q.read_bytes()).hexdigest();load=lambda q:json.loads(q.read_text('utf-8-sig'))
for n,h in load(r/'package_sha256.json').items():assert sha(r/n)==h,n
m=load(r/'source_snapshot/inputs.json');assert len(m)==372
for n,h in m.items():assert sha(r/'source_snapshot'/n)==h,n
for d in (r/'provenance').iterdir():
 for n,h in load(d/'inputs.json').items():
  q=d/'delta'/n;assert sha(q if q.exists() else r/'source_snapshot'/n)==h,(d.name,n)
a=load(r/'handoff.json');assert len(a['tests'])==14 and not a['physical_validation']
assert sha(r/'candidate/V12_SMALL_DUAL_1092_40_20261018.bit')==a['bit']['sha256']
src=load(r/'calibration_sources/receipt.json');assert sha(r/'calibration_sources'/Path(src['path']).name)==src['sha256']
print('PASS small dual package:372 inputs,14 tests,bit,all file hashes,5 prior source reconstructions,28-photo archive; field pending')
'''
write(out/'scripts/verify_candidate.py',verifier)
save(out/'package_sha256.json',{q.relative_to(out).as_posix():sha(q) for q in sorted(out.rglob('*')) if q.is_file()})
subprocess.run([sys.executable,'-X','utf8',str(out/'scripts/verify_candidate.py')],check=True)
zipname=out/'V12_SMALL_DUAL_1092_40_20261018_full.zip'
with zipfile.ZipFile(zipname,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as z:
 for q in sorted(out.rglob('*')):
  if q.is_file() and q!=zipname:z.write(q,q.relative_to(out).as_posix())
with zipfile.ZipFile(zipname) as z:
 assert z.testzip() is None
 for n,h in load(out/'package_sha256.json').items():assert hashlib.sha256(z.read(n)).hexdigest()==h,n
receipt=dict(short_bit_path=short.as_posix(),candidate=(out/'candidate'/bitname).relative_to(r).as_posix(),bit_sha256=sha(bit),full_package=zipname.relative_to(r).as_posix(),full_package_bytes=zipname.stat().st_size,full_package_sha256=sha(zipname),source_manifest_sha256=a['source_manifest_sha256'],resources=res,resource_delta=d,routed_sta=sta,tests=14,roi=a['roi'],objects_per_lane=1,labels_follow_box=True,physical_validation=False,all_parts_guaranteed=False,all_flipped_detected=False,raw_jitter_fixed=False,github_uploaded=False,guide=(out/'FIELD_GUIDE.md').relative_to(r).as_posix(),preview=(out/'preview/ui_case_1.png').relative_to(r).as_posix(),source_archive=source_archive)
assert sha(r/receipt['candidate'])==sha(Path(receipt['short_bit_path']))==receipt['bit_sha256'];save(r/'tmp/small_dual_delivery_receipt.json',receipt)
q=p/'td_project/current_calibration_handoff.json';h=load(q);h['small_dual_trial_20261018']=receipt;h['next_action']='Program SMALL DUAL R1; align two horizontal lanes to new central160x104 windows. One target/lane,labels follow measured boxes. Verify actual speed and missed/duplicate detections. No false claim all parts or flipped states solved. Existing observers retained.';save(q,h)
assert sha(formal)==formal_sha
with report.open('a',encoding='utf-8') as f:f.write('\n完整包'+receipt['full_package']+'，'+str(receipt['full_package_bytes'])+'B，SHA256 '+receipt['full_package_sha256']+'。全部源/位流/来源/ZIPCRC及集成一致性核对通过，正式构建指针未改。\n')
q=r/'AGENTS.md';t=q.read_text('utf-8');t=t[:t.index('## 当前断点')]+f'''## 当前断点（2026-10-18，中央小窗口双路单目标已验证集成并交付；等现场）

- lj4747-contest-work HEAD55090063。最新用户要求最新代码省资源/精简显示、搜索区改小，每路单目标，已明确两条水平载带；随后纠正“文字还是随框动”。最终{short.as_posix()}，SHA{receipt['bit_sha256']}，标题SMALL DUAL R1。主生产已集成，未提交/推送/JTAG/Flash。旧21dc、c093、观察66f9、正式current_codex_build与旧包不变。
- 372输入manifest{a['source_manifest_sha256']}，最终tmp/small_dual_r3_20261018为构建与测试共同源；集成frame_shape_search/inspection_region_config/isp_top/experiment_osd及对应SDC/测试/字体oracle，均与冻结字节一致，integration_before保留先前版本，CSI登记及原测试保留。CFG紧凑区x560—720/y248—352与368—472，各160×104、中心640/300和640/420。两路各1框，文字严格随当前框移动，空区待检测。顶部48像素、Logo/EXP/GAIN/FPS/视图/短版本/故障提示，删调试页脚/长英文卡/常驻WB细节。原阈值主体100/孔80/Sobel80/fill85%不变，原ISP/缩放/Sobel12ERAM/DDR/时钟/I/O不改。
- 每路实测当前候选，中央±40px内与上次选择曼哈顿≤32px时优先同件，出中央带交下一件，invalidate清除；没有保留旧框/旧结果或持久卷号。只改筛选输出和显示，保留完整T100及T80缓存184—536上下64px上下文。文字固定在搜索区旁的建议已被用户否决，不能恢复。
- 14测试全PASS：lane_handoff7帧14记录复现/修正4px扰动抢框；lane_search24帧42结果双路正反向3件都被选；lane_osd4栅格3686400独立像素（文字随框/失效/原子快照/ENABLE/3clock）；lane_hd_pins实际vendorFIFO/DDR/串行HDMI两完整720p60图；原10项全部保留通过。仅空间最近的r2用同oracle在frame2切换612/676失败，负例完整归档。早期r0保留字测试编译与失效SDC、r1缺glbl/GSR的失败保留；r3所有目标未放宽。仿真不是现场全检或全部翻面验收。
- 实际Slice{res['slice']['used']}({res['slice']['percent']}%)，较21dc16442/77.50%省{d['slice']['saved']}({d['slice']['percentage_points_saved']}个百分点)；ERAM{res['eram']['used']}/108省{d['eram']['saved']}；DSP26/PLL5不变。路由setup{sta['setup_ns']:+.3f}/hold{sta['hold_ns']:+.3f}ns、TNS0、STA{sta['sta_percent']}%。显示精简使u_publish_display/u_wb_process目的寄存器被优化，删除恰6条失效邮箱约束；其余32+2vendor全部匹配ignored0、20Gray实际扇出均满足原8ns预算。旧相机/DDR/IP/PLL/I/O警告保留。
- 完整包{receipt['full_package']}，{receipt['full_package_bytes']}B，SHA{receipt['full_package_sha256']}，含完整源/14日志/实际路由网表/五组旧源重建/失败与扰动反例/28原图来源包/预览/集成前备份，全SHA/ZIPCRC通过。记录开发实施/验收记录/20261018_A_中央小窗口双路单目标精简_轮次20.md；current_calibration_handoff新增small_dual_trial_20261018，正式指针未改。
- 下一步用户烧此bit，两条载带对准上、下新中央区，以实际速度验证每件至少有足够输入帧（不能用显示60Hz代替相机FPS）、新标签跟框、相邻不抢框、正常/空穴/侧立/翻面及失效清空。未保证全部器件无漏检；未称翻面盲点或整幅RAW抖动修好。无运行中测试/构建/新代理/新自动任务。
''';q.write_text(t,encoding='utf-8')
print(json.dumps(receipt,ensure_ascii=False,indent=2))
