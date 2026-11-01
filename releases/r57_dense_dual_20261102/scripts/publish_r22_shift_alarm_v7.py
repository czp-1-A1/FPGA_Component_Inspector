"""Seal RL7 only after exact frozen-input tests and strict physical audit."""
from pathlib import Path
import argparse,hashlib,json,re,shutil,subprocess,zipfile

def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def load(p):return json.loads(p.read_text(encoding='utf8'))
def write(p,obj):
 p.parent.mkdir(parents=True,exist_ok=True);p.write_text(json.dumps(obj,indent=2,ensure_ascii=False)+'\n',encoding='utf8')
def copy(s,d):d.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(s,d)
def passed(p,sentinel='PASS '):
 s=p.read_text(encoding='utf-8-sig');assert sentinel in s and not re.search(r'\*\* (?:Fatal|Error):|Errors:\s*[1-9]',s),p
def git_source_audit(repo,source):
 paths=['fpga/component_inspector/'+p for p in source]
 data=subprocess.check_output(['git','cat-file','--batch'],input=('\n'.join('HEAD:'+p for p in paths)+'\n').encode(),cwd=repo)
 offset=0
 for rel in source:
  end=data.index(b'\n',offset);header=data[offset:end].split();assert header[1]==b'blob',header
  size=int(header[2]);blob=data[end+1:end+1+size];offset=end+size+2
  assert hashlib.sha256(blob).hexdigest()==source[rel],('Git HEAD differs from frozen production',rel)
 assert offset==len(data)

def main():
 a=argparse.ArgumentParser();a.add_argument('--work',type=Path,required=True);a.add_argument('--check-only',action='store_true');args=a.parse_args()
 repo=Path(__file__).resolve().parents[1];work=args.work.resolve();project=work/'project';tmp=Path('E:/2026FPGA/.codex_tmp')
 oldrelease=repo/'releases/r22_relay_adjacent_v6_20261028';source=load(work/'frozen_inputs.json');old=load(oldrelease/'SOURCE_SHA256.json')
 changed=[p for p in source if source[p]!=old[p]]
 expected=['user_source/hdl_source/'+n+'.v' for n in ['classified_dual_page_osd','compact_inspector_osd','design_top_wrapper','isp/isp_top','pocket_relay_stop_v2']]
 assert len(source)==636 and set(source)==set(old) and set(changed)==set(expected),changed
 for rel,d in source.items():assert sha(project/rel)==sha(repo/'fpga/component_inspector'/rel)==d,rel
 for rel in ['user_source/constraints_source/pin.adc','td_project/camera_to_dsi_display.sdc','user_source/hdl_source/sensor_config/SC500GainTbl.v']:
  if rel in source:assert source[rel]==old[rel],rel
 assert all(source[p]==old[p] for p in source if 'SC500GainTbl' in p)
 top=(project/'user_source/hdl_source/design_top_wrapper.v').read_text(encoding='utf8')
 assert 'FIVE_EMPTY_V7=1,' in top and 'RELAY_TARGET_X=152,' in top and 'ENABLE_AUTO_RELAY && !relay_alarm &&' in top and 'ADJACENT_V6=1,' in top and 'RELAY_TOL_PX=80,' in top and '.WIDTH(163)) u_relay_display' in top
 body='reg motor_output;'+top.split('reg motor_output;',1)[1].split('assign O_relay_control=motor_output;',1)[0]+'assign O_relay_control=motor_output;'
 helper=(repo/'tests/shift_alarm_v7/extracted_production_motor.sv').read_text()
 assert body in helper and 'wire relay_auto=relay_mode==1 || relay_mode==2;' in top and 'wire relay_paused=relay_mode==2;' in top

 git_source_audit(repo,source)
 groups=[(tmp/'r22_v7_final_units_r2_20261028','shift_alarm_v7'),(tmp/'r22_v7_alarm_control_r2_20261028','shift_alarm_v7'),(tmp/'r22_v7_final_rgb_r3_20261028','shift_alarm_v7'),(tmp/'r22_v7_rgb_alarm_r1_20261028','shift_alarm_v7'),(tmp/'r22_v7_final_compat_r1_20261028',None)]
 selected=[]
 for folder,fixture in groups:
  proof=load(folder/'verification.json');assert proof['status']=='PASS'
  for rel,d in proof['inputs'].items():assert source[rel]==d,(folder,rel)
  for rel,d in proof['extra_inputs'].items():assert fixture and sha(repo/'tests'/fixture/Path(rel).name)==d
  for rel,d in {**proof['inputs'],**proof['extra_inputs']}.items():assert sha(folder/'inputs'/Path(rel).name)==d
  for test in proof['tests']:
   log=folder/(test['name']+'.log');assert sha(log)==test['sha256'];passed(log)
   selected.append({'name':test['name'],'group':folder.name,'log_sha256':sha(log),'mode':'NEW_RUN'})
 assert len(selected)==22 and len({t['name'] for t in selected})==22
 native=tmp/'r22_v7_final_native_r1_20261028';n=load(native/'verification.json');assert n['status']=='PASS'
 for rel,d in n['inputs'].items():assert source[rel]==d
 for rel,d in n['extra_inputs'].items():assert sha(repo/'tests/shift_alarm_v7'/Path(rel).name)==d and sha(native/'inputs/project'/rel)==d
 assert sha(native/'console.log')==n['console_sha256'];passed(native/'console.log','PASS V3_NATIVE_MODE1:')
 selected.append({'name':n['name'],'group':'native','log_sha256':n['console_sha256'],'mode':'NEW_RUN','scope':'V7 enabled, target152/tolerance80; 12 native RAW10/24 exact displayed rasters. RAW does NOT reach the parking line; parking proven separately.'})
 gate=tmp/'r22_v7_camera_gate_r1_20261028';g=load(gate/'verification.json');assert g['status']=='PASS'
 assert sha(work/'v7_camera_gate.v')==g['gate_netlist_sha256'] and g['cone_closure']['all_other_consumed_nets_have_selected_cell_drivers']
 for test in g['tests']:
  log=gate/(test['name']+'.log');assert sha(log)==test['log_sha256'];passed(log,'PASS CAMERA GATE BUS:')
  selected.append({'name':test['name'],'group':'camera_gate','log_sha256':sha(log),'mode':'NEW_RUN','scope':'Actual synthesized full camera cone, 2 resets x126 serialized writes, modeled ACK slave; not optical readback'})
 legacy=[];sentinels=dict(re.findall(r'Name="([^"]+)";\s*Pass="([^"]+)"',(project/'sim/run_modelsim.ps1').read_text(encoding='utf8')))
 for name in ['classified_counter','result_recorder_pipeline','local_pipeline','switch_recorder_controls','recovery_protection','simple_recovery_ui','text_plane_prefetch']:
  folder=project/'sim/modelsim_work'/name;passed(folder/'console.log',sentinels[name]);compiled={}
  cl=(folder/'compile.log').read_text(encoding='utf-8-sig');assert not re.search(r'\*\* (?:Fatal|Error):|Errors:\s*[1-9]',cl)
  for line in cl.splitlines():
   if 'vlog ' in line and '-work' in line:
    for token in line.split():
     token=token.strip('"')
     if token.endswith(('.v','.sv')):
      p=(project/'sim'/token).resolve();rel=p.relative_to(project).as_posix();assert sha(p)==source[rel];compiled[rel]=source[rel]
  assert compiled,name
  legacy.append({'name':name,'mode':'NEW_RUN','inputs':compiled,'compile_sha256':sha(folder/'compile.log'),'log_sha256':sha(folder/'console.log')})
 assert len(selected)+len(legacy)==31
 boundary=tmp/'r22_v6_highspeed_boundary_20261028'
 assert load(boundary/'VERDICT.json')['status']=='KNOWN_INHERITED_BOUNDARY_NOT_SELECTED_PASS'
 assert load(boundary/'v6_failure.json')['failure']==load(boundary/'rl5_failure.json')['failure']
 physical=load(work/'physical_verification.json');build=load(work/'build_result.json')
 assert physical['status'].startswith('PASS_R22_RELAY_V7_ROUTED_') and physical['max_delays_matched']==49 and physical['max_delays_ignored']==0
 assert physical['alarm_interlock_routed'] and physical['alarm_interlock_packed_cell_proof']['actual_alarm_Q_and_registered_motor_LUT']
 assert physical['control_mailbox_bits']==20 and physical['relay_display_declared_bits']==163
 assert all(physical['timing_ns'][k]>=0 for k in ['SWNS','HWNS','STNS','HTNS'])
 bit=work/'runs/phy_1/camera_to_dsi_display.bit';assert sha(bit)==build['bit_sha256']==physical['bit_sha256']
 protected=Path('E:/2026FPGA/BIT_FLASH/LATEST_READONLY.bit');protected_sha='30d067cef0667893fe548ba04e423cd6618b76f119cb2e0ecf48b96ba6a5b20f';assert sha(protected)==protected_sha
 oldbit=Path('E:/2026FPGA/BIT_FLASH/R22_RelayAuto_Left_V6_Adjacent_20261028.bit');assert sha(oldbit)=='7a6c18f56d90f0b2743d544a55bb4167882f4dbb930095b847f4372355ff20bd'
 name='R22_RelayAuto_Left_V7_ShiftAlarm_20261028';release=repo/'releases/r22_relay_shift_alarm_v7_20261028';archive=release.with_suffix('.zip');flash=Path('E:/2026FPGA/BIT_FLASH')/(name+'.bit')
 assert not release.exists() and not archive.exists() and not flash.exists()
 if args.check_only:
  print(json.dumps({'status':'READY_TO_PUBLISH','fresh_selected_checks':31,'changed_production_files':changed,'bit_sha256':sha(bit),'resources':physical['resources'],'timing_ns':physical['timing_ns']},indent=2));return
 release.mkdir(parents=True)
 for rel in source:copy(project/rel,release/'project'/rel)
 write(release/'SOURCE_SHA256.json',source);copy(repo/'releases/r22_20261027/frozen_inputs.json',release/'baseline/r22_frozen_inputs.json')
 for fixture in ['shift_alarm_v7','camera_gain_fix']:
  for p in (repo/'tests'/fixture).iterdir():
   if p.is_file():copy(p,release/'tests'/fixture/p.name)
 for folder,_ in groups+[(native,None),(gate,None)]:
  for p in folder.rglob('*'):
   if p.is_file() and ('inputs' in p.relative_to(folder).parts or p.suffix in ['.json','.log']):copy(p,release/'tests'/folder.name/p.relative_to(folder))
 for item in legacy:
  for f in ['compile.log','console.log']:copy(project/'sim/modelsim_work'/item['name']/f,release/'tests/legacy'/item['name']/f)
 # Keep inherited failed trials explicitly apart from the selected PASS set.
 for p in (oldrelease/'field_evidence/inherited_negative_and_boundary').rglob('*'):
  if p.is_file():copy(p,release/'field_evidence/inherited_negative_and_boundary'/p.relative_to(oldrelease/'field_evidence/inherited_negative_and_boundary'))
 for p in boundary.rglob('*'):
  if p.is_file() and (p.suffix in ['.json','.log','.v','.sv']):copy(p,release/'field_evidence/highspeed_boundary'/p.relative_to(boundary))
 for p in (repo/'docs/evidence/r22_rl6_shift_20261028').rglob('*'):
  if p.is_file():copy(p,release/'field_evidence/rl6_common_slow'/p.relative_to(repo/'docs/evidence/r22_rl6_shift_20261028'))
 for p in (repo/'docs/evidence/r22_shift_alarm_v7_rtl_20261028').rglob('*'):
  if p.is_file():copy(p,release/'field_evidence/rl7_simulated_raster'/p.relative_to(repo/'docs/evidence/r22_shift_alarm_v7_rtl_20261028'))
 for name2 in ['R22_V7_FIELD_ANALYSIS.md','R22_V7_FIELD_ANALYSIS.json']:copy(repo/'docs'/name2,release/'field_evidence'/name2)
 copy(repo/'docs/R22_SHIFT_ALARM_V7_FIELD_GUIDE.md',release/'FIELD_GUIDE.md');copy(oldrelease/'WEAK_NATIVE_BOUNDARY.json',release/'WEAK_NATIVE_BOUNDARY.json')
 for script in ['build_r22_relay.py','audit_r22_relay.py','relay_left_checks.py','relay_left_native_check.py','check_camera_gain_fix.py','publish_r22_shift_alarm_v7.py']:
  copy(repo/'scripts'/script,release/'scripts'/script)
 copy(work/'v7_camera_gate.v',release/'build/v7_camera_gate.v')
 for p in work.iterdir():
  if p.is_file() and p.suffix in ['.json','.py','.tcl','.log']:copy(p,release/'build'/p.name)
 for stage in ['syn_1','phy_1']:
  for p in (work/'runs'/stage).iterdir():
   if p.is_file() and (p.suffix in ['.log','.cfg','.tcl','.prj','.rpt','.area','.timing','.db'] or p.name=='constraint_coverage.txt'):copy(p,release/'build/runs'/stage/p.name)
 for directory in ['classified_audit','gray_packing_audit']:
  for p in (project/directory).iterdir():
   if p.is_file():copy(p,release/'build'/directory/p.name)
 verification={'status':'PASS_31_FRESH_SELECTED_CHECKS_AND_ROUTED_AUDIT','selected':selected,'legacy':legacy,'physical':physical,'changed_production_files':changed,'unchanged_source_files':631,'source_git_blob_audit':'ALL_636_MATCH_HEAD','board_operated':False,'new_board_parking_acceptance':False,'precision_1mm_acceptance':False,'automatic_speed_compensation':False,'actual_refill_actuator_implemented':False,'known_boundary':'Inherited weak RAW280 miss and unnumbered upstream-gap protection remain. Abrupt24px/source with40px pitch fails global event class order identically on RL5/V6 before parking; NOT a selected pass, not arbitrary high-speed coverage. No cross-gap publication, synthetic position or silent queue skip added. Two RL6 videos finish Q00 at common/slow speed; RL7 shifted station and five-hole alarm still await human validation. Inherited high-speed failure is archived prior RL5/V6 evidence, not a new V7 selected test.'}
 write(release/'VERIFICATION.json',verification);copy(bit,release/(name+'.bit'))
 receipt={'version':name,'branch':'codex/r22-left-shift-five-empty-v7','source_commit':subprocess.check_output(['git','rev-parse','HEAD'],cwd=repo,text=True).strip(),'parent_rl6_commit':'1a82896','source_worktree':str(repo),'build_work':str(work),'pushed':False,'bit_sha256':sha(bit),'bit_bytes':bit.stat().st_size,'td_version':'V6.2.168116','seed':2,'resources':physical['resources'],'slice_percent':physical['slice_percent'],'timing_ns':physical['timing_ns'],'source_files':636,'hardware_dependencies':104,'parameters':{'window_x':[72,232],'target_x':152,'tolerance_px':80,'advance_px':32,'trigger_x':184,'hold_ms':1000,'still_px':2,'stale_ms':150,'stopped_reacquire_ms':500,'retry_per_head':1,'maximum_search_radius_px':20,'consecutive_empty_alarm':5,'alarm_fault_hex':'F','alarm_reset':'K3 clear-stop or explicit newRUN'},'gpio':'rightJ2 pin1/V2 HIGH; board5V; no LED; original ADC/SDC','layout':'single row; right count ROI + left amber acceptance box72..232; auxiliary guides hidden','keys':'K1 freshRUN / K2 pause-resume / K3 clear-stop / K4 stop / SW3 up stop down freshRUN','source_manifest_sha256':sha(release/'SOURCE_SHA256.json'),'verification_sha256':sha(release/'VERIFICATION.json'),'board_acceptance':'PENDING_HUMAN_SHIFTED_WINDOW_AND_FIFTH_EMPTY_ALARM_RETEST'}
 write(release/'RELEASE.json',receipt)
 (release/'README.md').write_text('RL7 shifted-window / fifth-consecutive-EMPTY alarm field candidate. Read FIELD_GUIDE.md: stopped next-head handover, one bounded stopped reacquisition per head, full fresh 1000ms hold after recovery, frozen diagnostic trace. Window72..232/target152/trigger184 shifted8px left; red alarm15 at fifth confirmed EMPTY, motor latched OFF; no speed adaptation. 636 frozen sources/104 hardware dependencies;31 fresh selected checks and strict routed audit. Hardware validation pending. Inherited weak RAW280 and upstream-gap boundaries remain; no ID/source/type guard bypass. Rebuild to a NEW ASCII directory: scripts/build_r22_relay.py --keys-v3 --source project --baseline-manifest baseline/r22_frozen_inputs.json --work E:/2026FPGA/RL7_rebuild --td E:/TD; then scripts/audit_r22_relay.py --keys-v3 --adjacent-v6 --five-empty-v7 --work same_path. Tests documented in tests/shift_alarm_v7/README.md. Never overwrite this frozen release.\n',encoding='utf8')
 payload={p.relative_to(release).as_posix():{'bytes':p.stat().st_size,'sha256':sha(p)} for p in release.rglob('*') if p.is_file()};write(release/'PAYLOAD_SHA256.json',payload)
 with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as z:
  for p in release.rglob('*'):
   if p.is_file():z.write(p,p.relative_to(release).as_posix())
 with zipfile.ZipFile(archive) as z:
  assert z.testzip() is None
  for rel,row in payload.items():assert hashlib.sha256(z.read(rel)).hexdigest()==row['sha256']
 copy(release/(name+'.bit'),flash);copy(release/'FIELD_GUIDE.md',flash.with_name(name+'_说明.md'))
 write(flash.with_name(name+'_RELEASE.json'),{**receipt,'release_directory':str(release),'archive':str(archive),'archive_sha256':sha(archive)})
 assert sha(flash)==sha(bit) and sha(protected)==protected_sha and sha(oldbit)=='7a6c18f56d90f0b2743d544a55bb4167882f4dbb930095b847f4372355ff20bd'
 delivery={'status':'DELIVERED_FOR_HUMAN_SHIFT_AND_FIFTH_EMPTY_RETEST','release':str(release),'archive':str(archive),'archive_sha256':sha(archive),'flash_copy':str(flash),'bit_sha256':sha(bit),'payload_count':len(payload),'fresh_selected_checks':31}
 write(repo/'docs/R22_SHIFT_ALARM_V7_DELIVERY.json',delivery);print(json.dumps(delivery,indent=2),flush=True)
if __name__=='__main__':main()
