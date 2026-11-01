"""Verify V3 ownership logic and all unrelated production source bytes survive."""
from pathlib import Path
import hashlib,json,re,subprocess
repo=Path(__file__).resolve().parents[1];src=repo/'fpga/component_inspector'
base='904a2bb053a9e679b3f50378ca3163a55698b20e'
manifest=json.loads((repo/'validation/baseline_frozen_inputs.json').read_text())
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
changed={rel for rel,d in manifest.items() if sha(src/rel)!=d}
assert changed=={'user_source/hdl_source/design_top_wrapper.v','user_source/hdl_source/isp/isp_top.v','user_source/hdl_source/pocket_relay_stop_v2.v'}
rel='user_source/hdl_source/pocket_relay_stop_v2.v'
old=subprocess.check_output(['git','show',base+':fpga/component_inspector/'+rel],cwd=repo).decode()
new=(src/rel).read_bytes().decode()
get=lambda text,begin,end:text.split(begin,1)[1].split(end,1)[0]
for begin,end in [('wire fifth_empty=','wire pop='),('// One global prefix','cycle_done<=0;'),('wire global_event_bad=','wire tick=')]:
 assert get(old,begin,end)==get(new,begin,end),(begin,end)
for proof in json.loads((repo/'tests/empty_only_stop/derivation.json').read_text()):
 reference=repo/proof['reference'];derived=repo/proof['derived']
 assert sha(reference)==proof['reference_sha256'] and sha(derived)==proof['derived_sha256']
 old_text=reference.read_text();new_text=derived.read_text().replace(derived.stem,reference.stem)
 needle='isp_top #(' if 'native' in derived.stem else 'pocket_relay_stop_v2 #('
 assert new_text.replace(needle+'.EMPTY_ONLY_STOP(1),',needle)==old_text
result={'status':'PASS_V3_INDEPENDENT_ALARM_LEDGER_AND_ROLE_FILTER_PRESERVED','baseline':base,'sources':638,'unchanged_sources':635,'changed_sources':sorted(changed),'V3_fifth_expression_and_ledger_exact':True,'V3_role_filter_exact':True,'native_and_real_second_original_answers_exact':True,'board_operated':False}
(repo/'validation/v3_preservation.json').write_text(json.dumps(result,indent=2)+'\n')
print(result['status'])
