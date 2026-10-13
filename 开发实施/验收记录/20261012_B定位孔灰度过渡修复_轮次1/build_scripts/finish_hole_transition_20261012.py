from pathlib import Path
from collections import Counter
import hashlib, json, re, shutil, subprocess

root=Path(__file__).resolve().parent.parent
project=root/'fpga/component_inspector'
build=root/'tmp/hole_transition_r1_td_20261012'
prior=root/'tmp/wb100_d3_r1_td_20261012'
record=root/'开发实施/验收记录/20261012_B定位孔灰度过渡修复_轮次1'
release=project/'release/hole_transition_fix_v1_20261012'
read=lambda p:p.read_text(encoding='utf-8-sig',errors='replace')
load=lambda p:json.loads(read(p))
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
dump=lambda p,data:p.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
inputs=load(build/'inputs.json')
assert len(inputs)==210
for e in inputs:
    assert sha(build/e['path'])==e['sha256']==sha(project/e['path']),e['path']
for name in ['stage_inputs.json','simulation_inputs.json','unit_inputs.json']:
    for e in load(build/name):assert sha(build/e['path'])==e['sha256'],e['path']
old={e['path']:e['sha256'] for e in load(prior/'inputs.json')}
changed=[e['path'] for e in inputs if old[e['path']]!=e['sha256']]
assert changed==['user_source/hdl_source/tape_hole_tracker.v'],changed
for e in load(record/'changes.json'):
    assert sha(project/e['path'])==e['after_sha256']
    assert sha(record/'before'/e['path'])==e['before_sha256']==old[e['path']]
rel=changed[0]
assert (project/rel).read_bytes().split(b'endmodule',1)[1]==(prior/rel).read_bytes().split(b'endmodule',1)[1]
assert sha(build/rel)==sha(build/'hole_unit/tape_hole_tracker.v')
assert sha(build/'hole_unit/tb_hole_soft_requirement.v')==sha(root/'tmp/hole_scan_boundary_20261012_r1/tb_hole_soft_requirement.v')
# Full source hashes prove WB100, acquisition/display/metadata/classification
# and all geometry parameters outside hole_scanline are unchanged.

unit_runs=[p for p in (build/'hole_unit').glob('run_*') if (p/'unit_exit_code.txt').exists()]
assert len(unit_runs)==1,unit_runs
unit_run=unit_runs[0]
unit_tests={'hole_transition_requirements':'PASS bounded hole transition requirements: 133 cases',
            'hole_soft_requirement':'PASS soft hole requirement: two valid blurred-hole frames acquired'}
assert read(unit_run/'unit_exit_code.txt').strip()=='0'
for name,expected in unit_tests.items():
    log=read(unit_run/(name+'_console.log'))
    assert expected in log and not re.search(r'\*\* (Fatal|Error):',log+read(unit_run/'compile.log')),name

tests=['tracking_late','tracking_status','isp_tracking_late','tracking_age','isp_tracking','tracking','isp_metadata_stop','isp_writer_stop','roi_chain']
assert read(build/'sim/regression_exit_code.txt').strip()=='0'
for name in tests:
    p=build/'sim/modelsim_work'/name
    assert 'PASS ' in read(p/'console.log') and not re.search(r'(?m)^#?\s*\*\* (Fatal|Error):',read(p/'console.log')+read(p/'compile.log')),name

runs=build/'td_project/camera_to_dsi_display_Runs'
phy=runs/'phy_1'
oldruns=prior/'td_project/camera_to_dsi_display_Runs'
warnings={}
for stage,last in [('syn_1','opt_gate'),('phy_1','bitgen')]:
    p=runs/stage
    assert read(p/'build_exit_code.txt').strip()=='0'
    assert (p/('.'+last+'.end.f')).exists() and not list(p.glob('.*.error.f'))
    assert not re.search(r'(?m)^\w+-\d+\s+(?:CRITICAL-)?ERROR:',read(p/'build_console.log'))
    def warning_set(path):
        return Counter(re.sub(r'(\.v)\(\d+\)',r'\1(LINE)',s) for s in read(path).splitlines() if re.match(r'^\w+-\d+ (?:CRITICAL-)?WARNING:',s))
    new=warning_set(p/'build_console.log')
    previous=warning_set(oldruns/stage/'build_console.log')
    assert new==previous,(stage,list((new-previous).elements()),list((previous-new).elements()))
    warnings[stage]=sum(new.values())
timing=read(phy/'camera_to_dsi_display_pr.timing')
assert 'Confidence          : Routed' in timing and 'Check Corner        : Both (Slow and Fast)' in timing
metrics={}
for key,label in [('setup_wns_ns','SWNS'),('setup_tns_ns','STNS'),('hold_wns_ns','HWNS'),('hold_tns_ns','HTNS')]:
    values=[float(v) for v in re.findall(label+r'\s*:\s*([-\d.]+)ns',timing)]
    assert values
    assert all(v>=0 for v in values),(key,values)
    if 'tns' in key:assert all(v==0 for v in values)
    metrics[key]=min(values)
assert all(int(v)==0 for v in re.findall(r'(\d+) Viol Endpoints',timing))
metrics['sta_coverage_percent']=float(re.search(r'STA coverage\s*:\s*([\d.]+)%',timing)[1])
area=read(phy/'camera_to_dsi_display_phy.area')
resources={}
for name in ['slice','eram','dsp']:
    m=re.search(r'^#'+name+r'\*?\s+(\d+)\s+out of\s+(\d+)\s+([\d.]+)%',area,re.M)
    resources[name]=dict(used=int(m[1]),total=int(m[2]),percent=float(m[3]))
def delays(path):
    return [(int(m[1]),int(m[2]),m[3]) for m in re.finditer(r'^\s*(\d+)\s+\d+\s+\d+\s+(\d+)\s+(set_max_delay .+)$',read(path).split('MCP/SMD Details')[0],re.M)]
newdelays=delays(phy/'camera_to_dsi_display_exception.timing')
olddelays=delays(oldruns/'phy_1/camera_to_dsi_display_exception.timing')
assert len(newdelays)==37 and all(total>0 and ignored==0 for total,ignored,_ in newdelays)
assert Counter(e[2] for e in newdelays)==Counter(e[2] for e in olddelays)
bit=phy/'camera_to_dsi_display.bit'
audit=dict(status='PASS_source_simulation_and_routed_build',onsite='PENDING',
    changed_production_inputs=changed,unchanged_production_inputs=209,
    unchanged_downstream_tracker_modules=True,original_failed_requirement_unchanged=True,
    unit_tests=list(unit_tests),boundary_cases=133,regression_tests=tests,
    timing=metrics,resources=resources,warnings=warnings,
    max_delays_matched=37,max_delays_ignored=0,sdc_unchanged=True,
    bit=dict(bytes=bit.stat().st_size,sha256=sha(bit)))
dump(build/'audit.json',audit)
assert not release.exists() and not (record/'manifest.json').exists()
assert subprocess.check_output(['git','branch','--show-current'],cwd=root,text=True).strip()=='lj4747-contest-work'
head=subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip()
assert head=='3be3967f2457622566fb20b7cef3aa5038e7d885'
assert not subprocess.check_output(['git','diff','--cached','--name-only'],cwd=root,text=True).strip()
release.mkdir()
shutil.copy2(bit,release/bit.name)
shutil.copy2(build/'inputs.json',release/'build_inputs.json')
shutil.copy2(build/'audit.json',release/'audit.json')
(release/'SHA256.txt').write_text(sha(bit)+'  '+bit.name+'\n',encoding='ascii')
identity=f"{bit.stat().st_size}字节，SHA-256 `{sha(bit)}`"
stats=f"Routed慢/快角setup+{metrics['setup_wns_ns']:.3f}ns、hold+{metrics['hold_wns_ns']:.3f}ns，TNS0；Slice{resources['slice']['used']}/{resources['slice']['total']}={resources['slice']['percent']:.2f}%，ERAM{resources['eram']['used']}、DSP{resources['dsp']['used']}；STA覆盖{metrics['sta_coverage_percent']:.2f}%"
description='每侧允许最多8像素（两个4像素采样点）的101～119灰度过渡，亮区≥120、暗区≤100；孔宽只计亮区。保持20～64孔宽、两侧连续8像素暗边、96±24孔距、三行和帧/运动/分类门控，默认R100/B100 /64。'
(release/'README.md').write_text(f'# 定位孔有限灰度过渡修复 v1\n\n{identity}。基于R100/B100 D3，只改hole_scanline。{description}\n\n133项新边界要求、原失败两帧获取锁定要求及9项相关回归均新跑PASS；{stats}。37条max_delay匹配/ignored0，SDC及综合/物理告警内容与WB100相同。\n\n未上板、未提交、未推送。现场NO HOLE根因仍未完全确认；此镜像修复仿真已证明的边界过渡限制。旧镜像/失败证据保留。\n',encoding='utf-8')
guide=root/'开发实施/44_B定位孔灰度过渡修复_上板说明.md'
assert not guide.exists()
guide.write_text(f'''# 定位孔有限灰度过渡修复 v1

2026-10-12，按用户确认实施42方案。镜像：[camera_to_dsi_display.bit](../{(release/bit.name).relative_to(root).as_posix()})。{identity}。

本轮未更改HDMI版本文字，仍显示PFB W1C200；请以这个新release目录和SHA确认下载文件，单看PFB字样不能区分新旧镜像。

{description} 曝光默认2244、增益48；本轮不修改灰度/边缘分类算法和试用门限，不增加自动定位或调试统计。

下载后复位，保持同一照明/机位/倍率，把定位孔放到三条扫描线Y372/380/388附近；黄色参考X464附近的孔及至少一个符合孔距的相邻孔应同时可见。先静止观察，合格孔连续两帧后应出现 `ROW 7` 与 `TRACK LOCK`，青框跟随动态ROI。三条扫描线是固定搜索范围；手动横移范围/速度仍有原有约束。

锁定且整帧有效时，RAW/GRAY应恢复MEAN/MIN/MAX及现有灰度判定；EDGE使用现有边缘判定，GRAY+EDGE保持双特征一致性要求。结果仍需有件/空穴实物真值确认。未锁定或其他帧门控失败时保持待检测，不能把失孔当空穴。

建议先静止确认ROW7/LOCK，再慢左/慢右、暂停、遮孔/恢复，最后以同一位置的有件和真正空穴验证。若仍 `NO HOLE/ROW0`，本修复不能排除孔亮度不足120、带暗边高于100、孔宽/孔距/参考位置超界或三行形状不合格；后续应采实际扫描灰度和几何，不能只凭照片继续猜阈值。

本次133项新边界测试和原模糊孔两帧获取锁定测试PASS。9项相关回归新跑PASS：{', '.join(tests)}，包含真实ISP、6400像素统计、正反受限位移、失孔/恢复、帧元数据和写入取消。{stats}。37条max_delay全部匹配/ignored0，SDC及{warnings['syn_1']}/{warnings['phy_1']}条综合/物理告警内容与WB100相同。冻结210生产输入仅tracker变化，后续tracker子模块及其余209输入逐字节一致。

现场未验收；未执行JTAG/Flash、提交或推送。旧黑屏恢复根因与TAIL0遗漏记录继续保留。
''',encoding='utf-8')
p=record.with_suffix('.md')
s=read(p)
s=s.replace('验证/构建进行中，尚未发布新镜像。',f"软件验证/构建完成，已发布`{(release/bit.name).relative_to(root).as_posix()}`，{identity}。")
s+=f"\n9项相关回归PASS：{', '.join(tests)}；{stats}。37条max_delay匹配/ignored0，SDC与WB100逐字节一致，{warnings['syn_1']}/{warnings['phy_1']}条综合/物理告警内容相同。210生产输入冻结前后逐项散列一致，仅tracker变化；第一endmodule后全部字节与WB100相同，保持默认R100/B100和原定位/分类门控。\n\n现场定位、分类、运动及显示验收待人工完成；未执行JTAG/Flash、提交或推送。\n"
p.write_text(s,encoding='utf-8')
shutil.copy2(project/'td_project/current_codex_build.json',record/'current_build_before.json')
metadata=dict(purpose='bounded_hole_gray_transition_fix_v1_default_R100_B100',td_version='6.2.168116',base_head=head,source_commit=None,
    source_snapshot=(record.relative_to(root)/'source_snapshot').as_posix(),simulation_root=build.relative_to(root).as_posix(),
    release=dict(path=(release/bit.name).relative_to(root).as_posix(),**audit['bit']),
    validation_record=record.with_suffix('.md').relative_to(root).as_posix(),fresh_tests=list(unit_tests)+tests,onsite='PENDING')
dump(project/'td_project/current_codex_build.json',metadata)
def copy(src,rel):
    dst=record/rel
    assert not dst.exists(),rel
    dst.parent.mkdir(parents=True,exist_ok=True)
    shutil.copy2(src,dst)
for e in inputs:copy(build/e['path'],Path('source_snapshot')/e['path'])
for name in ['inputs.json','simulation_inputs.json','stage_inputs.json','unit_inputs.json','audit.json']:copy(build/name,name)
for stage in ['syn_1','phy_1']:
    for f in (runs/stage).iterdir():
        if f.is_file() and f.suffix.lower() in {'.log','.logw','.rpt','.txt','.status','.qor','.area','.tcl','.prj','.cfg','.timing','.bit','.f'}:
            copy(f,Path('td_reports')/stage/f.name)
for e in load(build/'simulation_inputs.json'):
    copy(build/e['path'],Path('simulation/source')/Path(e['path']).relative_to('sim'))
for name in tests:
    for filename in ['console.log','compile.log','transcript.log']:
        copy(build/'sim/modelsim_work'/name/filename,Path('simulation/results')/name/filename)
for name in ['regression_console.log','regression_exit_code.txt']:copy(build/'sim'/name,Path('simulation')/name)
for p in (build/'hole_unit').rglob('*'):
    if p.is_file() and (p.suffix in {'.v','.ps1','.json','.log','.csv','.txt'}):
        copy(p,Path('hole_unit')/p.relative_to(build/'hole_unit'))
for name in ['prepare_hole_transition_20261012.py','implement_hole_transition_20261012.py','freeze_hole_transition_20261012.py','run_hole_transition_build_20261012.ps1','run_hole_transition_regression_20261012.ps1','audit_hole_transition_build_20261012.py','finish_hole_transition_20261012.py']:
    copy(root/'tmp'/name,Path('build_scripts')/name)
copy(guide,Path('documents')/guide.name)
copy(project/'td_project/current_codex_build.json','current_build_after.json')
manifest=[dict(path=p.relative_to(record).as_posix(),bytes=p.stat().st_size,sha256=sha(p)) for p in record.rglob('*') if p.is_file()]
dump(record/'manifest.json',manifest)
for e in manifest:assert sha(record/e['path'])==e['sha256']
assert sha(release/bit.name)==sha(bit)
print(json.dumps(dict(release=str(release/bit.name),**audit),ensure_ascii=False))
