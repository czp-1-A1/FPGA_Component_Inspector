"""Select D3 verification only when every compiled input matches the candidate.

This receipt covers simulation and structural checks. It does not accept
resource utilization, timing, physical wiring or optical performance.
"""
from pathlib import Path
import argparse,hashlib,json,re

ROOT=Path(__file__).resolve().parents[1]
TMP=Path('E:/2026FPGA/.codex_tmp')
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def read(p):return json.loads(p.read_text(encoding='utf8'))
def passed(p):
    t=p.read_text(encoding='utf-8-sig')
    assert 'PASS ' in t and not re.search(r'\*\* (?:Fatal|Error):|Errors:\s*[1-9]',t),p

def verify(work):
    source=read(work/'frozen_inputs.json');project=work/'project';fixture=ROOT/'tests/dual_stop_d3'
    assert len(source)==704
    for rel,d in source.items():assert sha(project/rel)==sha(ROOT/'fpga/component_inspector'/rel)==d,rel
    # Test the exact real top-level transforms, not merely an ISP-only path.
    top=(project/'user_source/hdl_source/design_top_wrapper.v').read_text()
    motor='reg motor_output;'+top.split('reg motor_output;',1)[1].split('assign O_relay_control=motor_output;',1)[0]+'assign O_relay_control=motor_output;'
    assert motor in (fixture/'extracted_d3_motor.sv').read_text()
    begin='generate if(CLASSIFIED_COUNT)begin : count_record_views'
    mapping=begin+top.split(begin,1)[1].split('end endgenerate',1)[0]+'end endgenerate'
    assert mapping in (fixture/'extracted_d3_metadata.sv').read_text()
    assert mapping in (fixture/'tb_d3_native.sv').read_text()
    selected=[];evidence={}
    groups=[
        'd3_direct_final_cases_r3_20261030',
        'd3_keys_real_second_r2_20261030',
        'd3_metadata_final_r2_20261030',
        'd3_tracker_guards_r1_20261030',
        'd3_resource_opt_pixels_r7_20261030',
        'd3_resource_cache_address_r1_20261030',
        'd3_distance_selection_r1_20261030',
        'd3_final_ui_r4_20261030',
    ]
    for name in groups:
        folder=TMP/name;proof=read(folder/'verification.json');assert proof['status']=='PASS'
        for rel,d in proof['inputs'].items():assert source[rel]==d and sha(folder/'inputs'/Path(rel).name)==d,(name,rel)
        for rel,d in proof['extra_inputs'].items():assert sha(fixture/Path(rel).name)==sha(folder/'inputs'/Path(rel).name)==d,(name,rel)
        for test in proof['tests']:
            log=folder/(test['name']+'.log');assert sha(log)==test['sha256'];passed(log)
            selected.append({'name':test['name'],'folder':str(folder),'mode':'EXACT_COMPILED_SOURCE_AND_FIXTURE_MATCH','log_sha256':sha(log)})
        evidence[str(folder/'verification.json')]=sha(folder/'verification.json')
    for name in ['d3_resource_native_r3_20261030','d3_resource_empty_native_r3_20261030']:
        folder=TMP/name;proof=read(folder/'verification.json');assert proof['status']=='PASS'
        for rel,d in proof['inputs'].items():assert source[rel]==d and sha(folder/'inputs/project'/rel)==d,(name,rel)
        for rel,d in proof['extra_inputs'].items():assert sha(fixture/Path(rel).name)==sha(folder/'inputs/project'/rel)==d,(name,rel)
        for rel,d in proof['vendor'].items():assert sha(folder/'inputs/vendor'/rel)==d
        assert sha(folder/'console.log')==proof['console_sha256'];passed(folder/'console.log')
        selected.append({'name':proof['name'],'folder':str(folder),'mode':'EXACT_COMPILED_SOURCE_AND_FIXTURE_MATCH','log_sha256':sha(folder/'console.log'),
           'scope':'Real RAW/DDR/display or empty RAW proof order. Parking instantiated with motor permit off; not a RAW parking cycle or optical recall test.'})
        evidence[str(folder/'verification.json')]=sha(folder/'verification.json')
    reference=TMP/'d3_dual_stop_build_r11_resource_opt_20261030'
    assert read(reference/'frozen_inputs.json')==source
    export=work/'CAMERA_EXPORT.json'
    if export.is_file():
        e=read(export);gate=Path(e['check_directory'])
        assert e['gate_database_sha256']==sha(work/'runs/syn_1/camera_to_dsi_display_gate.db')
        assert e['netlist_sha256']==sha(work/'d3_camera_gate.v')
        netlist=work/'d3_camera_gate.v'
    else:
        gate=TMP/'d3_resource_camera_r1_20261030';netlist=reference/'d3_camera_gate.v'
    if work!=reference and not export.is_file():
        reuse=read(work/'EXACT_SYNTHESIS_REUSE.json')
        assert Path(reuse['source_work']).resolve()==reference.resolve()
        assert reuse['source_files_identical']==704
        assert sha(work/'runs/syn_1/camera_to_dsi_display_gate.db')==sha(reference/'runs/syn_1/camera_to_dsi_display_gate.db')==reuse['synthesis_database_sha256']
    g=read(gate/'verification.json');assert g['status']=='PASS'
    assert sha(netlist)==g['gate_netlist_sha256']
    assert g['cone_closure']['all_other_consumed_nets_have_selected_cell_drivers']
    for name,d in g['simulation_input_sha256'].items():assert sha(gate/'inputs'/name)==d
    for t in g['tests']:
        log=gate/(t['name']+'.log');assert sha(log)==t['log_sha256'];passed(log)
        selected.append({'name':t['name'],'folder':str(gate),'mode':'ACTUAL_CANDIDATE_SYNTHESIS_CAMERA_CONE','log_sha256':sha(log),'scope':str(g['cone_closure']['cells'])+' actual synthesized cells; two resets x126 serialized I2C writes; simulated ACK slave, no sensor readback.'})
    evidence[str(gate/'verification.json')]=sha(gate/'verification.json')
    observer=read(ROOT/'docs/D3_OBSERVED_COUNTER_PROOF.json')
    assert observer['original_raw_sha256']==source['user_source/hdl_source/classified_pocket_counter.v']
    assert observer['observed_raw_sha256']==source['user_source/hdl_source/observed_classified_pocket_counter.v']
    assert observer['restored_normalized_body_sha256']==observer['original_normalized_body_sha256']
    bounds=read(ROOT/'docs/D3_DISTANCE_BOUNDS.json')
    assert bounds['source_sha256']==source['user_source/hdl_source/frame_shape_search.v']
    for path in ['docs/D3_OBSERVED_COUNTER_PROOF.json','docs/D3_DISTANCE_BOUNDS.json']:
        evidence[str(ROOT/path)]=sha(ROOT/path)
    result={'status':'PASS_D3_EXACT_INPUT_SOFTWARE_CHECKS_ONLY','selected':selected,'selected_checks':len(selected),
        'inputs_manifest_sha256':sha(work/'frozen_inputs.json'),'evidence':evidence,
        'original_R27B_counter_sha256':observer['original_raw_sha256'],
        'hardware_acceptance':False,'resource_or_timing_acceptance':False}
    (work/'SOFTWARE_VERIFICATION.json').write_text(json.dumps(result,indent=2)+'\n')
    return result

if __name__=='__main__':
    a=argparse.ArgumentParser();a.add_argument('--work',type=Path,required=True);x=a.parse_args()
    r=verify(x.work.resolve());print(r['status'],r['selected_checks'])
