from pathlib import Path
import hashlib,json,re
root=Path(__file__).resolve().parents[1]
sha=lambda q:hashlib.sha256(q.read_bytes()).hexdigest()
def read(q):
 b=q.read_bytes();return b.decode('utf-16' if b[:2]==bytes((255,254)) else 'utf-8-sig')
def load(q):return json.loads(read(q))
m=load(root/'MANIFEST.json')
for n,v in m.items():
 q=(root/n).resolve();assert q.is_relative_to(root) and q.is_file(),n
 assert q.stat().st_size==v['bytes'] and sha(q)==v['sha256'],n
h=load(root/'handoff.json');inputs=load(root/'source_snapshot/inputs.json')
assert len(inputs)==356 and sha(root/'source_snapshot/inputs.json')==h['source_manifest_sha256']
for n,v in inputs.items():assert sha(root/'source_snapshot'/n)==v,n
assert len(h['tests'])==9 and h['status']=='PASS_FIELD180_TRIAL_SOFTWARE_ROUTED_PHYSICAL_VALIDATION_PENDING'
for t in h['tests']:
 q=root/'validation/tests'/t['name']/'console.log';s=read(q)
 assert sha(q)==t['console_sha256'] and 'Errors: 0,' in s and not re.search(r'[*][*] (?:Error|Fatal):',s),t['name']
for d in (root/'history').iterdir():
 if d.is_dir():
  for n,v in load(d/'inputs.json').items():
   q=d/'delta'/n;assert sha(q if q.exists() else root/'source_snapshot'/n)==v,n
bits=list((root/'candidate').glob('*.bit'));assert len(bits)==1 and sha(bits[0])==h['bit']['sha256']
assert h['max_delays_matched']==40 and h['max_delays_ignored']==0 and not h['sdc_changed']
assert min(h['routed_sta'][k] for k in ['setup_ns','hold_ns','setup_tns_ns','hold_tns_ns'])>=0
f=h['field_runtime'];assert max(f['unit_slope_cycles'])<=120000 and max(f['real_chain_result_latency_ns'])<f['real_chain_tail_budget_ns']
print('PASS FIELD180 TRIAL: full manifest,356 frozen inputs,9 test logs,preserved failures,27FPS timing and routed evidence; physical validation pending')
