from pathlib import Path
import hashlib,json,re
root=Path(__file__).resolve().parents[1]
sha=lambda q:hashlib.sha256(q.read_bytes()).hexdigest()
def read(q):
 b=q.read_bytes();return b.decode('utf-16' if b.startswith((b'\xff\xfe',b'\xfe\xff')) else 'utf-8-sig')
def load(q):return json.loads(read(q))
m=load(root/'MANIFEST.json')
for n,v in m.items():
 q=(root/n).resolve();assert q.is_relative_to(root) and q.is_file(),n
 assert q.stat().st_size==v['bytes'] and sha(q)==v['sha256'],n
a=load(root/'handoff.json');inputs=load(root/'source_snapshot/inputs.json')
assert len(inputs)==353 and sha(root/'source_snapshot/inputs.json')==a['source_manifest_sha256']
for n,h in inputs.items():assert sha(root/'source_snapshot'/n)==h,n
assert len(a['tests'])==5 and a['status']=='PASS_BODY_MINIMUM_TRIAL_SOFTWARE_ROUTED_PHYSICAL_CLASSIFICATION_PENDING'
for t in a['tests']:
 q=root/'validation/tests'/t['name']/'console.log';s=read(q)
 assert sha(q)==t['console_sha256'] and 'Errors: 0,' in s and re.search(r'PASS .*:',s) and not re.search(r'\*\* (Error|Fatal):',s),t['name']
for tag in ['r0_old_minimum_reproduction','r1_exact_build_fixture_failure']:
 prior=load(root/'history'/tag/'inputs.json')
 for n,h in prior.items():
  q=root/'history'/tag/'delta'/n
  assert sha(q if q.exists() else root/'source_snapshot'/n)==h,n
  if tag.startswith('r1') and n.startswith('user_source/'):assert h==inputs[n],n
 assert '** Fatal:' in read(root/'history'/tag/'console.log')
assert sha(root/'history/r1_exact_build_fixture_failure/inputs.json')==a['build_source_manifest_sha256']
assert len(a['gray_bits'])==20 and min(g['slack_ns'] for g in a['gray_bits'])>=0
assert a['gray_physical_report']['constraint_matched_paths']==22 and a['gray_physical_report']['reported_paths']==29
assert not a['sdc_changed'] and a['production_identical_between_rounds']
assert sha(root/'candidate/V12_CAL180_body_trial_1092_40_20261016.bit')==a['bit']['sha256']
print('PASS BODY TRIAL:',len(m),'payload files,353 inputs,5 test logs, preserved failure rounds, exact build binding and bit SHA; physical calibration pending')
