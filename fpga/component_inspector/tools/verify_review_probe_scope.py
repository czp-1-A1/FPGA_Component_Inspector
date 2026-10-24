"""Audit the exact change surface against the protected R13 source.

Projection restores the original text by removing the declared probe-only
additions. It is a source-scope check, not a formal-equivalence solver.
"""
from pathlib import Path
import argparse, ast, hashlib, json, re

root=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser()
parser.add_argument('--repo',type=Path,required=True)
args=parser.parse_args();repo=args.repo.resolve()
base=repo/'fpga/component_inspector'
manifest=json.loads((repo/'releases/r13_20261023/frozen_inputs.json').read_text(encoding='utf-8'))
def digest(p): return hashlib.sha256(p.read_bytes()).hexdigest()
for rel,expected in manifest.items(): assert digest(base/rel)==expected,rel

# Evaluate only the declarative replacement tuples, with edit replaced by a
# collector. The setup function and all subsequent asset/file writes are skipped.
declared=[]
tree=ast.parse((root/'tools/setup_review_probe.py').read_text(encoding='utf-8'))
nodes=[]
for node in tree.body:
    if isinstance(node,ast.Assign) and any(isinstance(t,ast.Name) and t.id=='layout' for t in node.targets):break
    if isinstance(node,ast.FunctionDef) and node.name=='edit':continue
    nodes.append(node)
scope={'__file__':str(root/'tools/setup_review_probe.py'),
       'edit':lambda name,changes:declared.append((name,changes))}
exec(compile(ast.Module(body=nodes,type_ignores=[]),'probe_change_declarations','exec'),scope)
projected=[]
for name,changes in declared:
    actual=(root/'user_source/hdl_source'/name).read_text(encoding='utf-8')
    for old,new,count in reversed(changes):
        assert actual.count(new)==count,(name,'undeclared or duplicate change',new)
        actual=actual.replace(new,old)
    expected=(base/'user_source/hdl_source'/name).read_text(encoding='utf-8')
    assert actual==expected,('original statements changed',name)
    projected.append('user_source/hdl_source/'+name)
rom='user_source/hdl_source/compact_template_rom.v'
actual=(root/rom).read_text(encoding='utf-8')
actual=actual.replace('module compact_template_rom #(parameter REVIEW_PROBE=0)(','module compact_template_rom(')
actual=re.sub(r"REVIEW_PROBE \? 10'h[0-9a-f]+ : (10'h[0-9a-f]+)",r'\1',actual)
assert actual==(base/rom).read_text(encoding='utf-8')
if rom not in projected:projected.append(rom)
unchanged=[]
for rel,expected in manifest.items():
    if rel in projected:continue
    if rel.startswith(('user_source/','sim/')) or rel.endswith('.sdc'):
        assert digest(root/rel)==expected,('protected source/test/constraint changed',rel)
        unchanged.append(rel)
report={'status':'PASS_EXACT_DECLARED_PROBE_CHANGE_SCOPE_AND_R13_SOURCE_PROJECTION',
        'baseline471_verified':len(manifest),'projected_files':projected,
        'unchanged_protected_files':len(unchanged),'counter_pipeline_unchanged':True,
        'all_original_test_inputs_and_oracles_unchanged':True,
        'sdc_sha256':digest(root/'td_project/camera_to_dsi_display.sdc'),
        'scope':'Probe capture/reference tags, reused CAL payload and diagnostic display; no changed classifier expression or recorder implementation',
        'formal_solver_used':False}
(root/'R1_SCOPE_VERIFICATION.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print(json.dumps(report,indent=2))
