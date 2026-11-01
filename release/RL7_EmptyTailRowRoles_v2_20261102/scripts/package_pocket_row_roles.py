"""Package only the frozen, simulated and physically audited row-role candidate."""
from pathlib import Path
import hashlib,json,re,shutil,subprocess,sys,zipfile
repo=Path(__file__).resolve().parents[1];src=repo/'fpga/component_inspector'
analysis=Path('D:/CodexWork/empty_tail_role_20261102');work=Path('D:/CodexWork/erole_build_r1_20261102')
desktop=Path('C:/Users/Li47/Desktop');name='RL7_EmptyTailRowRoles_v2_20261102'
release=repo/'release'/name;validation=repo/'validation/pocket_row_roles'
def sha(p):
 h=hashlib.sha256()
 with p.open('rb') as f:
  for chunk in iter(lambda:f.read(1048576),b''):h.update(chunk)
 return h.hexdigest()
def load(p):return json.loads(p.read_text(encoding='utf8'))
def save(p,data):p.parent.mkdir(parents=True,exist_ok=True);p.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
def copy(p,q):
 q.parent.mkdir(parents=True,exist_ok=True)
 shutil.copy2('\\\\?\\'+str(p.resolve()),'\\\\?\\'+str(q.resolve()))
baseline=load(analysis/'baseline_inputs.json');source=load(work/'frozen_inputs.json')
assert len(source)==len(baseline)==638
changed={r for r in source if source[r]!=baseline[r]}
assert changed=={'user_source/hdl_source/design_top_wrapper.v','user_source/hdl_source/isp/isp_top.v','user_source/hdl_source/frame_shape_search.v'}
for r,d in source.items():assert sha(src/r)==sha(work/'project'/r)==d,r
physical=load(work/'physical_verification.json')
assert physical['status']=='PASS_RL7_UIOPT_V2_ROUTED_50_BOUNDS_20_FIFO_GRAY_64_TIME_GRAY_KEYS_V2_C12'
assert physical['timing_ns']['SWNS']>=0 and physical['timing_ns']['HWNS']>=0
assert physical['timing_ns']['STNS']==physical['timing_ns']['HTNS']==0
assert physical['max_delays_matched']==50 and physical['max_delays_ignored']==0
assert physical['resources']['slice']<=21216
assert (physical['resources']['eram'],physical['resources']['dsp'],physical['resources']['pll'])==(98,30,5)
review=load(validation/'resource_review.json');assert review['actual_slice']==physical['resources']['slice'] and review['status']=='REVIEWED_NO_FURTHER_FEATURE_ADDITION'
assert load(analysis/'motion_run_r2/verification.json')['status']=='FAIL_RETAINED'
assert load(analysis/'motion_run_r3/verification.json')['status']=='PASS'
assert load(analysis/'motion_pixels_reference.json')['status']=='PASS'
for key in ['feed_roles','aperture_quantization']:
 cmp=load(analysis/'probe_comparison_r1.json')[key]
 assert cmp['new_wrong_feed']==0 and not cmp['previous_positive_regressions']
for freeze in ['frozen_r4','frozen_r5']:
 for p in (analysis/freeze).glob('*.v'):
  assert sha(p)==source['user_source/hdl_source/'+p.name],(freeze,p.name)
groups=['stop_r1','second_r0','alarm_r1','contracts_r1','native_r1'];tests=[];proofs={}
for group in groups:
 folder=analysis/group;proof=load(folder/'verification.json');assert proof['status']=='PASS',group
 proofs[group]=proof
 for rel,d in proof['inputs'].items():
  original=repo/rel if rel.startswith(('fpga/','tests/')) else src/rel
  assert sha(original)==d,(group,rel)
 for rel,d in proof.get('extra_inputs',{}).items():assert sha(repo/'tests/pocket_row_roles'/Path(rel).name)==d
 for rel,d in proof.get('fixtures',{}).items():assert sha(repo/'tests/rl7_alarm_roles_v3'/rel)==d
 for t in proof.get('tests',[]):
  bench=t.get('bench',t.get('name'));digest=t.get('log_sha256',t.get('console_sha256'))
  assert sha(folder/(bench+'.log'))==digest,(group,bench)
  tests.append({'group':group,'bench':bench,'console_sha256':digest})
 if 'console_sha256' in proof:
  assert sha(folder/'console.log')==proof['console_sha256']
  tests.append({'group':group,'bench':proof['name'],'console_sha256':proof['console_sha256']})
assert len(tests)==12,len(tests)
native_text=(analysis/'native_r1/console.log').read_text(encoding='utf8',errors='replace')
m=re.search(r'full exact RGB rasters=(\d+) pixels=(\d+) OF=(\d+) UF=(\d+)',native_text);assert m
rasters,pixels,of,uf=map(int,m.groups());assert rasters==24 and pixels>=3686400 and of==uf==0
bit=work/'runs/phy_1/camera_to_dsi_display.bit';digest=sha(bit);assert digest==physical['bit_sha256']
assert not release.exists();release.mkdir(parents=True)
for rel in source:copy(work/'project'/rel,release/'fpga/component_inspector'/rel)
copy(bit,release/(name+'.bit'));copy(work/'frozen_inputs.json',release/'SOURCE_SHA256.json')
copy(analysis/'baseline_inputs.json',release/'baseline/frozen_inputs.json')
for rel in changed:
 data=subprocess.check_output(['git','show','1b8a097f9dd7d7dee2783e9dcbcf43986f7650f4:fpga/component_inspector/'+rel],cwd=repo)
 assert hashlib.sha256(data).hexdigest()==baseline[rel]
 p=release/'baseline/changed_files'/rel;p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(data)
def copy_tree(folder,target):
 for p in folder.rglob('*'):
  if not p.is_file():continue
  rel=p.relative_to(folder)
  if any(part in ['work','anlogic_sim','temp','__pycache__'] for part in rel.parts):continue
  if p.suffix.lower() in ['.wlf','.exe','.dll','.pyc'] or p.name.startswith('VSOUT'):continue
  copy(p,target/rel)
for group in groups:copy_tree(analysis/group,release/'evidence/sw'/group.removesuffix('_r0').removesuffix('_r1'))
for group in ['frozen_r0','frozen_r1','frozen_r2','frozen_r3','run_r0','run_r1','run_r2','run_r3','motion_r2','motion_r3','motion_run_r2','motion_run_r3','frozen_r4','frozen_r5','run_r4','run_r5','phases_r0','phase_trace_r0','refine_phase_r1','refine_run_r1','native_r0']:
 copy_tree(analysis/group,release/'evidence/probe'/group)
for p in analysis.glob('*'):
 if p.is_file() and p.suffix in ['.py','.json']:copy(p,release/'evidence/analysis'/p.name)
for n in ['sheet_00.jpg','sheet_01.jpg','sheet_02.jpg','frame_0026.png','frame_0028.png','frame_0031.png']:
 copy(analysis/'video_r0'/n,release/'evidence/video'/n)
v=load(analysis/'field_facts.json')['field_video'];video=Path(v['path']);assert sha(video)==v['sha256'];copy(video,release/'evidence/video'/video.name)
for n in ['pocket_row_roles','empty_only_stop','shift_alarm_v7','demo_rl7','rl7_alarm_roles_v3']:copy_tree(repo/'tests'/n,release/'tests'/n)
for p in (repo/'scripts').glob('*.py'):copy(p,release/'scripts'/p.name)
copy(repo/'AGENTS.md',release/'handoff/AGENTS.md')
copy(repo/'docs/EMPTY_TAIL_ROW_ROLES_20261102.md',release/'handoff/EMPTY_TAIL_ROW_ROLES_20261102.md')
for p in (repo/'开发实施/验收记录').glob('20261102_C_全空尾段角色_轮次*.md'):copy(p,release/'handoff'/p.name)
for p in validation.glob('*'):
 if p.is_file() and p.name not in ['delivery_receipt.json','github_upload_state.json']:copy(p,release/'evidence'/p.name)
for p in work.rglob('*'):
 if not p.is_file():continue
 rel=p.relative_to(work)
 if rel.parts[0] in ['project','temp']:continue
 copy(p,release/'evidence/phy'/rel)
copy_tree(work/'project/classified_audit',release/'evidence/phy/classified_audit')
save(release/'VERIFICATION.json',{'status':'PASS_CURRENT_ROW_ROLE_SOURCE_12_SOFTWARE_CONTRACTS_AND_ROUTED_AUDIT','tests':tests,'physical':physical,'baseline_commit':'1b8a097f9dd7d7dee2783e9dcbcf43986f7650f4','changed':sorted(changed),'observed_old_failure_retained':True,'full_traverse':{'total':36,'normal':22,'empty':13,'review':1,'externally_driven_after_alarm':True},'fifth_tail_alarm':{'id':34,'normal':22,'empty':11,'review':1},'board_operated':False,'field_acceptance':'PENDING_HUMAN_SAME_FROZEN_IMAGE','publication_status':'See separate Desktop GitHub receipt'})
guide=f'''# 全空尾段识别修复 v2（2026-11-02）

镜像：{name}.bit
SHA-256：{digest}

基于已上传的AlarmRoles V3 + EmptyOnlyStop v1（源码22b1531d、回执1b8a097）。
本次改实际空穴识别：当前帧有件或上排定位孔辅助下排穴位参考，排除上排定位孔，
解决已复现的“全空时无有件参考＋小孔采样相位”漏检。保留五连空报警、人工停止、
真实空穴到站停靠；持续丢失和关联异常仍只记录。沿用原亮度阈值、字体、相机和视频传输。

由人用固定同一镜像操作：
1. 保存旧v1。先用TD Programmer选择本bit做SRAM下载，本助手未操作板卡。
2. 沿用原接线、SW5 FPGA控制档和四键：K1新段、K2暂停/继续、K3清零停止、K4停止保留。
3. 同一光源/焦点/曝光下，用原29穴再接同规格对齐7全空穴；新段前先清零。
4. 正常第5个追加空穴应在总号34触发报警停车：正常22、空穴11、复核1。
   此时最后2穴还未经过检测线，已检总数无需达到36。不要靠已检36判断停车版失败。
   若由外部继续移动使全部36穴经过，分类目标才是36/22/13/1。
5. 同时复核原29穴仍准确，并拍摄上下栏、空穴号和停车时刻。仿真通过不代表实板通过。
   视频里额外一次复核在尾段之前已发生，本次不冒称已通过现场分类标定。

本轮实际冻结验证：13幅角色/取消/复位/负例合同；171幅29+7完整运动，
同刺激旧版只31且不报警、新版全36且第34报警；67幅无P小空穴电机反馈闭环第五穴停车；
原20940停车、65控制、27按键、100MHz完整一秒、报警碰撞/21蜂鸣/18显示栅格像素合同。
原生12RAW/{rasters}精确显示栅格/{pixels}像素，OF=UF=0；手机视频不是原生传感器回放。
82组静态诊断保留旧失败和全部输入，40空孔扫描12组、42角色扫描另6组边界仍未知，未把未知当空穴。

Routed原SDC/引脚、seed1：Slice{physical['resources']['slice']}/21216、ERAM98/108、DSP30/40、PLL5/6；
setup{physical['timing_ns']['SWNS']:+.3f}ns、hold{physical['timing_ns']['HWNS']:+.3f}ns，双TNS0。
50最大延迟匹配/忽略0，20FIFO Gray、64时间Gray、控制邮箱/按键/实际V2/C12审计通过。
原PLL/DDR/I/O工具告警保留，不声称零告警。现场计数、物理停车距离与上电仍待人验收。

完整源在fpga/component_inspector，SOURCE_SHA256.json逐项绑定638输入；baseline保留三原文件。
跨机重建使用该源tools/prepare_portable_project.py，在新的英文无空格目录生成工程，
用--source指向完整源、--manifest指向SOURCE_SHA256.json、--work指定新目录、--td指向TD安装。
evidence保存本轮旧失败、成功日志、运行输入、路由DB/审计和用户视频；发布进度以桌面独立GitHub回执为准。
'''
(release/(name+'_烧录与验收.md')).write_text(guide,encoding='utf8')
payload={p.relative_to(release).as_posix():sha(p) for p in release.rglob('*') if p.is_file()}
save(release/'PAYLOAD_SHA256.json',payload)
archive=release.with_name(name+'_full.zip');assert not archive.exists()
with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED,compresslevel=9) as z:
 for p in release.rglob('*'):
  if p.is_file():z.write(p,p.relative_to(release).as_posix())
assert archive.stat().st_size<100*1024*1024,'Keep complete release under GitHub single-file limit; retain this attempt before adjusting packaging'
unpack=Path('D:/CodexWork/erole_unpack_r0_20261102');assert not unpack.exists();unpack.mkdir()
with zipfile.ZipFile(archive) as z:
 assert z.testzip() is None and set(z.namelist())==set(payload)|{'PAYLOAD_SHA256.json'};z.extractall(unpack)
for rel,d in payload.items():assert sha(unpack/rel)==d,rel
for rel,d in source.items():assert sha(unpack/'fpga/component_inspector'/rel)==d,rel
portable=Path('D:/CodexWork/erole_portable_r0_20261102')
r=subprocess.run([sys.executable,'-X','utf8',str(unpack/'fpga/component_inspector/tools/prepare_portable_project.py'),'--source',str(unpack/'fpga/component_inspector'),'--manifest',str(unpack/'SOURCE_SHA256.json'),'--work',str(portable),'--td','D:/td6.2.1'],capture_output=True,text=True)
(validation/'portable_check.log').write_text(r.stdout+r.stderr,encoding='utf8');assert r.returncode==0,r.stderr
items=[(release/(name+'.bit'),desktop/(name+'.bit')),(archive,desktop/(name+'_full.zip')),(release/(name+'_烧录与验收.md'),desktop/(name+'_烧录与验收.md'))]
for p,q in items:assert not q.exists(),q;copy(p,q);assert sha(p)==sha(q)
with zipfile.ZipFile(desktop/(name+'_full.zip')) as z:
 for rel,d in payload.items():assert hashlib.sha256(z.read(rel)).hexdigest()==d,rel
shafile=desktop/(name+'_SHA256.txt');assert not shafile.exists()
shafile.write_text('\n'.join(sha(q)+'  '+q.name for p,q in items)+'\n',encoding='utf8')
receipt={'status':'DELIVERED_FROZEN_CANDIDATE_FIELD_ACCEPTANCE_PENDING','desktop_bit':str(desktop/(name+'.bit')),'bit_sha256':digest,'desktop_zip':str(desktop/(name+'_full.zip')),'zip_sha256':sha(archive),'guide':str(desktop/(name+'_烧录与验收.md')),'source_files':638,'payload_files':len(payload),'software_contracts':12,'physical':physical['resources'],'timing_ns':physical['timing_ns'],'independent_all_payload_unzip_sha256':True,'portable_preparation_pass':True,'desktop_all_zip_payload_sha256':True,'baseline_old_bit_preserved':True,'board_operated':False,'committed':False,'pushed':False}
save(validation/'delivery_receipt.json',receipt);save(desktop/(name+'_交付回执.json'),receipt)
print(json.dumps(receipt,ensure_ascii=False,indent=2),flush=True)
