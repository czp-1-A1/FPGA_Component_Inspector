from pathlib import Path
from datetime import datetime
from zoneinfo import ZoneInfo
from collections import Counter
import hashlib, json, re, shutil, subprocess

root=Path(__file__).resolve().parent.parent
project=root/'fpga/component_inspector'
build=root/'tmp/led_presence_demo_v2_r2_td_20261008'
record=root/'开发实施/验收记录/20261008_A3528调参判定_轮次2'
release=project/'release/led_presence_demo_v2_r2_20261008'
assert not record.exists() and not release.exists(), 'Do not overwrite frozen evidence'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
read=lambda p:p.read_text(encoding='utf-8-sig',errors='replace')
load=lambda p:json.loads(read(p))
dump=lambda p,d:p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
inputs=load(build/'inputs.json')
assert len(inputs)==207
for entry in inputs:
    assert sha(build/entry['path'])==sha(project/entry['path'])==entry['sha256'],entry['path']
baseline=load(project/'release/led_presence_demo_v1_20261007/build_inputs.json')
changed=[x['path'] for x,y in zip(inputs,baseline) if x['sha256']!=y['sha256']]
assert changed==['user_source/hdl_source/design_top_wrapper.v']
rollback=[]
for version,expected in [('led_presence_demo_v1_20261007','4c8aa1695e06f3218ba5ae01b67e78e188755a61beea9f1229cdd1ef7296e22e'),('edge_tail_fix_20261007','bb6a71443b74790c64ceec562236799dc5b9418c07f4634c141b4df2a8bb9d65')]:
    path=project/'release'/version/'camera_to_dsi_display.bit'
    assert sha(path)==expected
    rollback.append({'path':path.relative_to(root).as_posix(),'sha256':expected})
v1_record=root/'开发实施/验收记录/20261007_A3528临时判定_轮次1'
v1_manifest=load(v1_record/'manifest.json')
for entry in v1_manifest['copies']:
    path=v1_record/entry['path']
    assert sha(path)==entry['sha256'] and path.stat().st_size==entry['bytes'],entry['path']
syn=build/'td_project/camera_to_dsi_display_Runs/syn_1'
phy=syn.parent/'phy_1'
for stage,end in [(syn,'opt_gate'),(phy,'bitgen')]:
    assert (stage/('.'+end+'.end.f')).exists()
    assert not list(stage.glob('.*.error.f'))
    assert not re.search(r'(?m)^\w+-\d+\s+(?:CRITICAL-)?ERROR:',read(stage/'build_console.log'))
timing=read(phy/'camera_to_dsi_display_pr.timing')
assert 'Confidence          : Routed' in timing and 'v6.2.168116' in timing
metrics={k:float(re.search(label+r':\s*([-\d.]+)ns',timing).group(1)) for k,label in [('setup_wns_ns','SWNS'),('setup_tns_ns','STNS'),('hold_wns_ns','HWNS'),('hold_tns_ns','HTNS')]}
metrics['sta_coverage_percent']=float(re.search(r'STA coverage\s*:\s*([\d.]+)%',timing).group(1))
assert metrics['setup_wns_ns']>=0 and metrics['hold_wns_ns']>=0
assert metrics['setup_tns_ns']==metrics['hold_tns_ns']==0
area=read(phy/'camera_to_dsi_display_phy.area')
resources={}
for name in ['slice','eram','dsp']:
    m=re.search(r'^#'+name+r'\*?\s+(\d+)\s+out of\s+(\d+)\s+([\d.]+)%',area,re.M)
    assert m,name
    resources[name+'_used'],resources[name+'_total'],resources[name+'_percent']=int(m[1]),int(m[2]),float(m[3])
for name in ['lut6','reg']:
    resources[name+'_used']=int(re.search(r'^#'+name+r'\s+(\d+)',area,re.M)[1])
assert resources['slice_percent']<80 and resources['eram_used']==48 and resources['dsp_used']==8
coverage=read(phy/'constraint_coverage.txt')
coverage_summary=[x.strip() for x in coverage.splitlines() if re.match(r'^\d+\. checking .*\(\d+\)',x)]
assert 'checking invalid constraint(0)' in coverage
assert 'checking no clock(0)' in coverage and 'checking combinational loops(0)' in coverage
budgets=[]
table=read(phy/'camera_to_dsi_display_exception.timing').split('MCP/SMD Details')[0]
for m in re.finditer(r'^\s*(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(set_max_delay .+)$',table,re.M):
    if '[get_regs {' in m[5]:
        budgets.append({'total':int(m[1]),'dominated':int(m[2]),'shadowed':int(m[3]),'ignored':int(m[4]),'constraint':m[5]})
assert len(budgets)==24 and all(x['total']>0 and x['ignored']==0 for x in budgets)
tests=['classifier','display_state','controls','observation','stop_recovery','osd','roi_chain']
assert 'PASS ModelSim: all 7 tests, including original vendor ERAM model' in read(build/'sim/suite_console.log')
test_results=[]
for name in tests:
    folder=build/'sim/modelsim_work'/name
    log=read(folder/'console.log')
    assert 'PASS' in log and 'Errors: 0' in log
    assert not re.search(r'(?m)^#?\s*\*\* (Fatal|Error):',log)
    assert sha(build/'sim'/('tb_'+name+'.v'))==sha(project/'sim'/('tb_'+name+'.v'))
    test_results.append({'name':name,'console_sha256':sha(folder/'console.log'),'pass_lines':[x for x in log.splitlines() if 'PASS ' in x]})
probe=build/'binding_probe'
assert 'PASS negative control:' in read(probe/'probe_console.log') and 'PASS v2 extracted bindings:' in read(probe/'probe_console.log')
assert 'Fatal: classifier FS freshness' in read(probe/'console_v1.log')
assert 'OBS binding tuning ex= 2244 gain=   47 enabled=1' in read(probe/'console_v1.log')
assert 'Errors: 0' in read(probe/'console_v2.log')
assert not re.search(r'(?m)^#?\s*\*\* (Fatal|Error):',read(probe/'console_v2.log'))
expressions=load(probe/'expressions.json')
assert expressions['v1']['top_sha256']==sha(root/'tmp/led_presence_demo_v2_before_20261008/user_source/hdl_source/design_top_wrapper.v')
assert expressions['v2']['top_sha256']==sha(project/'user_source/hdl_source/design_top_wrapper.v')
bit=phy/'camera_to_dsi_display.bit'
assert bit.stat().st_size==1789539
metadata={'syn':str(syn),'phy':str(phy),'flow':'D:/AAA/FPGA.....YZW/doc/scripts/DefaultFlow.tcl','tool':'D:/AAA/FPGA.....YZW/bin/td_commands_prompt.exe','td_version':'6.2.168116','source_commit':None,'base_head':subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip(),'source_snapshot':'开发实施/验收记录/20261008_A3528调参判定_轮次2/source_snapshot','release':{'path':(release/bit.name).relative_to(root).as_posix(),'sha256':sha(bit),'bytes':bit.stat().st_size},'validation_record':'开发实施/验收记录/20261008_A3528调参判定_轮次2.md'}
dump(project/'td_project/current_codex_build.json',metadata)
record.mkdir()
release.mkdir()
copies=[]
def copy(src,rel):
    dst=record/rel
    dst.parent.mkdir(parents=True,exist_ok=True)
    shutil.copy2(src,dst)
    assert sha(src)==sha(dst)
    copies.append({'path':dst.relative_to(record).as_posix(),'bytes':dst.stat().st_size,'sha256':sha(dst)})
for entry in inputs:
    copy(build/entry['path'],Path('source_snapshot')/entry['path'])
for name in ['inputs.json','stage_inputs.json','preparation.json','simulation_reuse.json']:
    copy(build/name,name)
for stage in [syn,phy]:
    for src in stage.iterdir():
        if src.is_file() and src.suffix.lower() in {'.log','.logw','.rpt','.txt','.status','.qor','.area','.tcl','.prj','.cfg','.timing','.bit','.f'}:
            copy(src,Path('td_reports')/stage.name/src.name)
for src in (build/'sim').iterdir():
    if src.is_file() and src.suffix.lower() in {'.v','.ps1','.py','.do','.md','.log','.hex'}:
        copy(src,Path('simulation')/src.name)
for src in (build/'sim/osd_assets').rglob('*'):
    if src.is_file():copy(src,Path('simulation/osd_assets')/src.relative_to(build/'sim/osd_assets'))
for name in tests:
    for src in (build/'sim/modelsim_work'/name).glob('*.log'):
        copy(src,Path('simulation/model_logs')/name/src.name)
for folder in ['binding_probe']:
    for src in (build/folder).iterdir():
        if src.is_file() and src.suffix.lower() in {'.log','.json','.v'}:
            copy(src,Path('simulation')/folder/src.name)
before=root/'tmp/led_presence_demo_v2_r2_before_20261008'
for src in before.rglob('*'):
    if src.is_file():copy(src,Path('before')/src.relative_to(before))
for name in ['prepare_led_presence_v2_r2_20261008.py','prepare_binding_probe_v2_r2_20261008.py','run_binding_probe_v2_r2_20261008.ps1','freeze_led_presence_v2_r2_20261008.py']:
    copy(root/'tmp'/name,Path('build_scripts')/name)
copy(root/'开发实施/31_A3528调参后自动判定_第二版说明.md','实施说明.md')
copy(v1_record/'threshold_source/历史照片记录.md','threshold_source/历史照片记录.md')
copy(v1_record/'threshold_source/historical_manifest.json','threshold_source/historical_manifest.json')
copy(project/'td_project/current_codex_build.json','current_codex_build.json')
warnings={stage.name:dict(Counter(re.findall(r'(?m)^(\w+-\d+) (?:CRITICAL-)?WARNING:',read(stage/'build_console.log')))) for stage in [syn,phy]}
vendor=Path('D:/AAA/FPGA.....YZW/sim_release')
vendor_files=['common/al_map_basic.v','common/al_map_lut.v','common/al_map_adder.v','common/al_phy_glbl.v','ph1p/ph1p_logic_eram.v','ph1p/ph1p_phy_gsr.v']
data={'created_at':datetime.now(ZoneInfo('Asia/Shanghai')).isoformat(timespec='seconds'),'status':'temporary_LED_v2_tuning_enabled_software_verified_board_validation_pending','branch':subprocess.check_output(['git','branch','--show-current'],cwd=root,text=True).strip(),'base_head':metadata['base_head'],'commit_status':'uncommitted_unpushed_workspace_snapshot','classification_enabled':True,'recipe':{'material':'current_3528_LED_black_tape_white_part','historical_part_number_verified':False,'threshold':58,'present_high':True,'exposure_gain_binding':False,'historical_reference_exposure':2244,'historical_reference_gain':48,'sample_roi':[472,552,260,340],'distance_mm_user_report':130},'threshold_source':v1_manifest['threshold_source'],'bit':metadata['release'],'tool':'TD6.2.168116','simulator':'ModelSim2019.2','build_inputs_count':len(inputs),'build_inputs_sha256':sha(build/'inputs.json'),'v1_changed':changed,'timing':metrics,'resources':resources,'coverage_summary':coverage_summary,'register_max_delay_summary':budgets,'warning_ids':warnings,'tests':test_results,'simulation_reuse':load(build/'simulation_reuse.json'),'binding_probe':{'extracted_expressions':expressions,'v1_negative_control_expected_failure':'gain47 disables classification; exact classifier FS assertion','v2_result':'PASS same tuning/freshness scenarios','scope':'logic bindings extracted from real wrapper; not full top/board simulation'},'rollback':rollback,'v1_frozen_evidence_files_verified':len(v1_manifest['copies']),'vendor_model_hashes':[{'path':str(vendor/x),'sha256':sha(vendor/x)} for x in vendor_files],'flow_sha256':sha(Path(metadata['flow'])),'limits':['No v2 board flashing, physical classification, continuous video acceptance or cold boot performed.','T58 accuracy changes with exposure/gain/light; only the hard enable binding was removed.','Historical photos lack confirmed part number, full static range and repeated placement.','Optical changes and misplaced ROI are not detected by validity gates.','DDR PLL, I/O delay and exception coverage findings retained; constraints unchanged and coverage not 100%.','Result is a recent sample, not bound to DDR display frame.','Only selected 7 regressions; not all 18 runner entries.'],'test_helper_repairs':['R1 generated a 32-bit-to-1-bit calibration port warning; R2 uses an explicitly sized one-bit literal and rebuilds the top. R1 evidence preserved.','Initial expression extraction regex required extra characters after CLASS_CALIBRATED; v2 constant expression needed zero. Preparation failure preserved; production/testbench unchanged.','ModelSim -onfinish exit returned zero at the expected v1 fatal. Negative-control checker now requires exact assertion, gain47 context and one error; positive run must contain PASS and no fatal. Checker failure preserved.'],'copies':copies}
dump(record/'manifest.json',data)
dump(release/'manifest.json',{k:v for k,v in data.items() if k!='copies'})
shutil.copy2(build/'inputs.json',release/'build_inputs.json')
shutil.copy2(bit,release/bit.name)
(release/'SHA256.txt').write_text(sha(bit)+'  '+bit.name+'\n',encoding='ascii')
dump(build/'final_audit.json',data)
print(json.dumps({'record':str(record),'release':str(release),'bit':data['bit'],'timing':metrics,'resources':resources,'copies':len(copies)},ensure_ascii=True))
