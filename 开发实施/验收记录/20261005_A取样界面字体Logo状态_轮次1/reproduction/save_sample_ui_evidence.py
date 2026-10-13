from pathlib import Path
import hashlib,json,re,shutil
from PIL import Image
r=Path(__file__).resolve().parents[2];p=r/'fpga/component_inspector';b=r/'tmp/sample_ui_td_build_20261005'
e=r/'开发实施/验收记录/20261005_A取样界面字体Logo状态_轮次1';release=p/'release/sample_ui_20261005'
old=json.loads((p/'release/roi_core_80_20261005/manifest.json').read_text(encoding='utf-8'))
sha=lambda f:hashlib.sha256(f.read_bytes()).hexdigest()
def copy(src,dst):dst.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(src,dst)
syn=b/'td_project/camera_to_dsi_display_Runs/syn_1';phy=b/'td_project/camera_to_dsi_display_Runs/phy_1'
for folder,marker in [(syn,'.opt_gate.end.f'),(phy,'.bitgen.end.f')]:
 assert (folder/marker).exists() and not list(folder.glob('*.error.f')),folder
timing=(phy/'camera_to_dsi_display_pr.timing').read_text(encoding='utf-8')
sw,st,hw,ht=map(float,re.search(r'SWNS:\s*([-\d.]+)ns, STNS:\s*([-\d.]+)ns\s*HWNS:\s*([-\d.]+)ns, HTNS:\s*([-\d.]+)ns',timing).groups())
assert sw>=0 and hw>=0 and st==ht==0,'Do not release timing violations'
area=(syn/'camera_to_dsi_display_gate.area').read_text(encoding='utf-8');qor=(phy/'route.qor').read_text(encoding='utf-8')
resources={n:int(re.search(r'^#'+n+r'\s+(\d+)',area,re.M)[1]) for n in ['lut','reg','eram','dsp']}
resources['slice']=int(re.search(r'#slices\s*\|\s*(\d+)',qor)[1]);resources['slice_percent']=float(re.search(r'slices percentage\s*\|\s*([\d.]+)%',qor)[1])
assert resources['eram']==36 and resources['dsp']==8
for module,count in [('u_ascii',1),('u_cjk',3),('u_logo',1)]:
 line=next(line for line in area.splitlines() if '|    '+module+' ' in line)
 assert int(line.split('|')[6].strip())==count,line
exception=(phy/'camera_to_dsi_display_exception.timing').read_text(encoding='utf-8')
budgets=[]
for module in ['u_camera_receive','u_roi_display']:
 for register in ['payload','req','ack']:
  line=next(line for line in exception.splitlines() if 'set_max_delay' in line and module+'/'+register in line)
  numbers=[int(v) for v in line.split()[:4]];assert numbers[0]>0 and numbers[0]==numbers[1] and numbers[2:]==[0,0],line
  budgets.append({'path':module+'/'+register,'matched':numbers[0],'dominated':numbers[1],'ignored':numbers[3]})
coverage=(phy/'constraint_coverage.txt').read_text(encoding='utf-8');pattern=r'^\d+\. checking ([^\n(]+)\((\d+)\)'
counts={name.strip():int(n) for name,n in re.findall(pattern,coverage,re.M)}
assert counts==old['constraint_coverage_counts'], 'Review any added coverage gap'
inputs=json.loads((b/'inputs.json').read_text(encoding='utf-8'));project_entry=inputs[-1];assert project_entry['path'].endswith('.al')
for entry in inputs:
 rel=entry['path'];assert sha(p/rel)==sha(b/rel)==entry['sha256'],rel
 copy(p/rel,e/'source_snapshot'/rel)
prior={x['path']:x['sha256'] for x in old['verified_build_inputs']}
changed=[x['path'] for x in inputs[:-1] if x['path'] in prior and x['sha256']!=prior[x['path']]]
assert set(changed)=={'user_source/hdl_source/design_top_wrapper.v','user_source/hdl_source/isp/isp_top.v','user_source/hdl_source/experiment_osd.v'},changed
tests=['stop_recovery','display_state','controls','cdc','monitor','csi_monitor','i2c','osd','pack_boundary','pixel_interface','roi_guard','roi_core','classifier','roi_chain']
runner=r/'tmp/modelsim_probe/regression_sample_ui_console.log'
assert 'PASS ModelSim: all 14 tests' in runner.read_text(encoding='utf-8-sig')
for test in tests:
 folder=p/'sim/modelsim_work'/test;log=(folder/'console.log').read_text(encoding='utf-8-sig')
 assert 'PASS ' in log and '** Fatal:' not in log and '** Error:' not in log,test
 for name in ['compile.log','console.log','transcript.log','wave.wlf']:copy(folder/name,e/'modelsim'/test/name)
for file in (p/'sim').iterdir():
 if file.is_file() and file.suffix in ['.v','.ps1','.py','.do','.md']:copy(file,e/'source_snapshot/sim'/file.name)
shutil.copytree(p/'sim/osd_assets',e/'source_snapshot/sim/osd_assets',dirs_exist_ok=True)
copy(runner,e/'modelsim/regression_console.log');copy(p/'sim/modelsim_vendor_compile.log',e/'modelsim/vendor_compile.log')
for name in ['osd']+[f'osd_state_{i}' for i in range(6)]:
 copy(p/'sim'/(name+'.ppm'),e/'rendered'/(name+'.ppm'))
 Image.open(p/'sim'/(name+'.ppm')).save(e/'rendered'/(name+'.png'))
for stage in ['syn_1','phy_1']:
 folder=b/'td_project/camera_to_dsi_display_Runs'/stage
 for file in folder.iterdir():
  if file.is_file() and file.suffix in ['.area','.timing','.qor','.cfg','.prj','.tcl','.txt','.status','.f','.log','.logw']:copy(file,e/'td'/stage/file.name)
for name in ['implement_sample_ui.py','prepare_sample_ui_build.py','update_sample_ui_docs.py','save_sample_ui_evidence.py']:copy(r/'tmp/modelsim_probe'/name,e/'reproduction'/name)
copy(b/'inputs.json',e/'reproduction/inputs.json')
shutil.copytree(r/'tmp/sample_ui_before_20261005',e/'history/before_implementation',dirs_exist_ok=True)
for name in ['sample_ui_integration_console.log','sample_ui_integration_console_retry.log','sample_ui_osd_console.log']:copy(r/'tmp/modelsim_probe'/name,e/'history'/name)
(e/'history/invocation_notes.md').write_text('''# 工具调用与测试修订记录

1. 首次TD误启动GUI td.exe，未执行综合，build_console.log为空。只关闭本轮新启动PID5644，未结束用户旧TD。随后使用td_commands_prompt.exe直接传build.tcl，最终综合为build_console_retry.log，物理阶段为phy_1/build_console.log。
2. 添加runner条目时字符串替换误触OnlyTests过滤表达式，首次定向调用只执行stop_recovery，未执行roi_chain。sample_ui_integration_console.log保留；修复过滤后定向两项通过，再执行默认完整14项，数量和每项最终PASS分别核对。
3. 初次停流边界测试第一场景停在已归零窗口，输出0参考拍，不能用作最坏边界证明。增加“停流前必须FPS非零”断言并将第一相位移至窗口150/1000，最终两相位分别1850、1020参考拍；此为增强测试，未放宽断言。
4. apply_patch首次拒绝同一文件的delete/add合并操作，未修改RTL；拆为顺序操作成功。没有本轮DUT断言失败或降低时序目标，约束未改变。

以上首次日志只保留历史，不当作本批最终通过证据。modelsim/regression_console.log和td最终报告属于最终203输入/.al。
''',encoding='utf-8')
bit=phy/'camera_to_dsi_display.bit';assert bit.stat().st_size>1000000;assert not release.exists(),'Never overwrite a release'
old_bits=[]
for folder in (p/'release').iterdir():
 if folder.is_dir() and (folder/'manifest.json').exists():
  prior_manifest=json.loads((folder/'manifest.json').read_text(encoding='utf-8'))
  prior_bit=folder/'camera_to_dsi_display.bit'
  if prior_bit.exists():
   assert sha(prior_bit)==prior_manifest['bitstream']['sha256'],prior_bit
   old_bits.append({'release':folder.name,'sha256':sha(prior_bit)})
for library in old['simulation_library']:assert sha(Path(library['path']))==library['sha256'],library['path']
copy(bit,release/bit.name);(release/(bit.name+'.sha256')).write_text(sha(bit)+'  '+bit.name+'\n',encoding='ascii')
manifest={'date':'2026-10-05','scope':'Approved sampling UI only: finite Chinese/ASCII fonts, Anlogic logo, 3-stage OSD, coherent recent statistics and recovery state; calibration disabled',
 'branch':old['branch'],'head':old['head'],'working_tree_uncommitted':True,'td_version':old['td_version'],'modelsim_version':old['modelsim_version'],'device':old['device'],'speed_grade':3,
 'bitstream':{'path':str((release/bit.name).relative_to(r)).replace('\\','/'),'bytes':bit.stat().st_size,'sha256':sha(bit)},
 'observation_roi':old['observation_roi'],'roi':old['roi'],'classifier':old['classifier'],'roi_mailbox_width':28,'osd_latency_clocks':3,
 'timing':{'setup_wns_ns':sw,'setup_tns_ns':st,'hold_wns_ns':hw,'hold_tns_ns':ht,'sta_coverage_percent':float(re.search(r'STA coverage\s*:\s*([\d.]+)%',timing)[1])},
 'resources':resources,'verification':{'modelsim':'14 default tests passed; complete raster and six state panels match independent references; actual RAW/ISP 7 frames; stopped CSI with independent reference monitor','synthesis':'passed','place_route':'passed','hardware':'not tested'},
 'constraints_pending':old['constraints_pending'],'constraint_coverage_counts':counts,'mailbox_budgets':budgets,'constraints_unchanged':True,
 'limitations':[v for v in old['limitations'] if not v.startswith('Stopped CSI detected')]+['Stopped CSI is detected by independent 1-second FPS windows (about 1-2 seconds), both calibrated and UNCAL displays then WAIT with invalid statistics','Mechanical fixture and formal calibration pending; display state injection is not hardware accuracy','Physical 30 minute run, flash persistence and cold boot untested for this version'],
 'build_directory':str(b),'verified_build_inputs':inputs[:-1],'project_sha256':project_entry['sha256'],'changes_vs_previous_release':changed,
 'simulation_library':old['simulation_library'],'previous_bit_sha256':old['bitstream']['sha256'],'previous_release_preserved':True,'user_implementation_approval':True,
 'assets':json.loads((p/'sim/osd_assets/manifest.json').read_text(encoding='utf-8')),'preserved_previous_bits':old_bits}
manifest['classifier']=dict(old['classifier'])
manifest['classifier']['source_classifier_fs_resets_freshness']=manifest['classifier'].pop('new_native_frame_clears_classification')
manifest['classifier']['display_history_retained_across_normal_fs']=True
for dst in [release/'manifest.json',e/'manifest.json']:dst.write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('Frozen:',manifest['bitstream']);print('Resources:',resources,'Timing:',manifest['timing']);print('203 inputs, .al, 14 tests, 5 mapped ROM ERAMs, six dedicated CDC budgets and unchanged coverage checked; hardware untested.')
