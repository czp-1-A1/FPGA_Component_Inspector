"""Record the inherited capacity review using actual routed resource evidence."""
from pathlib import Path
import hashlib,json
repo=Path(__file__).resolve().parents[1];analysis=Path('D:/CodexWork/empty_tail_role_20261102')
work=Path('D:/CodexWork/erole_build_r1_20261102');validation=repo/'validation/pocket_row_roles';validation.mkdir(parents=True,exist_ok=True)
p=json.loads((work/'physical_verification.json').read_text());assert p['status'].startswith('PASS_')
r=p['resources'];assert r['slice']<=21216 and (r['eram'],r['dsp'],r['pll'])==(98,30,5)
assert p['timing_ns']['SWNS']>=0 and p['timing_ns']['HWNS']>=0 and p['timing_ns']['STNS']==p['timing_ns']['HTNS']==0
baseline=json.loads((analysis/'baseline_inputs.json').read_text())
for rel in ['td_project/camera_to_dsi_display.sdc','user_source/constraints_source/pin.adc']:
 assert hashlib.sha256((work/'project'/rel).read_bytes()).hexdigest()==baseline[rel]
result={'status':'REVIEWED_NO_FURTHER_FEATURE_ADDITION','baseline_commit':'1b8a097f9dd7d7dee2783e9dcbcf43986f7650f4','actual_slice':r['slice'],'available_slice':21216,'slice_percent':round(r['slice']/21216*100,6),'remaining_slice':21216-r['slice'],'resources':r,'timing_ns':p['timing_ns'],'baseline_slice':18903,'same_td_version':'6.2.178840','seed':1,'assessment':'Review required above the AGENTS80% advisory line. This changes only current-frame shape/row role evidence using existing registers; no new ROI, RAM array, CDC, pixel backpressure, divider, DSP or PLL. Retain inherited device-capacity and full routed timing/CDC/output acceptance. Original SDC/pins/seed1 unchanged; no further feature addition. Native video and physical timing are independently measured, never inferred from synthesis area.','board_operated':False}
(validation/'resource_review.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result,indent=2))
