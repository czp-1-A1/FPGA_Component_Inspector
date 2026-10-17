from pathlib import Path
import hashlib,json,re
root=Path(__file__).resolve().parents[1]
sha=lambda q:hashlib.sha256(q.read_bytes()).hexdigest()
def read(q):
 b=q.read_bytes();return b.decode('utf-16' if b.startswith((b'\xff\xfe',b'\xfe\xff')) else 'utf-8-sig')
load=lambda q:json.loads(read(q))
m=load(root/'MANIFEST.json')
for n,v in m.items():
 q=(root/n).resolve();assert q.is_relative_to(root) and q.is_file(),n
 assert q.stat().st_size==v['bytes'] and sha(q)==v['sha256'],n
a=load(root/'handoff.json');inputs=load(root/'source_snapshot/inputs.json')
assert len(inputs)==354 and sha(root/'source_snapshot/inputs.json')==a['source_manifest_sha256']
for n,h in inputs.items():assert sha(root/'source_snapshot'/n)==h,n
assert a['status']=='PASS_HOLES80_TRIAL_SOFTWARE_ROUTED_PHYSICAL_VALIDATION_PENDING' and len(a['tests'])==7
for t in a['tests']:
 q=root/'validation/tests'/t['name']/'console.log';s=read(q)
 assert sha(q)==t['console_sha256'] and 'Errors: 0,' in s and re.search(r'PASS .*:',s) and not re.search(r'\*\* (?:Error|Fatal):',s),t['name']
for history in (root/'history').iterdir():
 if not history.is_dir():continue
 prior=load(history/'inputs.json')
 for n,h in prior.items():
  q=history/'delta'/n;assert sha(q if q.exists() else root/'source_snapshot'/n)==h,n
assert len(a['gray_bits'])==20 and all(g['budget_ns']==8 and g['slack_ns']>=0 for g in a['gray_bits'])
assert a['max_delays_matched']==40 and a['max_delays_ignored']==0 and not a['sdc_changed']
assert min(a['routed_sta'][n] for n in ['setup_ns','hold_ns','setup_tns_ns','hold_tns_ns'])>=0
bits=list((root/'candidate').glob('*.bit'));assert len(bits)==1 and sha(bits[0])==a['bit']['sha256']
print('PASS HOLES80 TRIAL:',len(m),'payload files,354 frozen inputs,7 test logs,preserved rounds,actual routed evidence and bit SHA; physical validation pending')
