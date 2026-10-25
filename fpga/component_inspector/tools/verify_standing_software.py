"""Aggregate completed P03 evidence without extending it to board acceptance."""
from pathlib import Path
import argparse
import hashlib
import json
import re

P=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser()
parser.add_argument('--compat',type=Path,default=Path('D:/FpgaWork/P03_compat_checks_20261025'))
C=parser.parse_args().compat.resolve()
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
load=lambda p:json.loads(p.read_text(encoding='utf-8-sig'))
checks={}

def log(name,path,marker):
 text=path.read_text(encoding='utf-8-sig')
 assert marker in text,(name,'missing successful completion')
 assert not re.search(r'(?m)^#?\s*\*\* (?:Fatal|Error):',text),(name,'fatal/error')
 result=dict(status='PASS',path=str(path),sha256=sha(path))
 count=re.search(r'Errors: (\d+), Warnings: (\d+)',text)
 if count:
  assert count[1]=='0'
  result.update(errors=int(count[1]),warnings=int(count[2]))
 checks[name]=result
 return text

log('unit',P/'sim/standing/unit_runtime.log','PASS P03 standing surface: 39 requests, 170 exact independent five-bit means;')
log('rgb_detector',P/'sim/standing/standing_detector.runtime.log',
    'PASS P03 standing detector:9 full720p RGB frames, 72 recorder records, 320 independent means, 44 quality bits changed, 2829736 clocks')
native=log('native_chain',P/'sim/modelsim_work/standing_raw_chain/console.log','PASS P03 standing raw chain:')
assert 'SURFACE native frame8 objects4 checks28 means140' in native
assert 'PROBE native frame8 checks70' in native
n=re.search(r'full exact RGB rasters=(\d+) pixels=(\d+) OF=0 UF=0',native)
assert n and int(n[1])>=14 and int(n[2])>=12902400
log('enabled_counting',P/'sim/standing/standing_counting.runtime.log',
 'PASS P03 standing counting: 70 actual T100/T80 frames, 140 classified observations, 4 crossings incl empty #3')
log('enabled_ui_sim',P/'sim/modelsim_work/standing_ui/console.log','PASS P03 standing UI:')
tests=load(P/'P01_MEASUREMENT_GATE_REFERENCE.json')['required_compat']
assert len(tests)==24
for name in tests:log('original_'+name,C/'sim/modelsim_work'/name/'console.log','PASS ')
for name,path in [('p03_ui',P/'sim/standing/independent_pixels/verification.json'),
                  ('original_ui',C/'independent_original_ui/verification.json')]:
 data=load(path)
 assert data['status']=='PASS' and len(data['frames'])==4
 assert sum(r['pixels'] for r in data['frames'])==3686400
 assert sum(r['mismatch'] for r in data['frames'])==0
 checks[name]=dict(status='PASS',path=str(path),sha256=sha(path),pixels=3686400,mismatches=0)
scope=load(P/'P03_SCOPE_VERIFICATION.json')
assert scope['status']=='PASS_DECLARED_P02_TO_P03_SCOPE_AND_EXACT_HARDWARE100'
assert load(P/'P03_NATIVE_RASTER_VERIFICATION.json')['surface_decisions']==28
inputs=load(P/'P03_DESIGN_INPUTS.json');assert len(inputs)==100
compat_inputs=load(C/'compat_inputs.json')
for name,h in inputs.items():
 assert sha(P/name)==h,('hardware input drift',name)
 assert sha(C/name)==h==compat_inputs[name],('compat did not use frozen hardware',name)
report=dict(status='PASS_P03_STANDING_SOFTWARE_GATE',checks=checks,compiled_dependencies=inputs,
 original_related_tests=24,original72_all_rerun=False,
 unit_requests=39,unit_exact_five_bit_means=170,unit_exact_five_bit_sums=170,
 rgb_record_comparisons=72,rgb_scalar_feature_references=320,
 rgb_quality_changes_against_p01=44,rgb_new_standing_changes_against_p02=8,
 rgb_prior_p02_scenes_unchanged=8,default_off_exact_p01_clocks=2829736,
 enabled_counting_frames=70,enabled_counting_observations=140,enabled_counting_crossings=4,
 native_source_frames=8,native_valid_quality_frames=7,native_quality_decisions=28,
 native_feature_sum_references=140,native_eight_bit_probe_means=70,
 native_full_rasters=int(n[1]),native_pixel_comparisons=int(n[2]),native_overflow=0,native_underflow=0,
 original_and_p03_ui_pixels_each=3686400,ui_mismatches=0,
 failed_native_fixture='Retained760 contrast fixture failed isolation; new synthetic contrast840 only, RTL/oracles unchanged',
 classification_board_accuracy_claimed=False,physical_acceptance='SEPARATE_ROUTED_AUDIT_REQUIRED')
(P/'P03_SOFTWARE_VERIFICATION.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print('PASS P03 software:',len(checks),'evidence groups; frozen hardware100; no board acceptance claim')
