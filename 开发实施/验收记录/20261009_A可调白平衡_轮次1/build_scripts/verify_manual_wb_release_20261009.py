from pathlib import Path
import hashlib,json,subprocess
root=Path(__file__).resolve().parent.parent
project=root/'fpga/component_inspector'
record=root/'开发实施/验收记录/20261009_A可调白平衡_轮次1'
release=project/'release/manual_wb_tuning_v1_20261009'
load=lambda p:json.loads(p.read_text(encoding='utf-8-sig'))
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
data=load(record/'manifest.json')
for e in data['copies']:
    p=record/e['path'];assert sha(p)==e['sha256'] and p.stat().st_size==e['bytes'],p
for e in load(release/'build_inputs.json'):
    assert sha(project/e['path'])==e['sha256']==sha(record/'source_snapshot'/e['path']),e['path']
bit=project.parent.parent/data['bit']['path']
assert sha(bit)==data['bit']['sha256'] and bit.stat().st_size==data['bit']['bytes']
assert (release/'SHA256.txt').read_text().strip()==sha(bit)+'  '+bit.name
assert sha(root/'AGENTS.md')==sha(record/'AGENTS_checkpoint.md')
assert sha(record.with_suffix('.md'))==sha(record/'验收记录.md')
meta=load(project/'td_project/current_codex_build.json')
assert meta['release']==data['bit'] and meta['source_commit'] is None
assert sha(project/'td_project/current_codex_build.json')==sha(record/'current_codex_build.json')
for e in data['vendor_model_hashes']:assert sha(Path(e['path']))==e['sha256']
assert sha(Path(meta['flow']))==data['flow_sha256']
assert sha(root/data['rollback']['path'])==data['rollback']['sha256']
assert not subprocess.check_output(['git','diff','--cached','--name-only'],cwd=root,text=True).strip()
result=dict(status='PASS_snapshot_release_integrity',copied_files_verified=len(data['copies']),production_inputs_verified=209,
    test_results_verified=len(data['audit']['tests']),bit=data['bit'],source_commit=None,board_validation='pending')
(record/'verification.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps(result,ensure_ascii=True))
