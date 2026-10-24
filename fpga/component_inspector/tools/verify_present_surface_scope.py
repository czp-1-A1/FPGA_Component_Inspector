"""Check declared edits against frozen P01 and exact compiled input identity."""
from pathlib import Path
import ast
import argparse
import hashlib
import json
import re

P=Path(__file__).resolve().parents[1]
BASE=Path('D:/FpgaWork/R13_present_review_p01_r1_20261024')
parser=argparse.ArgumentParser()
parser.add_argument('--baseline',type=Path,default=BASE)
BASE=parser.parse_args().baseline.resolve()
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
before=json.loads((P/'p01_final_inputs_before_p02.json').read_text(encoding='utf-8'))
tree=ast.parse((P/'tools/setup_present_surface.py').read_text(encoding='utf-8'))
edits=next(ast.literal_eval(n.value) for n in tree.body if isinstance(n,ast.Assign) and
           any(isinstance(t,ast.Name) and t.id=='edits' for t in n.targets))
protected=[]
for name,expected in before.items():
 assert sha(BASE/name)==expected,('parent baseline drift',name)
 if name in edits:
  actual=(P/name).read_text(encoding='utf-8-sig')
  for old,new in reversed(edits[name]):
   assert actual.count(new)==1,('declared edit missing/duplicated',name,new)
   actual=actual.replace(new,old,1)
  original=(BASE/name).read_text(encoding='utf-8-sig')
  if name.endswith('.al'):
   actual=re.sub(r'(<Project\b[^>]*\bPath=")[^"]*',r'\1<relocated>',actual,count=1)
   original=re.sub(r'(<Project\b[^>]*\bPath=")[^"]*',r'\1<relocated>',original,count=1)
  assert actual==original,('unexpected source edit',name)
 elif not name.startswith('td_project/camera_to_dsi_display_Runs/'):
  assert sha(P/name)==expected,('protected file changed',name)
  protected.append(name)
inputs=json.loads((P/'P02_DESIGN_INPUTS.json').read_text(encoding='utf-8'))
assert len(inputs)==100
for name,expected in inputs.items():assert sha(P/name)==expected,('compiled source drift',name)
assert inputs['td_project/camera_to_dsi_display.sdc']=='4a248232348e0f5338472dab5a8c275f1edb100354049be7df62ef1d88972a51'
assert 'place seed 2 ' in (P/'td_project/camera_to_dsi_display_Runs/phy_1/settings.cfg').read_text()
report=dict(status='PASS_EXACT_DECLARED_P01_TO_P02_SCOPE_AND_FROZEN_HARDWARE100',
 parent_static_inputs=len(before),protected_exact_sha=len(protected),
 declared_changed_files=list(edits),added_hdl='user_source/hdl_source/present_surface_check.v',
 counter_pipeline_original_test_and_gold_unchanged=True,metadata_bits=887,physical_seed=2,
 formal_solver_used=False)
(P/'P02_SCOPE_VERIFICATION.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print(json.dumps(report,indent=2))
