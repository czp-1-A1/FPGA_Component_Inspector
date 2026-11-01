"""Publish AlarmRoles V3 from exact 35-check and routed evidence; preserve V2."""
from pathlib import Path
import argparse, hashlib, json, re, shutil, subprocess, zipfile

def sha(p):
 h=hashlib.sha256()
 with p.open('rb') as f:
  for b in iter(lambda:f.read(1024*1024),b''):h.update(b)
 return h.hexdigest()
def load(p):return json.loads(p.read_text(encoding='utf-8-sig'))
def write(p,d):p.parent.mkdir(parents=True,exist_ok=True);p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
def copy(s,d):d.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(s,d)
def passed(p):
 text=p.read_text(encoding='utf-8-sig')
 assert 'PASS ' in text and not re.search(r'\*\* (?:Fatal|Error):|Errors:\s*[1-9]',text),p
def git_blobs(repo,source):
 p=subprocess.Popen(['git','cat-file','--batch'],cwd=repo,stdin=subprocess.PIPE,stdout=subprocess.PIPE)
 for rel,d in source.items():
  p.stdin.write(('HEAD:fpga/component_inspector/'+rel+'\n').encode());p.stdin.flush()
  header=p.stdout.readline().decode().split();assert len(header)==3 and header[1]=='blob',(rel,header)
  blob=p.stdout.read(int(header[2]));assert p.stdout.read(1)==b'\n'
  assert hashlib.sha256(blob).hexdigest()==d,('Git HEAD/source mismatch',rel)
 p.stdin.close();assert p.wait()==0

def main():
 ap=argparse.ArgumentParser();ap.add_argument('--work',type=Path,required=True)
 ap.add_argument('--check-only',action='store_true');ap.add_argument('--software-only',action='store_true');args=ap.parse_args()
 repo=Path(__file__).resolve().parents[1];work=args.work.resolve();project=work/'project'
 tmp=Path('E:/2026FPGA/.codex_tmp');source=load(work/'frozen_inputs.json');old=load(repo/'baseline/rl7_demo_ui_opt_v2_source_sha256.json')
 assert len(source)==638 and set(source)==set(old)
 scope=load(repo/'docs/RL7_ALARM_ROLES_V3_SCOPE.json');changed=[n for n in old if source[n]!=old[n]]
 expected_changed={'user_source/hdl_source/pocket_relay_stop_v2.v','user_source/hdl_source/compact_inspector_osd.v'}
 assert set(changed)==expected_changed
 for n,d in scope['production_changes'].items():
  rel='user_source/hdl_source/'+n;assert old[rel]==d['before'] and source[rel]==d['after']
 for n,h in old.items():
  if n not in expected_changed:assert source[n]==h,('Unexpected classifier/counter/camera/latency/font/pin change',n)
 for rel in ['td_project/camera_to_dsi_display.al','td_project/camera_to_dsi_display.sdc','user_source/constraints_source/pin.adc']:
  assert sha(project/rel)==old[rel],('Original V2 project/pin/timing changed',rel)
 golden=(repo/'tests/rl7_alarm_roles_v3/compact_inspector_osd_v1_ref.v').read_bytes().replace(b'module compact_inspector_osd_v1_ref #',b'module compact_inspector_osd #',1)
 v1=load(repo/'baseline/rl7_demo_v1_source_sha256.json')
 assert hashlib.sha256(golden).hexdigest()==v1['user_source/hdl_source/compact_inspector_osd.v']
 memory=load(repo/'docs/RL7_ALARM_ROLES_V3_MEMORY_PROOF.json')
 assert memory['netlist_sha256']==sha(work/'rl7_demo_camera_gate.v')
 assert memory['total_eram']==98 and memory['font_eram']==1 and memory['bridge_eram']==4

 for n,d in source.items():assert sha(project/n)==sha(repo/'fpga/component_inspector'/n)==d,n
 assert len(load(work/'hardware_inputs.json'))==106
 git_blobs(repo,source)
 top=(project/'user_source/hdl_source/design_top_wrapper.v').read_text(encoding='utf-8')
 assert 'DEMO_UI=1,' in top and 'FIVE_EMPTY_V7=1,' in top and 'RELAY_TARGET_X=152,' in top and 'RELAY_TOL_PX=80,' in top
 assert 'ENABLE_AUTO_RELAY && !relay_alarm &&' in top and '.WIDTH(195)) u_relay_display' in top
 body='reg motor_output;'+top.split('reg motor_output;',1)[1].split('assign O_relay_control=motor_output;',1)[0]+'assign O_relay_control=motor_output;'
 for path in [repo/'tests/shift_alarm_v7/extracted_production_motor.sv',repo/'tests/demo_rl7/extracted_production_motor.sv']:
  assert body in path.read_text(),path
 assert '.alarm(relay_alarm),.O_buzzer_n(O_buzzer_n)' in top and '.capture_info(active_frame_display[FRAME_META_WIDTH+67:FRAME_META_WIDTH+3])' in top
 assert '.vs(exp_vs),.de(exp_de)' in top and '.latest_source(latest_source_display)' in top
 selected=[];groups=[
  ('rl7_alarm_roles_v3_contracts_r4_20261101','rl7_alarm_roles_v3',3),
  ('rl7_alarm_roles_v3_units_r1_20261101','demo_rl7',3),('rl7_alarm_roles_v3_extra_r1_20261101','demo_rl7',2),
  ('rl7_alarm_roles_v3_regression_r1_20261101','shift_alarm_v7',17),
  ('rl7_alarm_roles_v3_empty_rgb_r1_20261101','rl7_alarm_roles_v3',1),
  ('rl7_alarm_roles_v3_font_r1_20261101','ui_opt_v2',1)]
 for name,fixture,count in groups:
  folder=tmp/name;proof=load(folder/'verification.json');assert proof['status']=='PASS' and len(proof['tests'])==count,name
  for n,d in proof['inputs'].items():assert source[n]==d and sha(folder/'inputs'/Path(n).name)==d,(name,n)
  fixtures=proof.get('fixtures',{}) or {Path(n).name:d for n,d in proof.get('extra_inputs',{}).items()}
  for n,d in fixtures.items():assert fixture and sha(repo/'tests'/fixture/n)==sha(folder/'inputs'/n)==d,(name,n)
  for t in proof['tests']:
   log=folder/(t['name']+'.log');d=t.get('log_sha256',t.get('sha256'));assert sha(log)==d;passed(log)
   selected.append({'name':t['name'],'group':name,'log_sha256':d,'mode':('EXACT_UNCHANGED_MODULE_REUSE' if name in ['rl7_demo_alarm_r1_20261101','rl7_demo_compat_r1_20261101'] else 'NEW_RUN_ALARM_ROLES_V3')})
 gate=tmp/'rl7_alarm_roles_v3_camera_gate_r1_20261101';g=load(gate/'verification.json');assert g['status']=='PASS'
 assert sha(work/'rl7_demo_camera_gate.v')==g['gate_netlist_sha256'] and g['cone_closure']['all_other_consumed_nets_have_selected_cell_drivers']
 for test in g['tests']:
  log=gate/(test['name']+'.log');assert sha(log)==test['log_sha256'];passed(log)
  selected.append({'name':test['name'],'group':gate.name,'log_sha256':sha(log),'mode':'NEW_RUN','scope':'Actual synthesized camera cone; modeled ACK, not physical sensor readback'})
 legacy=[];sentinels=dict(re.findall(r'Name="([^"]+)";\s*Pass="([^"]+)"',(project/'sim/run_modelsim.ps1').read_text()))
 for name in ['classified_counter','result_recorder_pipeline','local_pipeline','switch_recorder_controls','recovery_protection','simple_recovery_ui','text_plane_prefetch']:
  folder=project/'sim/modelsim_work'/name;passed(folder/'console.log');compiled={}
  assert sentinels[name] in (folder/'console.log').read_text()
  cl=(folder/'compile.log').read_text();assert not re.search(r'\*\* (?:Fatal|Error):|Errors:\s*[1-9]',cl)
  for line in cl.splitlines():
   if 'vlog ' in line and '-work' in line:
    for token in line.split():
     token=token.strip('"')
     if token.endswith(('.v','.sv')):
      p=(project/'sim'/token).resolve();rel=p.relative_to(project).as_posix();assert sha(p)==source[rel];compiled[rel]=source[rel]
  assert compiled,name
  legacy.append({'name':name,'group':'legacy','inputs':compiled,'compile_sha256':sha(folder/'compile.log'),'log_sha256':sha(folder/'console.log'),'mode':'NEW_RUN'})
 assert len(selected)==28 and len(legacy)==7 and len({t['name'] for t in selected})==28
 software={'status':'PASS_35_ALARM_ROLES_V3_EXACT_SOURCE_CHECKS','selected':selected,'legacy':legacy,'source_files':638,
  'scope':scope,'board_operated':False,'new_hardware_acceptance':False,'classification_or_cold_start_fixed':False,
  'actual_refill_actuator_implemented':False,'precision_1mm_acceptance':False,
  'measurement':'FPGA decoded RAW10 SOF -> actual first valid pixel after OSD at HDMI transmitter; excludes exposure-before-SOF and panel delay'}
 software['scope_exclusions']='No new full native RAW replay counted; 636 unchanged source hashes plus fresh RGB, full-raster pixel/control, latency and actual synthesized camera checks.'
 write(work/'demo_software_verification.json',software)
 if args.software_only:print(json.dumps({'status':software['status'],'checks':35,'source_files':638}));return
 physical=load(work/'physical_verification.json');build=load(work/'build_result.json')
 assert physical['status']=='PASS_RL7_UIOPT_V2_ROUTED_50_BOUNDS_20_FIFO_GRAY_64_TIME_GRAY_KEYS_V2_C12'
 assert physical['max_delays_matched']==50 and physical['max_delays_ignored']==0 and physical['latency_gray_paths']==64
 assert physical['gray_bits_dominating']==20 and physical['control_mailbox_bits']==20 and physical['relay_display_declared_bits']==195
 assert physical['alarm_interlock_routed'] and physical['alarm_interlock_packed_cell_proof']['actual_alarm_Q_and_registered_motor_LUT']
 assert all(physical['timing_ns'][k]>=0 for k in ['SWNS','HWNS','STNS','HTNS'])
 write(work/'verification_progress.json',{'status':'COMPLETE_35_SOURCE_CHECKS_AND_ROUTED_VERIFIED','completed_checks':35,'pending_checks':['human_board_acceptance'],'board_operated':False})
 assert physical['resources']['slice']<=21216 and physical['resources']['eram']==98,'Device/memory resource guard failed'
 bit=work/'runs/phy_1/camera_to_dsi_display.bit';assert sha(bit)==build['bit_sha256']==physical['bit_sha256']
 flashdir=Path('E:/2026FPGA/BIT_FLASH');protected={
  'R22_RL7_Demo_UIOpt_V2_20261101.bit':'242b9597a6f1fe045dd9c732e56d7ab9320badce9226dcc2c3b67d5ca5593ac5',
  'R22_RL7_Demo_BuzzerLatency_V1_20261101.bit':'c25af6efc844f7d01e81d70d102ffeb4c08f04f476654c25c91c74b818ffd626',
  'LATEST_READONLY.bit':'30d067cef0667893fe548ba04e423cd6618b76f119cb2e0ecf48b96ba6a5b20f',
  'R22_RelayAuto_Left_V7_ShiftAlarm_20261028.bit':'3b1c6ebc6a67c0e791827eba011e7890bdcc850b41a3eadf02cd9a3fb24a1750'}
 for f,d in protected.items():assert sha(flashdir/f)==d,f
 name='R22_RL7_Demo_AlarmRoles_V3_20261101';release=repo/'releases/rl7_demo_alarm_roles_v3_20261101';archive=release.with_suffix('.zip');flash=flashdir/(name+'.bit')
 assert not release.exists() and not archive.exists() and not flash.exists()
 if args.check_only:print(json.dumps({'status':'READY_TO_PUBLISH','checks':35,'resources':physical['resources'],'timing_ns':physical['timing_ns'],'bit_sha256':sha(bit)},indent=2));return
 release.mkdir(parents=True)
 for rel in source:copy(project/rel,release/'project'/rel)
 copy(bit,release/(name+'.bit'));copy(repo/'docs/RL7_ALARM_ROLES_V3_FIELD_GUIDE.md',release/'FIELD_GUIDE.md')
 copy(repo/'docs/RL7_ALARM_ROLES_V3_SCOPE.json',release/'SOURCE_SCOPE.json')
 copy(repo/'docs/RL7_ALARM_ROLES_V3_MEMORY_PROOF.json',release/'MEMORY_PROOF.json')
 write(release/'SOURCE_SHA256.json',source);write(release/'VERIFICATION.json',software)
 for p in (repo/'baseline').glob('*.json'):copy(p,release/'baseline'/p.name)
 for fixture in ['demo_rl7','ui_opt_v2','rl7_alarm_roles_v3','shift_alarm_v7','camera_gain_fix']:
  for p in (repo/'tests'/fixture).iterdir():
   if p.is_file():copy(p,release/'tests'/fixture/p.name)
 for folder in [tmp/name for name,_,_ in groups]+[gate]:
  for p in folder.rglob('*'):
   if p.is_file() and p.suffix.lower() in ['.json','.log','.v','.sv','.hex'] and 'work' not in p.relative_to(folder).parts and p.name not in ['demo_rgb.hex','demo_missing_rgb.hex']:
    copy(p,release/'tests'/folder.name/p.relative_to(folder))
 for item in legacy:
  folder=project/'sim/modelsim_work'/item['name']
  for n in ['console.log','compile.log']:copy(folder/n,release/'tests/legacy'/item['name']/n)
 for n in ['run_rl7_demo_checks.py','build_r22_relay.py','audit_r22_relay.py','relay_left_checks.py','relay_left_native_check.py','check_camera_gain_fix.py','prepare_rl7_ui_opt_v2.py','run_rl7_ui_opt_v2_checks.py','publish_rl7_ui_opt_v2.py','check_rl7_alarm_roles_v3.py','publish_rl7_alarm_roles_v3.py']:
  copy(repo/'scripts'/n,release/'scripts'/n)
 for p in work.rglob('*'):
  rel=p.relative_to(work)
  if p.is_file() and rel.parts[0] not in ['project','temp'] and (p.suffix.lower() in ['.json','.log','.tcl','.cfg','.rpt','.timing','.area','.txt','.prj','.db','.v','.sv'] or p.name=='verify_relay_physical.py'):
   copy(p,release/'build'/rel)
 for n in ['demo_rgb.png']:
  if (tmp/'rl7_alarm_roles_v3_units_r1_20261101'/n).exists():copy(tmp/'rl7_alarm_roles_v3_units_r1_20261101'/n,release/'preview'/n)
 # Retain the original classification boundaries without claiming they were repaired.
 oldrel=Path('E:/2026FPGA/HANDOFF/RL7_20261031/release')
 copy(oldrel/'WEAK_NATIVE_BOUNDARY.json',release/'WEAK_NATIVE_BOUNDARY.json')
 record={'version':name,'branch':subprocess.check_output(['git','branch','--show-current'],cwd=repo,text=True).strip(),
  'source_commit':subprocess.check_output(['git','rev-parse','HEAD'],cwd=repo,text=True).strip(),'baseline':'RL7 Demo UIOpt V2 83674658 (production61829cd8)' ,
  'bit_sha256':sha(bit),'bit_bytes':bit.stat().st_size,'resources':physical['resources'],'slice_percent':physical['slice_percent'],'timing_ns':physical['timing_ns'],
  'baseline_uiopt_v2_slice':19036,'slice_delta_vs_uiopt_v2':physical['resources']['slice']-19036,'eram_delta_vs_uiopt_v2':physical['resources']['eram']-98,
  'td_version':'6.2.168116','seed':build['seed'],'source_files':638,'hardware_dependencies':106,'selected_software_checks':35,'verification_reuse':'35 fresh exact-source checks; all-empty-head RGB and alarm/fault collisions added; native RAW rerun not counted, unchanged input/DDR/time logic verified by SHA and focused latency/pixel/camera checks',
  'buzzer':'C12/O_buzzer_n/LVCMOS33/PULLUP/active-low;100MHz;2kHz;200msON300msOFF;fifth-EMPTY latch',
  'measurement':software['measurement'],'ui':'DEMO filters kind0 and off-pocket-row unknown kind1 labels; confirmed P/review/E preserved; strict independent global five-empty guard survives local faults; original thresholds/counter/parking/latency/keys unchanged',
  'board_acceptance':'PENDING_HUMAN_LIVE_IMAGE_BUZZER_LATENCY_AND_STOP_RETEST','pushed':False}
 write(release/'RELEASE.json',record)
 copy(repo/'docs/RL7_ALARM_ROLES_V3_FIELD_ANALYSIS.md',release/'FIELD_ANALYSIS.md')
 (release/'README.md').write_text('RL7 AlarmRoles V3 candidate based on UIOpt V2. Read FIELD_GUIDE.md. Independent five-empty alarm and filtered noncomponent labels; unchanged classifier thresholds/counter/parking/keys/latency/fonts.35 fresh checks including all-empty RGB; strict final routed audit. Human board acceptance pending. Previous bits retained.\n')
 payload={p.relative_to(release).as_posix():{'bytes':p.stat().st_size,'sha256':sha(p)} for p in sorted(release.rglob('*')) if p.is_file()}
 write(release/'PAYLOAD_SHA256.json',payload)
 with zipfile.ZipFile(archive,'x',compression=zipfile.ZIP_DEFLATED,compresslevel=6) as z:
  for p in sorted(release.rglob('*')):
   if p.is_file():z.write(p,p.relative_to(release).as_posix())
 with zipfile.ZipFile(archive) as z:
  assert z.testzip() is None
  for rel,d in payload.items():assert hashlib.sha256(z.read(rel)).hexdigest()==d['sha256']
 copy(release/(name+'.bit'),flash);assert sha(flash)==sha(bit)
 copy(release/'FIELD_GUIDE.md',flashdir/(name+'_说明.md'));write(flashdir/(name+'_RELEASE.json'),record)
 copy(release/'preview/demo_rgb.png',flashdir/(name+'_界面预览.png'))
 receipt={'status':'DELIVERED_FOR_HUMAN_RETEST','release':str(release),'archive':str(archive),'archive_sha256':sha(archive),
  'flash_copy':str(flash),'bit_sha256':sha(bit),'payload_count':len(payload),'selected_software_checks':35,'verification_reuse':'35 fresh exact-source checks; all-empty-head RGB and alarm/fault collisions added; native RAW rerun not counted, unchanged input/DDR/time logic verified by SHA and focused latency/pixel/camera checks','protected_bits_unchanged':True,'board_operated':False}
 for f,d in protected.items():assert sha(flashdir/f)==d
 write(repo/'docs/RL7_ALARM_ROLES_V3_DELIVERY.json',receipt);print(json.dumps(receipt,indent=2))

if __name__=='__main__':main()
