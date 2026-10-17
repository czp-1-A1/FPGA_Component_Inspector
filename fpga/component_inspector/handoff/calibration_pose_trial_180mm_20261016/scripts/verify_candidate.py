from pathlib import Path
import hashlib,json,re,zipfile
root=Path(__file__).resolve().parents[1]
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
def load(p):return json.loads(p.read_text(encoding='utf-8-sig'))
for n,v in load(root/'MANIFEST.json').items():
 q=(root/n).resolve();assert q.is_relative_to(root) and q.stat().st_size==v['bytes'] and sha(q)==v['sha256'],n
h=load(root/'handoff.json');m=load(root/'source_snapshot/inputs.json')
assert len(m)==357 and sha(root/'source_snapshot/inputs.json')==h['source_manifest_sha256']
for n,v in m.items():assert sha(root/'source_snapshot'/n)==v,n
assert len(h['tests'])==10 and h['status']=='PASS_POSE180_TRIAL_SOFTWARE_ROUTED_PHYSICAL_VALIDATION_PENDING'
for t in h['tests']:
 p=root/'validation/tests'/t['name']/'console.log';b=p.read_bytes();s=b.decode('utf-16' if b[:2]==bytes((255,254)) else 'utf-8-sig')
 assert sha(p)==t['console_sha256'] and 'Errors: 0,' in s and not re.search(r'[*][*] (?:Error|Fatal):',s),t['name']
for d in (root/'history').iterdir():
 if d.is_dir():
  for n,v in load(d/'inputs.json').items():
   q=d/'delta'/n;assert sha(q if q.exists() else root/'source_snapshot'/n)==v,n
bits=list((root/'candidate').glob('*.bit'));assert len(bits)==1 and sha(bits[0])==h['bit']['sha256']
assert h['max_delays_matched']==40 and h['max_delays_ignored']==0 and not h['sdc_changed']
assert h['resources']['eram']['used']<=104 and h['resources']['dsp']['used']<=26
assert min(h['routed_sta'][k] for k in ['setup_ns','hold_ns','setup_tns_ns','hold_tns_ns'])>=0
assert max(h['pose_cycles'].values())<=120000
f=h['field_runtime'];assert max(f['real_chain_result_latency_ns'])<f['real_chain_tail_budget_ns']
z=next((root/'calibration_sources').glob('*.zip'))
with zipfile.ZipFile(z) as archive:
 assert archive.testzip() is None
 for n,v in json.loads(archive.read('MANIFEST.json')).items():assert hashlib.sha256(archive.read(n)).hexdigest()==v['sha256'],n
print('PASS POSE180: full package,357 frozen inputs,10 tests,history,source ZIP,27FPS and routed audit; physical validation pending')
