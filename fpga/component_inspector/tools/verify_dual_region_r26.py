"""Verify R26 frozen executions, independent results and actual routed audits."""
from pathlib import Path
import argparse, json, re
from verify_dual_region_r25 import sha, load, read, log_test, UNIT_TESTS
from verify_classified_physical import verify as physical_verify, timing

EXECUTED_SHA = 'df75d2fe88f512a60a02251675e48b55c8d32ce6309cf864740ddd0682207e44'

def inputs(source, project):
    initial = load(source/'R26_EXECUTED_INPUTS.json')
    final = load(source/'R26_FROZEN_INPUTS.json')
    assert len(initial)==668 and sha(source/'R26_EXECUTED_INPUTS.json')==EXECUTED_SHA
    assert all(final[n]==h for n,h in initial.items())
    for n,h in final.items(): assert sha(source/n)==h, ('changed final source',n)
    relocated = {'td_project/camera_to_dsi_display.al'} | {
        'td_project/camera_to_dsi_display_Runs/'+s+'/camera_to_dsi_display.prj' for s in ['syn_1','phy_1']}
    assert {n for n,h in initial.items() if sha(project/n)!=h}==relocated
    normalize=lambda t:re.sub(r'(<Project\b[^>]*\bPath=")[^"]*',r'\1<LOCAL_PATH>',t.replace('\r\n','\n'),count=1)
    n='td_project/camera_to_dsi_display.al'
    assert normalize(read(source/n))==normalize(read(project/n))
    profile=load(project/'R26_FROZEN_INPUTS.json')
    assert profile in [initial,final]
    for n in set(profile)-set(initial): assert sha(project/n)==final[n]
    receipt=load(project/'portable_preparation.json')
    assert receipt['frozen_source_manifest_sha256']==sha(project/'R26_FROZEN_INPUTS.json')
    assert len(receipt['inputs'])==102
    for n,h in receipt['inputs'].items(): assert sha(project/n)==h==initial[n],n
    for stage in ['syn_1','phy_1']:
        folder=project/'td_project/camera_to_dsi_display_Runs'/stage
        for n in re.findall(r'<File Path="([^"]+)"',read(folder/'camera_to_dsi_display.prj')):
            p=(folder/n).resolve()
            assert sha(p)==initial[p.relative_to(project).as_posix()]
    seed=re.search(r'place seed ([123]) ',read(project/'td_project/camera_to_dsi_display_Runs/phy_1/settings.cfg'))
    assert seed, 'Unrecorded physical seed; source/clocks/SDC must remain frozen'
    return {'inputs':len(initial),'dependencies':102,'relocated_descriptors':sorted(relocated),'physical_seed':int(seed[1])}

def units_check(units):
    names=UNIT_TESTS+['restart_epoch','switch_recorder_controls']
    tests={n:log_test(units,n) for n in names}
    for n in names:
        assert not re.search(r'Errors:\s*[1-9]',read(units/'sim/modelsim_work'/n/'compile.log'))
    reports={}
    for n in ['sim/two_region_ui_verification.json','sim/present_motion/unit_independent_result.json',
              'sim/present_motion/detector_independent_reference.json','sim/present_motion/independent_pixels/verification.json']:
        value=load(units/n);assert value['status'].startswith('PASS'),n
        identity=value.get('manifest_sha256',value.get('source_manifest_sha256'))
        if identity: assert identity==sha(units/'R26_FROZEN_INPUTS.json')
        reports[n]=sha(units/n)
    pattern=r'PTRACE_DETECTOR scene=(\d+) diag=([0-9a-f]+) objects=([0-9a-f]+) candidates=([0-9a-f]+) wait=(\d+)'
    a,b=[re.findall(pattern,read(units/'sim/modelsim_work'/n/'console.log')) for n in ['two_region_detector','sparse_equivalence']]
    assert len(a)==len(b)==14
    captures=[]
    for folder in ['dual_detector_out','sparse_detector_out']:
        paths=list((units/'sim/present_motion'/folder).glob('scene_*.pgm'))
        mapping={int(p.stem[len('scene_'):]):p for p in paths}
        assert len(paths)==len(mapping)==14
        captures.append(mapping)
    for x,y in zip(a,b):
        assert x[:4]==y[:4] and int(y[4])<=int(x[4])
        assert sha(captures[0][int(x[0])])==sha(captures[1][int(x[0])])
    rows=[tuple(map(int,t)) for t in re.findall(r'SPARSE_BUDGET scene=(\d+) rows=(\d+) old_cycles=(\d+) new_cycles=(\d+)',read(units/'sim/modelsim_work/sparse_row_detector/console.log'))]
    assert [t[0] for t in rows]==list(range(6)) and rows[2][2:]==(140456,97595)
    assert all(n<o for _,_,o,n in rows)
    restart=read(units/'sim/modelsim_work/restart_epoch/console.log')
    assert '150 command phases' in restart and 'true faults, timeout, config and LOST restart' in restart
    return tests,{'references':reports,'gray_capture_pairs':14,'dense_cycles':rows}

def restart_check(source, restart):
    import numpy as np
    text=read(restart/'sim/modelsim_work/restart_native/console.log')
    assert 'anlogic_sim.glbl anlogic_sim.PH1P_PHY_GSR' in text
    assert 'PASS R26_RESTART_NATIVE:' in text and 'DUAL_EVENT' not in text
    runtime=load(source/'validation/r26/runtime_freeze.json')
    assert sha(source/'validation/r26/run_r26_restart_native.ps1')==runtime['launcher_sha256']
    cadence=re.findall(r'CADENCE frame=(\d+) .*?LP=([0-9a-f]+)',text)
    assert [int(f) for f,_ in cadence]==list(range(1,11))
    assert all(3250<=int(lp,16)<=3380 for _,lp in cadence)
    boundaries=re.findall(r'RESTART_NATIVE_BOUNDARY source=(\d+) command=([0-9a-f]+) ready=(\d) live=([0-9a-f]+)',text)
    assert [int(f) for f,*_ in boundaries]==list(range(1,11))
    for f,command,ready,packed in boundaries:
        f=int(f);generation=1 if f<=2 else 2 if f<=8 else 3
        assert int(command,16)==generation*2
        assert int(ready)==int(f in [2,4,5,6,7,10])
        for bank in range(2):
            record=int(packed,16)>>(bank*256)
            assert (record>>32)&65535==generation
            assert (record>>48)&7!=3 and (record>>51)&15!=6
            assert (record>>58)&((1<<36)-1)==0
    faults=re.findall(r'RESTART_NATIVE_TRUE_FAULT source=9 command=([0-9a-f]+) live=([0-9a-f]+)',text)
    assert len(faults)==1 and int(faults[0][0],16)==4
    for bank in range(2):
        record=int(faults[0][1],16)>>(bank*256)
        assert (record>>48)&7==3 and (record>>51)&15==6
    rows=re.findall(r'DENSE_NATIVE_RESULT source=(\d+) latency_after_FE_ns=([\d.]+) objects=([0-9a-f]+)',text)
    assert [int(t[0]) for t in rows]==[2,4,5,6,7,10]
    captures={}
    oracle=source/'validation/r26/reference_R25/dense_cadence_1.pgm'
    for f,latency,packed in rows:
        assert 0<float(latency)<1250000
        assert all(((int(packed,16)>>(76*k+75))&1) and ((int(packed,16)>>(76*k+73))&3)==2 for k in range(4))
        p=restart/'sim'/('restart_cadence_'+f+'.pgm')
        assert sha(p)==sha(oracle),('dense original pixels changed',f)
        tokens=p.read_text().split();assert tokens[:4]==['P2','1280','720','255']
        pixels=np.array(tokens[4:],dtype=np.uint8).reshape(720,1280)
        assert np.array_equal(pixels[240:400,400:880],pixels[400:560,400:880])
        captures[p.name]=sha(p)
    match=re.search(r'exact RGB rasters=(\d+) pixels=(\d+) OF=0 UF=0',text)
    assert match and int(match[1])>=4 and int(match[2])>=3686400
    return {'status':'PASS_TEN_NATIVE_SW3_CDC_EPOCHS_TRUE_FAULT_AND_RESTART',
            'results':rows,'captures_sha256':captures,'translated_pixels':6*160*480,
            'full_rgb_rasters':int(match[1]),'checked_rgb_pixels':int(match[2]),
            'runtime_sha256':runtime['launcher_sha256']}

def verify(source,build,units,restart):
    identities={n:inputs(source,p) for n,p in [('native_and_physical',build),('units',units),('restart_native',restart)]}
    tests,references=units_check(units)
    tests['two_region_raw']=log_test(build,'two_region_raw')
    tests['restart_native']=log_test(restart,'restart_native')
    failure=source/'validation/r26/old_final_fixture_failure'
    expected=load(failure/'expected_failure.json')
    assert expected['status']=='EXPECTED_OLD_R25_PIPELINE_RESTART_FAILURE_REPRODUCED'
    assert expected['same_final_fixture_sha256']==sha(source/'sim/tb_restart_epoch.sv')==sha(failure/'tb_restart_epoch.sv')
    assert expected['old_pipeline_sha256']==sha(failure/'classified_count_pipeline.v')
    for n,h in expected['artifacts'].items(): assert sha(failure/n)==h
    assert 'Fatal: restart inherited preceding epoch offset=1' in read(failure/'console.log')
    native=load(build/'validation/r24/native_reference.json');assert native['status'].startswith('PASS')
    oracle=source/'validation/r26/reference_R25';identity=load(oracle/'identity.json')
    for n,h in identity['artifacts'].items(): assert sha(oracle/n)==h
    assert identity['same_motion_fixture_sha256']==sha(source/'sim/tb_two_region_raw.v')
    for pattern in [r'SPEED_CANDIDATES source=(\d+) data=([0-9a-f]+)',r'TRACE_NATIVE source=(\d+) data=([0-9a-f]+)']:
        a=re.findall(pattern,read(oracle/'native_console.log'))
        b=re.findall(pattern,read(build/'sim/modelsim_work/two_region_raw/console.log'))
        assert len(a)==len(b)==11 and a==b
    restarted=restart_check(source,restart)
    physical=physical_verify(build)
    final_log=build/'r26_finalization_console.log';text=read(final_log)
    assert 'PASS R26 ROUTED FINALIZATION:' in text and 'No multi-drive.' in text and 'No abnormal timing path.' in text
    phy=build/'td_project/camera_to_dsi_display_Runs/phy_1'
    routed=read(phy/'camera_to_dsi_display_pr.timing')
    for pattern in [r'^Top Model\s*:\s*design_top_wrapper\s*$',r'^Device\s*:\s*PH1P35MDG324\s*$',r'^Speed\s*:\s*3\s*$']:
        assert re.search(pattern,routed,re.M)
    assert timing(routed)==physical['timing_ns']
    resources={};area=read(phy/'camera_to_dsi_display_phy.area')
    for n,cap in [('slice',21216),('eram',108),('dsp',40),('pll',6)]:
        m=re.search(r'^#'+n+r'\s+(\d+)\s+out of\s+'+str(cap)+r'\b',area,re.M)
        assert m and int(m[1])<=cap
        resources[n]=int(m[1])
    assert resources['eram']==101 and len(tests)==24
    result={'status':'PASS_R26_24_ACTUAL_TESTS_SW3_EPOCH_RESTART_AND_ROUTED_AUDIT',
            'executed_inputs':668,'source_inputs':len(load(source/'R26_FROZEN_INPUTS.json')),
            'executed_manifest_sha256':EXECUTED_SHA,'source_manifest_sha256':sha(source/'R26_FROZEN_INPUTS.json'),
            'executed_project_identity':identities,'actual_tests':24,'identity_reused_tests':0,'tests':tests,
            'references':references,'restart_native':restarted,'native_reference_sha256':sha(build/'validation/r24/native_reference.json'),
            'timing_ns':physical['timing_ns'],'resources':resources,'physical_seed':identities['native_and_physical']['physical_seed'],
            'bit_sha256':sha(phy/'camera_to_dsi_display.bit'),
            'gate_db_sha256':sha(build/'td_project/camera_to_dsi_display_Runs/syn_1/camera_to_dsi_display_gate.db'),
            'routed_db_sha256':sha(phy/'camera_to_dsi_display_pr.db'),'finalization_log_sha256':sha(final_log),
            'board_acceptance':'HUMAN_PENDING','all_field_C6_causes_fixed_claimed':False}
    (source/'validation/r26/verification.json').write_text(json.dumps(result,indent=2),encoding='utf8')
    return result

if __name__=='__main__':
    parser=argparse.ArgumentParser()
    for n in ['source','build','units','restart']:parser.add_argument(n,type=Path)
    args=parser.parse_args()
    print(verify(*(getattr(args,n).resolve() for n in ['source','build','units','restart']))['status'])
