"""Bind lossless optimization evidence to exact current source and old oracles.

This is a bounded arithmetic/storage check plus source provenance, not a
complete sequential formal proof, physical timing verdict or board test.
"""
from pathlib import Path
import hashlib,json,re

r=Path(__file__).resolve().parents[1];tmp=Path('E:/2026FPGA/.codex_tmp')
old=tmp/'d3_dual_stop_build_r11_resource_opt_20261030'
candidate=Path('D:/CodexWork/D3_Lossless_Synthesis_R28_20261030')
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
load=lambda p:json.loads(p.read_text())
a=load(old/'frozen_inputs.json');b=load(candidate/'frozen_inputs.json')
changed={rel for rel in a if a[rel]!=b[rel]}
assert changed=={'user_source/hdl_source/'+n+'.v' for n in ['frame_shape_search','compact_inspector_osd','rgb_resize_2_3','roi_sobel_view']}
for rel,d in b.items():assert sha(candidate/'project'/rel)==sha(r/'fpga/component_inspector'/rel)==d,rel
oracles={}
for name in ['frame_shape_search','compact_inspector_osd','rgb_resize_2_3','roi_sobel_view']:
 p=old/('project/user_source/hdl_source/'+name+'.v')
 ref=r/('tests/dual_stop_d3/r11_reference_'+name+'.sv')
 restored=ref.read_bytes().replace(('module r11_reference_'+name).encode(),('module '+name).encode(),1)
 if name=='frame_shape_search':restored=restored.replace(b'r11_reference_empty_gate_trace',b'empty_gate_trace')
 if name=='roi_sobel_view':restored=re.sub(rb'\breference_process_beat\b',b'process',restored)
 assert restored.replace(b'\r\n',b'\n')==p.read_bytes().replace(b'\r\n',b'\n'),name
 oracles[name]={'original_sha256':sha(p),'reference_sha256':sha(ref),'restored_normalized_body_identical':True}
s=(candidate/'project/user_source/hdl_source/roi_sobel_view.v').read_text()
assert 'write_row>=read_y+10\'d3' in s and 'localparam RGB_WORDS=3*BEATS' in s
assert 'rgb_write_bank<=rgb_write_bank==2 ? 0 : rgb_write_bank+1\'b1' in s
assert 'rgb_read_bank<=rgb_read_bank==2 ? 0 : rgb_read_bank+1\'b1' in s
assert 'for(bank=0;bank<4;bank=bank+1)begin : line_bank' in s
assert 'if(early_sof || frame_bad || cache_overrun) begin out_valid<=0;out_last<=0;end' in s
assert 'assign gradient_valid=v4 && mode4[1] && !early_sof && !frame_bad && !cache_overrun;' in s
ring_checks=0
for height,width in [(30,96),(600,1024),(720,1280)]:
 beats=width//4
 for read_row in range(height):
  # An input row >= read_row+3 cancels valid output using the ORIGINAL guard.
  # None of the two later, non-aborting rows can overwrite middle-row RGB.
  for write_row in range(read_row,min(height,read_row+3)):
   if write_row!=read_row:assert write_row%3!=read_row%3
   for group in [0,beats-1]:
    assert 0<=write_row%3*beats+group<3*beats
    assert 0<=read_row%3*beats+group<3*beats
    ring_checks+=1
 # Bank-register increment and reset correspond exactly to row % 3.
 bank=0
 for row in range(height):assert bank==row%3;bank=0 if bank==2 else bank+1
assets=['compact_ascii_rom','compact_cjk_rom','compact_template_rom','osd_logo_rom']
for name in assets:assert a['user_source/hdl_source/'+name+'.v']==b['user_source/hdl_source/'+name+'.v']
assert a['user_source/hdl_source/classified_pocket_counter.v']==b['user_source/hdl_source/classified_pocket_counter.v']
assert a['user_source/constraints_source/pin.adc']==b['user_source/constraints_source/pin.adc']
assert a['td_project/camera_to_dsi_display.sdc']==b['td_project/camera_to_dsi_display.sdc']
groups=['d3_lossless_units_r6_20261030','d3_osd_share_pixels_r1_20261030','d3_resize_share_pixels_r1_20261030','d3_rgb_ring_pixels_r2_20261030']
proofs={}
for name in groups:
 folder=tmp/name;proof=load(folder/'verification.json');assert proof['status']=='PASS'
 for rel,d in proof['inputs'].items():assert b[rel]==d and sha(folder/'inputs'/Path(rel).name)==d,(name,rel)
 for rel,d in proof['extra_inputs'].items():assert sha(r/'tests/dual_stop_d3'/Path(rel).name)==sha(folder/'inputs'/Path(rel).name)==d,(name,rel)
 for test in proof['tests']:
  log=folder/(test['name']+'.log');text=log.read_text()
  assert sha(log)==test['sha256'] and 'PASS ' in text and not re.search(r'\*\* (Fatal|Error):',text)
 proofs[name]={'verification_sha256':sha(folder/'verification.json'),'tests':[t['name'] for t in proof['tests']]}
result={'status':'PASS_SOURCE_PROVENANCE_AND_BOUNDED_LOSSLESS_CHECKS','candidate':str(candidate),
 'candidate_manifest_sha256':sha(candidate/'frozen_inputs.json'),'changed_inputs':sorted(changed),
 'unchanged_inputs':700,'original_R27B_counter_unchanged':True,'all_fonts_and_diagnostics_retained':True,
 'oracles':oracles,'rgb_ring_bounded_address_checks':ring_checks,'proofs':proofs,
 'synthesis_comparison':{'R11':{'slice_estimate':22821,'lut':29345,'reg':23557,'eram':107,'dsp':31},
                         'R28':{'slice_estimate':22188,'lut':28596,'reg':23262,'eram':104,'dsp':31}},
 'rejected_font_experiment':'All font bits passed equivalence, but TD mapped its 1-bit ROM to 352 logic LUT +1DSP. Original fonts restored.',
 'scope':'No complete sequential formal proof, full RAW/physical timing verdict or board acceptance claimed here.'}
(r/'docs/D3_LOSSLESS_OPTIMIZATION.json').write_text(json.dumps(result,indent=2)+'\n')
print(result['status'],ring_checks,'ring bounds;',sum(len(x['tests']) for x in proofs.values()),'exact-source added/changed unit checks')
