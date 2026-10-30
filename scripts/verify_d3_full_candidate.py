"""Verify the frozen full-feature R36/R37 candidate; never accepts physical timing.

Only exact compiled-input/fixture matches are reused. Production matching is
optional for analysis, mandatory when this function is called for delivery.
"""
from pathlib import Path
import argparse,hashlib,json,re

ROOT=Path(__file__).resolve().parents[1]
TMP=Path('E:/2026FPGA/.codex_tmp')
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
read=lambda p:json.loads(p.read_text(encoding='utf-8-sig'))

def verify(work,require_production=False,suite_map=None):
    source=read(work/'frozen_inputs.json');project=work/'project'
    assert len(source)==704
    for rel,d in source.items():
        assert sha(project/rel)==d,rel
        if require_production:assert sha(ROOT/'fpga/component_inspector'/rel)==d,rel
    hardware=read(work/'hardware_inputs.json');assert len(hardware)==107
    for rel,d in hardware.items():assert sha(project/rel)==d,rel
    reference=read(TMP/'d3_dual_stop_build_r11_resource_opt_20261030/frozen_inputs.json')
    assert set(reference)==set(source)
    assert {n for n,d in source.items() if reference[n]!=d}=={
        'user_source/hdl_source/'+n+'.v' for n in [
        'frame_shape_search','compact_inspector_osd','rgb_resize_2_3',
        'roi_sobel_view','observed_classified_pocket_counter']}
    assert source['user_source/hdl_source/classified_pocket_counter.v']=='67dfbdd7f139eb275decc48d6fd19e64965679ad352b3a291a0675a09401394c'
    top=(project/'user_source/hdl_source/design_top_wrapper.v').read_text()
    fixture=ROOT/'tests/dual_stop_d3'
    motor='reg motor_output;'+top.split('reg motor_output;',1)[1].split('assign O_relay_control=motor_output;',1)[0]+'assign O_relay_control=motor_output;'
    assert motor in (fixture/'extracted_d3_motor.sv').read_text()
    begin='generate if(CLASSIFIED_COUNT)begin : count_record_views'
    mapping=begin+top.split(begin,1)[1].split('end endgenerate',1)[0]+'end endgenerate'
    assert mapping in (fixture/'extracted_d3_metadata.sv').read_text()
    assert mapping in (fixture/'tb_d3_native.sv').read_text()
    selected=[];evidence={}
    def passed(log,d):
        assert sha(log)==d,log
        t=log.read_text(encoding='utf-8-sig')
        assert 'PASS ' in t and not re.search(r'\*\* (?:Fatal|Error):|Errors:\s*[1-9]',t),log
    groups=[Path('D:/CodexWork/D3_Record_RAM_Cases_R34_20261030'),
        TMP/'d3_lossless_units_r8_20261030',TMP/'d3_byte_font_equivalence_r35_20261030']
    if suite_map is not None:
        groups=[Path(p) for p in suite_map['unit_groups']]
    for folder in groups:
        p=read(folder/'verification.json');assert p['status']=='PASS'
        for rel,d in p['inputs'].items():assert source[rel]==sha(folder/'inputs'/Path(rel).name)==d,(folder,rel)
        for rel,d in p['extra_inputs'].items():assert sha(fixture/Path(rel).name)==sha(folder/'inputs'/Path(rel).name)==d,(folder,rel)
        vendor=p.get('vendor_inputs',{})
        font=folder/'inputs/compact_inspector_osd.v'
        if font.is_file() and 'PH1P_PHY_ERAM_V2 #(' in font.read_text():
            assert set(vendor)=={'common/al_phy_glbl.v','ph1p/ph1p_phy_gsr.v','ph1p/ph1p_phy_eram_v2.v'}
        for rel,d in vendor.items():assert sha(folder/'inputs/vendor'/rel)==d,(folder,rel)
        for test in p['tests']:
            passed(folder/(test['name']+'.log'),test['sha256'])
            selected.append({'name':test['name'],'folder':str(folder),'log_sha256':test['sha256'],'mode':'EXACT_COMPILED_SOURCE_AND_FIXTURE_MATCH'})
        evidence[str(folder/'verification.json')]=sha(folder/'verification.json')
    native_groups=[TMP/'d3_lossless_native_r8_20261030',TMP/'d3_lossless_empty_native_r8_20261030']
    if suite_map is not None:native_groups=[Path(p) for p in suite_map['native_groups']]
    for folder in native_groups:
        p=read(folder/'verification.json');assert p['status']=='PASS'
        for rel,d in p['inputs'].items():assert source[rel]==sha(folder/'inputs/project'/rel)==d,(folder,rel)
        for rel,d in p['extra_inputs'].items():assert sha(fixture/Path(rel).name)==sha(folder/'inputs/project'/rel)==d,(folder,rel)
        for rel,d in p['vendor'].items():assert sha(folder/'inputs/vendor'/rel)==d,(folder,rel)
        passed(folder/'console.log',p['console_sha256'])
        selected.append({'name':p['name'],'folder':str(folder),'log_sha256':p['console_sha256'],'mode':'EXACT_COMPILED_SOURCE_AND_FIXTURE_MATCH',
            'scope':'Real RAW/DDR/display or empty RAW proof order. Parking motor permit is off; not a RAW parking cycle or optical recall test.'})
        evidence[str(folder/'verification.json')]=sha(folder/'verification.json')
    export=read(work/'CAMERA_EXPORT.json');camera=Path(export['check_directory']);gate=read(camera/'verification.json')
    assert export['gate_database_sha256']==sha(work/'runs/syn_1/camera_to_dsi_display_gate.db')
    assert export['netlist_sha256']==sha(work/'d3_camera_gate.v')==gate['gate_netlist_sha256']
    assert gate['status']=='PASS' and gate['cone_closure']['all_other_consumed_nets_have_selected_cell_drivers']
    for name,d in gate['simulation_input_sha256'].items():assert sha(camera/'inputs'/name)==d,name
    for test in gate['tests']:
        passed(camera/(test['name']+'.log'),test['log_sha256'])
        selected.append({'name':test['name'],'folder':str(camera),'log_sha256':test['log_sha256'],'mode':'ACTUAL_CANDIDATE_SYNTHESIS_CAMERA_CONE',
            'scope':str(gate['cone_closure']['cells'])+' synthesized cells; two resets x126 serialized I2C writes. No sensor readback.'})
    evidence[str(camera/'verification.json')]=sha(camera/'verification.json')
    observer=read(work/'OBSERVER_PROOF.json');bounds=read(ROOT/'docs/D3_DISTANCE_BOUNDS.json')
    assert observer['original_raw_sha256']==source['user_source/hdl_source/classified_pocket_counter.v']
    assert observer['observed_raw_sha256']==source['user_source/hdl_source/observed_classified_pocket_counter.v']
    assert observer['restored_normalized_body_sha256']==observer['original_normalized_body_sha256']
    assert observer['placement_attributes']==['reg [5:0] ledger[0:MAX_TOTAL-1];','reg [8:0] empty_ids[0:MAX_TOTAL-1];']
    if suite_map is not None:
        assert observer['id_ram_same_clock_read_reencoding'] is True
        assert observer['flag_write_index_sharing']==suite_map['flag_write_index_sharing']
        extraction=read(ROOT/'docs/D3_ID_RAM_PORT_EXTRACTION.json')
        assert extraction['inputs']['classified_pocket_counter.v']==source['user_source/hdl_source/classified_pocket_counter.v']
        assert extraction['inputs']['observed_classified_pocket_counter.v']==source['user_source/hdl_source/observed_classified_pocket_counter.v']
        assert extraction['fixture_sha256']==sha(fixture/'extracted_d3_id_ram.sv')
        evidence[str(ROOT/'docs/D3_ID_RAM_PORT_EXTRACTION.json')]=sha(ROOT/'docs/D3_ID_RAM_PORT_EXTRACTION.json')
        storage=read(work/'ID_RAM_SYNTHESIS_PROOF.json')
        assert storage['status']=='PASS_ACTUAL_SYNTHESIS_TWO_INDEPENDENT_ID_ERAMS'
        assert storage['gate_database_sha256']==export['gate_database_sha256'] and storage['netlist_sha256']==export['netlist_sha256']
        assert len(storage['cells'])==2 and {v['lane'] for v in storage['cells']}=={0,1}
        assert all(v['write_count_address_bits']==v['independent_read_address_bits']==9 for v in storage['cells'])
        evidence[str(work/'ID_RAM_SYNTHESIS_PROOF.json')]=sha(work/'ID_RAM_SYNTHESIS_PROOF.json')
    assert bounds['source_sha256']==source['user_source/hdl_source/frame_shape_search.v']
    font=read(work/'FONT_SYNTHESIS_PROOF.json')
    assert font['status']=='PASS_ACTUAL_SYNTHESIS_FONT_INITIALIZATION' and font['init_blocks_exact']==64
    assert font['gate_database_sha256']==export['gate_database_sha256'] and font['netlist_sha256']==export['netlist_sha256']
    assert font['source_sha256']==source['user_source/hdl_source/compact_inspector_osd.v']
    for path in [work/'CAMERA_EXPORT.json',work/'FONT_SYNTHESIS_PROOF.json',work/'OBSERVER_PROOF.json',ROOT/'docs/D3_DISTANCE_BOUNDS.json']:
        evidence[str(path)]=sha(path)
    required={'tb_d3_case'+str(i) for i in range(12)} | {
        'tb_d3_alarm_control','tb_d3_keys','tb_d3_real_second','tb_d3_metadata','tb_d3_tracker_guards',
        'tb_d3_pixels','tb_d3_rank_pixels','tb_d3_cache_address','tb_d3_distance_selection','tb_d3_osd',
        'tb_d3_resize_equivalence','tb_d3_rgb_ring','tb_d3_rgb_wide','tb_d3_math_bounds',
        'tb_d3_shared_font','tb_d3_osd_equivalence','tb_d3_osd_overlap','tb_d3_native','tb_d3_empty_native'}
    required|={t['name'] for t in gate['tests']}
    if suite_map is not None:required.add('tb_d3_id_ram')
    expected_count=33 if suite_map is not None else 32
    assert len(selected)==len(required)==expected_count and {t['name'] for t in selected}==required
    result={'status':'PASS_D3_EXACT_INPUT_SOFTWARE_CHECKS_ONLY','profile':'lossless-v5' if suite_map is not None else 'lossless-v4','selected':selected,
        'selected_checks':expected_count,'expected_checks':expected_count,'inputs_manifest_sha256':sha(work/'frozen_inputs.json'),
        'evidence':evidence,'production_source_match_required':require_production,
        'hardware_acceptance':False,'resource_or_timing_acceptance':False}
    (work/'SOFTWARE_VERIFICATION.json').write_text(json.dumps(result,indent=2)+'\n')
    return result

if __name__=='__main__':
    a=argparse.ArgumentParser();a.add_argument('--work',type=Path,required=True);a.add_argument('--require-production',action='store_true');a.add_argument('--suite-map',type=Path);x=a.parse_args()
    r=verify(x.work.resolve(),x.require_production,read(x.suite_map) if x.suite_map else None);print(r['status'],r['selected_checks'],'PRODUCTION_MATCH',x.require_production)
