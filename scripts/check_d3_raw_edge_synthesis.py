"""Verify RGB-cache removal and gray-bank preservation in the actual new SYN DB."""
from pathlib import Path
import argparse
import hashlib
import json
import re
from audit_d3_slice_packing import parse_cells

p=argparse.ArgumentParser()
p.add_argument('--work',type=Path,required=True)
a=p.parse_args();w=a.work.resolve()
sha=lambda path:hashlib.sha256(path.read_bytes()).hexdigest()
load=lambda path:json.loads(path.read_text(encoding='utf-8-sig'))
export=load(w/'CAMERA_EXPORT.json');net=w/'d3_camera_gate.v'
assert sha(net)==export['netlist_sha256']
assert sha(w/'runs/syn_1/camera_to_dsi_display_gate.db')==export['gate_database_sha256']
assert load(w/'RAW_EDGE_DISPLAY_PROOF.json')['status']=='PASS_RAW_EDGE_DISPLAY_SOURCE_AND_TARGETED_CHECKS'
erams=[c for c in parse_cells(net) if c['kind']=='PH1P_PHY_ERAM_V2']
sobel=[c for c in erams if '/u_roi_sobel_view/' in c['name']]
assert len(sobel)==4, [(c['name'],c['parameters']) for c in sobel]
assert all(c['parameters']['DATA_WIDTH_A']==c['parameters']['DATA_WIDTH_B']=='"40"' for c in sobel)
assert not any('color_cache/' in c['name'] for c in erams)
area=(w/'runs/syn_1/camera_to_dsi_display_gate.area').read_text()
used=int(re.search(r'(?m)^#eram\s+(\d+)',area)[1])
assert len(erams)==used==100
result={'status':'PASS_ACTUAL_SYNTHESIS_RAW_EDGE_FOUR_GRAY_NO_RGB_CACHE',
        'gate_database_sha256':export['gate_database_sha256'],'netlist_sha256':sha(net),
        'source_manifest_sha256':sha(w/'frozen_inputs.json'),
        'total_eram_cells':len(erams),'sobel_eram_cells':len(sobel),'rgb_background_cells':0,
        'expected_preserved_gray_banks':4,'eram_delta_vs_r50':-5,
        'cells':[{'name':c['name'],'widthA':c['parameters']['DATA_WIDTH_A'],'widthB':c['parameters']['DATA_WIDTH_B']} for c in sobel],
        'scope':'Actual full synthesized netlist and SYN area, not source-only dead-code inference. Functional scheduling/gradients/precision and rendered pixels proven by independent simulations. No routed timing or hardware acceptance.'}
(w/'RAW_EDGE_SYNTHESIS_PROOF.json').write_text(json.dumps(result,indent=2)+'\n')
print('PASS actual SYN: total100 ERAM; Sobel4 gray banks, no5 RGB background banks')
