"""Freeze D1 recognition-only release after exact-input checks and routed audit."""
from pathlib import Path
import argparse,hashlib,json,re,subprocess,zipfile
from publish_r22_shift_alarm_v7 import sha,load,write,copy,passed,git_source_audit

def main():
 a=argparse.ArgumentParser();a.add_argument('--work',type=Path,required=True);a.add_argument('--check-only',action='store_true');args=a.parse_args()
 repo=Path(__file__).resolve().parents[1];w=args.work.resolve();p=w/'project';tmp=Path('E:/2026FPGA/.codex_tmp')
 source=load(w/'frozen_inputs.json');oldrelease=repo/'releases/r22_relay_shift_alarm_v7_20261028';old=load(oldrelease/'SOURCE_SHA256.json')
 changed=[rel for rel in old if source.get(rel)!=old[rel]];added=set(source)-set(old)
 expected=['user_source/hdl_source/'+n+'.v' for n in ['design_top_wrapper','isp/isp_top','pocket_run_controls','classified_dual_page_osd','compact_inspector_osd']]
 assert len(source)==637 and set(old)<=set(source) and set(changed)==set(expected) and added=={'td_project/camera_to_dsi_recognition.sdc'},(changed,added)
 for rel,d in source.items():assert sha(p/rel)==sha(repo/'fpga/component_inspector'/rel)==d,rel
 for rel in ['user_source/constraints_source/pin.adc','td_project/camera_to_dsi_display.sdc','user_source/hdl_source/frame_shape_search.v','user_source/hdl_source/inspection_region_config.v']:
  assert source[rel]==old[rel],rel
 assert all(source[rel]==old[rel] for rel in old if 'SC500GainTbl' in rel)
 top=(p/'user_source/hdl_source/design_top_wrapper.v').read_text(encoding='utf8')
 assert 'DUAL_RECOGNITION_ONLY=1,' in top and '.MANUAL_ONLY(DUAL_RECOGNITION_ONLY)' in top
 body='reg motor_output;'+top.split('reg motor_output;',1)[1].split('assign O_relay_control=motor_output;',1)[0]+'assign O_relay_control=motor_output;'
 assert body in (repo/'tests/dual_recognition_d1/extracted_dual_motor.sv').read_text()
 git_source_audit(repo,source)
 groups=[(tmp/'dual_d1_initial_r2_20261029','dual_recognition_d1'),(tmp/'dual_d1_osd_r3_20261029','dual_recognition_d1'),(tmp/'dual_d1_compat_r1_20261029',None),(tmp/'dual_d1_osd_compat_r1_20261029','shift_alarm_v7')]
 selected=[]
 for folder,fixture in groups:
  proof=load(folder/'verification.json');assert proof['status']=='PASS'
  for rel,d in proof['inputs'].items():assert source[rel]==d,(folder,rel)
  for rel,d in proof['extra_inputs'].items():assert fixture and sha(repo/'tests'/fixture/Path(rel).name)==d
  for rel,d in {**proof['inputs'],**proof['extra_inputs']}.items():assert sha(folder/'inputs'/Path(rel).name)==d
  for t in proof['tests']:
   log=folder/(t['name']+'.log');assert sha(log)==t['sha256'];passed(log)
   selected.append({'name':t['name'],'group':folder.name,'mode':'NEW_RUN','log_sha256':sha(log)})
 assert len(selected)==5
 native=tmp/'dual_d1_native_r3_20261029';n=load(native/'verification.json');assert n['status']=='PASS'
 for rel,d in n['inputs'].items():assert source[rel]==d and sha(native/'inputs/project'/rel)==d
 for rel,d in n['extra_inputs'].items():assert sha(repo/'tests/dual_recognition_d1'/Path(rel).name)==d and sha(native/'inputs/project'/rel)==d
 for rel,d in n['vendor'].items():assert sha(native/'inputs/vendor'/rel)==d
 assert sha(native/'console.log')==n['console_sha256'];passed(native/'console.log','PASS DUAL RECOGNITION NATIVE:')
 selected.append({'name':n['name'],'group':native.name,'mode':'NEW_RUN','log_sha256':n['console_sha256'],'scope':'7 RAW10 complete sources including first; 14 displayed rasters, 13088282 exact pixels; both-region tuples; WB-canceled live video; no count/auto. Native P test, not optical E recall.'})
 gate=tmp/'dual_d1_camera_r1_20261029';g=load(gate/'verification.json');assert g['status']=='PASS'
 assert sha(w/'d1_camera_gate.v')==g['gate_netlist_sha256'] and g['cone_closure']['all_other_consumed_nets_have_selected_cell_drivers']
 for name,d in g['simulation_input_sha256'].items():assert sha(gate/'inputs'/name)==d
 for t in g['tests']:
  log=gate/(t['name']+'.log');assert sha(log)==t['log_sha256'];passed(log,'PASS CAMERA GATE BUS:')
  selected.append({'name':t['name'],'group':gate.name,'mode':'NEW_RUN','log_sha256':sha(log),'scope':'Actual synthesized camera cone; two resets x126 serialized I2C writes; modeled ACK slave, not optical readback.'})
 legacy=[];sentinels=dict(re.findall(r'Name="([^"]+)";\s*Pass="([^"]+)"',(p/'sim/run_modelsim.ps1').read_text(encoding='utf8')))
 for name in ['regions','text_plane_prefetch','empty_trace_abort']:
  folder=p/'sim/modelsim_work'/name;passed(folder/'console.log',sentinels[name]);compiled={}
  cl=(folder/'compile.log').read_text(encoding='utf-8-sig');assert not re.search(r'\*\* (?:Fatal|Error):|Errors:\s*[1-9]',cl)
  for line in cl.splitlines():
   if 'vlog ' in line and '-work' in line:
    for token in line.split():
     token=token.strip('"')
     if token.endswith(('.v','.sv')):
      f=(p/'sim'/token).resolve();rel=f.relative_to(p).as_posix();assert sha(f)==source[rel];compiled[rel]=source[rel]
  assert compiled,name
  legacy.append({'name':name,'mode':'NEW_RUN','inputs':compiled,'compile_sha256':sha(folder/'compile.log'),'log_sha256':sha(folder/'console.log')})
 assert len(selected)+len(legacy)==10
 physical=load(w/'physical_verification.json');build=load(w/'build_result.json')
 assert physical['status'].startswith('PASS_DUAL_RECOGNITION_46_') and physical['max_delays_matched']==46 and physical['max_delays_ignored']==0 and physical['gray_bits_dominating']==20
 assert not physical['counting_instantiated'] and not physical['auto_parking_instantiated']
 assert all(physical['timing_ns'][k]>=0 for k in ['SWNS','HWNS','STNS','HTNS'])
 bit=w/'runs/phy_1/camera_to_dsi_display.bit';assert sha(bit)==build['bit_sha256']==physical['bit_sha256']
 protected=Path('E:/2026FPGA/BIT_FLASH/LATEST_READONLY.bit');protected_sha='30d067cef0667893fe548ba04e423cd6618b76f119cb2e0ecf48b96ba6a5b20f'
 oldbit=Path('E:/2026FPGA/BIT_FLASH/R22_RelayAuto_Left_V7_ShiftAlarm_20261028.bit');oldsha='3b1c6ebc6a67c0e791827eba011e7890bdcc850b41a3eadf02cd9a3fb24a1750'
 assert sha(protected)==protected_sha and sha(oldbit)==oldsha
 name='R22_DualROI_Recognition_D1_20261029';release=repo/'releases/r22_dual_recognition_d1_20261029';archive=release.with_suffix('.zip');flash=Path('E:/2026FPGA/BIT_FLASH')/(name+'.bit')
 assert not release.exists() and not archive.exists() and not flash.exists()
 if args.check_only:
  print(json.dumps({'status':'READY_TO_PUBLISH','fresh_selected_checks':10,'changed_production_files':changed,'added':list(added),'bit_sha256':sha(bit),'resources':physical['resources'],'timing_ns':physical['timing_ns']},indent=2));return
 release.mkdir(parents=True)
 for rel in source:copy(p/rel,release/'project'/rel)
 write(release/'SOURCE_SHA256.json',source);copy(repo/'releases/r22_20261027/frozen_inputs.json',release/'baseline/r22_frozen_inputs.json');copy(oldrelease/'SOURCE_SHA256.json',release/'baseline/rl7_source_sha256.json')
 for fixture in ['dual_recognition_d1','camera_gain_fix']:
  for f in (repo/'tests'/fixture).iterdir():
   if f.is_file():copy(f,release/'tests'/fixture/f.name)
 for folder,_ in groups+[(native,None),(gate,None)]:
  for f in folder.rglob('*'):
   if f.is_file() and ('inputs' in f.relative_to(folder).parts or f.suffix in ['.json','.log']):copy(f,release/'tests'/folder.name/f.relative_to(folder))
 for t in legacy:
  for fname in ['compile.log','console.log']:copy(p/'sim/modelsim_work'/t['name']/fname,release/'tests/legacy'/t['name']/fname)
 # First-frame fixture assumption failures, deliberately separate from PASS.
 for dirname in ['dual_d1_native_r1_20261029','dual_d1_native_probe_r2_20261029','dual_d1_baseline_probe_r1_20261029']:
  for f in (tmp/dirname).iterdir():
   if f.is_file() and f.suffix in ['.log','.json']:copy(f,release/'diagnostics/not_selected'/dirname/f.name)
 write(release/'diagnostics/not_selected/README.json',{'status':'DIAGNOSTIC_NOT_PASS','finding':'Original RL7 and D1 both produce complete valid first frame. Final fixture requires full video proof for all 7 frames; no first-frame exemption. Failed old warm-up assumption is not a production regression.'})
 copy(repo/'docs/R22_DUAL_RECOGNITION_D1_FIELD_GUIDE.md',release/'FIELD_GUIDE.md');copy(repo/'docs/R22_DUAL_RECOGNITION_D1_INTERFACE.md',release/'INTERFACE.md');copy(repo/'docs/evidence/dual_recognition_d1/simulated_osd.png',release/'SIMULATED_OSD.png')
 for script in ['build_r22_relay.py','audit_dual_recognition.py','relay_left_checks.py','relay_left_native_check.py','check_camera_gain_fix.py','publish_dual_recognition.py','publish_r22_shift_alarm_v7.py']:
  copy(repo/'scripts'/script,release/'scripts'/script)
 copy(w/'d1_camera_gate.v',release/'build/d1_camera_gate.v')
 for f in w.iterdir():
  if f.is_file() and f.suffix in ['.json','.py','.tcl','.log']:copy(f,release/'build'/f.name)
 for stage in ['syn_1','phy_1']:
  for f in (w/'runs'/stage).iterdir():
   if f.is_file() and (f.suffix in ['.log','.cfg','.tcl','.prj','.rpt','.area','.timing','.db'] or f.name=='constraint_coverage.txt'):copy(f,release/'build/runs'/stage/f.name)
 for directory in ['classified_audit','gray_packing_audit']:
  for f in (p/directory).iterdir():
   if f.is_file():copy(f,release/'build'/directory/f.name)
 verification={'status':'PASS_10_FRESH_SELECTED_CHECKS_AND_ROUTED_AUDIT','selected':selected,'legacy':legacy,'physical':physical,'changed_production_files':changed,'added_production_files':list(added),'unchanged_source_files':631,'source_git_blob_audit':'ALL_637_MATCH_HEAD','board_operated':False,'hardware_recognition_acceptance':False,'dual_counting_implemented':False,'auto_parking_enabled':False,'known_boundary':'Existing white3528 recipe only; weak RAW reflected-hole miss not repaired; no arbitrary speed or optical recall claim. Old automatic-mode global ID/high-speed boundary not addressed. This release has no counting instances.'}
 write(release/'VERIFICATION.json',verification);copy(bit,release/(name+'.bit'))
 receipt={'version':name,'branch':'codex/r22-dual-recognition-d1','source_commit':subprocess.check_output(['git','rev-parse','HEAD'],cwd=repo,text=True).strip(),'parent_archive_commit':'a716eac','source_worktree':str(repo),'build_work':str(w),'pushed':False,'bit_sha256':sha(bit),'bit_bytes':bit.stat().st_size,'td_version':'V6.2.168116','seed':2,'resources':physical['resources'],'slice_percent':physical['slice_percent'],'timing_ns':physical['timing_ns'],'source_files':637,'hardware_dependencies':105,'parameters':{'DUAL_RECOGNITION_ONLY':1,'ROI1_X':[400,880],'ROI1_Y':[240,400],'ROI2_X':[400,880],'ROI2_Y':[432,600],'bounds':'half-open 1280x720 processing pixels','internal_candidates_per_roi':4,'visible_results_per_roi':2,'frame_meta_bits':631,'counting':False,'auto_parking':False,'five_empty_alarm':False},'gpio':'right J2 pin1/V2 HIGH; board5V supply; original ADC; no LED','keys':'K1 manual run / K2 pause-run / K3 or K4 stop / SW3 up stop, falling edge run','constraint_profile':'camera_to_dsi_recognition.sdc: only 3 inactive count-live mailbox bounds omitted; original SDC unchanged','source_manifest_sha256':sha(release/'SOURCE_SHA256.json'),'verification_sha256':sha(release/'VERIFICATION.json'),'board_acceptance':'PENDING_HUMAN_TWO_ROI_RECOGNITION_TEST'}
 write(release/'RELEASE.json',receipt)
 (release/'README.md').write_text('D1 recognition-only upper/lower ROIs, R22 classifier preserved. No dual counting, IDs, automatic parking or five-empty alarm active. K1 run, K2 pause/run, K3/K4 stop; V2 unchanged. FIELD_GUIDE.md and INTERFACE.md describe coordinates, manual motor and qualified candidate contract. 637 frozen files/105 hardware dependencies; 10 fresh checks + strict routed audit; hardware test pending. Rebuild to a NEW ASCII folder: python scripts/build_r22_relay.py --keys-v3 --recognition-only --source project --baseline-manifest baseline/r22_frozen_inputs.json --work E:/2026FPGA/D1_rebuild --td E:/TD ; then python scripts/audit_dual_recognition.py --work same_path. Preserve frozen original and prior RL7. SIMULATED_OSD.png is a test raster, not a board photo.\n',encoding='utf8')
 payload={f.relative_to(release).as_posix():{'bytes':f.stat().st_size,'sha256':sha(f)} for f in release.rglob('*') if f.is_file()};write(release/'PAYLOAD_SHA256.json',payload)
 with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as z:
  for f in release.rglob('*'):
   if f.is_file():z.write(f,f.relative_to(release).as_posix())
 with zipfile.ZipFile(archive) as z:
  assert z.testzip() is None and set(z.namelist())==set(payload)|{'PAYLOAD_SHA256.json'}
  for rel,row in payload.items():assert hashlib.sha256(z.read(rel)).hexdigest()==row['sha256']
 copy(release/(name+'.bit'),flash);copy(release/'FIELD_GUIDE.md',flash.with_name(name+'_说明.md'))
 write(flash.with_name(name+'_RELEASE.json'),{**receipt,'release_directory':str(release),'archive':str(archive),'archive_sha256':sha(archive)})
 assert sha(flash)==sha(bit) and sha(protected)==protected_sha and sha(oldbit)==oldsha
 delivery={'status':'DELIVERED_FOR_HUMAN_DUAL_RECOGNITION_TEST','release':str(release),'archive':str(archive),'archive_sha256':sha(archive),'flash_copy':str(flash),'bit_sha256':sha(bit),'payload_count':len(payload),'fresh_selected_checks':10}
 write(repo/'docs/R22_DUAL_RECOGNITION_D1_DELIVERY.json',delivery);print(json.dumps(delivery,indent=2),flush=True)
if __name__=='__main__':main()
