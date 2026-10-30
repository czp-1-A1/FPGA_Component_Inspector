"""Verify actual R27 executions, early-result regression and routed evidence."""
from pathlib import Path
import argparse,json,re
from verify_dual_region_r25 import sha,load,read,log_test,UNIT_TESTS
from verify_classified_physical import verify as physical_verify,timing

SHORT_TESTS=UNIT_TESTS+['restart_epoch','switch_recorder_controls','empty_result_proof','high_slot_choice']

def inputs(source,project):
    frozen=load(source/'R27_FROZEN_INPUTS.json')
    assert load(source/'R27_EXECUTED_INPUTS.json')==frozen
    relocated={'td_project/camera_to_dsi_display.al'} | {
        'td_project/camera_to_dsi_display_Runs/'+stage+'/camera_to_dsi_display.prj' for stage in ['syn_1','phy_1']}
    for name,digest in frozen.items():
        assert sha(source/name)==digest,('source changed',name)
        if name not in relocated:assert sha(project/name)==digest,('execution changed',name)
    normalize=lambda text:re.sub(r'(<Project\b[^>]*\bPath=")[^"]*',r'\1<LOCAL_PATH>',text.replace('\r\n','\n'),count=1)
    for name in relocated:assert normalize(read(source/name))==normalize(read(project/name)),name
    receipt=load(project/'portable_preparation.json')
    assert receipt['frozen_source_manifest_sha256']==sha(source/'R27_FROZEN_INPUTS.json')
    assert len(receipt['inputs'])==102
    for name,digest in receipt['inputs'].items():assert sha(project/name)==digest==frozen[name],name
    assert 'place seed 2 ' in read(project/'td_project/camera_to_dsi_display_Runs/phy_1/settings.cfg')
    previous=load(source/'R26_FROZEN_INPUTS.json')
    changed=[name for name in previous if name.startswith('user_source/') and frozen[name]!=previous[name]]
    assert sorted(changed)==['user_source/hdl_source/compact_template_rom.v','user_source/hdl_source/frame_shape_search.v','user_source/hdl_source/isp/isp_top.v']
    assert all(frozen[name]==digest for name,digest in previous.items() if name.endswith('.sdc'))
    return {'source_manifest_sha256':sha(source/'R27_FROZEN_INPUTS.json'),'source_files':len(frozen),'production_dependencies':102,'production_changes':changed,'physical_seed':2}

def software(source,build,units):
    identities={key:inputs(source,p) for key,p in [('build',build),('units',units)]}
    tests={name:log_test(units,name) for name in SHORT_TESTS}
    tests['empty_native']=log_test(build,'empty_native')
    assert len(tests)==25
    independent={}
    for name in ['sim/two_region_ui_verification.json','sim/present_motion/unit_independent_result.json',
                 'sim/present_motion/detector_independent_reference.json','sim/present_motion/independent_pixels/verification.json']:
        report=load(units/name);assert report['status'].startswith('PASS'),name
        identity=report.get('manifest_sha256',report.get('source_manifest_sha256'))
        if identity:assert identity==sha(source/'R27_FROZEN_INPUTS.json'),name
        independent[name]=sha(units/name)
    # The original old-ISP failure must be the intended runtime assertion.
    old=source/'validation/r27/old_isp_order_failure'
    assert sha(old/'isp_top_r26.v')==load(source/'R26_FROZEN_INPUTS.json')['user_source/hdl_source/isp/isp_top.v']
    assert sha(old/'tb_empty_result_proof.sv')==sha(source/'sim/tb_empty_result_proof.sv')
    text=read(old/'console.log')
    assert '** Fatal: proved empty result must publish exactly once' in text and 'accepts=0' in text
    assert 'PASS EMPTY_RESULT_PROOF:' not in text
    selector=read(units/'sim/modelsim_work/high_slot_choice/console.log')
    assert '420000 actual RTL comparisons' in selector and 'vsim-12070' not in selector
    reference=source/'sim/reference/frame_shape_search_r27a.v'
    import hashlib
    original=reference.read_bytes().replace(b'module frame_shape_search_r27a #(',b'module frame_shape_search #(',1)
    assert hashlib.sha256(original).hexdigest()==load(source/'R27A_FROZEN_INPUTS.json')['user_source/hdl_source/frame_shape_search.v']
    unit=read(units/'sim/modelsim_work/empty_result_proof/console.log')
    assert '202 checks' in unit and '25 proof/result orders' in unit
    native=read(build/'sim/modelsim_work/empty_native/console.log')
    rows=re.findall(r'EMPTY_NATIVE_DONE source=(\d+) raw=(\d+) proof_minus_detector_ns=([-0-9.]+) accept_minus_proof_ns=([-0-9.]+)',native)
    assert [int(r[0]) for r in rows]==[1,2] and [int(r[1]) for r in rows]==[120,880]
    assert float(rows[0][2])<0 and float(rows[1][2])>0,'Both actual native proof/result orders required'
    assert 0<float(rows[1][3])<=100,'Early result must be released just after native proof'
    assert 'PASS EMPTY_NATIVE:' in native and 'force dut.' not in read(build/'sim/tb_empty_native.v')
    return {'status':'PASS_R27B_25_ACTUAL_SOFTWARE_TESTS_EARLY_EMPTY_RESULT_JOIN_AND_SELECTOR_EQUIVALENCE',
        'identities':identities,'actual_tests':25,'identity_reused_tests':0,'tests':tests,
        'independent_reports':independent,'native_empty_results':rows,
        'old_failure_console_sha256':sha(old/'console.log'),'board_acceptance':'HUMAN_PENDING',
        'scope':'24 short tests and one two-source native RAW test; old R26 12-source motion/10-source restart executions are historical only.'}

def verify(source,build,units,software_only=False):
    result=software(source,build,units)
    if software_only:return result
    physical=physical_verify(build)
    phy=build/'td_project/camera_to_dsi_display_Runs/phy_1'
    assert timing(read(phy/'camera_to_dsi_display_pr.timing'))==physical['timing_ns']
    final=read(build/'r27_finalization_console.log')
    assert 'PASS R27 ROUTED FINALIZATION:' in final and 'No multi-drive.' in final and 'No abnormal timing path.' in final
    resources={};area=read(phy/'camera_to_dsi_display_phy.area')
    for key,cap in [('slice',21216),('eram',108),('dsp',40),('pll',6)]:
        match=re.search(r'^#'+key+r'\s+(\d+)\s+out of\s+'+str(cap)+r'\b',area,re.M)
        assert match and int(match[1])<=cap;resources[key]=int(match[1])
    assert resources['eram']==101
    result.update(status='PASS_R27B_25_ACTUAL_TESTS_EMPTY_RESULT_JOIN_SELECTOR_EQUIVALENCE_AND_ROUTED_AUDIT',
        timing_ns=physical['timing_ns'],resources=resources,physical=physical,
        bit_sha256=sha(phy/'camera_to_dsi_display.bit'),routed_db_sha256=sha(phy/'camera_to_dsi_display_pr.db'),
        all_field_C6_causes_fixed_claimed=False)
    return result

if __name__=='__main__':
    parser=argparse.ArgumentParser()
    for name in ['source','build','units']:parser.add_argument(name,type=Path)
    parser.add_argument('--software-only',action='store_true')
    args=parser.parse_args()
    result=verify(args.source.resolve(),args.build.resolve(),args.units.resolve(),args.software_only)
    directory=args.source/'validation/r27';directory.mkdir(parents=True,exist_ok=True)
    name='software_verification.json' if args.software_only else 'verification.json'
    (directory/name).write_text(json.dumps(result,indent=2),encoding='utf8')
    print(result['status'])
