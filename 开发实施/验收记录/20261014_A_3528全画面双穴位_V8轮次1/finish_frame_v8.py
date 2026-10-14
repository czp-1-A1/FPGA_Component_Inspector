from pathlib import Path
import json,hashlib,shutil,re,subprocess
r=Path.cwd();p=r/'fpga/component_inspector';build=r/'tmp/fullframe_v8_r12_20261014'
sha=lambda f:hashlib.sha256(f.read_bytes()).hexdigest()
read=lambda f:f.read_text(encoding='utf-8-sig',errors='replace')
inputs=json.loads(read(build/'inputs.json'));audit=json.loads(read(build/'build_audit.json'))
assert audit['status']=='PASS_BUILD_TESTS_PENDING'
rounds=[('fullframe_v8_r12_20261014',['frame_search','frame_osd','frame_wait_metadata','shape_snapshot','shape_model','shape_osd','video_fallback_display','video_metadata_fallback','writer_epoch','wb_epoch','observation','display_state','roi_guard']),('fullframe_v8_r13_20261014',['frame_tailproof','frame_video'])]
tests=[]
for round_name,names in rounds:
 q=r/'tmp'/round_name;assert json.loads(read(q/'inputs.json'))==inputs
 for name in names:
  log=q/'sim/modelsim_work'/name/'console.log';s=read(log)
  assert 'Errors: 0,' in s and re.search(r'PASS .*:',s) and '** Fatal:' not in s and '** Error:' not in s,(round_name,name)
  tests.append(dict(name=name,round=round_name,status='PASS',console_sha256=sha(log)))
refs=[]
for round_name,_ in rounds:
 items=json.loads(read(r/'tmp'/round_name/'independent_reference_results.json'));assert all(e['status']=='PASS' for e in items);refs+=items
assert len(tests)==15 and len(refs)==17
for item in inputs:assert sha(build/item['path'])==item['sha256']==sha(p/item['path'])
# Validate old release preservation before writing a new pointer.
old={'presence_review_v7_20261014':'a3d1164e41690a93c9113c6620cc081c63954f0191bffe3d445bcab91d0dfc2c','local_shape_v6_20261014':'79d63d1878309c0a2fce58f664aa6ac50b5cc0f740b631fcdb492c244a026a9b','shape_detection_v5_20261013':'3afb541a5f219b6a06481512cb8bae6f787a5b03e05d9bed7e284bd8b7788fbe'}
for name,digest in old.items():assert sha(p/'release'/name/'camera_to_dsi_display.bit')==digest
assert sha(p/'sim/tb_frame_metadata.v')==sha(r/'tmp/presence_v7_r4_20261014/sim/tb_frame_metadata.v')
assert sha(p/'user_source/hdl_source/roi_shape_search.v')==sha(r/'tmp/presence_v7_r1_20261014/user_source/hdl_source/roi_shape_search.v')
audit.update(status='PASS_SOFTWARE_EXPERIMENT_ONSITE_PENDING',tests=tests,independent_reference_images=17,native_input_frames=11,scope='Same 3528 white LED and tape; full-frame 2x2 reduction; up to two independent results; model diagnostics, no calibrated quality labels')
(build/'build_audit.json').write_text(json.dumps(audit,ensure_ascii=False,indent=2),encoding='utf-8')
e=r/'开发实施/验收记录/20261014_A_3528全画面双穴位_V8轮次1';assert not e.exists();e.mkdir(parents=True)
for item in inputs:
 dest=e/'source_snapshot'/item['path'];dest.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(build/item['path'],dest)
shutil.copytree(r/'tmp/fullframe_v8_r13_20261014/sim',e/'source_snapshot/sim',ignore=shutil.ignore_patterns('modelsim_work','*.log','modelsim.ini','*.wlf','transcript','*.pgm'))
for name in ['inputs.json','build_audit.json']:shutil.copy2(build/name,e/name)
for t in tests:
 q=r/'tmp'/t['round'];dest=e/'tests'/t['name'];dest.mkdir(parents=True)
 for f in ['tb_'+t['name']+'.v','run_modelsim.ps1']:shutil.copy2(q/'sim'/f,dest/f)
 for f in ['compile.log','console.log','transcript.log']:shutil.copy2(q/'sim/modelsim_work'/t['name']/f,dest/f)
 shutil.copy2(q/'simulation_inputs.json',dest/'simulation_inputs.json')
for round_name,_ in rounds:
 q=r/'tmp'/round_name;dest=e/'independent_reference'/round_name;dest.mkdir(parents=True)
 for f in (q/'sim').glob('*.pgm'):shutil.copy2(f,dest/f.name)
 for name in ['independent_reference_results.json','reference.log']:shutil.copy2(q/name,dest/name)
for no in range(1,14):
 q=r/'tmp'/f'fullframe_v8_r{no}_20261014';dest=e/'round_history'/q.name;dest.mkdir(parents=True)
 for name in ['inputs.json','simulation_inputs.json','tests_console.log','build_audit.json','reference.log','independent_reference_results.json']:
  if (q/name).exists():shutil.copy2(q/name,dest/name)
 for tb in (q/'sim').glob('tb_frame*.v'):shutil.copy2(tb,dest/tb.name)
 for path in audit['changed_inputs']:
  src=q/path
  if src.exists():
   target=dest/'changed_inputs'/path;target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(src,target)
 for td in (q/'sim/modelsim_work').glob('*'):
  if td.is_dir():
   for name in ['compile.log','console.log']:
    if (td/name).exists():target=dest/'tests'/td.name/name;target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(td/name,target)
 for stage in ['syn_1','phy_1']:
  src=q/'td_project/camera_to_dsi_display_Runs'/stage
  for f in src.iterdir():
   if f.is_file() and (f.suffix in ['.timing','.area','.prj','.cfg','.tcl'] or f.name in ['build_console.log','build_exit_code.txt','constraint_coverage.txt']):
    target=dest/'td_reports'/stage/f.name;target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(f,target)
# The superseded local prototype also remains reproducible.
proto=r/'tmp/dual_v8_r1_20261014';shutil.copytree(proto,e/'local_prototype_history',ignore=shutil.ignore_patterns('modelsim_work','*.wlf','*.db','*.bit'))
for stage in ['syn_1','phy_1']:
 src=build/'td_project/camera_to_dsi_display_Runs'/stage;dest=e/'td_reports'/stage;dest.mkdir(parents=True)
 for f in src.iterdir():
  if f.is_file() and (f.suffix in ['.timing','.area','.prj','.cfg','.tcl'] or f.name in ['build_console.log','build_exit_code.txt','constraint_coverage.txt']):shutil.copy2(f,dest/f.name)
 dest=e/'source_snapshot/td_project/camera_to_dsi_display_Runs'/stage;dest.mkdir(parents=True)
 for name in ['build.tcl','settings.cfg','camera_to_dsi_display.prj']:shutil.copy2(src/name,dest/name)
for name in ['freeze_frame_v8.py','audit_frame_v8.py','check_frame_native.py','finish_frame_v8.py']:
 if (r/'tmp'/name).exists():shutil.copy2(r/'tmp'/name,e/name)
shutil.copytree(r/'开发实施/验收记录/20261014_A_3528全画面双穴位需求与照片_轮次1',e/'photo_feedback')
guide=r/'开发实施/57_A3528全画面双穴位_V8实现与上板说明.md';record=r/'开发实施/验收记录/20261014_A_3528全画面双穴位_V8轮次1.md'
shutil.copy2(guide,e/'board_instructions.md');shutil.copy2(record,e/'validation_record.md')
profile=p/'tools/shape3528/3528w_fullframe_v8_trial.json';shutil.copy2(profile,e/profile.name)
release=p/'release/fullframe_dual_v8_20261014';assert not release.exists();release.mkdir(parents=True)
bit=build/'td_project/camera_to_dsi_display_Runs/phy_1/camera_to_dsi_display.bit';assert sha(bit)==audit['bit']['sha256']
for dest in [release,e]:shutil.copy2(bit,dest/bit.name)
shutil.copy2(guide,release/'README.md');shutil.copy2(profile,release/profile.name);shutil.copy2(build/'build_audit.json',release/'build_audit.json')
(release/'SHA256.txt').write_text(sha(bit)+'  camera_to_dsi_display.bit\n',encoding='ascii')
(e/'worktree_diff.patch').write_bytes(subprocess.check_output(['git','diff','--binary'],cwd=r))
manifest=[dict(path=f.relative_to(e).as_posix(),sha256=sha(f),bytes=f.stat().st_size) for f in e.rglob('*') if f.is_file()]
(e/'archive_sha256.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
for item in manifest:assert sha(e/item['path'])==item['sha256']
pointer=dict(purpose='3528_SAME_MATERIAL_FULLFRAME_DUAL_V8',td_version='6.2.168116',base_head='e604d4fbe4bd40f0d7b40e5fce4ecfda10ea4351',source_commit=None,source_snapshot=(e/'source_snapshot').relative_to(r).as_posix(),build_root=build.relative_to(r).as_posix(),release=dict(path=(release/bit.name).relative_to(r).as_posix(),bytes=bit.stat().st_size,sha256=sha(bit)),validation_record=record.relative_to(r).as_posix(),fresh_tests=[t['name'] for t in tests],onsite='PENDING')
(p/'td_project/current_codex_build.json').write_text(json.dumps(pointer,ensure_ascii=False,indent=2),encoding='utf-8')
print('PASS released V8',sha(bit),'214 production inputs, 15 tests, 17 independent images; archive',len(manifest),'files',sum(m['bytes'] for m in manifest),'bytes; onsite PENDING')
