from pathlib import Path
import hashlib,json,re,shutil
root=Path(__file__).resolve().parents[2]
project=root/'fpga/component_inspector'
build=root/'tmp/roi_classifier_final_td_build_20261004'
evidence=root/'开发实施/验收记录/20261004_A均值离线判定_轮次1'
release=project/'release/roi_classifier_20261004'
previous=json.loads((project/'release/roi_statistics_large_20261003/manifest.json').read_text(encoding='utf-8'))
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def copy(source,target):target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(source,target)
phy=build/'td_project/camera_to_dsi_display_Runs/phy_1'
timing=(phy/'camera_to_dsi_display_pr.timing').read_text(encoding='utf-8')
setup,stns,hold,htns=map(float,re.search(r'SWNS:\s*([-\d.]+)ns, STNS:\s*([-\d.]+)ns\s*HWNS:\s*([-\d.]+)ns, HTNS:\s*([-\d.]+)ns',timing).groups())
assert setup>=0 and hold>=0 and stns==htns==0, 'Do not release timing failures'
qor=(phy/'route.qor').read_text(encoding='utf-8')
slice_count=int(re.search(r'#slices\s*\|\s*(\d+)',qor)[1])
slice_percent=float(re.search(r'slices percentage\s*\|\s*([\d.]+)%',qor)[1])
gate_area=(build/'td_project/camera_to_dsi_display_Runs/syn_1/camera_to_dsi_display_gate.area').read_text(encoding='utf-8')
gate_resources={name:int(re.search(r'^#'+name+r'\s+(\d+)',gate_area,re.M)[1]) for name in ['lut','reg','eram','dsp']}
physical_area=(phy/'camera_to_dsi_display_phy.area').read_text(encoding='utf-8')
physical_resources={name:int(re.search(r'^#'+name+r'\s+(\d+)',physical_area,re.M)[1]) for name in ['lut6','reg']}
exception=(phy/'camera_to_dsi_display_exception.timing').read_text(encoding='utf-8')
for name in ['u_camera_receive/payload','u_camera_receive/req','u_camera_receive/ack','u_roi_display/payload','u_roi_display/req','u_roi_display/ack']:
 line=next(l for l in exception.splitlines() if 'set_max_delay' in l and name in l)
 numbers=[int(s) for s in line.split()[:4]]
 assert numbers[0]>0 and numbers[0]==numbers[1] and numbers[2:]==[0,0],line
inputs=[];changed=[]
paths=[e['path'] for e in previous['verified_build_inputs']]+['user_source/hdl_source/roi_classifier.v']
assert len(set(paths))==198
for relative in paths:
 source=project/relative;assert sha(source)==sha(build/relative),relative
 copy(source,evidence/'source_snapshot'/relative)
 inputs.append({'path':relative,'sha256':sha(source),'bytes':source.stat().st_size})
 old=next((e for e in previous['verified_build_inputs'] if e['path']==relative),None)
 if not old or sha(source)!=old['sha256']:changed.append({'path':relative,'old_sha256':old['sha256'] if old else None,'new_sha256':sha(source)})
assert {e['path'] for e in changed}=={'user_source/hdl_source/design_top_wrapper.v','user_source/hdl_source/experiment_osd.v','user_source/hdl_source/isp/isp_top.v','user_source/hdl_source/roi_statistics.v','user_source/hdl_source/roi_classifier.v'}
relative='td_project/camera_to_dsi_display.al'
assert sha(project/relative)==sha(build/relative)
copy(project/relative,evidence/'source_snapshot'/relative)
for p in (project/'sim').iterdir():
 if p.is_file() and (p.suffix in ['.v','.do','.ps1'] or p.name in ['README.md','.gitignore']):copy(p,evidence/'source_snapshot/sim'/p.name)
for stage in ['syn_1','phy_1']:
 source=build/'td_project/camera_to_dsi_display_Runs'/stage
 assert not list(source.glob('*.error.f'))
 assert (source/('.opt_gate.end.f' if stage=='syn_1' else '.bitgen.end.f')).exists()
 for p in source.iterdir():
  if p.is_file() and (p.suffix in ['.area','.timing','.qor','.cfg','.prj','.tcl','.txt','.status','.f'] or p.name=='build_console.log'):
   copy(p,evidence/'td'/stage/p.name)
tests=['controls','cdc','monitor','csi_monitor','i2c','osd','pack_boundary','pixel_interface','roi_guard','classifier','roi_chain']
for test in tests:
 folder=project/'sim/modelsim_work'/test
 content=(folder/'console.log').read_text(encoding='utf-8-sig')
 assert 'PASS ' in content and '** Fatal:' not in content and '** Error:' not in content,test
 for name in ['compile.log','console.log','transcript.log','wave.wlf']:copy(folder/name,evidence/'modelsim'/test/name)
regressions={'regression_classifier_final10_console.log':'all 10 tests','regression_classifier_retention_console.log':'all 1 tests','regression_classifier_final_chain_console.log':'all 1 tests'}
for filename,expected in regressions.items():
 source=root/'tmp/modelsim_probe'/filename;assert 'PASS ModelSim: '+expected in source.read_text(encoding='utf-8-sig')
 copy(source,evidence/'modelsim'/filename)
for filename in ['regression_classifier_console.log','regression_classifier_retry_console.log','regression_classifier_probe_console.log','regression_classifier_fixed_console.log']:
 source=root/'tmp/modelsim_probe'/filename
 if source.exists():copy(source,evidence/'history'/filename)
failure=root/'tmp/modelsim_probe/classifier_td_missing_inputs'
for p in failure.iterdir():
 if p.is_file():copy(p,evidence/'history/td_missing_inputs'/p.name)
superseded=root/'tmp/roi_classifier_td_build_20261004/td_project/camera_to_dsi_display_Runs/syn_1'
for p in superseded.iterdir():
 if p.is_file() and (p.suffix in ['.area','.timing','.cfg','.prj','.tcl','.txt'] or p.name=='build_console.log'):
  copy(p,evidence/'history/superseded_synthesis'/p.name)
superseded_inputs=[]
for relative in paths:
 source=root/'tmp/roi_classifier_td_build_20261004'/relative
 superseded_inputs.append({'path':relative,'sha256':sha(source)})
 if sha(source)!=sha(project/relative):copy(source,evidence/'history/superseded_source'/relative)
(evidence/'history/superseded_build_inputs.json').write_text(json.dumps(superseded_inputs,indent=2)+'\n',encoding='utf-8')
(evidence/'history/failure_notes.md').write_text('''# 中间失败与未发布结果

以下前两项是会话终端观察摘要，原工作目录compile/console/WLF被后续复测更新，不能当作完整冻结失败波形。相关runner输出能保留的部分位于本history目录，不补造原始日志。

1. 首次改动脚本在换行匹配失败后续跑，roi_statistics重复声明sample_new；ModelSim报告 `sample_new already declared`，未进入ROI测试。重复声明已修复，最终编译通过。
2. 人工测试检查27位异步邮箱后未重新对齐CSI时钟，导致FS脉冲不足以跨源时钟边沿。终端报告 `state frame 4 expected=1 got=2 fs=0 child_fs=0 cancel=0 fresh=1`，Time 19951ns。测试刺激改为在negedge clk驱动并保持完整周期；最终测试通过，没有放松期望状态。
3. 初次隔离TD仅复制.al直接引用的59项文件，缺少间接IP依赖，open_project返回PRJ-8644。原始完整TD日志与设置保留td_missing_inputs，补齐旧197项清单及新增classifier后重新构建。
4. 新帧开始时清除旧统计的中间实现完成过综合及7帧仿真。随后细化为保留最近完整调参统计、取消未完成计算，另建最终目录重新综合/布局布线并复测。superseded_synthesis只作中间记录；其198项哈希位于superseded_build_inputs.json，与最终不同的源文件保留superseded_source，其余与最终快照相同。此中间配置没有发布bit。

最终通过证据使用上级modelsim/及td/，交付版默认未标定，实物未测。
''',encoding='utf-8')
copy(project/'sim/osd.ppm',evidence/'osd_preview.ppm')
copy(root/'tmp/modelsim_probe/classifier_osd_preview.png',evidence/'osd_preview.png')
copy(Path(__file__),evidence/'save_classifier_evidence.py')
coverage=(phy/'constraint_coverage.txt').read_text(encoding='utf-8')
assert 'checking no clock(0)' in coverage and 'checking invalid constraint(0)' in coverage
bit=phy/'camera_to_dsi_display.bit';copy(bit,release/bit.name)
(release/'camera_to_dsi_display.bit.sha256').write_text(sha(bit)+'  camera_to_dsi_display.bit\n',encoding='ascii')
manifest={
 'date':'2026-10-04','scope':'Offline mean classifier and independent RECENT label; default calibration disabled; temporary 512x256 observation ROI',
 'branch':previous['branch'],'head':previous['head'],'working_tree_uncommitted':True,
 'td_version':previous['td_version'],'modelsim_version':previous['modelsim_version'],'device':previous['device'],'speed_grade':3,
 'bitstream':{'path':str((release/bit.name).relative_to(root)).replace('\\','/'),'bytes':bit.stat().st_size,'sha256':sha(bit)},
 'roi':previous['roi'],
 'classifier':{'calibrated':False,'threshold_placeholder':0,'present_high_placeholder':True,'exposure_placeholder':2244,'gain_placeholder':48,'state_encoding':{'0':'UNCAL','1':'WAIT','2':'PRESENT','3':'EMPTY'},'ddr_frame_bound':False,'new_native_frame_clears_classification':True,'recent_tuning_statistics_retained':True,'comparison_when_enabled':'mean >= threshold for present_high; mean <= threshold otherwise'},
 'timing':{'setup_wns_ns':setup,'setup_tns_ns':stns,'hold_wns_ns':hold,'hold_tns_ns':htns,'sta_coverage_percent':float(re.search(r'STA coverage\s*:\s*([\d.]+)%',timing)[1])},
 'resources':{'slice':slice_count,'slice_percent':slice_percent,'eram':gate_resources['eram'],'dsp':gate_resources['dsp'],'synthesis_lut':gate_resources['lut'],'synthesis_reg':gate_resources['reg'],'physical_lut6':physical_resources['lut6'],'physical_reg':physical_resources['reg']},
 'verification':{'modelsim':'All 11 default tests passed on final RTL; classifier extra completed-statistics retention assertions also passed; 7 full native RAW/ISP frames with enabled artificial T=110','synthesis':'passed','place_route':'passed','hardware':'not tested'},
 'constraints_pending':previous['constraints_pending'],
 'limitations':[s for s in previous['limitations'] if s not in ['temporary ROI, no classification/accuracy result','stopped CSI clock causes WAIT after about 1-2 seconds']]+['Temporary multi-pocket observation ROI; default bit outputs UNCAL, no calibrated hardware classification or accuracy result','Stopped CSI detected after about 1-2 seconds; calibrated state falls to WAIT, uncalibrated state stays UNCAL','Production classification disabled pending actual single-hole ROI/threshold/polarity calibration; default synthesis may remove comparison logic, so enabling requires new TD validation','No measured real-world classification accuracy; synthetic specular test is not a guarantee of optical robustness','Result only recent acquisition, no DDR display frame identity; mailbox and VS snapshot can retain prior text until next display update'],
 'build_directory':str(build),'verified_build_inputs':inputs,'changes_vs_previous_release':changed,
 'project_sha256':sha(project/'td_project/camera_to_dsi_display.al'),'simulation_library':previous['simulation_library'],'previous_bit_sha256':previous['bitstream']['sha256'],'previous_release_preserved':True,
}
(release/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
(evidence/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('Bit:',sha(bit),'Final timing/resources:',manifest['timing'],manifest['resources'])
print('198 inputs verified; 11 tests passed; default calibration disabled; hardware not tested')
