from pathlib import Path
import hashlib,json
r=Path(__file__).resolve().parents[1]
sha=lambda q:hashlib.sha256(q.read_bytes()).hexdigest()
load=lambda q:json.loads(q.read_text('utf-8-sig'))
for n,h in load(r/'package_sha256.json').items():assert sha(r/n)==h,n
m=load(r/'source_snapshot/inputs.json')
for n,h in m.items():assert sha(r/'source_snapshot'/n)==h,n
for label in ['selected_c093','negative_baseline','unselected_r0_dsp27']:
 for n,h in load(r/'provenance'/label/'inputs.json').items():
  q=r/'provenance'/label/'delta'/n
  assert sha(q if q.exists() else r/'source_snapshot'/n)==h,(label,n)
a=load(r/'handoff.json');assert len(m)==361 and len(a['tests'])==10 and not a['physical_validation']
assert sha(r/'candidate/V12_THRESHOLD180_1092_40_20261018.bit')==a['bit']['sha256']
photos=load(r/'calibration_sources/originals_manifest.json');assert len(photos)==28
for z in photos:assert sha(r/'calibration_sources'/z['session']/z['name'])==z['sha256']
print('PASS threshold package,361 frozen inputs,bit,10 tests,28 original photos,all hashes,c093/negative reconstruction; field pending')
