"""Record the required high-utilization review from actual audited reports."""
from pathlib import Path
import hashlib,json
repo=Path(__file__).resolve().parents[1];work=Path('D:/CodexWork/rl7_alarm_roles_empty_only_20261102_build_r0')
p=json.loads((work/'physical_verification.json').read_text())
assert p['status'].startswith('PASS_')
resources=p['resources'];assert resources['slice']<=21216 and resources['eram']==98 and resources['dsp']==30 and resources['pll']==5
assert p['timing_ns']['SWNS']>=0 and p['timing_ns']['HWNS']>=0 and p['timing_ns']['STNS']==p['timing_ns']['HTNS']==0
baseline=json.loads((repo/'validation/baseline_frozen_inputs.json').read_text())
for rel in ['td_project/camera_to_dsi_display.sdc','user_source/constraints_source/pin.adc']:
 assert hashlib.sha256((work/'project'/rel).read_bytes()).hexdigest()==baseline[rel]
review={'status':'REVIEWED_NO_FURTHER_FEATURE_ADDITION','baseline_commit':'904a2bb053a9e679b3f50378ca3163a55698b20e','actual_slice':resources['slice'],'available_slice':21216,'slice_percent':round(resources['slice']/21216*100,6),'remaining_slice':21216-resources['slice'],'resources':resources,'timing_ns':p['timing_ns'],'baseline_slice':19131,'current_td':'6.2.178840','baseline_td':'6.2.168116','seed':1,'assessment':'Retain inherited V3 device-capacity and full routed timing/CDC/output gates. This task changes only stop policy: no new ROI/detector/camera feature, RAM/DSP/PLL. Above AGENTS80% advisory line requires this review and no further feature addition. Do not attribute cross-TD area difference solely to the3 source changes. Original SDC/pin bytes and seed1 preserved.','board_operated':False}
(repo/'validation/resource_review.json').write_text(json.dumps(review,indent=2)+'\n')
print(json.dumps(review,indent=2))
