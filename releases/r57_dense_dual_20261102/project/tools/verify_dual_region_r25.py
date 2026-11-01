"""Verify R25 execution identities, 22 actual tests, dense deadline and routed audits."""
from pathlib import Path
import argparse, hashlib, json, re

EXECUTED_SHA = '1afd1aae81035d4827071f0cc9a5e4fa68c6f9afdff2a01a9ed7d4760c8e036b'
UNIT_TESTS = ['counter_timing_equivalence'] + ['counter_timing_case'+str(i) for i in range(1,5)] + [
    'two_region_count','classified_counter','local_pipeline','velocity_pipeline','local_recovery',
    'result_recorder_pipeline','two_region_ui','two_region_detector','present_trace_unit',
    'present_trace_detector','present_trace_ui','regions','frame_metadata','sparse_row_detector','sparse_equivalence']

def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def load(p): return json.loads(p.read_text(encoding='utf8'))
def read(p):
    b=p.read_bytes()
    return b.decode('utf-16' if b.startswith(b'\xff\xfe') else 'utf-8-sig')

def inputs(source, project):
    initial=load(source/'R25_EXECUTED_INPUTS.json')
    assert len(initial)==661 and sha(source/'R25_EXECUTED_INPUTS.json')==EXECUTED_SHA
    final=load(source/'R25_FROZEN_INPUTS.json')
    for n,h in final.items(): assert sha(source/n)==h, ('changed final source',n)
    assert all(final[n]==h for n,h in initial.items()), 'executed input changed'
    changes={n for n,h in initial.items() if sha(project/n)!=h}
    relocated={'td_project/camera_to_dsi_display.al'} | {
        'td_project/camera_to_dsi_display_Runs/'+s+'/camera_to_dsi_display.prj' for s in ['syn_1','phy_1']}
    assert changes==relocated, ('unexpected executed input difference',changes)
    normalize=lambda t:re.sub(r'(<Project\b[^>]*\bPath=")[^"]*',r'\1<LOCAL_PATH>',t.replace('\r\n','\n').replace('\r','\n'),count=1)
    n='td_project/camera_to_dsi_display.al'
    assert normalize(read(source/n))==normalize(read(project/n))
    receipt=load(project/'portable_preparation.json')
    project_manifest=load(project/'R25_FROZEN_INPUTS.json')
    assert project_manifest in [initial,final], 'Unrecognized execution source profile'
    assert receipt['frozen_source_manifest_sha256']==sha(project/'R25_FROZEN_INPUTS.json')
    assert len(receipt['inputs'])==102
    for n in set(project_manifest)-set(initial): assert sha(project/n)==final[n],n
    for n,h in receipt['inputs'].items(): assert sha(project/n)==h==initial[n],n
    for stage in ['syn_1','phy_1']:
        folder=project/'td_project/camera_to_dsi_display_Runs'/stage
        for n in re.findall(r'<File Path="([^"]+)"',read(folder/'camera_to_dsi_display.prj')):
            f=(folder/n).resolve()
            assert sha(f)==initial[f.relative_to(project).as_posix()],n
    assert 'place seed 2 ' in read(project/'td_project/camera_to_dsi_display_Runs/phy_1/settings.cfg')
    return {'executed_inputs':len(initial),'relocated_descriptors':sorted(relocated),'dependencies':102}

def log_test(project,name):
    folder=project/'sim/modelsim_work'/name
    compile_log,log=read(folder/'compile.log'),read(folder/'console.log')
    assert re.search(r'Errors:\s*0\b',compile_log),name
    assert re.search(r'(?m)^# PASS ',log) and not re.search(r'(?m)^#\s*\*\* (Fatal|Error):',log),name
    return {'compile_sha256':sha(folder/'compile.log'),'console_sha256':sha(folder/'console.log'),'actual_execution':True}

def unit_checks(units):
    tests={n:log_test(units,n) for n in UNIT_TESTS}
    reports={}
    for n in ['sim/two_region_ui_verification.json','sim/present_motion/unit_independent_result.json',
              'sim/present_motion/detector_independent_reference.json','sim/present_motion/independent_pixels/verification.json']:
        value=load(units/n);assert value['status'].startswith('PASS'),n
        identity=value.get('manifest_sha256',value.get('source_manifest_sha256'))
        if identity: assert identity==sha(units/'R25_FROZEN_INPUTS.json'),n
        reports[n]=sha(units/n)
    old,new=read(units/'sim/modelsim_work/two_region_detector/console.log'),read(units/'sim/modelsim_work/sparse_equivalence/console.log')
    pattern=r'PTRACE_DETECTOR scene=(\d+) diag=([0-9a-f]+) objects=([0-9a-f]+) candidates=([0-9a-f]+) wait=(\d+)'
    a,b=re.findall(pattern,old),re.findall(pattern,new)
    assert len(a)==len(b)==14
    captures={}
    capture_maps=[]
    for folder in ['dual_detector_out','sparse_detector_out']:
        paths=list((units/'sim/present_motion'/folder).glob('scene_*.pgm'))
        mapping={int(p.stem[len('scene_'):]):p for p in paths}
        assert len(paths)==len(mapping)==14,folder
        capture_maps.append(mapping)
    for x,y in zip(a,b):
        assert x[:4]==y[:4] and int(y[4])<=int(x[4]),('optimized result identity',x[0])
        first,second=[m[int(x[0])] for m in capture_maps]
        assert sha(first)==sha(second),x[0]
        captures[second.name]=sha(second)
    benchmark=read(units/'sim/modelsim_work/sparse_row_detector/console.log')
    rows=[tuple(map(int,t)) for t in re.findall(r'SPARSE_BUDGET scene=(\d+) rows=(\d+) old_cycles=(\d+) new_cycles=(\d+)',benchmark)]
    assert [t[0] for t in rows]==list(range(6))
    assert all(0<=n<o for _,_,o,n in rows) and rows[2][2]==140456 and rows[2][3]<125000
    return tests,{'independent_references':reports,'equivalent_original_fixture_captures':captures,'dense_cycles':rows}

def dense_checks(dense):
    import numpy as np
    log=read(dense/'sim/modelsim_work/two_region_dense_raw/console.log')
    rows=re.findall(r'DENSE_NATIVE_RESULT source=(\d+) latency_after_FE_ns=([\d.]+) objects=([0-9a-f]+)',log)
    assert [int(t[0]) for t in rows]==[1,2,3,4] and 'DUAL_EVENT' not in log
    captures={}
    for f,latency,packed in rows:
        assert 0<float(latency)<1250000,(f,latency)
        objects=int(packed,16)
        assert all(((objects>>(76*k+75))&1) and ((objects>>(76*k+73))&3)==2 for k in range(4)),('dense present objects',f)
        p=dense/'sim'/('dense_cadence_'+f+'.pgm');tokens=p.read_text().split()
        assert tokens[:4]==['P2','1280','720','255']
        pixels=np.array(tokens[4:],dtype=np.uint8).reshape(720,1280)
        assert np.array_equal(pixels[240:400,400:880],pixels[400:560,400:880]),f
        assert np.count_nonzero(pixels[298:342,420:860]>100)>5000,f
        captures[p.name]=sha(p)
    cadence=re.findall(r'CADENCE frame=(\d+) .*?LP=([0-9a-f]+)',log)
    assert [int(f) for f,_ in cadence]==[1,2,3,4,5] and all(3250<=int(t,16)<=3380 for _,t in cadence)
    assert 'OF=0 UF=0' in log and 'PASS R25_DENSE_NATIVE:' in log
    return {'status':'PASS_FOUR_DENSE_NATIVE_RESULTS_WITHIN_1_25MS_AND_CANCELED_FIFTH_NO_EVENTS',
            'results':rows,'captures_sha256':captures,'compared_translated_pixels':4*160*480,'field_acceptance':False}

def verify(source,build,units,dense):
    identities={name:inputs(source,project) for name,project in [('native_and_physical',build),('units',units),('dense_native',dense)]}
    tests,references=unit_checks(units)
    tests['two_region_raw']=log_test(build,'two_region_raw')
    tests['two_region_dense_raw']=log_test(dense,'two_region_dense_raw')
    native=load(build/'validation/r24/native_reference.json');assert native['status'].startswith('PASS')
    old_native=source/'validation/r25/reference_R24_native'
    oracle=load(old_native/'identity.json')
    assert sha(old_native/'console.log')==oracle['old_console_sha256']
    assert sha(source/'sim/tb_two_region_raw.v')==oracle['same_fixture_sha256']
    for pattern in [r'SPEED_CANDIDATES source=(\d+) data=([0-9a-f]+)',r'TRACE_NATIVE source=(\d+) data=([0-9a-f]+)']:
        original=re.findall(pattern,read(old_native/'console.log'))
        current=re.findall(pattern,read(build/'sim/modelsim_work/two_region_raw/console.log'))
        assert len(original)==len(current)==11 and original==current,'Original native classification/trace changed'
    dense_result=dense_checks(dense)
    failure=source/'validation/r25/baseline_deadline_failure'
    expected=load(failure/'expected_failure.json');assert expected['status']=='EXPECTED_R24_DENSE_NATIVE_ANALYSIS_DEADLINE_FAILURE_REPRODUCED'
    assert expected['same_bench_as_frozen_R25'] and sha(failure/'tb_two_region_dense_raw.v')==sha(source/'sim/tb_two_region_dense_raw.v')
    assert expected['console_sha256']==sha(failure/'console.log')
    assert re.search(r'Fatal: analysis did not finish within real cadence frame=1 phase=10 ready=0 FG=7776',read(failure/'console.log'))
    from verify_classified_physical import verify as physical_verify,timing
    physical=physical_verify(build)
    final_log=build/'r25_finalization_console.log';text=read(final_log)
    assert 'PASS R25 ROUTED FINALIZATION:' in text and 'No multi-drive.' in text and 'No abnormal timing path.' in text
    assert not re.search(r'(?m)^\S+\s+ERROR:',text)
    phy=build/'td_project/camera_to_dsi_display_Runs/phy_1'
    routed_text=read(phy/'camera_to_dsi_display_pr.timing')
    for pattern in [r'^Top Model\s*:\s*design_top_wrapper\s*$',r'^Device\s*:\s*PH1P35MDG324\s*$',r'^Speed\s*:\s*3\s*$']:
        assert re.search(pattern,routed_text,re.M), 'Wrong implementation target'
    assert timing(routed_text)==physical['timing_ns']
    resources={};area=read(phy/'camera_to_dsi_display_phy.area')
    for n,cap in [('slice',21216),('eram',108),('dsp',40),('pll',6)]:
        m=re.search(r'^#'+n+r'\s+(\d+)\s+out of\s+'+str(cap)+r'\b',area,re.M)
        assert m and int(m[1])<=cap,n
        resources[n]=int(m[1])
    assert resources['eram']==101,'Unexpected image memory replication'
    result={'status':'PASS_R25_22_ACTUAL_TESTS_EXPECTED_OLD_DEADLINE_FAILURE_AND_ROUTED_AUDIT',
            'executed_inputs':661,'source_inputs':len(load(source/'R25_FROZEN_INPUTS.json')),
            'executed_manifest_sha256':EXECUTED_SHA,'source_manifest_sha256':sha(source/'R25_FROZEN_INPUTS.json'),
            'executed_project_identity':identities,'actual_tests':len(tests),'identity_reused_tests':0,'tests':tests,
            'references':references,'dense_native':dense_result,'native_reference_sha256':sha(build/'validation/r24/native_reference.json'),
            'timing_ns':physical['timing_ns'],'resources':resources,'bit_sha256':sha(phy/'camera_to_dsi_display.bit'),
            'gate_db_sha256':sha(build/'td_project/camera_to_dsi_display_Runs/syn_1/camera_to_dsi_display_gate.db'),
            'routed_db_sha256':sha(phy/'camera_to_dsi_display_pr.db'),'finalization_log_sha256':sha(final_log),
            'board_acceptance':'HUMAN_PENDING','field_false_review_fixed':False,'unique_cause_of_all_field_C6_claimed':False}
    assert result['actual_tests']==22
    (source/'validation/r25/verification.json').write_text(json.dumps(result,indent=2),encoding='utf8')
    return result

if __name__=='__main__':
    p=argparse.ArgumentParser()
    for n in ['source','build','units','dense']:p.add_argument(n,type=Path)
    a=p.parse_args();print(verify(a.source.resolve(),a.build.resolve(),a.units.resolve(),a.dense.resolve())['status'])
