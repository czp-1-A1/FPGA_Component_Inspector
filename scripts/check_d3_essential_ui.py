"""Bind the intentional UI cut, retained core and actual targeted simulations."""
from pathlib import Path
import argparse
import hashlib
import json
import re
from probe_d3_essential_ui import rewrite

p=argparse.ArgumentParser()
p.add_argument('--reference',type=Path,required=True)
p.add_argument('--work',type=Path,required=True)
p.add_argument('--targeted',type=Path,required=True)
p.add_argument('--cdc',type=Path,required=True)
p.add_argument('--legacy',type=Path,required=True)
p.add_argument('--font',type=Path,required=True)
p.add_argument('--fields',type=Path,required=True)
a=p.parse_args();root=Path(__file__).resolve().parents[1]
sha=lambda q:hashlib.sha256(q.read_bytes()).hexdigest()
load=lambda q:json.loads(q.read_text(encoding='utf-8-sig'))
before=load(a.reference/'frozen_inputs.json');after=load(a.work/'frozen_inputs.json')
names=['design_top_wrapper.v','classified_dual_page_osd.v','compact_template_rom.v','compact_inspector_osd.v']
expected={'user_source/hdl_source/'+name for name in names}
assert len(before)==len(after)==704 and set(before)==set(after)
assert {n for n in before if before[n]!=after[n]}==expected
for n,d in after.items():assert sha(a.work/'project'/n)==d,n
for name in names:
    rel='user_source/hdl_source/'+name
    assert rewrite(name,(a.reference/'project'/rel).read_text())==(a.work/'project'/rel).read_text(),name
hardware=load(a.work/'hardware_inputs.json');assert len(hardware)==107
for n,d in hardware.items():assert sha(a.work/'project'/n)==d,n
assert all(after[n]==before[n] for n in before if n.endswith(('.adc','.sdc')))
assert after['user_source/hdl_source/classified_pocket_counter.v']=='67dfbdd7f139eb275decc48d6fd19e64965679ad352b3a291a0675a09401394c'
top=(a.work/'project/user_source/hdl_source/design_top_wrapper.v').read_text()
old_top=(a.reference/'project/user_source/hdl_source/design_top_wrapper.v').read_text()
for begin,end in [('reg motor_output;','assign O_relay_control=motor_output;'),
                  ('generate if(CLASSIFIED_COUNT)begin : count_record_views','wire [2:0] relay_mode=')]:
    assert top.split(begin,1)[1].split(end,1)[0]==old_top.split(begin,1)[1].split(end,1)[0]
fixture=(root/'tests/dual_stop_d3/extracted_r56_ui_cones.sv').read_text()
for begin,end in [('// R56 relay display cone begin','wire camera_metadata_ready;'),
                  ('    // R56 monitor display cone begin','    wire [81:0] cam_display;'),
                  ('    wire [83:0] overflow_display;','    wire transport_ok=')]:
    assert begin+top.split(begin,1)[1].split(end,1)[0] in fixture
assert 'status_cdc #(.WIDTH(RELAY_UI_BITS)) u_relay_display(' in top
assert 'status_cdc #(.WIDTH(MONITOR_UI_BITS)) u_monitor_display(' in top
osd=a.work/'project/user_source/hdl_source/compact_inspector_osd.v'
assert osd.read_text().split('module compact_shared_font_rom(',1)[1]==(a.reference/'project/user_source/hdl_source/compact_inspector_osd.v').read_text().split('module compact_shared_font_rom(',1)[1]
groups=[(a.targeted,{'tb_d3_essential_ui','tb_d3_essential_overlap'}),
        (a.cdc,{'tb_d3_essential_cdc'}),
        (a.legacy,{'tb_d3_osd','tb_d3_osd_equivalence','tb_d3_osd_overlap'}),
        (a.font,{'tb_d3_shared_font'}),
        (a.fields,{'tb_d3_essential_fields'})]
tests=[];proofs={}
for folder,required in groups:
    receipt=load(folder/'verification.json');assert receipt['status']=='PASS'
    assert {t['name'] for t in receipt['tests']}==required
    for rel,d in receipt['inputs'].items():assert after[rel]==d==sha(folder/'inputs'/Path(rel).name),(folder,rel)
    for rel,d in receipt['extra_inputs'].items():assert sha(root/'tests/dual_stop_d3'/Path(rel).name)==d==sha(folder/'inputs'/Path(rel).name),(folder,rel)
    for t in receipt['tests']:
        log=folder/(t['name']+'.log');body=log.read_text(encoding='utf-8-sig')
        assert sha(log)==t['sha256'] and 'PASS ' in body and not re.search(r'\*\* (?:Fatal|Error):|Errors:\s*[1-9]',body)
        tests.append({'name':t['name'],'directory':str(folder.resolve()),'log_sha256':t['sha256']})
    proofs[str(folder.resolve())]=sha(folder/'verification.json')
result={'status':'PASS_ESSENTIAL_UI_SOURCE_AND_TARGETED_SIMULATIONS_NOT_PHYSICAL_ACCEPTANCE',
        'reference':str(a.reference.resolve()),'reference_manifest_sha256':sha(a.reference/'frozen_inputs.json'),
        'source_manifest_sha256':sha(a.work/'frozen_inputs.json'),'changed_inputs':sorted(expected),
        'unchanged_inputs':700,'rewrite_helper_sha256':sha(root/'scripts/probe_d3_essential_ui.py'),
        'tests':tests,'proof_receipts':proofs,'selected_checks':len(tests),
        'fonts_unchanged':True,'original_R27B_counter_unchanged':True,
        'actual_top_display_cones_extracted':True,'core_motor_and_metadata_views_unchanged':True,
        'retained_cdc_fields_cycle_exact':True,'pixel_pipeline_clocks':3,
        'authorized_change':'Essential dual counts/IDs/state/keys/boxes and RAW/EDGE. Debug pages/diagnostic text and display-only mailboxes removed; frame-cache eligibility/N-R. Legacy parameter0 remains pixel-equivalent.',
        'scope':'Eight current-source targeted checks; not a full native, route, timing or board verdict.',
        'production_modified':False,'hardware_operated':False,'deliverable_bit':False}
(a.work/'ESSENTIAL_UI_PROOF.json').write_text(json.dumps(result,indent=2)+'\n')
print('PASS essential UI canonical source/700 unchanged inputs/8 actual-source UI and CDC checks')
