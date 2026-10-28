"""Seal the single-row query-retention / clean-view candidate after fresh tests and routed audit."""
from pathlib import Path
import argparse, hashlib, json, re, shutil, subprocess, zipfile

def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def load(p): return json.loads(p.read_text(encoding='utf8'))
def write(p, data):
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(json.dumps(data, indent=2, ensure_ascii=False)+'\n', encoding='utf8')
def copy(src, dst):
    dst.parent.mkdir(parents=True, exist_ok=True); shutil.copy2(src, dst)
def passed(p, sentinel='PASS '):
    text=p.read_text(encoding='utf-8-sig')
    assert sentinel in text and not re.search(r'\*\* (?:Fatal|Error):|Errors:\s*[1-9]', text), p

def main():
    a=argparse.ArgumentParser();a.add_argument('--work',required=True,type=Path);a.add_argument('--check-only',action='store_true');args=a.parse_args()
    repo=Path(__file__).resolve().parents[1];work=args.work.resolve();project=work/'project'
    source=load(work/'frozen_inputs.json');base=repo/'releases/r22_relay_wide_v4_20261028';old=load(base/'SOURCE_SHA256.json')
    changed=[p for p in source if source[p]!=old[p]]
    expected=['user_source/hdl_source/'+n+'.v' for n in ['design_top_wrapper','classified_dual_page_osd','compact_inspector_osd','classified_pocket_counter']]
    assert len(source)==636 and set(source)==set(old) and set(changed)==set(expected),changed
    for rel,d in source.items():assert sha(project/rel)==sha(repo/'fpga/component_inspector'/rel)==d,rel
    top=(project/expected[0]).read_text(encoding='utf8')
    assert 'RELAY_TOL_PX=80,' in top and top.count('.RELAY_TOL_PX(RELAY_TOL_PX)')==2
    for rel in ['user_source/constraints_source/pin.adc','td_project/camera_to_dsi_display.sdc','user_source/hdl_source/pocket_relay_stop_v2.v']:
        assert source[rel]==old[rel],rel
    groups=[Path('E:/2026FPGA/.codex_tmp')/n for n in ['r22_brake_faults_r2_20261028','r22_brake_clean_osd_r2_20261028','r22_brake_wide_r1_20261028','r22_brake_compat_r1_20261028']]
    selected=[]
    for group in groups:
        proof=load(group/'verification.json');assert proof['status']=='PASS'
        for rel,d in proof['inputs'].items():assert source[rel]==d,(group,rel)
        fixture='brake_track' if group.name in ['r22_brake_faults_r2_20261028','r22_brake_clean_osd_r2_20261028'] else 'wide_stop'
        for rel,d in proof['extra_inputs'].items():assert sha(repo/'tests'/fixture/Path(rel).name)==d
        for rel,d in {**proof['inputs'],**proof['extra_inputs']}.items():assert sha(group/'inputs'/Path(rel).name)==d
        for test in proof['tests']:
            log=group/(test['name']+'.log');assert sha(log)==test['sha256'];passed(log)
            selected.append({'name':test['name'],'group':group.name,'log_sha256':sha(log),'mode':'NEW_RUN'})
    assert len(selected)==14 and len({x['name'] for x in selected})==14
    native=Path('E:/2026FPGA/.codex_tmp/r22_brake_native_r1_20261028');n=load(native/'verification.json');assert n['status']=='PASS'
    for rel,d in n['inputs'].items():assert source[rel]==d
    assert sha(native/'console.log')==n['console_sha256'];passed(native/'console.log','PASS V3_NATIVE_MODE1:')
    selected.append({'name':n['name'],'group':'native','log_sha256':n['console_sha256'],'mode':'NEW_RUN','scope':'12 native RAW10/24 exact rasters, legacy-default tolerance8 compatibility; RAW does not reach station stop line. Wide parameter80 covered separately by wide controller/transport/display tests.'})
    gate=Path('E:/2026FPGA/.codex_tmp/r22_brake_camera_gate_r1_20261028');g=load(gate/'verification.json');assert g['status']=='PASS'
    field=Path('E:/2026FPGA/.codex_tmp/r22_rl4_f6_field_20261028')
    assert sha(field/'trackclean_camera_gate.v')==g['gate_netlist_sha256'] and g['cone_closure']['all_other_consumed_nets_have_selected_cell_drivers']
    for item in g['tests']:
        log=gate/(item['name']+'.log');assert sha(log)==item['log_sha256'];passed(log,'PASS CAMERA GATE BUS:')
        selected.append({'name':item['name'],'group':'camera_gate','log_sha256':sha(log),'mode':'NEW_RUN','scope':'Actual full synthesized camera cone,2 resets x126 serialized writes; simulated ACK slave, not optical readback'})
    legacy=[];sentinels=dict(re.findall(r'Name="([^"]+)";\s*Pass="([^"]+)"',(project/'sim/run_modelsim.ps1').read_text(encoding='utf8')))
    for name in ['classified_counter','result_recorder_pipeline','local_pipeline','switch_recorder_controls','recovery_protection','simple_recovery_ui','text_plane_prefetch']:
        folder=project/'sim/modelsim_work'/name;passed(folder/'console.log',sentinels[name]);compiled={}
        cl=(folder/'compile.log').read_text(encoding='utf-8-sig');assert not re.search(r'\*\* (?:Fatal|Error):|Errors:\s*[1-9]',cl)
        for line in cl.splitlines():
            if 'vlog ' in line and '-work' in line:
                for token in line.split():
                    token=token.strip('"')
                    if token.endswith(('.v','.sv')):
                        p=(project/'sim'/token).resolve();rel=p.relative_to(project).as_posix();assert sha(p)==source[rel];compiled[rel]=source[rel]
        assert compiled,name
        legacy.append({'name':name,'mode':'NEW_RUN','inputs':compiled,'compile_sha256':sha(folder/'compile.log'),'log_sha256':sha(folder/'console.log')})
    assert len(selected)+len(legacy)==23
    negative=field/'negative_and_boundary/r22_brake_dropout_old_r2_20261028'
    assert sha(negative/'inputs/tb_relay_brake_dropout.sv')==sha(repo/'tests/brake_track/tb_relay_brake_dropout.sv')
    assert 'unexpected fault F6 MS2 LS2 main4 local2' in (negative/'tb_relay_brake_dropout.log').read_text()
    assert sha(negative/'inputs/classified_pocket_counter.v')==old['user_source/hdl_source/classified_pocket_counter.v']
    assert 'RELAY_CLEAN_UI=1,' in top
    physical=load(work/'physical_verification.json');build=load(work/'build_result.json')
    assert physical['status'].startswith('PASS_R22_RELAY_V3_ROUTED_') and physical['max_delays_matched']==49 and physical['max_delays_ignored']==0
    assert physical['control_mailbox_bits']==20 and all(physical['timing_ns'][k]>=0 for k in ['SWNS','HWNS','STNS','HTNS'])
    bit=work/'runs/phy_1/camera_to_dsi_display.bit';assert sha(bit)==build['bit_sha256']==physical['bit_sha256']
    protected=Path('E:/2026FPGA/BIT_FLASH/LATEST_READONLY.bit');protected_sha='30d067cef0667893fe548ba04e423cd6618b76f119cb2e0ecf48b96ba6a5b20f';assert sha(protected)==protected_sha
    name='R22_RelayAuto_Left_V5_TrackClean_20261028';release=repo/'releases/r22_relay_trackclean_v5_20261028';archive=release.with_suffix('.zip');flash=Path('E:/2026FPGA/BIT_FLASH')/(name+'.bit')
    assert not release.exists() and not archive.exists() and not flash.exists()
    if args.check_only:
        print(json.dumps({'status':'READY_TO_PUBLISH','new_tests':23,'changed_production_files':changed,'bit_sha256':sha(bit),'resources':physical['resources'],'timing_ns':physical['timing_ns']},indent=2));return
    release.mkdir(parents=True)
    for rel in source:copy(project/rel,release/'project'/rel)
    write(release/'SOURCE_SHA256.json',source);copy(repo/'releases/r22_20261027/frozen_inputs.json',release/'baseline/r22_frozen_inputs.json')
    for p in (repo/'tests/wide_stop').iterdir():
        if p.is_file():copy(p,release/'tests/wide_stop'/p.name)
    for p in (repo/'tests/brake_track').iterdir():
        if p.is_file():copy(p,release/'tests/brake_track'/p.name)
    for p in (repo/'tests/camera_gain_fix').iterdir():
        if p.is_file():copy(p,release/'tests/camera_gain_fix'/p.name)
    for group,label in [(x,x.name) for x in groups]+[(native,'native'),(gate,'camera_gate')]:
        for p in group.rglob('*'):
            if p.is_file() and ('inputs' in p.relative_to(group).parts or p.suffix in ['.json','.log','.png']):copy(p,release/'tests'/label/p.relative_to(group))
    for item in legacy:
        for f in ['compile.log','console.log']:copy(project/'sim/modelsim_work'/item['name']/f,release/'tests/legacy'/item['name']/f)
    for p in field.rglob('*'):
        if p.is_file() and p.suffix in ['.json','.jpg','.png','.tcl','.log','.v']:copy(p,release/'field_evidence'/p.relative_to(field))
    copy(repo/'docs/R22_TRACKCLEAN_FIELD_ANALYSIS.json',release/'FIELD_ANALYSIS.json')
    copy(repo/'docs/R22_TRACKCLEAN_FIELD_GUIDE.md',release/'FIELD_GUIDE.md');copy(base/'WEAK_NATIVE_BOUNDARY.json',release/'WEAK_NATIVE_BOUNDARY.json')
    for script in ['build_r22_relay.py','audit_r22_relay.py','relay_left_checks.py','relay_left_native_check.py','check_camera_gain_fix.py','publish_r22_trackclean.py']:
        copy(repo/'scripts'/script,release/'scripts'/script)
    for p in work.iterdir():
        if p.is_file() and p.suffix in ['.json','.py','.tcl','.log']:copy(p,release/'build'/p.name)
    for stage in ['syn_1','phy_1']:
        for p in (work/'runs'/stage).iterdir():
            if p.is_file() and (p.suffix in ['.log','.cfg','.tcl','.prj','.rpt','.area','.timing','.db'] or p.name=='constraint_coverage.txt'):copy(p,release/'build/runs'/stage/p.name)
    for directory in ['classified_audit','gray_packing_audit']:
        for p in (project/directory).iterdir():
            if p.is_file():copy(p,release/'build'/directory/p.name)
    verification={'status':'PASS_23_FRESH_SELECTED_CHECKS_AND_ROUTED_AUDIT','selected':selected,'legacy':legacy,'physical':physical,'changed_production_files':changed,'unchanged_source_files':632,'field_sample_coverage':'RL4 current video F6 after S2, last valid X185; video root cause only partially reproduced, NOT a new-bit hardware success rate','board_operated':False,'new_board_parking_acceptance':False,'precision_1mm_acceptance':False,'automatic_speed_compensation':False,'actual_refill_actuator_implemented':False,'known_boundary':'Inherited weak RAW280 miss; dense candidate pruning can still block current query publication through an upstream gap. Failure logs preserved under field_evidence/negative_and_boundary. No lost-ID/epoch/type protection bypass.'}
    write(release/'VERIFICATION.json',verification);copy(bit,release/(name+'.bit'))
    receipt={'version':name,'branch':'codex/r22-brake-track-clean-ui','source_commit':subprocess.check_output(['git','rev-parse','HEAD'],cwd=repo,text=True).strip(),'parent_rl4_commit':'bcf29a4','source_worktree':str(repo),'build_work':str(work),'pushed':False,'bit_sha256':sha(bit),'bit_bytes':bit.stat().st_size,'td_version':'V6.2.168116','seed':2,'resources':physical['resources'],'slice_percent':physical['slice_percent'],'timing_ns':physical['timing_ns'],'source_files':636,'hardware_dependencies':104,'parameters':{'window_x':[80,240],'target_x':160,'tolerance_px':80,'advance_px':32,'trigger_x':192,'hold_ms':1000,'still_px':2},'gpio':'rightJ2 pin1/V2 HIGH; board5V; no LED; original ADC/SDC','layout':'single upper row; right count ROI + amber acceptance box80..240; internal left station preserved, auxiliary guides hidden','keys':'K1 freshRUN / K2 pause-resume / K3 clear-stop / K4 stop / SW3 up stop down freshRUN','source_manifest_sha256':sha(release/'SOURCE_SHA256.json'),'verification_sha256':sha(release/'VERIFICATION.json'),'board_acceptance':'PENDING_HUMAN_F6_SAME_TAPE_RETEST'}
    write(release/'RELEASE.json',receipt)
    (release/'README.md').write_text('RL5 active-query retention / clean-view field candidate. Read FIELD_GUIDE.md. Window80..240/target160/trigger192/hold1000ms; compile-time tolerance80, no speed adaptation. Full636 project/104 hardware dependencies;23 fresh selected checks plus strict routed audit. Actual field F6 resolution remains pending. One/two missing-frame query returns fixed in RTL; dense upstream pruning and weak RAW280 limitations remain. Read FIELD_ANALYSIS.json. Rebuild into a new ASCII directory with scripts/build_r22_relay.py --keys-v3 --source project --baseline-manifest baseline/r22_frozen_inputs.json --work E:/2026FPGA/RL5_rebuild --td E:/TD; then scripts/audit_r22_relay.py --keys-v3 --work same_path. Wide benches are separate: scripts/relay_left_checks.py --source project --bench-dir tests/wide_stop --osd --only tb_relay_wide_stop tb_relay_wide_transport tb_relay_wide_osd tb_relay_wide_real_second --out a_new_path. Native RAW compatibility: scripts/relay_left_native_check.py --v3 --source project --out another_new_path (legacy-default tolerance8, not arrival at stop line). Never overwrite this frozen release.\n',encoding='utf8')
    payload={p.relative_to(release).as_posix():{'bytes':p.stat().st_size,'sha256':sha(p)} for p in release.rglob('*') if p.is_file()};write(release/'PAYLOAD_SHA256.json',payload)
    with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as z:
        for p in release.rglob('*'):
            if p.is_file():z.write(p,p.relative_to(release).as_posix())
    with zipfile.ZipFile(archive) as z:
        assert z.testzip() is None
        for rel,row in payload.items():assert hashlib.sha256(z.read(rel)).hexdigest()==row['sha256']
    copy(release/(name+'.bit'),flash);copy(release/'FIELD_GUIDE.md',flash.with_name(name+'_说明.md'))
    write(flash.with_name(name+'_RELEASE.json'),{**receipt,'release_directory':str(release),'archive':str(archive),'archive_sha256':sha(archive)})
    assert sha(flash)==sha(bit) and sha(protected)==protected_sha
    delivery={'status':'DELIVERED_FOR_HUMAN_F6_RETEST','release':str(release),'archive':str(archive),'archive_sha256':sha(archive),'flash_copy':str(flash),'bit_sha256':sha(bit),'payload_count':len(payload),'new_tests':23}
    write(repo/'docs/R22_TRACKCLEAN_DELIVERY.json',delivery);print(json.dumps(delivery,indent=2),flush=True)

if __name__=='__main__':main()
