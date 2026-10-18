from pathlib import Path
import hashlib,json
r=Path(__file__).resolve().parents[1];sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
load=lambda p:json.loads(p.read_text('utf-8-sig'))
for n,v in load(r/'MANIFEST.json').items():
 p=(r/n).resolve();assert p.is_relative_to(r) and p.stat().st_size==v['bytes'] and sha(p)==v['sha256'],n
for n,h in load(r/'source_snapshot/inputs.json').items():assert sha(r/'source_snapshot'/n)==h,n
for d in (r/'provenance').iterdir():
 for n,h in load(d/'inputs.json').items():
  p=d/'delta'/n;assert sha(p if p.exists() else r/'source_snapshot'/n)==h,n
print('PASS WIP handoff integrity: frozen sources, original logs, negative-round reconstruction; this is not release approval')
