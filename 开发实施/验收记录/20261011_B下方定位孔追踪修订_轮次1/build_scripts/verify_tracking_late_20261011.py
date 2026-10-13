from pathlib import Path
import hashlib,json,subprocess,re
root=Path(__file__).resolve().parent.parent
project=root/'fpga/component_inspector'
record=root/'开发实施/验收记录/20261011_B下方定位孔追踪修订_轮次1'
release=project/'release/tracking_lower_holes_v1_20261011'
build=root/'tmp/tracking_late_r1_td_20261011'
tests=root/'tmp/tracking_late_r3_td_20261011'
load=lambda p:json.loads(p.read_text(encoding='utf-8-sig'))
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
m=load(record/'manifest.json');copies=m['copies']
assert len({e['path'] for e in copies})==len(copies)
for e in copies:
    p=record/e['path'];assert p.stat().st_size==e['bytes'] and sha(p)==e['sha256'],p
inputs=load(record/'inputs.json');assert len(inputs)==210 and inputs==load(build/'inputs.json')==load(tests/'inputs.json')
for e in inputs:
    for p in [build/e['path'],tests/e['path'],project/e['path'],record/'source_snapshot'/e['path']]:
        assert sha(p)==e['sha256'] and p.stat().st_size==e['bytes'],p
sim_inputs=load(record/'simulation_inputs.json')
assert sim_inputs==load(tests/'simulation_inputs.json')
for e in sim_inputs:
    for p in [tests/e['path'],project/e['path'],record/'simulation/source'/Path(e['path']).relative_to('sim')]:assert sha(p)==e['sha256'],p
assert load(release/'build_inputs.json')==inputs
bit_hash='0c1fe0ded306b532e3cb31310e556387de2d4c6caceeb53d80195b33a380745f'
for p in [release/'camera_to_dsi_display.bit',build/'td_project/camera_to_dsi_display_Runs/phy_1/camera_to_dsi_display.bit',record/'td_reports/phy_1/camera_to_dsi_display.bit']:
    assert p.stat().st_size==1789539 and sha(p)==bit_hash,p
assert (release/'SHA256.txt').read_text().split()[0]==bit_hash
assert m['bit']['sha256']==bit_hash and load(release/'manifest.json')=={k:v for k,v in m.items() if k!='copies'}
current=load(project/'td_project/current_codex_build.json')
assert current==load(record/'current_codex_build.json') and current['release']==m['bit']
assert current['source_snapshot']==(record/'source_snapshot').relative_to(root).as_posix()
assert current['simulation_root']==tests.relative_to(root).as_posix()
assert current['syn']==str(build/'td_project/camera_to_dsi_display_Runs/syn_1')
assert current['phy']==str(build/'td_project/camera_to_dsi_display_Runs/phy_1')
audit=load(record/'audit.json');assert audit==load(tests/'audit.json')==m['audit']
assert audit['status']=='PASS_logic_and_build_only' and len(audit['tests'])==32
assert (record/'simulation/r3/regression_exit_code.txt').read_text().strip()=='0'
for e in audit['tests']:
    p=record/'simulation/logs'/e['name']
    assert sha(p/'console.log')==e['console_sha256'] and sha(p/'compile.log')==e['compile_sha256']
    s=(p/'console.log').read_text(errors='replace')
    assert 'Errors: 0' in s and all(line in s for line in e['pass_lines'])
    assert not re.search(r'(?m)^#?\s*\*\* (?:Fatal|Error):',s)
notes=load(record/'simulation/visual/visual_notes.json')
assert notes['source_sha256']==sha(project/'sim/tb_tracking_osd.v')
assert notes['modified_testbench_sha256']==sha(record/'simulation/visual/sim/tb_tracking_osd.v')
for e in notes['rasters']:assert sha(record/'simulation/visual'/Path(e['path']).name)==e['sha256']
assert len(notes['rasters'])==3 and notes['not_a_hardware_photo']
assert (record/'simulation/visual/sim/visual_exit_code.txt').read_text().strip()=='0'
for p in [root/'AGENTS.md',root/'开发实施/39_B3528下方定位孔追踪与诊断_上板说明.md',record.with_suffix('.md')]:
    frozen=record/('AGENTS_checkpoint.md' if p.name=='AGENTS.md' else 'documents/'+p.name)
    assert sha(frozen)==sha(p),p
rollback_counts={}
for name,folder,expected in [
 ('upper','20261010_B3528动态追踪_轮次1','a93d219750d3d76564a4677895f63c8f3b811277fcc8007a9828f38c4608a379'),
 ('manual_wb','20261009_A可调白平衡_轮次1','f71b8d6cc7e8d90c04a84c9ce4916403e2d763c49c5d2c57a1ebf511e8e02800')]:
    old=root/'开发实施/验收记录'/folder;old_m=load(old/'manifest.json')
    for e in old_m['copies']:
        p=old/e['path'];assert sha(p)==e['sha256'] and p.stat().st_size==e['bytes'],p
    rollback_counts[name]=len(old_m['copies'])
    assert sha(root/old_m['bit']['path'])==expected
assert rollback_counts==dict(upper=517,manual_wb=456)
assert subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip()==m['base_head']
assert subprocess.check_output(['git','branch','--show-current'],cwd=root,text=True).strip()==m['branch']
assert not subprocess.check_output(['git','diff','--cached','--name-only'],cwd=root,text=True).strip()
result=dict(status='PASS_publication_identity',evidence_copies=len(copies),production_inputs=210,
 final_simulation_inputs=len(sim_inputs),tests=32,rollback_evidence_copies=rollback_counts,bit_sha256=bit_hash,
 hardware_validation='pending',git_status='uncommitted_unpushed_staged_empty')
(record/'verification.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps(result,ensure_ascii=False))
