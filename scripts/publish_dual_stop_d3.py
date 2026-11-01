"""Package D3 only after exact-source simulation, routed audit and Git checks."""
from pathlib import Path
import argparse,hashlib,json,subprocess,zipfile
from publish_r22_shift_alarm_v7 import sha,load,write,copy,git_source_audit
from verify_d3_full_candidate import verify

def main():
    ap=argparse.ArgumentParser();ap.add_argument('--work',type=Path,required=True);ap.add_argument('--check-only',action='store_true');args=ap.parse_args()
    repo=Path(__file__).resolve().parents[1];w=args.work.resolve();p=w/'project';tmp=Path('E:/2026FPGA/.codex_tmp')
    software=verify(w,require_production=True,suite_map=load(w/'SUITE_MAP.json'))
    assert software['selected_checks']==software['expected_checks']
    assert (software['selected_checks'],software['profile']) in [(33,'lossless-v5'),(34,'lossless-v6-check-prepare'),(36,'lossless-v7-slot-valid'),(37,'raw-monochrome-edge-v1'),(41,'essential-ui-v1')]
    essential_ui=software['profile']=='essential-ui-v1'
    raw_edge=software['profile'] in ['raw-monochrome-edge-v1','essential-ui-v1']
    source=load(w/'frozen_inputs.json');assert len(source)==704
    assert len(load(w/'hardware_inputs.json'))==107
    git_source_audit(repo,source)
    prior=load(repo/'releases/r22_dual_stop_d2_20261029/SOURCE_SHA256.json')
    protected_source=['user_source/constraints_source/pin.adc','td_project/camera_to_dsi_display.sdc','user_source/hdl_source/pocket_run_controls.v']
    protected_source += [rel for rel in prior if 'SC500GainTbl' in rel]
    for rel in protected_source:assert source[rel]==prior[rel],rel
    physical=load(w/'physical_verification.json');build=load(w/'build_result.json')
    expected_status='PASS_D3_ESSENTIAL_UI_DUAL_COUNT_PARK_ROUTED_40_ACTIVE_9_REMOVED_UI_BOUNDS_20_GRAY_9_MAILBOXES_4_KEYS_V2_TWO_ALARMS' if essential_ui else 'PASS_D3_R27B_DUAL_COUNT_PARK_ROUTED_49_BOUNDS_20_GRAY_9_MAILBOXES_4_KEYS_V2_TWO_ALARMS'
    assert physical['status']==expected_status
    assert physical['max_delays_matched']==(40 if essential_ui else 49) and physical['max_delays_ignored']==0 and physical['gray_bits_dominating']==20
    if essential_ui:
        assert physical['original_49_source_bounds_accounted'] and physical['all_remaining_timing_budgets_unchanged']
        assert physical['compiled_out_display_only_bounds']==9 and physical['active_explicit_bounds']==38 and physical['relay_display_declared_bits']==12
    assert physical['first_lane_counting_and_parking_enabled'] and physical['second_lane_counting_and_parking_enabled']
    assert physical['frame_metadata_bits']==1143 and physical['count_record_bits']==512
    assert physical['alarm_interlock_packed_cell_proof']['actual_alarm_Q_and_registered_motor_LUT']
    assert all(physical['timing_ns'][k]>=0 for k in ['SWNS','HWNS','STNS','HTNS'])
    assert physical['resources']['slice']<=21216 and physical['resources']['eram']==(100 if raw_edge else 105) and physical['resources']['dsp']==31
    bit=w/'runs/phy_1/camera_to_dsi_display.bit';assert sha(bit)==build['bit_sha256']==physical['bit_sha256']
    flash_root=Path('E:/2026FPGA/BIT_FLASH')
    protected={
        'LATEST_READONLY.bit':'30d067cef0667893fe548ba04e423cd6618b76f119cb2e0ecf48b96ba6a5b20f',
        'R22_RelayAuto_Left_V7_ShiftAlarm_20261028.bit':'3b1c6ebc6a67c0e791827eba011e7890bdcc850b41a3eadf02cd9a3fb24a1750',
        'R22_SingleStop_SecondRecognition_D2_20261029.bit':'1b2d3c1b0e279b53e8245fe8acd61db0ce6c69e37ae1ff3d9419fbab938803ae'}
    for name,d in protected.items():assert sha(flash_root/name)==d
    name='R27B_DualCount_DualStop_D3_EssentialUI_R56_20261101' if essential_ui else 'R27B_DualCount_DualStop_D3_RawEdge_R55_20261031' if raw_edge else 'R27B_DualCount_DualStop_D3_Slice_20261031'
    release=repo/('releases/r27b_dual_count_dual_stop_d3_essential_ui_r56_20261101' if essential_ui else 'releases/r27b_dual_count_dual_stop_d3_rawedge_r55_20261031' if raw_edge else 'releases/r27b_dual_count_dual_stop_d3_slice_20261031');archive=release.with_suffix('.zip');flash=flash_root/(name+'.bit')
    assert not release.exists() and not archive.exists() and not flash.exists()
    receipt={'version':name,'source_commit':subprocess.check_output(['git','rev-parse','HEAD'],cwd=repo,text=True).strip(),
        'branch':subprocess.check_output(['git','branch','--show-current'],cwd=repo,text=True).strip(),'pushed':False,
        'source_worktree':str(repo),'build_work':str(w),'seed':build['seed'],'td_version':'V6.2.168116',
        'bit_sha256':sha(bit),'bit_bytes':bit.stat().st_size,'resources':physical['resources'],
        'slice_percent':physical['slice_percent'],'timing_ns':physical['timing_ns'],'source_files':704,'hardware_dependencies':107,
        'selected_checks':software['selected_checks'],'gpio':'Right J2 pin1/V2: HIGH run, LOW stop. Existing board5V relay supply; no LEDs.',
        'keys':'K1 new dual run; K2 pause/resume or idle motor debug; K3 clear/stop; K4 stop; SW3 up-stop/down-new-run.',
        'parameters':{'DUAL_REGION_COUNT':1,'ENABLE_AUTO_RELAY':1,'main_rois':[[400,880,240,400],[400,880,432,600]],
            'station_x':[64,400],'refill_windows_x':[72,232],'target_x':152,'trigger_x':184,'hold_ms':1000,
            'queue_per_lane':32,'fifth_consecutive_empty_per_lane':True,'motor_shared':True},
        'original_R27B_counter_sha256':source['user_source/hdl_source/classified_pocket_counter.v'],
        'board_acceptance':'PENDING_HUMAN_TWO_LANE_RECOGNITION_COUNT_PARKING_TEST','hardware_operated':False,
        'limits':'Existing white3528 recipe; no arbitrary-speed, optical recall, actual nozzle/refill or +/-1mm claim. Real RAW checks use permit=0; separate candidate-stream tests exercise parking.'}
    strategy=load(w/'BUILD_STRATEGY.json') if (w/'BUILD_STRATEGY.json').is_file() else {'strategy':'Default'}
    receipt['display_profile']='RAW / monochrome white-on-black edge; SW2 selects; SW1 ignored. Recognition grayscale/local-edge algorithms retained.' if raw_edge else 'Four original display modes'
    if essential_ui:
        receipt['display_profile']+=' Essential UI: per-lane counts/IDs/state, keys, labels/ROIs; debug pages and upper-right latency omitted.'
        receipt['constraint_accounting']={'original_total':49,'active_explicit':38,'active_vendor':2,'compiled_out_display_only':9,'budgets_relaxed':False}
    receipt['synthesis_strategy']=strategy
    physical_strategy=load(w/'PHYSICAL_STRATEGY.json') if (w/'PHYSICAL_STRATEGY.json').is_file() else {'strategy':'Default'}
    receipt['physical_strategy']=physical_strategy
    if args.check_only:
        print(json.dumps({'status':'READY_TO_PUBLISH','receipt':receipt},indent=2));return
    release.mkdir(parents=True)
    for rel in source:copy(p/rel,release/'project'/rel)
    write(release/'SOURCE_SHA256.json',source)
    for name0 in ['frozen_inputs.json','hardware_inputs.json','baseline_delta.json','build_result.json','physical_verification.json','SOFTWARE_VERIFICATION.json']:
        copy(w/name0,release/'build'/name0)
    for name0 in ['EXACT_SYNTHESIS_REUSE.json','BUILD_STRATEGY.json','PHYSICAL_STRATEGY.json','CAMERA_EXPORT.json','CHECK_PROFILE.json','SUITE_MAP.json','OBSERVER_PROOF.json','FONT_SYNTHESIS_PROOF.json','ID_RAM_SYNTHESIS_PROOF.json','CHECK_PREPARE_MATH_PROOF.json','SLOT_VALID_STORAGE_PROOF.json','RAW_EDGE_DISPLAY_PROOF.json','RAW_EDGE_SYNTHESIS_PROOF.json','PLACEMENT_COMPARISON.json','PLACEMENT_RESULT.json','STAGE_PLACE.json','STAGE_ROUTE.json','SOURCE_INVARIANTS.json','PRODUCTION_ADOPTION.json','ESSENTIAL_UI_PROOF.json','ESSENTIAL_SDC_PROOF.json','ESSENTIAL_SDC_NEGATIVE_TESTS.json']:
        if (w/name0).is_file():copy(w/name0,release/'build'/name0)
    if 'official_file' in strategy:copy(Path(strategy['official_file']),release/'build/official_strategy_ph1.json')
    camera_work=w if (w/'CAMERA_EXPORT.json').is_file() else tmp/'d3_dual_stop_build_r11_resource_opt_20261030'
    copy(camera_work/'d3_camera_gate.v',release/'build/d3_camera_gate.v')
    copy(camera_work/'export_camera.log',release/'build/export_camera.log')
    for stage in ['syn_1','phy_1']:
        for f in (w/'runs'/stage).iterdir():
            if f.is_file() and (f.suffix in ['.log','.cfg','.tcl','.prj','.rpt','.area','.timing'] or f.name=='constraint_coverage.txt'):
                copy(f,release/'build/runs'/stage/f.name)
    for folder in ['classified_audit','gray_packing_audit']:
        for f in (p/folder).iterdir():
            if f.is_file():copy(f,release/'build'/folder/f.name)
    folders={Path(t['folder']) for t in software['selected']}
    for folder in sorted(folders):
        for f in folder.rglob('*'):
            if f.is_file() and ('inputs' in f.relative_to(folder).parts or f.suffix in ['.json','.log']):
                copy(f,release/'tests'/folder.name/f.relative_to(folder))
        proof=load(folder/'verification.json')
        for rel in proof.get('extra_inputs',{}):
            file=repo/'tests/dual_stop_d3'/Path(rel).name
            copy(file,release/'tests/dual_stop_d3'/file.name)
    for f in (repo/'tests/camera_gain_fix').iterdir():
        if f.is_file():copy(f,release/'tests/camera_gain_fix'/f.name)
    docs=['R27B_DUAL_STOP_D3_FIELD_GUIDE.md','R27B_DUAL_STOP_MERGE_ANALYSIS.md','D3_RESOURCE_ANALYSIS.md','D3_RESOURCE_ANALYSIS.json',
        'D3_DISTANCE_BOUNDS.json','D3_OBSERVED_COUNTER_PROOF.json','D3_RANK_REFERENCE.json','D3_RESIZE_REFERENCE.json','D3_LOSSLESS_OPTIMIZATION.json','R27B_D3_IMPORT.json','R27B_ANALYSIS_REPLAY_VERIFICATION.json',
        'D3_SLICE_CODE_REVIEW_20261031.md','D3_SLICE_CODE_REVIEW_20261031_EVIDENCE.json','D3_ID_RAM_PORT_EXTRACTION.json','D3_SLICE_EXECUTION_20261031.md','D3_CHECK_PREPARE_20261031.md']
    if (w/'SLOT_VALID_STORAGE_PROOF.json').is_file():docs+=['D3_R53_ACTUAL_SLICE_PACKING_AUDIT.md','D3_R54_SLOT_VALID_STORAGE.md']
    if raw_edge:docs+=['D3_RAW_EDGE_R55_FIELD_GUIDE.md','D3_RAW_EDGE_R55_IMPLEMENTATION.md']
    if essential_ui:docs+=['D3_ESSENTIAL_UI_R56_FIELD_GUIDE.md','D3_ESSENTIAL_UI_R56_IMPLEMENTATION.md']
    for name0 in docs:copy(repo/'docs'/name0,release/'docs'/name0)
    comparison=load(repo/'docs/D3_RESOURCE_ANALYSIS.json');comparison_index={}
    for label,row in comparison['reports'].items():
        f=Path(row['path']);assert sha(f)==row['sha256']
        target=release/'resource_comparison'/(label+'.area');copy(f,target)
        comparison_index[label]={'file':target.relative_to(release).as_posix(),'sha256':sha(target),'original_path':str(f)}
    write(release/'resource_comparison/REPORTS.json',comparison_index)
    copy(repo/'docs'/('D3_ESSENTIAL_UI_R56_FIELD_GUIDE.md' if essential_ui else 'D3_RAW_EDGE_R55_FIELD_GUIDE.md' if raw_edge else 'R27B_DUAL_STOP_D3_FIELD_GUIDE.md'),release/'FIELD_GUIDE.md')
    scripts=['build_r22_relay.py','reuse_d3_synthesis.py','run_d3_prepared.py','audit_dual_stop_d3.py','relay_left_checks.py','relay_left_native_check.py',
        'check_camera_gain_fix.py','export_d3_camera.py','verify_d3_checks.py','publish_dual_stop_d3.py','publish_r22_shift_alarm_v7.py',
        'check_d3_distance_bounds.py','check_d3_observed_counter.py','report_d3_resources.py','verify_d3_full_candidate.py','check_d3_synthesis_storage.py','probe_d3_slice_stage.py','make_d3_id_ram_equivalence.py',
        'd3_check_prepare_rewrite.py','probe_d3_check_prepare.py','check_d3_check_prepare_math.py','run_d3_staged_physical.py','run_d3_prepared_synthesis.py',
        'd3_slot_valid_storage_rewrite.py','probe_d3_slot_valid_storage.py','check_d3_slot_valid_storage.py','compare_d3_placements.py','d3_fss_ref_prepare_rewrite.py']
    if raw_edge:scripts+=['d3_raw_edge_rewrite.py','probe_d3_raw_edge.py','check_d3_raw_edge.py','check_d3_raw_edge_synthesis.py','audit_d3_slice_packing.py']
    if essential_ui:scripts+=['probe_d3_essential_ui.py','check_d3_essential_ui.py','verify_d3_essential_sdc.py','seal_d3_completed_native.py']
    for name0 in scripts:copy(repo/'scripts'/name0,release/'scripts'/name0)
    rejected=tmp/'d3_dual_stop_build_r12_local_banks_20261030'
    copy(rejected/'REJECTED_RESOURCE.json',release/'diagnostics/rejected_local_bank_unroll/REJECTED_RESOURCE.json')
    for stage in ['syn_1','phy_1']:
        for f in (rejected/'runs'/stage).iterdir():
            if f.is_file() and f.suffix in ['.log','.area','.timing']:copy(f,release/'diagnostics/rejected_local_bank_unroll'/stage/f.name)
    write(release/'VERIFICATION.json',{'status':'PASS_EXACT_INPUT_SIMULATION_AND_STRICT_ROUTED_AUDIT',
        'software':software,'physical':physical,'hardware_acceptance':False})
    write(release/'RELEASE.json',receipt);copy(bit,release/(name+'.bit'))
    (release/'README.md').write_text('R27B 双列识别/独立计数 + D3 双列补件停车。原成功计数算法保留，每列32任务、完整1秒保持、相邻穴继续、各列五空报警、一个共用电机。操作与验收见 FIELD_GUIDE.md。尚未实板验收。构建冻结704源/107依赖，'+str(software['selected_checks'])+'项精确编译输入软件检查，原49条约束与建立/保持/双报警到V2注册输出审计通过。重建到新目录：python scripts/build_r22_relay.py --source project --keys-v3 --seed '+str(build['seed'])+' --synthesis-strategy '+strategy['strategy']+' --physical-strategy '+physical_strategy['strategy']+' --stage-timeout 7200 --baseline-manifest build/frozen_inputs.json --extra-source user_source/hdl_source/observed_classified_pocket_counter.v user_source/hdl_source/global_empty_position_tracker.v user_source/hdl_source/dual_lane_parking.v --work E:/2026FPGA/D3_rebuild 。不得覆盖已有构建目录；重建仍需重新物理审计。\n',encoding='utf8')
    if essential_ui:
        readme=release/'README.md'
        readme.write_text(readme.read_text().replace('原49条约束与建立/保持/双报警到V2注册输出审计通过','原SDC逐字节保留：38条显式及2条厂商有效约束通过，9条已删除显示通路的约束逐条核销；建立/保持/双报警到V2注册输出审计通过'),encoding='utf8')
    payload={f.relative_to(release).as_posix():{'bytes':f.stat().st_size,'sha256':sha(f)} for f in release.rglob('*') if f.is_file()}
    write(release/'PAYLOAD_SHA256.json',payload)
    with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as z:
        for f in release.rglob('*'):
            if f.is_file():z.write(f,f.relative_to(release).as_posix())
    with zipfile.ZipFile(archive) as z:
        assert z.testzip() is None and set(z.namelist())==set(payload)|{'PAYLOAD_SHA256.json'}
        for rel,row in payload.items():assert hashlib.sha256(z.read(rel)).hexdigest()==row['sha256']
    copy(release/(name+'.bit'),flash);copy(release/'FIELD_GUIDE.md',flash_root/(name+'_说明.md'))
    write(flash_root/(name+'_RELEASE.json'),{**receipt,'release_directory':str(release),'archive':str(archive),'archive_sha256':sha(archive)})
    assert sha(flash)==sha(bit)
    for file,d in protected.items():assert sha(flash_root/file)==d
    delivery={'status':'DELIVERED_FOR_HUMAN_TWO_LANE_COUNT_AND_PARKING_TEST','release':str(release),'archive':str(archive),
        'archive_sha256':sha(archive),'flash_copy':str(flash),'bit_sha256':sha(bit),'payload_count':len(payload),'selected_checks':software['selected_checks']}
    write(repo/'docs/R27B_DUAL_STOP_D3_DELIVERY.json',delivery);print(json.dumps(delivery,indent=2),flush=True)

if __name__=='__main__':main()
