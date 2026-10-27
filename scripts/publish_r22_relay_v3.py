"""Publish the exact frozen V3 candidate after selected tests and routed audit."""
from pathlib import Path
import argparse,hashlib,json,re,subprocess,zipfile
from publish_r22_relay import sha,load,write,copy

def main():
 ap=argparse.ArgumentParser();ap.add_argument('--work',required=True,type=Path);ap.add_argument('--check-only',action='store_true');args=ap.parse_args()
 repo=Path(__file__).resolve().parents[1];live=repo/'fpga/component_inspector';work=args.work.resolve();project=work/'project'
 physical=load(work/'physical_verification.json');build=load(work/'build_result.json')
 assert physical['status'].startswith('PASS_R22_RELAY_V3_ROUTED_')
 assert physical['max_delays_matched']==49 and physical['max_delays_ignored']==0 and physical['control_mailbox_bits']==20
 assert all(physical['timing_ns'][n]>=0 for n in ['SWNS','HWNS','STNS','HTNS'])
 source=load(work/'frozen_inputs.json')
 for rel,d in source.items():assert sha(project/rel)==sha(live/rel)==d,rel
 assert len(source)==636
 groups=[Path('E:/2026FPGA/.codex_tmp/r22_relay_v3_final_unit_20261027'),Path('E:/2026FPGA/.codex_tmp/r22_relay_v3_final_closed_20261027')]
 selected=[]
 for group in groups:
  proof=load(group/'verification.json');assert proof['status']=='PASS'
  for rel,d in proof['inputs'].items():assert source[rel]==d,(group,rel)
  for test in proof['tests']:
   log=group/(test['name']+'.log');assert sha(log)==test['sha256']
   text=log.read_text(encoding='utf8');assert 'PASS ' in text and not re.search(r'\*\* (Fatal|Error):|Errors:\s*[1-9]',text)
   selected.append({'name':test['name'],'status':'PASS','console_sha256':sha(log),'group':group.name})
 assert len(selected)==9 and len({r['name'] for r in selected})==9
 native_dir=Path('E:/2026FPGA/.codex_tmp/r22_relay_v3_final_native_20261027');native=load(native_dir/'verification.json')
 assert native['status']=='PASS' and native['name']=='tb_relay_v3_native'
 for rel,d in native['inputs'].items():assert source[rel]==d,('native',rel)
 assert sha(native_dir/'console.log')==native['console_sha256']
 selected.append({'name':native['name'],'status':'PASS','console_sha256':native['console_sha256'],'scope':'12 native RAW10 frames,27fps,24 exact display rasters,4 known crossings,2 EMPTY queued; not arrival at stop line'})
 legacy_names=['classified_counter','result_recorder_pipeline','local_pipeline','switch_recorder_controls','recovery_protection','simple_recovery_ui','text_plane_prefetch']
 sentinels=dict(re.findall(r'Name="([^"]+)";\s*Pass="([^"]+)"',(project/'sim/run_modelsim.ps1').read_text(encoding='utf8')))
 legacy=[]
 for name in legacy_names:
  folder=project/'sim/modelsim_work'/name
  cl=(folder/'compile.log').read_text(encoding='utf-8-sig');co=(folder/'console.log').read_text(encoding='utf-8-sig')
  assert sentinels[name] in co and not re.search(r'\*\* (Fatal|Error):|Errors:\s*[1-9]',cl+co),name
  compiled={}
  for line in cl.splitlines():
   if 'vlog ' in line and '-work' in line:
    for token in line.split():
     token=token.strip('"')
     if token.endswith(('.v','.sv')):
      p=(project/'sim'/token).resolve();rel=p.relative_to(project).as_posix()
      assert source[rel]==sha(p),(name,rel);compiled[rel]=source[rel]
  assert compiled,name
  legacy.append({'name':name,'status':'PASS','inputs':compiled,'compile_sha256':sha(folder/'compile.log'),'console_sha256':sha(folder/'console.log')})
 assert len(legacy)+len(selected)==17
 baseline=load(repo/'releases/r22_relay_left_v2_20261027/SOURCE_SHA256.json')
 inherited=['frame_shape_search','local_edge_surface_check','present_surface_check','classified_pocket_counter','classified_count_pipeline']
 for n in inherited:assert source['user_source/hdl_source/'+n+'.v']==baseline['user_source/hdl_source/'+n+'.v']
 for rel in ['user_source/constraints_source/pin.adc','td_project/camera_to_dsi_display.sdc']:
  assert source[rel]==baseline[rel],('Changed pin/SDC',rel)
 protected=Path('E:/2026FPGA/BIT_FLASH/LATEST_READONLY.bit');protected_sha='30d067cef0667893fe548ba04e423cd6618b76f119cb2e0ecf48b96ba6a5b20f'
 assert sha(protected)==protected_sha
 name='R22_RelayAuto_Left_V3_20261027';release=repo/'releases/r22_relay_left_v3_20261027';assert not release.exists()
 bit=work/'runs/phy_1/camera_to_dsi_display.bit';assert sha(bit)==build['bit_sha256']==physical['bit_sha256']
 if args.check_only:
  print(json.dumps({'status':'READY_TO_PUBLISH','sources':len(source),'selected_tests':17,'bit_sha256':sha(bit),'resources':physical['resources'],'timing_ns':physical['timing_ns']},indent=2));return
 release.mkdir(parents=True)
 for rel in source:copy(project/rel,release/'project'/rel)
 write(release/'SOURCE_SHA256.json',source)
 copy(repo/'releases/r22_20261027/frozen_inputs.json',release/'baseline/r22_frozen_inputs.json')
 original=repo/'releases/r22_20261027/PocketCount_SW3_LocalEdge_r22_20261027.bit'
 assert sha(original)=='a07bd753296d320c495f234669477563f1f34cdc60af87089575b3bc1bad4df2'
 copy(original,release/'baseline'/original.name)
 for script in ['build_r22_relay.py','relay_left_checks.py','relay_left_native_check.py','audit_r22_relay.py','publish_r22_relay.py','publish_r22_relay_v3.py']:
  copy(repo/'scripts'/script,release/'scripts'/script)
 copy(repo/'docs/R22_RELAY_V3_FIELD_GUIDE.md',release/'FIELD_GUIDE.md')
 copy(repo/'docs/R22_RELAY_V3_FIELD_ANALYSIS.json',release/'FIELD_ANALYSIS.json')
 copy(repo/'docs/R22_RELAY_LEFT_V2_WEAK_NATIVE_BOUNDARY.json',release/'WEAK_NATIVE_BOUNDARY.json')
 field=repo/'tmp/autostop_v2_field_20261027'
 for f in ['video_metadata.json','stop_status_sequence.png']:
  copy(field/f,release/'field_evidence'/f)
 for p in work.iterdir():
  if p.is_file() and p.suffix in ['.json','.py','.tcl','.log']:copy(p,release/'build'/p.name)
 for stage in ['syn_1','phy_1']:
  for p in (work/'runs'/stage).iterdir():
   if p.is_file() and (p.suffix in ['.log','.cfg','.tcl','.prj','.rpt','.area','.timing','.db'] or p.name=='constraint_coverage.txt'):
    copy(p,release/'build/runs'/stage/p.name)
 for directory in ['classified_audit','gray_packing_audit']:
  for p in (project/directory).iterdir():
   if p.is_file():copy(p,release/'build'/directory/p.name)
 for group in groups:
  for p in group.rglob('*'):
   if p.is_file() and (p.suffix in ['.json','.log','.png'] or p.parent.name=='inputs'):
    copy(p,release/'tests'/group.name/p.relative_to(group))
 for row in legacy:
  for f in ['compile.log','console.log']:copy(project/'sim/modelsim_work'/row['name']/f,release/'tests/legacy'/row['name']/f)
 for p in native_dir.iterdir():
  if p.is_file() and p.suffix in ['.json','.log']:copy(p,release/'tests/native'/p.name)
 for p in (native_dir/'inputs').rglob('*'):
  if p.is_file():copy(p,release/'tests/native/inputs'/p.relative_to(native_dir/'inputs'))
 verification={'status':'PASS_17_SELECTED_TESTS_AND_ROUTED_AUDIT','selected':selected,'legacy':legacy,'physical':physical,
  'source_count':len(source),'hardware_dependencies':104,'known_boundary':'R22 weak RAW280 aperture miss retained; classifier/tracker sources checked identical to V2. Original failure and bitwise replay archived in V2 release. Not counted PASS.',
  'physical_position_accuracy':False,'speed_adaptive':False,'physical_hold_test':False,'actual_refill_actuator_implemented':False,'board_operated':False}
 write(release/'VERIFICATION.json',verification)
 copy(bit,release/(name+'.bit'))
 receipt={'version':name,'feature_branch':'codex/r22-relay-controls-v3','base_commit':'a1cceaa9b5a37ff31b7f84a77c00042b027208d0','parent_v2_commit':'e51cb15',
  'source_commit':subprocess.check_output(['git','rev-parse','HEAD'],cwd=repo,text=True).strip(),'source_worktree':str(repo),'pushed':False,
  'bit_sha256':sha(bit),'bit_bytes':bit.stat().st_size,'td_version':'V6.2.168116','seed':2,'resources':physical['resources'],'slice_percent':physical['slice_percent'],'timing_ns':physical['timing_ns'],
  'gpio':'right J2 pin1/V2 HIGH; board5V; no LED; original ADC/SDC unchanged',
  'keys':{'K1':'fresh RUN, count + auto feed','K2':'pause/resume same RUN; idle manual motor toggle','K3':'one-press clear and stop','K4':'stop','SW3':'up stop/down fresh RUN without clear'},
  'parameters':{'target_x':160,'advance_px':32,'trigger_x':192,'tolerance_px':8,'hold_ms':1000,'direction':'LEFT','automatic_speed_compensation':False},
  'source_manifest_sha256':sha(release/'SOURCE_SHA256.json'),'verification_sha256':sha(release/'VERIFICATION.json'),'board_acceptance':'PENDING_HUMAN_CALIBRATION'}
 write(release/'RELEASE.json',receipt)
 (release/'README.md').write_text("R22 left refill V3: read FIELD_GUIDE.md. New controls and calibration candidate; fixed advance32, target160/tolerance8. No board accuracy claim. Full frozen636 source and17 selected tests plus routed reports included. Original R22 rollback bit is in baseline. Build in a new ASCII directory with scripts/build_r22_relay.py --keys-v3 --source project --baseline-manifest baseline/r22_frozen_inputs.json --work E:/2026FPGA/R22_V3_rebuild --td E:/TD. Then scripts/audit_r22_relay.py --keys-v3 --work E:/2026FPGA/R22_V3_rebuild. Run scripts/relay_left_checks.py with --source project and explicit V3 bench names, and scripts/relay_left_native_check.py --v3 --source project --out a_new_directory. Never run in or overwrite this frozen release.\n",encoding='utf8')
 payload={p.relative_to(release).as_posix():{'bytes':p.stat().st_size,'sha256':sha(p)} for p in release.rglob('*') if p.is_file()};write(release/'PAYLOAD_SHA256.json',payload)
 archive=release.with_suffix('.zip');assert not archive.exists()
 with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as z:
  for p in release.rglob('*'):
   if p.is_file():z.write(p,p.relative_to(release).as_posix())
 with zipfile.ZipFile(archive) as z:
  assert z.testzip() is None
  for rel,row in payload.items():assert hashlib.sha256(z.read(rel)).hexdigest()==row['sha256']
 flash=Path('E:/2026FPGA/BIT_FLASH');dst=flash/(name+'.bit');assert not dst.exists();copy(release/dst.name,dst)
 copy(release/'FIELD_GUIDE.md',flash/(name+'_说明.md'));copy(release/'WEAK_NATIVE_BOUNDARY.json',flash/(name+'_BOUNDARY.json'))
 write(flash/(name+'_RELEASE.json'),{**receipt,'release_directory':str(release),'archive':str(archive),'archive_sha256':sha(archive)})
 assert sha(protected)==protected_sha and sha(dst)==sha(bit)
 delivery={'status':'DELIVERED_FOR_HUMAN_CALIBRATION','release':str(release),'archive':str(archive),'archive_sha256':sha(archive),'flash_copy':str(dst),'bit_sha256':sha(bit),'payload_count':len(payload),'selected_tests_pass':17}
 write(repo/'docs/R22_RELAY_V3_DELIVERY.json',delivery);print(json.dumps(delivery,indent=2),flush=True)
if __name__=='__main__':main()
