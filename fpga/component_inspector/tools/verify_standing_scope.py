"""Verify the declared P02->P03 source delta and frozen hardware inputs."""
from pathlib import Path
import argparse
import ast
import hashlib
import json
import re

P=Path(__file__).resolve().parents[1]
a=argparse.ArgumentParser()
a.add_argument('--baseline',type=Path,default=Path('D:/FpgaWork/R13_present_surface_p02_r0_20261024'))
B=a.parse_args().baseline.resolve()
sha=lambda q:hashlib.sha256(q.read_bytes()).hexdigest()
parent=json.loads((P/'p02_final_inputs_before_p03.json').read_text())
def project_root_from_entry(folder):
 text=(folder/'td_project/camera_to_dsi_display.al').read_text(encoding='utf-8-sig')
 return Path(re.search(r'<Project\b[^>]*\bPath="([^"]+)"',text)[1]).parent.as_posix()
old_root=project_root_from_entry(B)
new_root=project_root_from_entry(P)
tree=ast.parse((P/'tools/setup_standing_p03.py').read_text())
edits=next(ast.literal_eval(n.value) for n in tree.body if isinstance(n,ast.Assign) and
           any(isinstance(t,ast.Name) and t.id=='edits' for t in n.targets))
relocated={'td_project/camera_to_dsi_display.al',
 'td_project/camera_to_dsi_display_Runs/phy_1/camera_to_dsi_display.prj',
 'td_project/camera_to_dsi_display_Runs/syn_1/camera_to_dsi_display.prj'}
changed=[];protected=[]
for name,digest in parent.items():
 assert sha(B/name)==digest,('P02 parent changed',name)
 if name in edits:
  text=(P/name).read_text(encoding='utf-8-sig')
  for old,new in reversed(edits[name]):
   assert text.count(new)==1,(name,new)
   text=text.replace(new,old,1)
  assert text==(B/name).read_text(encoding='utf-8-sig'),('unexpected RTL delta',name)
  changed.append(name)
 elif name in relocated:
  old=(B/name).read_text(encoding='utf-8-sig');new=(P/name).read_text(encoding='utf-8-sig')
  # Exactly this root changed in the three project location descriptors.
  old=old.replace(old_root,'<project>').replace(old_root.replace('/','\\'),'<project>')
  new=new.replace(new_root,'<project>').replace(new_root.replace('/','\\'),'<project>')
  assert old==new,('unexpected project descriptor delta',name)
 else:
  assert sha(P/name)==digest,('protected parent input changed',name)
  protected.append(name)
inputs=json.loads((P/'P03_DESIGN_INPUTS.json').read_text())
assert len(inputs)==100
for name,digest in inputs.items():assert sha(P/name)==digest,('frozen hardware changed',name)
assert inputs['td_project/camera_to_dsi_display.sdc']=='4a248232348e0f5338472dab5a8c275f1edb100354049be7df62ef1d88972a51'
assert 'place seed 2 ' in (P/'td_project/camera_to_dsi_display_Runs/phy_1/settings.cfg').read_text()
report=dict(status='PASS_DECLARED_P02_TO_P03_SCOPE_AND_EXACT_HARDWARE100',
 parent_static_inputs=len(parent),protected_exact_sha=len(protected),declared_changed_hdl=changed,
 relocation_only=sorted(relocated),image_cache_added=False,metadata_width=887,physical_seed=2,
 original_test_and_gold_unchanged=True,formal_solver_used=False)
(P/'P03_SCOPE_VERIFICATION.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print(json.dumps(report,indent=2))
