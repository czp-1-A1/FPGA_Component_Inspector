from pathlib import Path
import hashlib,json,re,shutil
from PIL import Image

root=Path(__file__).resolve().parents[2];project=root/'fpga/component_inspector'
build=root/'tmp/roi_core_td_build_20261005'
evidence=root/'开发实施/验收记录/20261005_A单穴80x80取样_轮次1'
release=project/'release/roi_core_80_20261005'
previous=json.loads((project/'release/roi_classifier_20261004/manifest.json').read_text(encoding='utf-8'))
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
def copy(source,target):
    target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(source,target)
phy=build/'td_project/camera_to_dsi_display_Runs/phy_1'
syn=build/'td_project/camera_to_dsi_display_Runs/syn_1'
timing=(phy/'camera_to_dsi_display_pr.timing').read_text(encoding='utf-8')
setup,stns,hold,htns=map(float,re.search(r'SWNS:\s*([-\d.]+)ns, STNS:\s*([-\d.]+)ns\s*HWNS:\s*([-\d.]+)ns, HTNS:\s*([-\d.]+)ns',timing).groups())
assert setup>=0 and hold>=0 and stns==htns==0,'Do not release timing violations'
qor=(phy/'route.qor').read_text(encoding='utf-8')
slice_count=int(re.search(r'#slices\s*\|\s*(\d+)',qor)[1])
slice_percent=float(re.search(r'slices percentage\s*\|\s*([\d.]+)%',qor)[1])
gate_area=(syn/'camera_to_dsi_display_gate.area').read_text(encoding='utf-8')
gr={n:int(re.search(r'^#'+n+r'\s+(\d+)',gate_area,re.M)[1]) for n in ['lut','reg','eram','dsp']}
physical_area=(phy/'camera_to_dsi_display_phy.area').read_text(encoding='utf-8')
pr={n:int(re.search(r'^#'+n+r'\s+(\d+)',physical_area,re.M)[1]) for n in ['lut6','reg']}
exception=(phy/'camera_to_dsi_display_exception.timing').read_text(encoding='utf-8')
for name in ['u_camera_receive/payload','u_camera_receive/req','u_camera_receive/ack','u_roi_display/payload','u_roi_display/req','u_roi_display/ack']:
    line=next(l for l in exception.splitlines() if 'set_max_delay' in l and name in l)
    numbers=[int(s) for s in line.split()[:4]]
    assert numbers[0]>0 and numbers[0]==numbers[1] and numbers[2:]==[0,0],line
coverage=(phy/'constraint_coverage.txt').read_text(encoding='utf-8')
baseline=(root/'tmp/roi_classifier_final_td_build_20261004/td_project/camera_to_dsi_display_Runs/phy_1/constraint_coverage.txt').read_text(encoding='utf-8')
pattern=r'^\d+\. checking ([^\n(]+)\((\d+)\)'
coverage_counts={name.strip():int(n) for name,n in re.findall(pattern,coverage,re.M)}
assert coverage_counts=={name.strip():int(n) for name,n in re.findall(pattern,baseline,re.M)},'New constraint gap requires review'
inputs=[];changed=[]
assert len(previous['verified_build_inputs'])==198
for old in previous['verified_build_inputs']:
    relative=old['path'];source=project/relative
    assert sha(source)==sha(build/relative),relative
    copy(source,evidence/'source_snapshot'/relative)
    inputs.append({'path':relative,'sha256':sha(source),'bytes':source.stat().st_size})
    if sha(source)!=old['sha256']:changed.append({'path':relative,'old_sha256':old['sha256'],'new_sha256':sha(source)})
assert {e['path'] for e in changed}=={'user_source/hdl_source/design_top_wrapper.v','user_source/hdl_source/isp/isp_top.v','user_source/hdl_source/experiment_osd.v'}
relative='td_project/camera_to_dsi_display.al'
assert sha(project/relative)==sha(build/relative)==previous['project_sha256']
copy(project/relative,evidence/'source_snapshot'/relative)
for p in (project/'sim').iterdir():
    if p.is_file() and (p.suffix in ['.v','.do','.ps1'] or p.name in ['README.md','.gitignore']):copy(p,evidence/'source_snapshot/sim'/p.name)
for stage in ['syn_1','phy_1']:
    folder=build/'td_project/camera_to_dsi_display_Runs'/stage
    assert not list(folder.glob('*.error.f'))
    assert (folder/('.opt_gate.end.f' if stage=='syn_1' else '.bitgen.end.f')).exists()
    for p in folder.iterdir():
        if p.is_file() and p.suffix in ['.area','.timing','.qor','.cfg','.prj','.tcl','.txt','.status','.f','.log','.logw']:copy(p,evidence/'td'/stage/p.name)
tests=['controls','cdc','monitor','csi_monitor','i2c','osd','pack_boundary','pixel_interface','roi_guard','roi_core','classifier','roi_chain']
for test in tests:
    folder=project/'sim/modelsim_work'/test
    content=(folder/'console.log').read_text(encoding='utf-8-sig')
    assert 'PASS ' in content and '** Fatal:' not in content and '** Error:' not in content,test
    for name in ['compile.log','console.log','transcript.log','wave.wlf']:copy(folder/name,evidence/'modelsim'/test/name)
runner=root/'tmp/modelsim_probe/regression_roi_core_console.log'
assert 'PASS ModelSim: all 12 tests' in runner.read_text(encoding='utf-8-sig')
copy(runner,evidence/'modelsim/regression_console.log')
copy(project/'sim/modelsim_vendor_compile.log',evidence/'modelsim/vendor_compile.log')
copy(project/'sim/osd.ppm',evidence/'osd_preview.ppm')
Image.open(project/'sim/osd.ppm').save(evidence/'osd_preview.png')
for name in ['implement_roi_core.py','prepare_roi_core.py','save_roi_core_evidence.py']:
    copy(root/'tmp/modelsim_probe'/name,evidence/'reproduction'/name)
(evidence/'history').mkdir(exist_ok=True)
(evidence/'history/invocation_notes.md').write_text('''# 本轮工具调用记录

1. 首次ModelSim启动将Tee-Object日志设为相对路径，runner的Push-Location导致日志目录解析错误，未得到完整回归。终端出现`Could not find a part of the path ... sim/tmp/modelsim_probe/...`。此项只保留调用观察，未保存完整原始日志，不补造失败波形。改用绝对日志路径后默认12项完整回归通过；未改DUT或放松断言。
2. 首次TD调用带`-f build.tcl`，工具报`wrong # args: should be "source ?-encoding name? fileName"`，没有执行综合。原始日志在td/syn_1/build_console.log。按TD接口直接传build.tcl后重跑，最终综合日志为td/syn_1/build_console_retry.log；以.opt_gate.end.f和最终报告确认完成。

这两项是命令/日志路径问题，不能作为RTL失败或通过证据。上级modelsim和TD最终报告属于本批冻结输入，旧release未修改。本版尚未上板。
''',encoding='utf-8')
bit=phy/'camera_to_dsi_display.bit'
assert bit.stat().st_size>1000000
assert not release.exists(), 'Never overwrite a release'
copy(bit,release/bit.name)
(release/'camera_to_dsi_display.bit.sha256').write_text(sha(bit)+'  camera_to_dsi_display.bit\n',encoding='ascii')
manifest={
 'date':'2026-10-05','scope':'512x256 gray observation; one central 80x80 cyan core statistics ROI; calibration disabled',
 'branch':previous['branch'],'head':previous['head'],'working_tree_uncommitted':True,
 'td_version':previous['td_version'],'modelsim_version':previous['modelsim_version'],'device':previous['device'],'speed_grade':3,
 'bitstream':{'path':str((release/bit.name).relative_to(root)).replace('\\','/'),'bytes':bit.stat().st_size,'sha256':sha(bit)},
 'observation_roi':previous['roi'],
 'roi':{'x0':472,'x1_exclusive':552,'y0':260,'y1_exclusive':340,'pixels':6400,'temporary':True,'purpose':'core inside one pocket, not full outline'},
 'classifier':previous['classifier'],
 'timing':{'setup_wns_ns':setup,'setup_tns_ns':stns,'hold_wns_ns':hold,'hold_tns_ns':htns,'sta_coverage_percent':float(re.search(r'STA coverage\s*:\s*([\d.]+)%',timing)[1])},
 'resources':{'slice':slice_count,'slice_percent':slice_percent,'eram':gr['eram'],'dsp':gr['dsp'],'synthesis_lut':gr['lut'],'synthesis_reg':gr['reg'],'physical_lut6':pr['lut6'],'physical_reg':pr['reg']},
 'verification':{'modelsim':'All 12 default tests passed; independent 6400 pixel reference, outside black/white exclusion, full-scale; OSD raster/cyan/sync/bypass; 7 native RAW/ISP frames','synthesis':'passed','place_route':'passed','hardware':'not tested'},
 'constraints_pending':previous['constraints_pending'],'constraint_coverage_counts':coverage_counts,'mailbox_six_budgets_valid':True,'constraints_unchanged':True,
 'limitations':[s for s in previous['limitations'] if 'Temporary multi-pocket' not in s]+['Cyan core physical fit and repeatability unverified; default UNCAL, no calibrated accuracy result'],
 'build_directory':str(build),'verified_build_inputs':inputs,'changes_vs_previous_release':changed,
 'project_sha256':sha(project/relative),'simulation_library':previous['simulation_library'],'previous_bit_sha256':previous['bitstream']['sha256'],'previous_release_preserved':True,
}
for dst in [release/'manifest.json',evidence/'manifest.json']:dst.write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('Bit:',sha(bit),'Timing/resources:',manifest['timing'],manifest['resources'])
print('198 input hashes, 12 tests, six mailbox budgets and unchanged constraint coverage verified. Hardware untested.')
