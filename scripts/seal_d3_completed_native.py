"""Seal a finished RAW-edge native run whose wrapper used the wrong PASS token.

Never rerun/edit a simulation or change its fixture/log. Require the actual
fixture's success token, clean compiler/simulator logs and every frozen input.
"""
from pathlib import Path
import argparse
import hashlib
import json
import re

p=argparse.ArgumentParser();p.add_argument('--work',type=Path,required=True);p.add_argument('--run',type=Path,required=True);a=p.parse_args()
root=Path(__file__).resolve().parents[1];w=a.work.resolve();run=a.run.resolve()
sha=lambda q:hashlib.sha256(q.read_bytes()).hexdigest()
manifest=json.loads((run/'INPUT_SHA256.json').read_text());source=json.loads((w/'frozen_inputs.json').read_text())
assert not (run/'verification.json').exists()
bench='tb_d3_raw_edge_native';fixture=root/'tests/dual_stop_d3'/f'{bench}.sv'
assert set(manifest['extra_inputs'])=={'sim/'+bench+'.sv'}
for rel,d in manifest['source'].items():assert d==source[rel]==sha(w/'project'/rel)==sha(run/'inputs/project'/rel),rel
for rel,d in manifest['extra_inputs'].items():assert d==sha(fixture)==sha(run/'inputs/project'/rel),rel
for rel,d in manifest['vendor'].items():assert d==sha(Path('E:/TD/sim_release')/rel)==sha(run/'inputs/vendor'/rel),rel
success='PASS D3_RAW_EDGE_TOP_DDR:'
assert success in fixture.read_text()
logs={}
for name in ['vendor_compile.log','compile_rtl.log','compile_bench.log','console.log']:
    text=(run/name).read_text()
    assert not re.search(r'\*\* (?:Fatal|Error):|Errors:\s*[1-9]',text),name
    assert re.search(r'Errors:\s*0',text),name
    logs[name]=sha(run/name)
text=(run/'console.log').read_text()
assert success in text and 'full exact RGB rasters=24 pixels=22940160 OF=0 UF=0' in text
assert '#  quit -code 0' in text and '# ** Note: $finish' in text
result={'status':'PASS','name':bench,'inputs':manifest['source'],'extra_inputs':manifest['extra_inputs'],
        'vendor':manifest['vendor'],'console_sha256':sha(run/'console.log'),'simulation_timeout_seconds':5400,
        'verification_mode':'RESEAL_EXISTING_COMPLETED_SIMULATION_EXACT_INPUTS_NO_REEXECUTION',
        'receipt_repair_reason':'Original wrapper configured PASS D3_RAW_EDGE_NATIVE but actual unchanged fixture prints PASS D3_RAW_EDGE_TOP_DDR. Simulator completed with zero errors and original full assertions intact.',
        'compile_and_console_sha256':logs,'simulation_or_fixture_modified':False,'board_acceptance':False}
(run/'verification.json').write_text(json.dumps(result,indent=2)+'\n')
print('PASS actual completed native run sealed:24 rasters/22940160 exact pixels/OF0UF0; fixture/logs unchanged')
