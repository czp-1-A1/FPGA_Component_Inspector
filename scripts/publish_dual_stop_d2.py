"""Freeze D2 original parking plus extra recognition release after exact-input checks and routed audit."""
from pathlib import Path
import argparse,hashlib,json,re,subprocess,zipfile
from publish_r22_shift_alarm_v7 import sha,load,write,copy,passed,git_source_audit

def main():
 a=argparse.ArgumentParser();a.add_argument('--work',type=Path,required=True);a.add_argument('--check-only',action='store_true');args=a.parse_args()
 repo=Path(__file__).resolve().parents[1];w=args.work.resolve();p=w/'project';tmp=Path('E:/2026FPGA/.codex_tmp')
 source=load(w/'frozen_inputs.json');oldrelease=repo/'releases/r22_relay_shift_alarm_v7_20261028';old=load(oldrelease/'SOURCE_SHA256.json')
 changed=[rel for rel in old if source.get(rel)!=old[rel]];added=set(source)-set(old)
 expected=['user_source/hdl_source/'+n+'.v' for n in ['design_top_wrapper','isp/isp_top','pocket_run_controls','classified_dual_page_osd','compact_inspector_osd','frame_shape_search','local_edge_surface_check']]
 assert len(source)==636 and set(source)==set(old) and set(changed)==set(expected) and not added,(changed,added)
 for rel,d in source.items():assert sha(p/rel)==sha(repo/'fpga/component_inspector'/rel)==d,rel
 for rel in ['user_source/constraints_source/pin.adc','td_project/camera_to_dsi_display.sdc','user_source/hdl_source/classified_count_pipeline.v','user_source/hdl_source/classified_pocket_counter.v','user_source/hdl_source/pocket_relay_stop_v2.v','user_source/hdl_source/inspection_region_config.v']:
  assert source[rel]==old[rel],rel
 assert all(source[rel]==old[rel] for rel in old if 'SC500GainTbl' in rel)
 top=(p/'user_source/hdl_source/design_top_wrapper.v').read_text(encoding='utf8')
 assert 'SECOND_LANE=1,DUAL_RECOGNITION_ONLY=0,' in top and '.MANUAL_ONLY(DUAL_RECOGNITION_ONLY)' in top
 body='reg motor_output;'+top.split('reg motor_output;',1)[1].split('assign O_relay_control=motor_output;',1)[0]+'assign O_relay_control=motor_output;'
 assert body in (repo/'tests/dual_stop_d2/extracted_d2_motor.sv').read_text()
 git_source_audit(repo,source)
 groups=[(tmp/'d2_pixels_final_r4_20261029','dual_stop_d2'),(tmp/'d2_ui_control_r4_20261029','dual_stop_d2'),(tmp/'d2_rgb_final_r3_20261029','dual_stop_d2'),(tmp/'d2_final_compat_r4_20261029','shift_alarm_v7'),(tmp/'d2_keys_compat_r1_20261029',None)]
 selected=[]
 for folder,fixture in groups:
  proof=load(folder/'verification.json');assert proof['status']=='PASS'
  for rel,d in proof['inputs'].items():assert source[rel]==d,(folder,rel)
  for rel,d in proof['extra_inputs'].items():assert fixture and sha(repo/'tests'/fixture/Path(rel).name)==d
  for rel,d in {**proof['inputs'],**proof['extra_inputs']}.items():assert sha(folder/'inputs'/Path(rel).name)==d
  for t in proof['tests']:
   log=folder/(t['name']+'.log');assert sha(log)==t['sha256'];passed(log)
   selected.append({'name':t['name'],'group':folder.name,'mode':'NEW_RUN','log_sha256':sha(log)})
 assert len(selected)==11
 native=tmp/'d2_native_r3_20261029';n=load(native/'verification.json');assert n['status']=='PASS'
 for rel,d in n['inputs'].items():assert source[rel]==d and sha(native/'inputs/project'/rel)==d
 for rel,d in n['extra_inputs'].items():assert sha(repo/'tests/dual_stop_d2'/Path(rel).name)==d and sha(native/'inputs/project'/rel)==d
 for rel,d in n['vendor'].items():assert sha(native/'inputs/vendor'/rel)==d
 assert sha(native/'console.log')==n['console_sha256'];passed(native/'console.log','PASS D2 NATIVE UPPER COUNT/PARK + LOWER RECOGNITION:')
 selected.append({'name':n['name'],'group':native.name,'mode':'NEW_RUN','log_sha256':n['console_sha256'],'scope':'7 RAW10 complete sources including first; 14 displayed rasters, 13088282 exact pixels; original upper count/repair and independent lower tuples, 1039bit metadata; WB-canceled live video; counter/parking instantiated, motor permit off. Not a RAW parking cycle or optical E recall.'})
 gate=tmp/'d2_camera_r3_20261029';g=load(gate/'verification.json');assert g['status']=='PASS'
 assert sha(w/'d2_camera_gate.v')==g['gate_netlist_sha256'] and g['cone_closure']['all_other_consumed_nets_have_selected_cell_drivers']
 for name,d in g['simulation_input_sha256'].items():assert sha(gate/'inputs'/name)==d
 for t in g['tests']:
  log=gate/(t['name']+'.log');assert sha(log)==t['log_sha256'];passed(log,'PASS CAMERA GATE BUS:')
  selected.append({'name':t['name'],'group':gate.name,'mode':'NEW_RUN','log_sha256':sha(log),'scope':'Actual synthesized camera cone; two resets x126 serialized I2C writes; modeled ACK slave, not optical readback.'})
 legacy=[];sentinels=dict(re.findall(r'Name="([^"]+)";\s*Pass="([^"]+)"',(p/'sim/run_modelsim.ps1').read_text(encoding='utf8')))
 for name in ['regions','classified_counter','result_recorder_pipeline','empty_trace_abort','text_plane_prefetch']:
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
 assert len(selected)+len(legacy)==18
 physical=load(w/'physical_verification.json');build=load(w/'build_result.json')
 assert physical['status'].startswith('PASS_R22_D2_ROUTED_') and physical['max_delays_matched']==49 and physical['max_delays_ignored']==0 and physical['gray_bits_dominating']==20
 assert physical['first_lane_counting_and_parking_enabled'] and physical['second_lane_recognition_enabled'] and not physical['second_lane_counting_enabled'] and physical['alarm_interlock_packed_cell_proof']['actual_alarm_Q_and_registered_motor_LUT']
 assert all(physical['timing_ns'][k]>=0 for k in ['SWNS','HWNS','STNS','HTNS'])
 bit=w/'runs/phy_1/camera_to_dsi_display.bit';assert sha(bit)==build['bit_sha256']==physical['bit_sha256']
 protected=Path('E:/2026FPGA/BIT_FLASH/LATEST_READONLY.bit');protected_sha='30d067cef0667893fe548ba04e423cd6618b76f119cb2e0ecf48b96ba6a5b20f'
 oldbit=Path('E:/2026FPGA/BIT_FLASH/R22_RelayAuto_Left_V7_ShiftAlarm_20261028.bit');oldsha='3b1c6ebc6a67c0e791827eba011e7890bdcc850b41a3eadf02cd9a3fb24a1750'
 assert sha(protected)==protected_sha and sha(oldbit)==oldsha
 name='R22_SingleStop_SecondRecognition_D2_20261029';release=repo/'releases/r22_dual_stop_d2_20261029';archive=release.with_suffix('.zip');flash=Path('E:/2026FPGA/BIT_FLASH')/(name+'.bit')
 assert not release.exists() and not archive.exists() and not flash.exists()
 if args.check_only:
  print(json.dumps({'status':'READY_TO_PUBLISH','fresh_selected_checks':18,'changed_production_files':changed,'added':list(added),'bit_sha256':sha(bit),'resources':physical['resources'],'timing_ns':physical['timing_ns']},indent=2));return
 release.mkdir(parents=True)
 for rel in source:copy(p/rel,release/'project'/rel)
 write(release/'SOURCE_SHA256.json',source);copy(repo/'releases/r22_20261027/frozen_inputs.json',release/'baseline/r22_frozen_inputs.json');copy(oldrelease/'SOURCE_SHA256.json',release/'baseline/rl7_source_sha256.json')
 for fixture in ['dual_stop_d2','camera_gain_fix']:
  for f in (repo/'tests'/fixture).iterdir():
   if f.is_file():copy(f,release/'tests'/fixture/f.name)
 for folder,_ in groups+[(native,None),(gate,None)]:
  for f in folder.rglob('*'):
   if f.is_file() and ('inputs' in f.relative_to(folder).parts or f.suffix in ['.json','.log']):copy(f,release/'tests'/folder.name/f.relative_to(folder))
 for t in legacy:
  for fname in ['compile.log','console.log']:copy(p/'sim/modelsim_work'/t['name']/fname,release/'tests/legacy'/t['name']/fname)
 # Keep earlier test invocation/geometry failures separate from selected proofs.
 for dirname in ['d2_first_compat_r1_20261029','d2_pixels_r1_20261029']:
  for f in (tmp/dirname).iterdir():
   if f.is_file() and f.suffix in ['.log','.json']:copy(f,release/'diagnostics/not_selected'/dirname/f.name)
 copy(tmp/'d2_single_stop_second_lane_build_r1_20261029/ABORT_REASON.json',release/'diagnostics/not_selected/initial_build/ABORT_REASON.json')
 copy(tmp/'d2_single_stop_second_lane_build_r2_20261029/ABORT_REASON.json',release/'diagnostics/not_selected/second_build/ABORT_REASON.json')
 for fname in ['console.log','camera_to_dsi_display_place.timing']:
  copy(tmp/'d2_single_stop_second_lane_build_r2_20261029/runs/phy_1'/fname,release/'diagnostics/not_selected/second_build'/fname)
 for fname in ['console.log','camera_to_dsi_display_place.timing']:
  copy(tmp/'d2_single_stop_second_lane_build_r1_20261029/runs/phy_1'/fname,release/'diagnostics/not_selected/initial_build'/fname)
 write(release/'diagnostics/not_selected/README.json',{'status':'TEST_FIXTURE_FAILURES_NOT_PASS','finding':'First compat invocation omitted required include support; first pixel fixture accidentally put its outside object inside the original left station. Final independent input truth fixes fixtures, not production RTL. No selected proof suppressed.'})
 copy(repo/'docs/R22_DUAL_STOP_D2_FIELD_GUIDE.md',release/'FIELD_GUIDE.md');copy(repo/'docs/R22_DUAL_STOP_D2_INTERFACE.md',release/'INTERFACE.md');copy(repo/'docs/evidence/dual_stop_d2/simulated_osd.png',release/'SIMULATED_OSD.png')
 for script in ['build_r22_relay.py','audit_r22_relay.py','relay_left_checks.py','relay_left_native_check.py','check_camera_gain_fix.py','publish_dual_stop_d2.py','publish_r22_shift_alarm_v7.py']:
  copy(repo/'scripts'/script,release/'scripts'/script)
 copy(w/'d2_camera_gate.v',release/'build/d2_camera_gate.v')
 for f in w.iterdir():
  if f.is_file() and f.suffix in ['.json','.py','.tcl','.log']:copy(f,release/'build'/f.name)
 for stage in ['syn_1','phy_1']:
  for f in (w/'runs'/stage).iterdir():
   if f.is_file() and (f.suffix in ['.log','.cfg','.tcl','.prj','.rpt','.area','.timing','.db'] or f.name=='constraint_coverage.txt'):copy(f,release/'build/runs'/stage/f.name)
 for directory in ['classified_audit','gray_packing_audit']:
  for f in (p/directory).iterdir():
   if f.is_file():copy(f,release/'build'/directory/f.name)
 verification={'status':'PASS_18_FRESH_SELECTED_CHECKS_AND_ORIGINAL_ROUTED_ALARM_AUDIT','selected':selected,'legacy':legacy,'physical':physical,'changed_production_files':changed,'added_production_files':list(added),'unchanged_source_files':629,'source_git_blob_audit':'ALL_636_MATCH_HEAD','board_operated':False,'hardware_acceptance':False,'dual_counting_implemented':False,'first_lane_auto_parking_enabled':True,'second_lane_auto_parking_enabled':False,'known_boundary':'Existing white3528 recipe only; weak RAW reflected-hole miss not repaired; no arbitrary speed or optical recall claim. Old automatic-mode global ID/high-speed boundary not addressed. Original first-lane count/park/5-empty protection retained; second-lane counting deferred to teammate.'}
 write(release/'VERIFICATION.json',verification);copy(bit,release/(name+'.bit'))
 receipt={'version':name,'branch':'codex/r22-single-stop-plus-second-recognition-d2','source_commit':subprocess.check_output(['git','rev-parse','HEAD'],cwd=repo,text=True).strip(),'parent_d1_audit_commit':'30d1a5a5','preserved_rl7_archive_commit':'a716eac','source_worktree':str(repo),'build_work':str(w),'pushed':False,'bit_sha256':sha(bit),'bit_bytes':bit.stat().st_size,'td_version':'V6.2.168116','seed':build['seed'],'resources':physical['resources'],'slice_percent':physical['slice_percent'],'timing_ns':physical['timing_ns'],'source_files':636,'hardware_dependencies':104, 'parameters':{'SECOND_LANE':1,'DUAL_RECOGNITION_ONLY':0,'first_lane_count_roi':[448,832,240,400],'first_lane_station_roi':[64,448,240,400],'second_lane_recognition_roi':[400,880,432,600],'bounds':'half-open full1280x720 pixels','window_x':[72,232],'target_x':152,'trigger_x':184,'advance_px':32,'hold_ms':1000,'five_empty_alarm':True,'frame_meta_bits':1039,'first_lane_counting_and_parking':True,'second_lane_counting_and_parking':False},'gpio':'right J2 pin1/V2 HIGH; board5V; original ADC; no LED','keys':'K1 newRUN/count/auto / K2 pause-resume/manual / K3 clear-stop / K4 stop / SW3 up stop falling-edge newRUN','constraint_profile':'Original parking SDC unchanged; 49 bounds, 9 mailbox groups, original alarm/motor Q and V2 FF proof', 'source_manifest_sha256':sha(release/'SOURCE_SHA256.json'),'verification_sha256':sha(release/'VERIFICATION.json'),'board_acceptance':'PENDING_HUMAN_UPPER_STOP_AND_LOWER_RECOGNITION_TEST'}
 write(release/'RELEASE.json',receipt)
 (release/'README.md').write_text('RL7+D2: preserve original first-lane count/IDs/parking/full1000ms/resume/five-empty alarm; add independent lower-lane recognition. Teammate only supplies dual counting; parking integration remains here. FIELD_GUIDE.md and INTERFACE.md explain three internal zones and independent buses. 636 frozen files/104 hardware dependencies, 18 fresh selected checks and original strict 49-bound routed/alarm audit. Hardware acceptance pending. Rebuild to NEW ASCII directory: python scripts/build_r22_relay.py --keys-v3 --seed 3 --stage-timeout 7200 --source project --baseline-manifest baseline/r22_frozen_inputs.json --work E:/2026FPGA/D2_rebuild --td E:/TD ; python scripts/audit_r22_relay.py --keys-v3 --adjacent-v6 --five-empty-v7 --second-lane-d2 --work same_path. SIMULATED_OSD.png is a fixture output, not board photo. Prior RL7/D1/read-only R2 preserved.\n',encoding='utf8')
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
 delivery={'status':'DELIVERED_FOR_HUMAN_FIRST_LANE_STOP_PLUS_SECOND_RECOGNITION_TEST','release':str(release),'archive':str(archive),'archive_sha256':sha(archive),'flash_copy':str(flash),'bit_sha256':sha(bit),'payload_count':len(payload),'fresh_selected_checks':18}
 write(repo/'docs/R22_DUAL_STOP_D2_DELIVERY.json',delivery);print(json.dumps(delivery,indent=2),flush=True)
if __name__=='__main__':main()
