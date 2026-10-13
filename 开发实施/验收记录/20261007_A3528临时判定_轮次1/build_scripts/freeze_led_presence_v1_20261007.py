from pathlib import Path
from datetime import datetime
from zoneinfo import ZoneInfo
from collections import Counter
import hashlib, json, re, shutil, subprocess

root = Path(__file__).resolve().parent.parent
project = root / 'fpga/component_inspector'
build = root / 'tmp/led_presence_demo_v1_td_20261007'
record = root / '开发实施/验收记录/20261007_A3528临时判定_轮次1'
release = project / 'release/led_presence_demo_v1_20261007'
assert not record.exists() and not release.exists(), 'Do not overwrite frozen evidence'
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
read = lambda p: p.read_text(encoding='utf-8-sig', errors='replace')
load = lambda p: json.loads(read(p))
dump = lambda p, d: p.write_text(json.dumps(d, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
inputs = load(build / 'inputs.json')
assert len(inputs) == 207
for entry in inputs:
    assert sha(build / entry['path']) == sha(project / entry['path']) == entry['sha256'], entry['path']
baseline = load(project / 'release/edge_tail_fix_20261007/build_inputs.json')
changed = [x['path'] for x,y in zip(inputs,baseline) if x['sha256'] != y['sha256']]
assert changed == ['user_source/hdl_source/design_top_wrapper.v']
oldbit = project / 'release/edge_tail_fix_20261007/camera_to_dsi_display.bit'
assert sha(oldbit) == 'bb6a71443b74790c64ceec562236799dc5b9418c07f4634c141b4df2a8bb9d65'
phy = build / 'td_project/camera_to_dsi_display_Runs/phy_1'
syn = phy.parent / 'syn_1'
for stage, end in [(syn,'opt_gate'),(phy,'bitgen')]:
    assert (stage / ('.'+end+'.end.f')).exists()
    assert not list(stage.glob('.*.error.f'))
    assert not re.search(r'(?m)^\w+-\d+\s+(?:CRITICAL-)?ERROR:', read(stage/'build_console.log'))
timing = read(phy / 'camera_to_dsi_display_pr.timing')
assert 'Confidence          : Routed' in timing and 'v6.2.168116' in timing
metrics = {k: float(re.search(label+r':\s*([-\d.]+)ns', timing).group(1)) for k,label in [('setup_wns_ns','SWNS'),('setup_tns_ns','STNS'),('hold_wns_ns','HWNS'),('hold_tns_ns','HTNS')]}
metrics['sta_coverage_percent'] = float(re.search(r'STA coverage\s*:\s*([\d.]+)%', timing).group(1))
assert metrics['setup_wns_ns'] >= 0 and metrics['hold_wns_ns'] >= 0
assert metrics['setup_tns_ns'] == metrics['hold_tns_ns'] == 0
area = read(phy / 'camera_to_dsi_display_phy.area')
resources = {}
for name in ['slice','eram','dsp']:
    m = re.search(r'^#'+name+r'\*?\s+(\d+)\s+out of\s+(\d+)\s+([\d.]+)%',area,re.M)
    assert m, name
    resources[name+'_used'], resources[name+'_total'], resources[name+'_percent'] = int(m[1]),int(m[2]),float(m[3])
for name in ['lut6','reg']:
    resources[name+'_used'] = int(re.search(r'^#'+name+r'\s+(\d+)',area,re.M)[1])
assert resources['slice_percent'] < 80 and resources['eram_used']==48 and resources['dsp_used']==8
coverage = read(phy / 'constraint_coverage.txt')
coverage_summary = [x.strip() for x in coverage.splitlines() if re.match(r'^\d+\. checking .*\(\d+\)', x)]
assert 'checking invalid constraint(0)' in coverage
assert 'checking no clock(0)' in coverage and 'checking combinational loops(0)' in coverage
budgets=[]
prior=None
for line in read(phy/'camera_to_dsi_display_exception.timing').splitlines():
    m=re.match(r'^\s*(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(set_max_delay .+)',line)
    if m:
        prior={'total':int(m[1]),'dominated':int(m[2]),'shadowed':int(m[3]),'ignored':int(m[4])}
        command=m[5]
    elif line.strip().startswith('set_max_delay ') and prior:
        command=line.strip()
    else:
        continue
    if '[get_regs {' in command:
        budgets.append(dict(prior,constraint=command))
assert budgets and all(x['total']>0 and x['ignored']==0 for x in budgets)
tests=['classifier','display_state','controls','roi_core','roi_chain','osd','observation','sobel_tail','isp_writer_stop']
assert 'PASS ModelSim: all 9 tests, including original vendor ERAM model' in read(build/'sim/suite_console.log')
assert 'PASS ModelSim: all 1 tests, including original vendor ERAM model' in read(build/'sim/classifier_final_console.log')
test_results=[]
for name in tests:
    folder=build/'sim/modelsim_work'/name
    log=read(folder/'console.log')
    assert 'PASS' in log and 'Errors: 0' in log
    assert not re.search(r'(?m)^#?\s*\*\* (Fatal|Error):',log)
    assert sha(build/'sim'/('tb_'+name+'.v')) == sha(project/'sim'/('tb_'+name+'.v'))
    test_results.append({'name':name,'console_sha256':sha(folder/'console.log'),'pass_lines':[x for x in log.splitlines() if 'PASS ' in x]})
bit=phy/'camera_to_dsi_display.bit'
assert bit.stat().st_size==1789539
metadata={'syn':str(syn),'phy':str(phy),'flow':'D:/AAA/FPGA.....YZW/doc/scripts/DefaultFlow.tcl','tool':'D:/AAA/FPGA.....YZW/bin/td_commands_prompt.exe','td_version':'6.2.168116','source_commit':None,'base_head':subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),'source_snapshot':'开发实施/验收记录/20261007_A3528临时判定_轮次1/source_snapshot','release':{'path':(release/bit.name).relative_to(root).as_posix(),'sha256':sha(bit),'bytes':bit.stat().st_size},'validation_record':'开发实施/验收记录/20261007_A3528临时判定_轮次1.md'}
dump(project/'td_project/current_codex_build.json',metadata)
record.mkdir()
release.mkdir()
copies=[]
def copy(src, rel):
    dst=record/rel
    dst.parent.mkdir(parents=True,exist_ok=True)
    shutil.copy2(src,dst)
    assert sha(src)==sha(dst)
    copies.append({'path':dst.relative_to(record).as_posix(),'bytes':dst.stat().st_size,'sha256':sha(dst)})
for entry in inputs:
    copy(build/entry['path'],Path('source_snapshot')/entry['path'])
for name in ['inputs.json','stage_inputs.json','preparation.json']:
    copy(build/name,name)
for stage in [syn,phy]:
    for src in stage.iterdir():
        if src.is_file() and (src.suffix.lower() in {'.log','.logw','.rpt','.txt','.status','.qor','.area','.tcl','.prj','.cfg','.timing','.bit','.f'}):
            copy(src,Path('td_reports')/stage.name/src.name)
for src in (build/'sim').iterdir():
    if src.is_file() and src.suffix.lower() in {'.v','.ps1','.py','.do','.md','.log','.hex'}:
        copy(src,Path('simulation')/src.name)
for folder in ['osd_assets','history_classifier_eol']:
    for src in (build/'sim'/folder).rglob('*'):
        if src.is_file(): copy(src,Path('simulation')/folder/src.relative_to(build/'sim'/folder))
for name in tests:
    for src in (build/'sim/modelsim_work'/name).glob('*.log'):
        copy(src,Path('simulation/model_logs')/name/src.name)
for src in (root/'tmp/led_presence_demo_v1_before_20261007').rglob('*'):
    if src.is_file(): copy(src,Path('before')/src.relative_to(root/'tmp/led_presence_demo_v1_before_20261007'))
for name in ['prepare_led_presence_v1_20261007.py','checkpoint_led_presence_v1_20261007.py','freeze_led_presence_v1_20261007.py']:
    copy(root/'tmp'/name,Path('build_scripts')/name)
copy(root/'开发实施/29_A3528_LED临时有件空穴_实施说明.md','实施说明.md')
copy(root/'开发实施/验收记录/20261005_80x80单穴反馈_轮次1.md','threshold_source/历史照片记录.md')
copy(project/'td_project/current_codex_build.json','current_codex_build.json')
warnings={stage.name:dict(Counter(re.findall(r'(?m)^(\w+-\d+) (?:CRITICAL-)?WARNING:',read(stage/'build_console.log')))) for stage in [syn,phy]}
vendor=Path('D:/AAA/FPGA.....YZW/sim_release')
vendor_files=['common/al_map_basic.v','common/al_map_lut.v','common/al_map_adder.v','common/al_phy_glbl.v','ph1p/ph1p_logic_eram.v','ph1p/ph1p_phy_gsr.v']
data={'created_at':datetime.now(ZoneInfo('Asia/Shanghai')).isoformat(timespec='seconds'),'status':'temporary_LED_prototype_software_verified_board_validation_pending','branch':subprocess.check_output(['git','branch','--show-current'],text=True).strip(),'base_head':metadata['base_head'],'commit_status':'uncommitted_unpushed_workspace_snapshot','classification_enabled':True,'recipe':{'material':'current_3528_LED_black_tape_white_part','historical_part_number_verified':False,'threshold':58,'present_high':True,'exposure':2244,'gain':48,'sample_roi':[472,552,260,340],'distance_mm_user_report':130},'threshold_source':{'present_means':[85,88,78,82],'empty_means':[36,37,37,37,36],'duplicate_photo':'08 equals 06','use':'historical_display_MEAN_replay_only_not_independent_accuracy'},'bit':metadata['release'],'tool':'TD6.2.168116','simulator':'ModelSim2019.2','build_inputs_count':len(inputs),'build_inputs_sha256':sha(build/'inputs.json'),'baseline_changed':changed,'timing':metrics,'resources':resources,'coverage_summary':coverage_summary,'register_max_delay_summary':budgets,'warning_ids':warnings,'tests':test_results,'rollback':{'path':oldbit.relative_to(root).as_posix(),'sha256':sha(oldbit)},'vendor_model_hashes':[{'path':str(vendor/x),'sha256':sha(vendor/x)} for x in vendor_files],'flow_sha256':sha(Path(metadata['flow'])),'limits':['No board flashing, physical classification, continuous video acceptance or cold boot performed.','Historical photos lack confirmed part number, full static range and repeated placement.','Optical changes and misplaced ROI are not detected by validity gates.','DDR PLL, I/O delay and exception coverage findings retained; constraints unchanged and coverage not 100%.','Result is a recent sample, not bound to DDR display frame.','Only selected 9 regressions; not all 18 runner entries.'],'copies':copies}
dump(record/'manifest.json',data)
dump(release/'manifest.json',{k:v for k,v in data.items() if k!='copies'})
shutil.copy2(build/'inputs.json',release/'build_inputs.json')
shutil.copy2(bit,release/bit.name)
(release/'SHA256.txt').write_text(sha(bit)+'  '+bit.name+'\n',encoding='ascii')
dump(build/'final_audit.json',data)
print(json.dumps({'record':str(record),'release':str(release),'bit':data['bit'],'timing':metrics,'resources':resources,'copies':len(copies)},ensure_ascii=True))
