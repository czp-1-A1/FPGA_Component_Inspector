from pathlib import Path
import hashlib,json,re

root=Path('D:/FpgaWork/r28_field_20261102');source=Path('D:/FpgaWork/dual_roi_r57_20261102');build=Path('D:/FpgaWork/r57_build_20261102')
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
old=json.loads((source/'R56_BASELINE_SHA256.json').read_text());new=json.loads((build/'frozen_inputs.json').read_text())
changed={n for n in new if old[n]!=new[n]}
expected={'user_source/hdl_source/'+x+'.v' for x in ['frame_shape_search','compact_template_rom','compact_inspector_osd']}
assert len(old)==len(new)==704 and changed==expected
for name,digest in new.items():assert sha(source/'project'/name)==sha(build/'project'/name)==digest,name
tests=[]
groups=['r57_budget_b','r57_rank','r57_ui_a','r57_parking_controls_b','r57_legacy_ui','r57_closure_final']
for group in groups:
 folder=root/group;receipt=json.loads((folder/'verification.json').read_text());assert receipt['status']=='PASS'
 for name,digest in receipt['inputs'].items():
  assert sha(Path(name))==digest,name
  path=Path(name)
  if 'user_source' in path.parts:
   rel=path.relative_to(source/'project').as_posix() if path.is_relative_to(source/'project') else None
   if rel:assert new[rel]==digest,rel
 for test in receipt['tests']:
  log=folder/(test['top']+'.log');text=log.read_text(encoding='utf8')
  assert sha(log)==test['sha256'] and 'PASS ' in text and not re.search(r'\*\* (?:Fatal|Error):',text)
  tests.append({'name':test['top'],'directory':str(folder),'log_sha256':sha(log)})
native=root/'r57_dense_native_a';n=json.loads((native/'verification.json').read_text());assert n['status']=='PASS'
for name,digest in n['inputs'].items():assert new[name]==digest,name
text=(native/'console.log').read_text(encoding='utf8');assert 'PASS R57_DENSE_NATIVE:' in text and 'Fatal:' not in text
tests.append({'name':n['name'],'directory':str(native),'log_sha256':sha(native/'console.log')})
assert len(tests)==21
control=root/'r56_dense_native_control/console.log';ct=control.read_text(encoding='utf8')
assert 'dense native deadline failed source=2 proof=1 result=0 accepted=0 meta=0 good=1 bad=0' in ct
ui=json.loads((root/'R57_UI_PIXEL_VERIFICATION.json').read_text());assert ui['compared_pixels']==540672 and ui['second_lane_glyph_rows']==112
ref=(root/'frame_shape_search_r56.v').read_bytes().replace(b'module frame_shape_search_r56 #(',b'module frame_shape_search #(',1).replace(b'empty_gate_trace_r56',b'empty_gate_trace')
assert hashlib.sha256(ref).hexdigest()==old['user_source/hdl_source/frame_shape_search.v']
budget=(root/'r57_budget_b/tb_r57_budget.log').read_text(encoding='utf8');values=[int(v) for v in re.findall(r'R57_BUDGET scene=\d+ cycles=(\d+)',budget)];assert len(values)==9 and max(values)==99050
native_delay=[float(v) for v in re.findall(r'accept_minus_proof_ns=([\d.]+)',text)];assert native_delay==[527490.0,1042210.0]
assert sha(source/'project/td_project/camera_to_dsi_display.sdc')==old['td_project/camera_to_dsi_display.sdc']
result={'status':'PASS_R57_21_ACTUAL_TESTS_DENSE_NATIVE_DIFFERENTIAL_AND_UI_PIXELS',
 'baseline_commit':'fd794186da46b5914bb6faed817fc1d2da0e903b',
 'source_manifest_sha256':sha(build/'frozen_inputs.json'),'source_files':704,'changed_files':sorted(changed),'unchanged_files':701,
 'actual_tests':len(tests),'historical_pass_reused':0,'tests':tests,
 'negative_R56_native_control_sha256':sha(control),'negative_control_expected_failure':True,
 'dense_native_accept_after_proof_ns':native_delay,'max_dense_detector_cycles':max(values),
 'independent_UI_pixels':ui,'reference_R56_detector_restored_sha256':hashlib.sha256(ref).hexdigest(),
 'constraints_unchanged':True,'original_counter_sha256':new['user_source/hdl_source/classified_pocket_counter.v'],
 'board_acceptance':'HUMAN_PENDING','physical_verification':'PENDING'}
(root/'R57_SOFTWARE_VERIFICATION.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf8')
# This gate enables only the inherited accounting for nine removed display paths.
# It does not change any active SDC budget or hardware timing acceptance check.
ui_gate={'status':'PASS_R57_21_ACTUAL_TESTS_DENSE_NATIVE_DIFFERENTIAL_AND_UI_PIXELS','selected_checks':21,
 'source_manifest_sha256':sha(build/'frozen_inputs.json'),'reference':'D:/FpgaWork/r56_baseline_20261102',
 'software_receipt_sha256':sha(root/'R57_SOFTWARE_VERIFICATION.json'),'changed_files':sorted(changed)}
(build/'ESSENTIAL_UI_PROOF.json').write_text(json.dumps(ui_gate,indent=2),encoding='utf8')
print('PASS R57: 21 actual tests, old-R56 native deadline failure reproduced, 540672 independent UI pixels, all704 byte-exact')
