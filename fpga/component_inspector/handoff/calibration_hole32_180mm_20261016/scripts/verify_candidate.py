from pathlib import Path
import hashlib,json,re
root=Path(__file__).resolve().parents[1]
sha=lambda q:hashlib.sha256(q.read_bytes()).hexdigest()
def read(q):
 b=q.read_bytes();return b.decode('utf-16' if b.startswith((b'\xff\xfe',b'\xfe\xff')) else 'utf-8-sig')
m=json.loads(read(root/'MANIFEST.json'))
for n,v in m.items():
 q=(root/n).resolve();assert q.is_relative_to(root) and q.is_file(),n
 assert q.stat().st_size==v['bytes'] and sha(q)==v['sha256'],n
a=json.loads(read(root/'handoff.json'));inputs=json.loads(read(root/'source_snapshot/inputs.json'))
assert len(inputs)==352 and sha(root/'source_snapshot/inputs.json')==a['source_manifest_sha256']
for n,h in inputs.items():assert sha(root/'source_snapshot'/n)==h,n
assert a['status']=='PASS_CAL32_OBSERVER_SOFTWARE_ROUTED_PENDING_NEW_PHYSICAL_READINGS' and len(a['tests'])==6
for t in a['tests']:
 q=root/'validation/tests'/t['name']/'console.log';s=read(q)
 assert sha(q)==t['console_sha256'] and 'Errors: 0,' in s and re.search(r'PASS .*:',s),t['name']
 assert not re.search(r'\*\* (Error|Fatal):',s),t['name']
assert sha(root/'candidate/V12_CAL180_hole32_1092_40_20261016.bit')==a['bit']['sha256']
assert len(a['gray_bits'])==20 and min(g['slack_ns'] for g in a['gray_bits'])>=0
assert a['max_delays_matched']==40 and a['max_delays_ignored']==0 and not a['classifier_changed'] and not a['sdc_changed']
print('PASS CAL32 candidate:',len(m),'payload files,352 inputs,6 test logs,routed/CDC audit and bit SHA; physical calibration pending')
