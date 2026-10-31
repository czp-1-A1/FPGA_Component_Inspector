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
    raw_edge = (work/'RAW_EDGE_DISPLAY_PROOF.json').is_file()
    assert {n for n,d in source.items() if reference[n]!=d}=={
        'user_source/hdl_source/'+n+'.v' for n in [
        'frame_shape_search','compact_inspector_osd','rgb_resize_2_3',
        'roi_sobel_view','observed_classified_pocket_counter']} | ({
        'user_source/hdl_source/design_top_wrapper.v',
        'user_source/hdl_source/observation_controls.v',
        'user_source/hdl_source/isp/isp_top.v'} if raw_edge else set())
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
    check_prepare=observer.get('check_prepare_retiming',False)
    if check_prepare:
        assert observer['check_prepare_variant'] in ['offset','minimal']
    if check_prepare and observer['check_prepare_variant']=='offset':
        math=read(work/'CHECK_PREPARE_MATH_PROOF.json')
        assert math['status']=='PASS_EXHAUSTIVE_CHECK_DISTANCE_MODULO_14'
        assert math['source_sha256']==source['user_source/hdl_source/observed_classified_pocket_counter.v']
        assert math['script_sha256']==sha(ROOT/'scripts/check_d3_check_prepare_math.py')
        assert math['line_x']==[640] and math['comparisons']==268435456
        evidence[str(work/'CHECK_PREPARE_MATH_PROOF.json')]=sha(work/'CHECK_PREPARE_MATH_PROOF.json')
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
    slot_valid = (work/'SLOT_VALID_STORAGE_PROOF.json').is_file()
    assert not (raw_edge and slot_valid), 'Do not combine unreviewed display/storage trials'
    if raw_edge:
        from d3_raw_edge_rewrite import FILES, rewrite
        display=read(work/'RAW_EDGE_DISPLAY_PROOF.json')
        baseline=Path(display['baseline']);old_source=read(baseline/'frozen_inputs.json')
        expected={'user_source/hdl_source/'+name for name in FILES}
        assert display['status']=='PASS_RAW_EDGE_DISPLAY_SOURCE_AND_TARGETED_CHECKS'
        assert display['baseline_manifest_sha256']==sha(baseline/'frozen_inputs.json')
        assert display['source_manifest_sha256']==sha(work/'frozen_inputs.json') and display['unchanged_inputs']==700
        assert set(old_source)==set(source) and {n for n in source if source[n]!=old_source[n]}==expected
        assert display['rewrite_helper_sha256']==sha(ROOT/'scripts/d3_raw_edge_rewrite.py')
        for name in FILES:
            rel='user_source/hdl_source/'+name;original=baseline/'project'/rel
            assert sha(original)==old_source[rel]
            assert rewrite(name,(project/rel).read_text(),inverse=True)==original.read_text()
            assert hashlib.sha256(original.read_text().encode()).hexdigest()==display['restored_normalized_sha256'][rel]
        assert 'ENABLE_AUTO_RELAY=1,RAW_EDGE_ONLY=1,' in top
        assert 'observation_controls #(.RAW_EDGE_ONLY(RAW_EDGE_ONLY))' in top
        assert 'isp_top #(.RAW_EDGE_ONLY(RAW_EDGE_ONLY),' in top
        assert display['oracle_sha256']==sha(fixture/'r50_reference_roi_sobel_view.sv')
        assert display['native_fixture_sha256']==sha(fixture/'tb_d3_raw_edge_native.sv')
        assert display['empty_native_fixture_sha256']==sha(fixture/'tb_d3_raw_edge_empty_native.sv')
        mapping_proof=read(work/'RAW_EDGE_SYNTHESIS_PROOF.json')
        assert mapping_proof['status']=='PASS_ACTUAL_SYNTHESIS_RAW_EDGE_FOUR_GRAY_NO_RGB_CACHE'
        assert mapping_proof['gate_database_sha256']==export['gate_database_sha256'] and mapping_proof['netlist_sha256']==export['netlist_sha256']
        assert mapping_proof['sobel_eram_cells']==4 and mapping_proof['rgb_background_cells']==0
        evidence[str(work/'RAW_EDGE_DISPLAY_PROOF.json')]=sha(work/'RAW_EDGE_DISPLAY_PROOF.json')
        evidence[str(work/'RAW_EDGE_SYNTHESIS_PROOF.json')]=sha(work/'RAW_EDGE_SYNTHESIS_PROOF.json')
    if slot_valid:
        from d3_slot_valid_storage_rewrite import restore
        slot = read(work/'SLOT_VALID_STORAGE_PROOF.json')
        assert slot['status']=='PASS_SLOT_VALID_PRIVATE_BUFFER_SOURCE_AND_TARGETED_EQUIVALENCE'
        assert slot['before_sha256']==bounds['source_sha256']=='e031d235d78b1bfbd271f33718d064d15c0eeb80f55b3cd6f938dacd358813a4'
        target='user_source/hdl_source/frame_shape_search.v'
        assert slot['after_sha256']==source[target] and slot['source_manifest_sha256']==sha(work/'frozen_inputs.json')
        assert slot['unchanged_inputs']==703 and slot['FSM_cycles_added']==0
        assert slot['rewrite_helper_sha256']==sha(ROOT/'scripts/d3_slot_valid_storage_rewrite.py')
        baseline=Path(slot['baseline']);baseline_source=read(baseline/'frozen_inputs.json')
        assert set(baseline_source)==set(source) and {n for n in source if source[n]!=baseline_source[n]}=={target}
        original=baseline/'project'/target
        assert sha(original)==bounds['source_sha256'] and restore((project/target).read_text())==original.read_text()
        assert hashlib.sha256(original.read_text().encode()).hexdigest()==slot['original_normalized_sha256']==slot['restored_normalized_sha256']
        assert slot['oracle_sha256']==sha(fixture/'r50_reference_frame_shape_search.sv')
        evidence[str(work/'SLOT_VALID_STORAGE_PROOF.json')]=sha(work/'SLOT_VALID_STORAGE_PROOF.json')
    else:
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
    if check_prepare:required.add('tb_d3_check_prepare')
    if slot_valid:required|={'tb_d3_slot_valid_storage','tb_d3_slot_valid_pixels'}
    if raw_edge:
        required-={'tb_d3_native','tb_d3_empty_native'}
        required|={'tb_d3_raw_edge_native','tb_d3_raw_edge_empty_native','tb_d3_raw_edge_controls','tb_d3_pure_edge','tb_d3_pure_edge_wide'}
    expected_count=(33 if suite_map is not None else 32)+int(check_prepare)+2*int(slot_valid)+3*int(raw_edge)
    assert len(selected)==len(required)==expected_count and {t['name'] for t in selected}==required
    if slot_valid:assert suite_map is not None and check_prepare and observer['check_prepare_variant']=='minimal'
    if raw_edge:assert suite_map is not None and check_prepare and observer['check_prepare_variant']=='minimal'
    result={'status':'PASS_D3_EXACT_INPUT_SOFTWARE_CHECKS_ONLY','profile':'raw-monochrome-edge-v1' if raw_edge else 'lossless-v7-slot-valid' if slot_valid else 'lossless-v6-check-prepare' if check_prepare else 'lossless-v5' if suite_map is not None else 'lossless-v4','selected':selected,
        'selected_checks':expected_count,'expected_checks':expected_count,'inputs_manifest_sha256':sha(work/'frozen_inputs.json'),
        'evidence':evidence,'production_source_match_required':require_production,
        'hardware_acceptance':False,'resource_or_timing_acceptance':False}
    (work/'SOFTWARE_VERIFICATION.json').write_text(json.dumps(result,indent=2)+'\n')
    return result

if __name__=='__main__':
    a=argparse.ArgumentParser();a.add_argument('--work',type=Path,required=True);a.add_argument('--require-production',action='store_true');a.add_argument('--suite-map',type=Path);x=a.parse_args()
    r=verify(x.work.resolve(),x.require_production,read(x.suite_map) if x.suite_map else None);print(r['status'],r['selected_checks'],'PRODUCTION_MATCH',x.require_production)
