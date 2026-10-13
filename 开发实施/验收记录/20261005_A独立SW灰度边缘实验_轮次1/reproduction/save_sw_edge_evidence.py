from pathlib import Path
import hashlib,json,re,shutil
from PIL import Image
r=Path(__file__).resolve().parents[2];p=r/'fpga/component_inspector';b=r/'tmp/sw_edge_td_build_20261005'
e=r/'开发实施/验收记录/20261005_A独立SW灰度边缘实验_轮次1';release=p/'release/sw_edge_20261005'
old=json.loads((p/'release/sample_ui_20261005/manifest.json').read_text(encoding='utf-8'))
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
assert resources['eram']==48 and resources['dsp']==8 and resources['slice_percent']<=80
line=next(line for line in area.splitlines() if '|    u_roi_sobel_view ' in line)
assert int(line.split('|')[6].strip())==12,line
exception=(phy/'camera_to_dsi_display_exception.timing').read_text(encoding='utf-8')
budgets=[]
for module in ['u_camera_receive','u_roi_display','u_observation_receive','u_observation_display']:
 for register in ['payload','req','ack']:
  line=next(line for line in exception.splitlines() if 'set_max_delay' in line and module+'/'+register in line)
  numbers=[int(v) for v in line.split()[:4]]
  assert numbers[0]>0 and numbers[0]==numbers[1] and numbers[2:]==[0,0],line
  budgets.append({'path':module+'/'+register,'matched':numbers[0],'dominated':numbers[1],'ignored':numbers[3]})
ignored=(r/'tmp/modelsim_probe/sw_edge_ignored.timing').read_text(encoding='utf-8')
switch_line=next(line for line in ignored.splitlines() if 'set_false_path' in line and 'I_switch' in line)
switch_numbers=[int(v) for v in switch_line.split()[:4]]
assert switch_numbers[0]==switch_numbers[1]==2 and switch_numbers[2:]==[0,0],switch_line
coverage=(phy/'constraint_coverage.txt').read_text(encoding='utf-8');pattern=r'^\d+\. checking ([^\n(]+)\((\d+)\)'
counts={name.strip():int(n) for name,n in re.findall(pattern,coverage,re.M)}
expected_counts=dict(old['constraint_coverage_counts'])
expected_counts['no input delay']+=2 # async SW inputs: matched false paths, not synchronous timed I/O
expected_counts['shadowed/ignored timing exception constraints']+=3
assert counts==expected_counts,'Review unexpected coverage changes before release'
for previous,current in [('u_monitor_display/req','u_observation_display/req'),('u_monitor_display/ack','u_observation_display/ack')]:
 detail=exception.split('Constraint     :   set_max_delay -datapath_only 19.0 -from [get_regs {'+previous+'}]')[1].split('Constraint     :')[0]
 assert 'Shadowed       :            1' in detail and current in detail and '19.0' in detail,previous
detail=exception.split('Constraint     :   set_max_delay -datapath_only 19.0 -from [get_regs {u_camera_display/payload*}]')[1].split('Constraint     :')[0]
assert 'Shadowed       :           13' in detail and '8.0' in detail and 'u_camera_receive/payload*' in detail
probe=(r/'tmp/modelsim_probe/sw_edge_constraints_probe.log').read_text(encoding='utf-8-sig')
assert re.search(r'SW_PORTS=.*COUNT=2',probe) and probe.count('Net: I_switch[')==4
assert 'set_false_path -from [get_ports {I_switch[*]}]' in (r/'tmp/modelsim_probe/sw_edge_exported.sdc').read_text()
inputs=json.loads((b/'inputs.json').read_text(encoding='utf-8'));project_entry=inputs[-1]
assert len(inputs)==207 and project_entry['path'].endswith('.al')
for entry in inputs:
 rel=entry['path'];assert sha(p/rel)==sha(b/rel)==entry['sha256'],rel
prior={x['path']:x['sha256'] for x in old['verified_build_inputs']}
changed=[x['path'] for x in inputs[:-1] if x['path'] in prior and x['sha256']!=prior[x['path']]]
tests=['sobel_view','observation','stop_recovery','display_state','controls','cdc','monitor','csi_monitor','i2c','osd','pack_boundary','pixel_interface','roi_guard','roi_core','classifier','roi_chain']
runner=r/'tmp/modelsim_probe/regression_sw_edge_console.log'
assert 'PASS ModelSim: all 16 tests' in runner.read_text(encoding='utf-8-sig')
concurrent=r/'tmp/modelsim_probe/sw_edge_concurrent_console.log'
assert 'PASS ModelSim: all 1 tests' in concurrent.read_text(encoding='utf-8-sig')
for test in tests:
 log=(p/'sim/modelsim_work'/test/'console.log').read_text(encoding='utf-8-sig')
 assert 'PASS ' in log and '** Fatal:' not in log and '** Error:' not in log,test
chain=(p/'sim/modelsim_work/roi_chain/console.log').read_text(encoding='utf-8-sig')
assert 'frame=9' in chain and 'view=0' in chain and 'view=1' in chain and 'view=2' in chain and 'view=3' in chain
for library in old['simulation_library']:assert sha(Path(library['path']))==library['sha256'],library['path']
old_bits=[]
for folder in (p/'release').iterdir():
 if folder.is_dir() and (folder/'manifest.json').exists() and (folder/'camera_to_dsi_display.bit').exists():
  prior_manifest=json.loads((folder/'manifest.json').read_text(encoding='utf-8'))
  prior_bit=folder/'camera_to_dsi_display.bit';assert sha(prior_bit)==prior_manifest['bitstream']['sha256'],prior_bit
  old_bits.append({'release':folder.name,'sha256':sha(prior_bit)})
assert not release.exists() and not e.exists(),'Never overwrite frozen evidence/release'
for entry in inputs:copy(p/entry['path'],e/'source_snapshot'/entry['path'])
for test in tests:
 for name in ['compile.log','console.log','transcript.log','wave.wlf']:
  copy(p/'sim/modelsim_work'/test/name,e/'modelsim'/test/name)
for file in (p/'sim').iterdir():
 if file.is_file() and file.suffix in ['.v','.ps1','.py','.do','.md']:copy(file,e/'source_snapshot/sim'/file.name)
shutil.copytree(p/'sim/osd_assets',e/'source_snapshot/sim/osd_assets')
copy(runner,e/'modelsim/regression_console.log');copy(p/'sim/modelsim_vendor_compile.log',e/'modelsim/vendor_compile.log')
copy(concurrent,e/'modelsim/observation_concurrent_console.log')
for name in ['osd']+[f'osd_state_{i}' for i in range(6)]+[f'osd_mode_{i}' for i in range(4)]:
 copy(p/'sim'/(name+'.ppm'),e/'rendered'/(name+'.ppm'))
 Image.open(p/'sim'/(name+'.ppm')).save(e/'rendered'/(name+'.png'))
for stage in ['syn_1','phy_1']:
 for file in (b/'td_project/camera_to_dsi_display_Runs'/stage).iterdir():
  if file.is_file() and file.suffix in ['.area','.timing','.qor','.cfg','.prj','.tcl','.txt','.status','.f','.log','.logw']:
   copy(file,e/'td'/stage/file.name)
for name in ['implement_sw_edge.py','prepare_sw_edge_build.py','save_sw_edge_evidence.py']:
 copy(r/'tmp/modelsim_probe'/name,e/'reproduction'/name)
copy(b/'inputs.json',e/'reproduction/inputs.json')
for name in ['sw_edge_constraints_probe.tcl','sw_edge_constraints_probe.log','sw_edge_exported.sdc','sw_edge_ignored.timing','sw_edge_td_help.tcl','sw_edge_td_help.log']:
 copy(r/'tmp/modelsim_probe'/name,e/'td/constraint_probe'/name)
shutil.copytree(r/'tmp/sw_edge_before_20261005',e/'history/before_implementation')
shutil.copytree(r/'tmp/modelsim_probe/sw_edge_history_unit1',e/'history/unit_first_attempts')
for name in ['sw_edge_unit_console.log','sw_edge_unit2_console.log','sw_edge_unit3_console.log','sw_edge_chain_console.log','sw_edge_osd_console.log']:
 copy(r/'tmp/modelsim_probe'/name,e/'history'/name)
for file in (r/'tmp/sw_edge_td_attempt1_20261005/td_project/camera_to_dsi_display_Runs/syn_1').iterdir():
 if file.is_file() and file.suffix in ['.log','.logw','.cfg','.prj','.tcl','.f','.txt']:
  copy(file,e/'history/td_adc_comment_attempt1'/file.name)
bit=phy/'camera_to_dsi_display.bit';assert bit.stat().st_size>1000000
copy(bit,release/bit.name);(release/(bit.name+'.sha256')).write_text(sha(bit)+'  '+bit.name+'\n',encoding='ascii')
manifest={'date':'2026-10-05','scope':'Approved independent SW1 gray / SW2 Sobel observation, all four combinations, unchanged KEY tuning and sampling UI; classification disabled',
 'branch':old['branch'],'head':old['head'],'working_tree_uncommitted':True,'td_version':old['td_version'],'modelsim_version':old['modelsim_version'],'device':old['device'],'speed_grade':3,
 'bitstream':{'path':str((release/bit.name).relative_to(r)).replace('\\','/'),'bytes':bit.stat().st_size,'sha256':sha(bit)},
 'observation_roi':old['observation_roi'],'roi':old['roi'],'classifier':old['classifier'],'roi_mailbox_width':83,'observation_request_width':18,'osd_latency_clocks':3,
 'switches':{'SW1':'A4, bit0 gray; UP=1','SW2':'B4, bit1 edge; UP=1','debounce_ms':20,'native_FS_applies_mode':True,'stable_change_increments_epoch16':True},
 'edge':{'kernel':'Sobel 3x3','magnitude':'abs(Gx)+abs(Gy)','threshold':80,'count_bits':13,'sum_bits':24,'core_pixels_required':6400,'line_banks':4,'line_bank_erams':12,'classification':False},
 'timing':{'setup_wns_ns':sw,'setup_tns_ns':st,'hold_wns_ns':hw,'hold_tns_ns':ht,'sta_coverage_percent':float(re.search(r'STA coverage\s*:\s*([\d.]+)%',timing)[1])},
 'resources':resources,'resource_delta':{k:resources[k]-old['resources'][k] for k in resources},
 'verification':{'modelsim':'16 default tests plus observation targeted repeat with concurrent tuning/configuration and mode changes; independent per-pixel Sobel/packing/core stats, nine actual RAW/ISP frames including native-FS mode application and mid-frame cancellation, four full OSD mode references, stopped CSI and reset/debounce/epoch recovery','synthesis':'passed','place_route':'passed','hardware':'not tested'},
 'constraints_pending':old['constraints_pending'],'constraint_coverage_counts':counts,'mailbox_budgets':budgets,'switch_constraint_counts':switch_numbers,'constraints_unchanged':False,'coverage_counts_unchanged':False,
 'coverage_review':{'no_input_delay_delta':2,'reason':'Both SW async paths are intentionally cut; ignored report proves 2/2 matched, 0 shadowed/ignored; report_nets shows only synchronizer loads','shadowed_constraint_delta':3,'reason_shadow':'Monitor req/ack shared physical paths covered by equal 19ns SW-display constraints; 13 camera-display payload paths covered by stricter 8ns camera-receive budget; none newly ignored'},
 'limitations':['Recent coherent capture statistics are not bound to the current DDR display frame; MODE shows the requested mode, which applies at the next native FS','Edge threshold 80 is exploratory, not an empty/present threshold or a validated value for three materials','CORE80 may miss outlines; pocket wall, bottom hole, reflections and cover film may also produce edges','CSI stop is detected by independent 1-second FPS windows, approximately 1-2 seconds plus display-frame update','Existing non-100% coverage and two PLL local-feedback warnings remain','Mechanical position/calibration, hardware image, three-material comparison, accuracy, 30-minute run, flash persistence and cold boot remain untested'],
 'build_directory':str(b),'verified_build_inputs':inputs[:-1],'project_sha256':project_entry['sha256'],'changes_vs_previous_release':changed,
 'simulation_library':old['simulation_library'],'previous_bit_sha256':old['bitstream']['sha256'],'previous_release_preserved':True,'user_implementation_approval':True,
 'assets':json.loads((p/'sim/osd_assets/manifest.json').read_text(encoding='utf-8')),'preserved_previous_bits':old_bits}
for dst in [release/'manifest.json',e/'manifest.json']:dst.write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
(e/'history/invocation_notes.md').write_text('''# 首次与复测记录

1. 首次observation单元失败：目的端把tag匹配放在live条件，第一份新tag记录到达才开始稳定等待，消耗其token。修正为独立请求变化触发等待、tag仅屏蔽记录有效位；不改变32拍排空标准。缩小仿真帧时序需先等45个显示拍再发布，第一次重试尚未满足等待的日志亦保留。停CSI/快速往返/恢复均需新完成token。
2. 首次实际ISP编译失败：Verilog模式不接受view_last/sample_cancel前向显式声明，已提前声明并用assign，保留编译日志。
3. TD首轮ADC注释使用//不被ADC命令解释器接受，改为#后新建构建目录重跑；首轮报告保留。没有放松时钟或跨域预算。
4. 7帧集成/OSD定向测试通过后，增强到9帧：覆盖四模式、帧中请求撤旧而视频保持本帧模式、下一原生FS应用与恢复；SW上电已拨上状态另加复位测试。默认16项最终回归是最终通过证据。
5. 默认回归运行时又补充observation单元的同时调参/配置与拨动恢复场景，独立定向重跑通过；其最终compile/console/WLF对应冻结的最新tb_observation.v，补测runner日志另存。没有为此重复慢速真实9帧或TD（DUT未改变）。
6. 检查覆盖报告新增2个no-input-delay（异步SW仍有匹配false-path，不加虚构同步input_delay）和3项shadow。只读导入最终数据库，report_timing_ignored明确SW 2/2匹配、0覆盖/忽略；report_nets显示每个SW仅一个同步寄存器负载。旧monitor req/ack由相同19ns观察显示预算覆盖，camera-display13个payload路径由更严格8ns接收预算覆盖。12项CSI/ROI/SW专用预算全部有效。report_timing_path直接从无同步delay的输入查询告警，不能用它的空结果作为路径证明，实际采用ignored报告。

初次日志不是最终验收。正式分类及实物性能尚未验证。
''',encoding='utf-8')
print('Frozen:',manifest['bitstream']);print('Resources:',resources,'Timing:',manifest['timing'])
print('206 inputs + .al; 16 tests; 12 new line ERAM; 12 CSI/ROI/SW CDC budgets and two SW input paths verified. Hardware untested.')
