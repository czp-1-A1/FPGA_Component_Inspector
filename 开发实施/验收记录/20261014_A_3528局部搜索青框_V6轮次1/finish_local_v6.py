from pathlib import Path
import json,re,hashlib,shutil,subprocess

root=Path.cwd();project=root/'fpga/component_inspector';build=root/'tmp/local_v6_r11_20261014'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
read=lambda p:p.read_text(encoding='utf-8-sig',errors='replace')
load=lambda p:json.loads(read(p))
inputs=load(build/'inputs.json');audit=load(build/'build_audit.json')
assert audit['status']=='PASS_BUILD_TESTS_PENDING'
tests=[]
test_rounds=[('local_v6_r11_20261014', ['local_search','local_osd','shape_snapshot','shape_model','shape_osd','video_fallback_display','video_metadata_fallback','writer_epoch','wb_epoch','observation','display_state']),('local_v6_r14_20261014',['local_isp']),('local_v6_r17_20261014',['local_video'])]
for round_name,names in test_rounds:
 source=root/'tmp'/round_name
 assert load(source/'inputs.json')==inputs,round_name
 for name in names:
  log=source/'sim/modelsim_work'/name/'console.log';s=read(log)
  assert re.search(r'PASS .*:',s) and 'Errors: 0,' in s and '** Fatal:' not in s and '** Error:' not in s,(round_name,name)
  tests.append(dict(name=name,round=round_name,status='PASS',console_sha256=sha(log)))
refs=load(root/'tmp/local_v6_r14_20261014/native_reference_results.json')
assert len(refs)==8 and all(r['status']=='PASS' for r in refs)
for e in inputs:assert sha(build/e['path'])==e['sha256']==sha(project/e['path']),e['path']
audit.update(status='PASS_SOFTWARE_EXPERIMENT_ONSITE_PENDING',tests=tests,independent_native_reference_frames=8,scope='3528 white LED, bounded 192x144 local search; unchanged V5 shape limits; onsite pending')
(build/'build_audit.json').write_text(json.dumps(audit,ensure_ascii=False,indent=2),encoding='utf-8')
e=root/'开发实施/验收记录/20261014_A_3528局部搜索青框_V6轮次1';assert not e.exists();e.mkdir(parents=True)
for item in inputs:
 dst=e/'source_snapshot'/item['path'];dst.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(build/item['path'],dst)
for name in ['inputs.json','build_audit.json']:shutil.copy2(build/name,e/name)
shutil.copytree(root/'tmp/local_v6_r17_20261014/sim',e/'source_snapshot/sim',ignore=shutil.ignore_patterns('modelsim_work','*.log','modelsim.ini','*.wlf','transcript'))
for test in tests:
 source=root/'tmp'/test['round']/'sim';dst=e/'tests'/test['name'];dst.mkdir(parents=True)
 for name in ['tb_'+test['name']+'.v','run_modelsim.ps1']:shutil.copy2(source/name,dst/name)
 for name in ['compile.log','console.log','transcript.log']:
  p=source/'modelsim_work'/test['name']/name
  if p.exists():shutil.copy2(p,dst/name)
 shutil.copy2(root/'tmp'/test['round']/'simulation_inputs.json',dst/'simulation_inputs.json')
native=e/'native_reference';native.mkdir()
for p in (root/'tmp/local_v6_r14_20261014/sim').glob('native_case_*.pgm'):shutil.copy2(p,native/p.name)
shutil.copy2(root/'tmp/local_v6_r14_20261014/native_reference_results.json',native/'native_reference_results.json')
for name in ['freeze_local_v6.py','check_local_native.py','audit_local_v6.py','finish_local_v6.py']:shutil.copy2(root/'tmp'/name,e/name)
for round_no in range(1,18):
 matches=list((root/'tmp').glob(f'local_v6_r{round_no}_*'));assert len(matches)==1
 source=matches[0];dst=e/'round_history'/source.name;dst.mkdir(parents=True)
 for name in ['inputs.json','simulation_inputs.json','tests_console.log','build_audit.json','native_reference_results.json']:
  if (source/name).exists():shutil.copy2(source/name,dst/name)
 for tb in (source/'sim').glob('tb_local*.v'):shutil.copy2(tb,dst/tb.name)
 for name in audit['changed_inputs']:
  p=source/name;target=dst/'changed_inputs'/name;target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(p,target)
 work=source/'sim/modelsim_work'
 if work.exists():
  for testdir in work.iterdir():
   if testdir.is_dir():
    for name in ['compile.log','console.log']:
     p=testdir/name
     if p.exists():
      target=dst/'tests'/testdir.name/name;target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(p,target)
 if round_no in [3,8,11]:
  for stage in ['syn_1','phy_1']:
   src=source/'td_project/camera_to_dsi_display_Runs'/stage;target=dst/'td_reports'/stage;target.mkdir(parents=True)
   for p in src.iterdir():
    if p.is_file() and (p.suffix in ['.timing','.area','.prj','.cfg','.tcl'] or p.name in ['build_console.log','build_exit_code.txt','constraint_coverage.txt']):shutil.copy2(p,target/p.name)
for stage in ['syn_1','phy_1']:
 src=build/'td_project/camera_to_dsi_display_Runs'/stage;dst=e/'td_reports'/stage;dst.mkdir(parents=True)
 for p in src.iterdir():
  if p.is_file() and (p.suffix in ['.timing','.area','.prj','.cfg','.tcl'] or p.name in ['build_console.log','build_exit_code.txt','constraint_coverage.txt']):shutil.copy2(p,dst/p.name)
 replay=e/'source_snapshot/td_project/camera_to_dsi_display_Runs'/stage;replay.mkdir(parents=True)
 for name in ['build.tcl','settings.cfg','camera_to_dsi_display.prj']:shutil.copy2(src/name,replay/name)
release=project/'release/local_shape_v6_20261014';assert not release.exists();release.mkdir(parents=True)
bit=build/'td_project/camera_to_dsi_display_Runs/phy_1/camera_to_dsi_display.bit'
assert sha(bit)==audit['bit']['sha256'] and bit.stat().st_size==audit['bit']['bytes']
shutil.copy2(bit,release/bit.name);shutil.copy2(bit,e/bit.name)
(release/'SHA256.txt').write_text(sha(bit)+'  camera_to_dsi_display.bit\n',encoding='ascii')
shutil.copy2(build/'build_audit.json',release/'build_audit.json')
guide=root/'开发实施/55_A3528局部搜索青框_V6实现与上板说明.md'
record=root/'开发实施/验收记录/20261014_A_3528局部搜索青框_V6轮次1.md'
shutil.copy2(guide,e/'board_instructions.md');shutil.copy2(record,e/'validation_record.md')
shutil.copy2(guide,release/'README.md')
(e/'worktree_diff.patch').write_bytes(subprocess.check_output(['git','diff','--binary'],cwd=root))
manifest=[dict(path=p.relative_to(e).as_posix(),sha256=sha(p),bytes=p.stat().st_size) for p in e.rglob('*') if p.is_file()]
(e/'archive_sha256.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
for item in manifest:assert sha(e/item['path'])==item['sha256']
pointer=dict(purpose='3528_LOCAL_SHAPE_EXPERIMENT_V6',td_version='6.2.168116',base_head='e604d4fbe4bd40f0d7b40e5fce4ecfda10ea4351',source_commit=None,source_snapshot=(e/'source_snapshot').relative_to(root).as_posix(),build_root=build.relative_to(root).as_posix(),release=dict(path=(release/bit.name).relative_to(root).as_posix(),bytes=bit.stat().st_size,sha256=sha(bit)),validation_record=(e.parent/(e.name+'.md')).relative_to(root).as_posix(),fresh_tests=[t['name'] for t in tests],onsite='PENDING')
(project/'td_project/current_codex_build.json').write_text(json.dumps(pointer,ensure_ascii=False,indent=2),encoding='utf-8')
assert sha(project/'release/shape_detection_v5_20261013/camera_to_dsi_display.bit')=='3afb541a5f219b6a06481512cb8bae6f787a5b03e05d9bed7e284bd8b7788fbe'
print('Released V6 experimental image',sha(bit),'13 tests PASS; archived',len(manifest),'files',sum(m['bytes'] for m in manifest),'bytes; onsite PENDING')
