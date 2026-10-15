"""Verify archived bytes, all historical source manifests, test provenance and bit."""
from pathlib import Path
import hashlib,json
H=Path(__file__).resolve().parents[1]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
m=json.loads((H/'MANIFEST.json').read_text(encoding='utf-8'))
for rel,item in m.items():
 p=(H/rel).resolve()
 assert p.is_relative_to(H) and p.is_file(),rel
 assert p.stat().st_size==item['bytes'] and sha(p)==item['sha256'],rel
snap=H/'source_snapshot'; final=json.loads((snap/'inputs.json').read_text())
for rel,v in final.items():assert sha(snap/rel)==v,rel
for d in sorted((H/'history').iterdir()):
 old=json.loads((d/'inputs.json').read_text())
 for rel,v in old.items():
  p=d/'source_delta'/rel
  if not p.exists():p=snap/rel
  assert sha(p)==v,(d.name,rel)
 if d.name in ['r2','r3','r4','r5','r6','r7']:
  for rel,v in old.items():
   if rel.startswith('user_source/') or rel.endswith('.sdc'):assert final[rel]==v,(d.name,rel)
a=json.loads((H/'validation/final_audit.json').read_text())
for e in a['test_provenance']:
 p=H/'validation'/e['console'];assert sha(p)==e['console_sha256'],e['name']
 assert 'PASS' in p.read_text(errors='replace'),e['name']
bit=H/'candidate/V12_CAL180_observer_1092_40_20261016.bit'
assert sha(bit)==a['bit']['sha256'] and bit.stat().st_size==a['bit']['bytes']
print('PASS handoff payload:',len(m),'files; frozen inputs:',len(final),'; test records:',len(a['test_provenance']))
print('PASS historical snapshots r1-r7 and identical production inputs r2-r7')
print('Recipe and SHA-bound board acceptance remain pending.')
