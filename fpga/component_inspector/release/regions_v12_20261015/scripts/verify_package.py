"""Verify this immutable local V12 delivery without TD or ModelSim."""
from pathlib import Path
import hashlib,json,re

root=Path(__file__).resolve().parents[1]
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
def load(p):return json.loads(p.read_text(encoding='utf-8-sig'))
def read(p):
 b=p.read_bytes()
 return b.decode('utf-16' if b.startswith((b'\xff\xfe',b'\xfe\xff')) else 'utf-8-sig')
manifest=load(root/'MANIFEST.json')
for name,want in manifest['files'].items():
 path=(root/name).resolve()
 assert path.is_relative_to(root) and path.is_file(),name
 assert path.stat().st_size==want['bytes'] and sha(path)==want['sha256'],name
release=load(root/'release.json'); final=load(root/'source_snapshot/inputs.json')
assert sha(root/'source_snapshot/inputs.json')==release['final_source_manifest_sha256']
assert len(final)==346
for name,want in final.items():assert sha(root/'source_snapshot'/name)==want,name
for index in ['r1','r2','r3','r4']:
 history=root/'history'/index; inputs=load(history/'inputs.json')
 for name,want in inputs.items():
  delta=history/'source_delta'/name
  assert sha(delta if delta.is_file() else root/'source_snapshot'/name)==want,(index,name)
build=load(root/'history/r3/inputs.json')
assert [n for n in build if build[n]!=final[n]]==['sim/tb_regions.v']
assert sha(root/release['bit']['path'])==release['bit']['sha256']
tests=load(root/'validation/test_provenance.json');assert len(tests)==31
for t in tests:
 p=root/t['archive_console'];assert sha(p)==t['console_sha256'],t['name']
 text=read(p)
 assert re.search(r'PASS .*:',text) and 'Errors: 0,' in text and not re.search(r'\*\* (Error|Fatal):',text),t['name']
audit=load(root/'validation/final_audit.json')
assert audit['status']=='PASS_SOFTWARE_AND_ROUTED_ONSITE_PENDING'
assert audit['sdc_changed_from_v11'] is False and audit['all_max_delays_matched']==40
assert len(audit['gray_bits'])==20 and min(x['slack_ns'] for x in audit['gray_bits'])>=0
assert release['routed_sta']['setup_ns']>=0 and release['routed_sta']['hold_ns']>=0
print(f'PASS V12 package: {len(manifest["files"])} payload files, 346 inputs, 4 historical snapshots, 31 logs, routed audit and bit SHA')
