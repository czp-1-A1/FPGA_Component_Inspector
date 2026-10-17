from pathlib import Path
import hashlib,json,zipfile
r=Path(__file__).resolve().parents[1];sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
def load(p):return json.loads(p.read_text(encoding='utf-8-sig'))
for n,v in load(r/'MANIFEST.json').items():
 p=(r/n).resolve();assert p.is_relative_to(r) and p.stat().st_size==v['bytes'] and sha(p)==v['sha256'],n
h=load(r/'handoff.json');m=load(r/'source_snapshot/inputs.json');assert len(m)==358 and len(h['tests'])==3 and sha(r/'source_snapshot/inputs.json')==h['source_manifest_sha256']
for n,v in m.items():assert sha(r/'source_snapshot'/n)==v
for t in h['tests']:assert sha(r/'validation/tests'/t['name']/'console.log')==t['console_sha256']
for d in (r/'provenance').iterdir():
 for n,v in load(d/'inputs.json').items():
  p=d/'delta'/n;assert sha(p if p.exists() else r/'source_snapshot'/n)==v,n
for t in h['previous_validation']['tests']:assert sha(r/'provenance/previous_pose_trial/tests'/t['name']/'console.log')==t['console_sha256']
assert h['max_delays_matched']==40 and h['max_delays_ignored']==0 and h['resources']['eram']['used']<=104 and h['resources']['dsp']['used']<=26
assert min(h['routed_sta'][k] for k in ['setup_ns','hold_ns','setup_tns_ns','hold_tns_ns'])>=0
bit=next((r/'candidate').glob('*.bit'));assert sha(bit)==h['bit']['sha256']
for z in (r/'calibration_sources').glob('*.zip'):
 with zipfile.ZipFile(z) as f:
  assert f.testzip() is None
  for n,v in json.loads(f.read('MANIFEST.json')).items():assert hashlib.sha256(f.read(n)).hexdigest()==v['sha256']
print('PASS stable IDs full package:358 inputs,3 current tests,prior10,old-source reproduction,actual routed reports,source archives; physical check pending')
