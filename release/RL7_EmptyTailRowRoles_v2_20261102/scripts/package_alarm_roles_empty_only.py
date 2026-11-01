"""Release only current-source, simulated, audited routed EMPTY-only candidate."""
from pathlib import Path
import hashlib,json,re,shutil,subprocess,sys,zipfile

repo=Path(__file__).resolve().parents[1]
src=repo/'fpga/component_inspector';work=Path('D:/CodexWork/rl7_alarm_roles_empty_only_20261102_build_r0')
desktop=Path('C:/Users/Li47/Desktop');name='RL7_AlarmRolesV3_EmptyOnlyStop_v1_20261102'
release=repo/'release'/name
def sha(p):
 h=hashlib.sha256()
 with p.open('rb') as f:
  for chunk in iter(lambda:f.read(1048576),b''):h.update(chunk)
 return h.hexdigest()
def load(p):return json.loads(p.read_text(encoding='utf8'))
def write(p,data):p.parent.mkdir(parents=True,exist_ok=True);p.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
def copy(p,target):
 target.parent.mkdir(parents=True,exist_ok=True)
 # CopyFile2 needs an extended path for deep Windows evidence paths.
 shutil.copy2('\\\\?\\'+str(p.resolve()),'\\\\?\\'+str(target.resolve()))
source=load(work/'frozen_inputs.json');baseline=load(repo/'validation/baseline_frozen_inputs.json')
assert len(source)==len(baseline)==638
changed={rel for rel in source if source[rel]!=baseline[rel]}
assert changed=={'user_source/hdl_source/design_top_wrapper.v','user_source/hdl_source/isp/isp_top.v','user_source/hdl_source/pocket_relay_stop_v2.v'}
for rel,digest in source.items():assert sha(src/rel)==sha(work/'project'/rel)==digest,rel
physical=load(work/'physical_verification.json')
assert physical['status']=='PASS_RL7_UIOPT_V2_ROUTED_50_BOUNDS_20_FIFO_GRAY_64_TIME_GRAY_KEYS_V2_C12'
# Use the repository's inherited physical capacity acceptance. The AGENTS
# 80% line is advisory and requires a recorded review, not a new 90% limit.
assert physical['resources']['slice']<=21216 and physical['resources']['eram']==98
review=load(repo/'validation/resource_review.json')
assert review['actual_slice']==physical['resources']['slice'] and review['status']=='REVIEWED_NO_FURTHER_FEATURE_ADDITION'
assert physical['resources']['dsp']==30 and physical['resources']['pll']==5
assert physical['max_delays_matched']==50 and physical['max_delays_ignored']==0
assert physical['timing_ns']['SWNS']>=0 and physical['timing_ns']['HWNS']>=0
assert physical['timing_ns']['STNS']==physical['timing_ns']['HTNS']==0
groups=[Path('D:/CodexWork/rl7_alarm_roles_empty_only_20261102_checks_r0'),Path('D:/CodexWork/rl7_alarm_roles_empty_only_20261102_second_r0'),Path('D:/CodexWork/rl7_alarm_roles_empty_only_20261102_native_r0'),Path('D:/CodexWork/rl7_alarm_roles_empty_only_20261102_roles_r0')]
selected=[]
for folder in groups:
 proof=load(folder/'verification.json');assert proof['status']=='PASS'
 for rel,digest in proof['inputs'].items():
  original=repo/rel if rel.startswith(('fpga/','tests/')) else src/rel
  assert sha(original)==digest,(folder,rel)
 for rel,digest in proof.get('extra_inputs',{}).items():assert sha(repo/'tests/empty_only_stop'/Path(rel).name)==digest
 for fixture,d in proof.get('fixtures',{}).items():assert sha(repo/'tests/rl7_alarm_roles_v3'/fixture)==d
 for test in proof.get('tests',[]):
  bench=test.get('bench',test.get('name'));log=folder/(bench+'.log');assert sha(log)==test['log_sha256'];selected.append(test)
 if 'console_sha256' in proof:
  assert sha(folder/'console.log')==proof['console_sha256'];selected.append({'bench':proof['name'],'log_sha256':proof['console_sha256']})
assert len(selected)==9
native_log=(groups[2]/'console.log').read_text(errors='replace')
native_match=re.search(r'full exact RGB rasters=(\d+) pixels=(\d+) OF=(\d+) UF=(\d+)',native_log)
assert native_match
rasters,pixels,overflows,underflows=map(int,native_match.groups())
assert rasters==24 and pixels>=3686400 and overflows==underflows==0
bit=work/'runs/phy_1/camera_to_dsi_display.bit'
assert sha(bit)==physical['bit_sha256'];digest=sha(bit)
assert not release.exists();release.mkdir(parents=True)
for rel in source:copy(work/'project'/rel,release/'fpga/component_inspector'/rel)
copy(bit,release/(name+'.bit'))
for rel in changed:
 data=subprocess.check_output(['git','show','904a2bb053a9e679b3f50378ca3163a55698b20e:fpga/component_inspector/'+rel],cwd=repo)
 assert hashlib.sha256(data).hexdigest()==baseline[rel]
 target=release/'baseline/changed_files'/rel;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(data)
copy(repo/'validation/baseline_frozen_inputs.json',release/'baseline/frozen_inputs.json')
for folder in groups:
 for p in folder.rglob('*'):
  if not p.is_file():continue
  rel=p.relative_to(folder)
  if rel.parts[0] in ('work','anlogic_sim') or p.suffix.lower() in ('.wlf','.dll','.exe') or p.name.startswith('VSOUT'):continue
  group_name=['targeted','second','native','roles'][groups.index(folder)]
  copy(p,release/'evidence/software'/group_name/rel)
for root in [repo/'tests/empty_only_stop',repo/'tests/shift_alarm_v7',repo/'tests/demo_rl7',repo/'tests/rl7_alarm_roles_v3']:
 for p in root.rglob('*'):
  if p.is_file():copy(p,release/p.relative_to(repo))
for p in (repo/'scripts').glob('*.py'):copy(p,release/'scripts'/p.name)
for p in [repo/'docs/ALARM_ROLES_EMPTY_ONLY_20261102.md',repo/'validation/current_status.json',repo/'AGENTS.md']:
 copy(p,release/'handoff'/p.name)
record=repo/'开发实施/验收记录/20261102_C_AlarmRolesV3仅空穴停车_轮次1.md'
record_text=record.read_text(encoding='utf8')
record_text=record_text.replace('second_r0，冻结运行；以verification.json为准','second_r0：生产100MHz完整100000000拍保持/一次完成PASS，全部编译输入SHA同最终源')
record_text=record_text.replace('roles_r0，冻结运行；以verification.json为准','roles_r0：原报警碰撞/21报警蜂鸣检查/18栅格66355200参考像素对/无P全空RGB四合同实际PASS')
record_text=record_text.replace('native_r0，12RAW冻结运行；以verification.json为准',f'native_r0：12RAW/{rasters}精确显示栅格/{pixels}像素/25时间绑定/OFUF0实际PASS')
record_text=record_text.replace('build_r0，V3 seed1/原SDC；physical_verification.json为准',f"build_r0，V3 seed1/原SDC，Routed Slice{physical['resources']['slice']}/21216 ERAM98/DSP30/PLL5；setup{physical['timing_ns']['SWNS']:+.3f}ns/hold{physical['timing_ns']['HWNS']:+.3f}ns/双TNS0，50maxdelay/20FIFO及64时间Gray/实际V2 C12完整审计PASS")
record_text=record_text.replace('native_r0：本轮冻结运行中，最终以verification.json和交付回执为准',f'native_r0：12RAW/{rasters}显示栅格、{pixels}实际像素、OFUF0及真实图像时间绑定PASS，见verification.json')
record_text=record_text.replace('build_r1：原SDC/seed1；最终以physical_verification.json和交付回执为准',f"build_r1：原SDC/seed1，Routed Slice{physical['resources']['slice']}/21216、ERAM98/DSP30/PLL5；setup{physical['timing_ns']['SWNS']:+.3f}ns/hold{physical['timing_ns']['HWNS']:+.3f}ns/双TNS0；50匹配0忽略、20FIFO及64时间Gray与实际V2/C12审计PASS")
record.write_text(record_text,encoding='utf8')
copy(record,release/'handoff'/record.name)
for p in (repo/'validation').glob('*'):
 if p.is_file() and p.name!='delivery_receipt.json':copy(p,release/'evidence'/p.name)
for p in work.rglob('*'):
 if not p.is_file():continue
 rel=p.relative_to(work)
 if rel.parts[0] in ('project','temp'):continue
 copy(p,release/'evidence/physical'/rel)
for p in (work/'project/classified_audit').rglob('*'):
 if p.is_file():copy(p,release/'evidence/physical/classified_audit'/p.relative_to(work/'project/classified_audit'))
copy(work/'frozen_inputs.json',release/'SOURCE_SHA256.json')
write(release/'VERIFICATION.json',{'status':'PASS_CURRENT_SOURCE_NINE_SOFTWARE_CONTRACTS_AND_ROUTED_AUDIT','tests':selected,'physical':physical,'baseline_commit':'904a2bb053a9e679b3f50378ca3163a55698b20e','changed':sorted(changed),'board_operated':False,'committed':False,'pushed':False})
guide=f'''# RL7 AlarmRoles V3 + 仅空穴自动停车 v1（2026-11-02）

镜像：{name}.bit；SHA-256：{digest}

基于远端codex/rl7-v3-alarm-roles / 904a2bb053a9e679b3f50378ca3163a55698b20e。
只改top、ISP参数传递和停车控制器。EMPTY_ONLY_STOP生产默认1；
持续丢失、关联异常、图像/位置过期及运行超时只记录，不触发故障停车，
也取消原找回期间的500ms停车。故障不弹未完成队列，不算补件完成。
原识别失锁后可能没有可靠空穴事件或位置，本版不猜测、不修编号/识别算法。

真实EMPTY仍按原左补件窗口72..232、触发184定位停车，稳定后完整1秒再继续。
第五连续EMPTY仍锁存停车和蜂鸣；PRESENT打断连续空累计。
K1新RUN、K2暂停/继续、K3清零停止、K4停止保留结果、SW3语义保持。
人工暂停/停止和复位仍能关闭送料。故障中断的HOLD不会伪报完成，
可靠同ID位置回来后重新确认并完整保持。

由人操作：
1. 保存旧镜像，先用TD打开Programmer，通过JTAG选择本bit执行SRAM下载；本助手未烧录。
2. 保持原接线与SW5 FPGA控制档；界面沿用RL7，请以本文件名和SHA区分版本。
3. 用有件带验证正常送料，模拟持续无可靠检测/关联异常，确认不会锁存故障停车；
   检查人工K2/K4仍可停止，K3清零停止。
4. 清零新RUN后用已知空穴排列，检查单/相邻空穴到站保持完整1秒；
   4空不报警、第五连续空报警停车蜂鸣、4空-P-4空不累计。
5. 记录实际总数、空穴号和视频；现场测试始终固定同一镜像，勿边测边换。

保留V3独立报警账本、无效序列使观察器失效规则和送料孔标签过滤，首次异常上下文保留。

软件：新20940检查、旧65控制/27按键、生产100MHz完整100000000拍一秒、
原生12RAW/{rasters}显示栅格/{pixels}实际像素视频回归。另有V3原报警/标签边界/无P全空RGB四合同。全部本轮实际运行；未重跑基线全部35合同。
Routed：Slice {physical['resources']['slice']}/21216，ERAM98/108，DSP30/40，PLL5/6；
setup {physical['timing_ns']['SWNS']:+.3f}ns、hold {physical['timing_ns']['HWNS']:+.3f}ns，双TNS0；
50最大延迟匹配/忽略0、20FIFO Gray和64时间Gray、控制邮箱/按键/V2/C12审计通过。
原工具PLL/DDR/I/O告警边界保留，不声称零告警或实板通过。未提交、未推送。

完整源在fpga/component_inspector；冻结清单SOURCE_SHA256.json。跨机重建时先运行
该目录tools/prepare_portable_project.py，使用--source指向冻结源、--manifest指向
SOURCE_SHA256.json、--work指定新的英文无空格目录、--td指向本机TD安装；
工具只在新工作副本重定位，原冻结文件保留。evidence包含日志/实际DB/约束审计，
baseline包含本次3个原源和完整基线SHA清单。本次交付回执优先于handoff内封包前进度快照。
'''
(release/(name+'_烧录与验收.md')).write_text(guide,encoding='utf8')
files={p.relative_to(release).as_posix():sha(p) for p in release.rglob('*') if p.is_file()}
write(release/'PAYLOAD_SHA256.json',files)
archive=release.with_name(name+'_full.zip');assert not archive.exists()
with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as z:
 for p in release.rglob('*'):
  if p.is_file():z.write(p,p.relative_to(release).as_posix())
unpack=repo/'release/independent_unpack';assert not unpack.exists();unpack.mkdir()
with zipfile.ZipFile(archive) as z:
 assert z.testzip() is None;assert set(z.namelist())==set(files)|{'PAYLOAD_SHA256.json'};z.extractall(unpack)
for rel,d in files.items():assert sha(unpack/rel)==d,rel
for rel,d in source.items():assert sha(unpack/'fpga/component_inspector'/rel)==d,rel
# Exercise portable project preparation from the independently recovered tree.
portable=repo/'release/portable_check'
result=subprocess.run([sys.executable,str(unpack/'fpga/component_inspector/tools/prepare_portable_project.py'),'--source',str(unpack/'fpga/component_inspector'),'--manifest',str(unpack/'SOURCE_SHA256.json'),'--work',str(portable),'--td','D:/td6.2.1'],capture_output=True,text=True)
(repo/'validation/portable_check.log').write_text(result.stdout+result.stderr,encoding='utf8');assert result.returncode==0,result.stderr
desktop_items=[(release/(name+'.bit'),desktop/(name+'.bit')),(archive,desktop/(name+'_full.zip')),(release/(name+'_烧录与验收.md'),desktop/(name+'_烧录与验收.md'))]
for original,target in desktop_items:
 assert not target.exists(),target;copy(original,target);assert sha(original)==sha(target)
sha_file=desktop/(name+'_SHA256.txt');assert not sha_file.exists()
sha_file.write_text('\n'.join(sha(p)+'  '+p.name for _,p in desktop_items)+'\n',encoding='utf8')
with zipfile.ZipFile(desktop/(name+'_full.zip')) as z:
 for rel,d in files.items():assert hashlib.sha256(z.read(rel)).hexdigest()==d,rel
receipt={'status':'DELIVERED_CURRENT_SOURCE_AUDITED_CANDIDATE_NOT_BOARD_ACCEPTED','desktop_bit':str(desktop/(name+'.bit')),'bit_sha256':digest,'desktop_zip':str(desktop/(name+'_full.zip')),'zip_sha256':sha(desktop/(name+'_full.zip')),'guide':str(desktop/(name+'_烧录与验收.md')),'sources':638,'payload_files':len(files),'software_tests':9,'physical':physical['resources'],'timing_ns':physical['timing_ns'],'independent_unzip_all_sha256':True,'portable_preparation_pass':True,'desktop_all_zip_payload_verified':True,'board_operated':False,'committed':False,'pushed':False}
write(repo/'validation/delivery_receipt.json',receipt);write(desktop/(name+'_交付回执.json'),receipt)
assert load(desktop/(name+'_交付回执.json'))==receipt
print(json.dumps(receipt,ensure_ascii=False,indent=2),flush=True)
