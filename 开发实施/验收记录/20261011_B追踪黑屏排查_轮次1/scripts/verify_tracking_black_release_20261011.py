from pathlib import Path
import hashlib,json,subprocess

root=Path(__file__).resolve().parent.parent
project=root/'fpga/component_inspector'
record=root/'开发实施/验收记录/20261011_B追踪黑屏排查_轮次1'
release=project/'release/tracking_lower_holes_v2_blackfix_20261011'
load=lambda p:json.loads(p.read_text(encoding='utf-8-sig'))
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()

manifest=load(record/'manifest.json');identity=manifest['metadata']
for e in manifest['copies']:
    p=record/e['path']
    assert p.stat().st_size==e['bytes'] and sha(p)==e['sha256'],e['path']
release_manifest=load(release/'manifest.json')
assert release_manifest['metadata']==identity
for e in release_manifest['files']:
    p=release/e['path']
    assert p.stat().st_size==e['bytes'] and sha(p)==e['sha256'],e['path']
inputs=load(record/'inputs.json');assert len(inputs)==210
for e in inputs:
    assert sha(record/'source_snapshot'/e['path'])==e['sha256']==sha(project/e['path']),e['path']
sim_inputs=load(record/'simulation_inputs.json')
for e in sim_inputs:
    rel=Path(e['path']).relative_to('sim')
    assert sha(record/'simulation/source'/rel)==e['sha256']==sha(project/e['path']),e['path']
audit=load(record/'audit.json')
assert audit['status']=='PASS_logic_and_build_only' and len(audit['tests'])==33
assert sum(e['execution'].startswith('fresh_') for e in audit['tests'])==6
assert len(audit['variants'])==3
for e in audit['tests']:
    logs=record/'simulation/logs'/e['name']
    assert sha(logs/'console.log')==e['console_sha256']
    assert sha(logs/'compile.log')==e['compile_sha256']
    for source in e['compiled_inputs']:
        assert sha(project/source['path'])==source['sha256']
for e in audit['variants']:
    assert sha(record/'simulation'/f"metadata_mode{e['mode']}_console.log")==e['console_sha256']
bit=release/'camera_to_dsi_display.bit'
assert sha(bit)==audit['bit']['sha256']==identity['release']['sha256']
assert bit.stat().st_size==audit['bit']['bytes']==identity['release']['bytes']
assert (release/'SHA256.txt').read_text(encoding='ascii').split()[0]==sha(bit)
assert load(project/'td_project/current_codex_build.json')==identity
assert identity['source_commit'] is None
assert (root/identity['source_snapshot']).resolve()==(record/'source_snapshot').resolve()
for name in ['20261011_B下方定位孔追踪修订_轮次1','20261010_B3528动态追踪_轮次1','20261009_A可调白平衡_轮次1']:
    old=root/'开发实施/验收记录'/name
    for e in load(old/'manifest.json')['copies']:
        assert sha(old/e['path'])==e['sha256'] and (old/e['path']).stat().st_size==e['bytes'],(name,e['path'])
assert not subprocess.check_output(['git','diff','--cached','--name-only'],cwd=root,text=True).strip()
for p in [root/'AGENTS.md',root/'开发实施/40_B追踪黑屏修复_上板说明.md',record.with_suffix('.md')]:
    assert sha(bit) in p.read_text(encoding='utf-8')
result=dict(status='PASS_release_integrity_software_only',record_copies=len(manifest['copies']),production_inputs=len(inputs),simulation_inputs=len(sim_inputs),fresh_tests=6,reused_tests=27,metadata_views=[0,1,2,3],bit=audit['bit'],onsite_validation='PENDING')
(record/'verification.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps(result,ensure_ascii=False))
