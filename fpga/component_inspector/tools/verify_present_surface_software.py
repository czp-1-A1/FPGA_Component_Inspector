"""Collect only actually completed P02 software evidence; no physical or field claim."""
from pathlib import Path
import hashlib
import json
import re

P=Path(__file__).resolve().parents[1]
C=Path('D:/FpgaWork/P02_compat_checks_20261024')
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
  result['errors']=int(count[1]);result['warnings']=int(count[2])
 checks[name]=result
log('unit',P/'sim/surface/unit_runtime.log','PASS present surface: 26 requests, 105 exact independent five-bit means;')
log('rgb_detector',P/'sim/surface/detector_runtime_r2.log','PASS surface detector:8 full720p RGB frames, 64 recorder records, 280 independent means, 36 quality bits changed, 2506968 clocks')
log('native_chain',P/'sim/modelsim_work/surface_raw_chain/console.log','PASS surface raw chain:')
native=(P/'sim/modelsim_work/surface_raw_chain/console.log').read_text(encoding='utf-8-sig')
assert 'SURFACE native frame7 objects4 checks24 means120' in native
assert 'PROBE native frame7 checks60' in native
assert 'rasters=13 pixels=12538000 OF=0 UF=0' in native
log('enabled_counting',P/'sim/surface/counting_runtime.log','PASS surface counting: 70 actual T100/T80 frames, 140 classified observations, 4 crossings incl empty #3')
tests=load(P/'P01_MEASUREMENT_GATE_REFERENCE.json')['required_compat']
assert len(tests)==24
for name in tests:log('original_'+name,C/'sim/modelsim_work'/name/'console.log','PASS ')
for name,path in [('p02_ui',P/'sim/surface/independent_pixels/verification.json'),
                  ('original_ui',C/'independent_original_ui/verification.json')]:
 data=load(path)
 assert data['status']=='PASS' and len(data['frames'])==4
 assert sum(r['pixels'] for r in data['frames'])==3686400
 assert sum(r['mismatch'] for r in data['frames'])==0
 checks[name]=dict(status='PASS',path=str(path),sha256=sha(path),pixels=3686400,mismatches=0)
scope=load(P/'P02_SCOPE_VERIFICATION.json')
assert scope['status']=='PASS_EXACT_DECLARED_P01_TO_P02_SCOPE_AND_FROZEN_HARDWARE100'
inputs=load(P/'P02_DESIGN_INPUTS.json')
assert len(inputs)==100
for name,h in inputs.items():assert sha(P/name)==h,('hardware input drift',name)
report=dict(status='PASS_P02_SURFACE_SOFTWARE_GATE',checks=checks,compiled_dependencies=inputs,
 original_related_tests=24,original72_all_rerun=False,
 unit_exact_five_bit_feature_comparisons=105,rgb_independent_feature_references=280,
 rgb_record_comparisons=64,rgb_expected_quality_bit_changes=36,
 default_off_cycles=2506968,default_off_signals=['ready','sample_new','objects','region_objects','recorder_objects','probe_record','probe_ready'],
 enabled_counting_frames=70,enabled_counting_observations=140,enabled_counting_crossings=4,
 native_frames=7,native_eight_bit_probe_mean_comparisons=60,
 native_surface_quality_decisions=24,native_independent_five_bit_feature_references=120,
 native_pixel_comparisons=12538000,native_full_rasters=13,native_overflow=0,native_underflow=0,
 original_and_p02_ui_pixels_each=3686400,ui_mismatches=0,
 classification_field_accuracy_claimed=False,physical_acceptance='SEPARATE_ROUTED_AUDIT_REQUIRED',
 distinction='RGB/native five-bit scalar means independently predict every quality decision; exact five-bit mean outputs separately compared by unit105. Eight-bit diagnostic means compared exactly in native60.')
(P/'P02_SOFTWARE_VERIFICATION.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print('PASS P02 software:',len(checks),'evidence groups; 24 original regressions, enabled native/70-frame count, both independent UI references; hardware100 frozen')
