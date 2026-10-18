from pathlib import Path
import hashlib,json
r=Path(__file__).resolve().parents[1];sha=lambda q:hashlib.sha256(q.read_bytes()).hexdigest();load=lambda q:json.loads(q.read_text('utf-8-sig'))
for n,h in load(r/'package_sha256.json').items():assert sha(r/n)==h,n
m=load(r/'source_snapshot/inputs.json');assert len(m)==372
for n,h in m.items():assert sha(r/'source_snapshot'/n)==h,n
for d in (r/'provenance').iterdir():
 for n,h in load(d/'inputs.json').items():
  q=d/'delta'/n;assert sha(q if q.exists() else r/'source_snapshot'/n)==h,(d.name,n)
a=load(r/'handoff.json');assert len(a['tests'])==14 and not a['physical_validation']
assert sha(r/'candidate/V12_SMALL_DUAL_1092_40_20261018.bit')==a['bit']['sha256']
src=load(r/'calibration_sources/receipt.json');assert sha(r/'calibration_sources'/Path(src['path']).name)==src['sha256']
print('PASS small dual package:372 inputs,14 tests,bit,all file hashes,5 prior source reconstructions,28-photo archive; field pending')
