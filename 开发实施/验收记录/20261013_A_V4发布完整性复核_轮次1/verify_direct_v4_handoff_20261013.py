from pathlib import Path
import hashlib,json,subprocess
root=Path(__file__).resolve().parent.parent;project=root/'fpga/component_inspector'
load=lambda p:json.loads(p.read_text(encoding='utf-8-sig'))
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
current=load(project/'td_project/current_codex_build.json')
archive=root/Path(current['source_snapshot']).parent
inputs=load(archive/'inputs.json');manifest=load(archive/'manifest.json')
for item in inputs:
 assert sha(project/item['path'])==item['sha256']==sha(archive/'source_snapshot'/item['path']),item['path']
for item in manifest:
 assert sha(archive/item['path'])==item['sha256'] and (archive/item['path']).stat().st_size==item['bytes'],item['path']
release_path=root/current['release']['path'];release=release_path.parent
assert sha(release_path)==current['release']['sha256'] and release_path.stat().st_size==current['release']['bytes']
assert (release/'SHA256.txt').read_text().split()[0]==sha(release_path)
assert load(release/'build_inputs.json')==inputs
audit=load(release/'audit.json');assert audit==load(archive/'audit.json')
assert audit['status']=='PASS_source_simulation_and_routed_build' and audit['onsite']=='PENDING'
assert len(audit['tests'])==len(current['fresh_tests'])==9
assert {t['test'] for t in audit['tests']}==set(current['fresh_tests'])
assert not audit['warning_deltas']['syn_1']['added'] and not audit['warning_deltas']['phy_1']['added']
for document in (archive/'documents').iterdir():
 assert sha(root/'开发实施'/document.name if '上板说明' in document.name else root/current['validation_record'])==sha(document)
head=subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip()
assert head==current['base_head']
assert not subprocess.check_output(['git','diff','--cached','--name-only'],cwd=root,text=True).strip()
result=dict(date='2026-10-13',status='PASS_RELEASE_HANDOFF_INTEGRITY',production_inputs=len(inputs),archive_files=len(manifest),
 tests_in_accepted_release=9,bit_sha256=sha(release_path),source_head=head,onsite='PENDING',rtl_changed=False,tests_rerun=False)
output=root/'tmp/direct_v4_handoff_integrity_20261013.json'
assert not output.exists()
output.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps(result,ensure_ascii=False,indent=2))
