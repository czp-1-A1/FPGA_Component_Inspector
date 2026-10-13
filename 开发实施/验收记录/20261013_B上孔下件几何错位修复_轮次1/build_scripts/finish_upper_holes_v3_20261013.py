from pathlib import Path
import hashlib,json,re,shutil,subprocess
root=Path(__file__).resolve().parent.parent;project=root/'fpga/component_inspector'
build=root/'tmp/upper_holes_v3_r2_20261013';integration=root/'tmp/upper_holes_v3_r3_20261013'
record=root/'开发实施/验收记录/20261013_B上孔下件几何错位修复_轮次1'
release=project/'release/upper_hole_geometry_v3_20261013'
read=lambda p:p.read_text(encoding='utf-8-sig',errors='replace')
load=lambda p:json.loads(read(p));sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
def dump(path,data):path.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
inputs=load(build/'inputs.json');audit=load(build/'build_audit.json')
assert len(inputs)==211 and audit['status']=='PASS_routed_build_software_tests_pending'
assert not release.exists() and not record.exists()
for e in inputs:assert sha(build/e['path'])==e['sha256']==sha(project/e['path'])==sha(integration/e['path']),e['path']
for fixture in [build,integration]:
 for name in ['inputs.json','simulation_inputs.json','stage_inputs.json']:
  for e in load(fixture/name):assert sha(fixture/e['path'])==e['sha256'],(fixture,e['path'])
tests={name:build for name in ['geometry_polarity','rectangular_anchors','multi_pockets','multi_osd']}
tests.update({name:integration for name in ['multi_first_invalid','video_fallback_display','multi_video','video_metadata_fallback','writer_epoch','multi_writer','tracking_osd']})
accepted=[]
for name,fixture in tests.items():
 logs=fixture/'sim/modelsim_work'/name;console=read(logs/'console.log');compile_log=read(logs/'compile.log')
 assert 'PASS ' in console and not re.search(r'(?m)^#?\s*\*\* (Fatal|Error):',console+compile_log),name
 assert sha(fixture/'sim'/('tb_'+name+'.v'))==sha(build/'sim'/('tb_'+name+'.v')),name
 assert [e['sha256'] for e in load(fixture/'inputs.json')]==[e['sha256'] for e in inputs],name
 accepted.append(dict(test=name,root=fixture.relative_to(root).as_posix(),passes=[l.strip('# ') for l in console.splitlines() if 'PASS ' in l]))
assert len(accepted)==11
assert 'PASS ModelSim: all 4 tests' in read(build/'sim/unit_runner.log')
assert 'PASS ModelSim: all 7 tests' in read(integration/'sim/integration_runner.log')
assert not audit['warning_deltas']['syn_1']['added'] and not audit['warning_deltas']['phy_1']['added']
assert audit['max_delays_matched']==37 and audit['max_delays_ignored']==0
assert audit['resources']['slice']['percent']<=75
head=subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip()
assert not subprocess.check_output(['git','diff','--cached','--name-only'],cwd=root,text=True).strip()
audit.update(status='PASS_source_simulation_and_routed_build',onsite='PENDING',tests=accepted,
 reproduced_defect='V2 upper-sprocket/lower-part counterexample: 4 valid PRESENT boxes on sprocket row, mean72',
 source_head_at_freeze=head,source_commit=None,
 resource_review='74.57% within existing reviewed70-75% experiment band; +104 Slice vs V2, no new ERAM/DSP; optimize before expansion')
dump(build/'audit.json',audit)
bit=build/'td_project/camera_to_dsi_display_Runs/phy_1/camera_to_dsi_display.bit';assert sha(bit)==audit['bit']['sha256']
release.mkdir();shutil.copy2(bit,release/bit.name);shutil.copy2(build/'inputs.json',release/'build_inputs.json');shutil.copy2(build/'audit.json',release/'audit.json')
(release/'SHA256.txt').write_text(sha(bit)+'  '+bit.name+'\n',encoding='ascii')
(release/'README.md').write_text(f'''# 3528 上孔下件定位修复实验 V3

camera_to_dsi_display.bit：{audit['bit']['bytes']}字节，SHA-256 `{sha(bit)}`。
顶部 **AUTO4 EXP V3 / D4**；默认曝光2244、增益48、R100/B100。

固定圆形送料定位孔在上、器件穴位在下。孔搜索Y[168,336)/X[128,896)，孔→穴(-32,+80)，80×80；弦宽局部峰拒绝恒宽亮矩形并细化孔行中心，Sobel Y1扩464。首槽无效时帧参数标签仍完整，其余有效槽可显示。偏移仍为试验估计，尚需现场原生坐标确认。

分类保留原MEAN58及EC96/48、GS32768/16384规则，联合模式要求一致；定位孔不作为器件空穴样本。保留V2完整视频与检测结果隔离、错epoch清零、短/坏/未写完帧拒绝。

11项冻结测试PASS：旧误圈孔反例修复、上方矩形锚点拒绝、358项多穴/全空穴/四视图/移动恢复、首槽无效隔离、384精确RGB像素、614400请求完整竞争读出、632064 OSD像素、实际ISP/full writer/短帧及8种近FS相位恢复。Slice15821/21216=74.57%，ERAM48/108、DSP8/40；Routed慢快角建立+0.133ns、保持+0.020ns、TNS0，STA92.79%。原37条max_delay均匹配、ignored0，SDC不变；综合125/物理10告警无增量。

上板说明：开发实施/48_B3528上孔下件定位修复_V3上板说明.md。请先用GRAY确认所有大框落在下方真正器件穴位，再用有件/真正空穴真值检查类别；位置仍偏先修几何，不用阈值掩盖错位。软件通过不代表现场准确率。V3未提交、推送、JTAG/Flash或烧板；旧V2保留。
''',encoding='utf-8')
record.mkdir()
def copy(src,rel):
 dst=record/rel;assert not dst.exists(),rel;dst.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(src,dst)
for e in inputs:copy(build/e['path'],Path('source_snapshot')/e['path'])
for name in ['inputs.json','build_audit.json','audit.json','simulation_inputs.json','stage_inputs.json']:copy(build/name,name)
for e in load(build/'simulation_inputs.json'):copy(build/e['path'],Path('simulation/source')/Path(e['path']).relative_to('sim'))
for name,fixture in tests.items():
 for fn in ['console.log','compile.log','transcript.log']:copy(fixture/'sim/modelsim_work'/name/fn,Path('simulation/results')/name/fn)
for stage in ['syn_1','phy_1']:
 for f in (build/'td_project/camera_to_dsi_display_Runs'/stage).iterdir():
  if f.is_file() and f.suffix.lower() in {'.log','.logw','.rpt','.txt','.status','.qor','.area','.tcl','.prj','.cfg','.timing','.bit','.f'}:copy(f,Path('td_reports')/stage/f.name)
for fixture,test in [('multi_geometry_repro_r1_20261013','geometry_polarity'),('upper_holes_v3_r1_20261013','multi_first_invalid')]:
 d=root/'tmp'/fixture
 for fn in ['console.log','compile.log']:copy(d/'sim/modelsim_work'/test/fn,Path('failed_tests')/fixture/test/fn)
 copy(d/'sim'/('tb_'+test+'.v'),Path('failed_tests')/fixture/('tb_'+test+'.v'))
 copy(d/'inputs.json',Path('failed_tests')/fixture/'inputs.json')
copy(root/'tmp/multi_geometry_repro_r1_20261013/user_source/hdl_source/multi_pocket_detector.v','failed_tests/v2_multi_pocket_detector.v')
for fn in ['freeze_multi_video_fix.py','prepare_geometry_repro_20261013.py','prepare_upper_hole_tests_20261013.py','audit_upper_holes_v3_20261013.py','finish_upper_holes_v3_20261013.py','run_upper_holes_v3_r2_20261013.ps1']:copy(root/'tmp'/fn,Path('build_scripts')/fn)
guide=root/'开发实施/48_B3528上孔下件定位修复_V3上板说明.md';copy(guide,Path('documents')/guide.name)
metadata=dict(purpose='3528_AUTO4_upper_hole_geometry_v3',td_version='6.2.168116',base_head=head,source_commit=None,
 source_snapshot=(record.relative_to(root)/'source_snapshot').as_posix(),build_root=build.relative_to(root).as_posix(),
 release=dict(path=(release/bit.name).relative_to(root).as_posix(),**audit['bit']),validation_record=record.with_suffix('.md').relative_to(root).as_posix(),fresh_tests=list(tests),onsite='PENDING')
dump(project/'td_project/current_codex_build.json',metadata);copy(project/'td_project/current_codex_build.json','current_build_after.json')
manifest=[dict(path=f.relative_to(record).as_posix(),bytes=f.stat().st_size,sha256=sha(f)) for f in record.rglob('*') if f.is_file()]
dump(record/'manifest.json',manifest)
for e in manifest:assert sha(record/e['path'])==e['sha256']
assert sha(release/bit.name)==sha(bit)
print(json.dumps(dict(release=str(release/bit.name),tests=len(accepted),manifest_files=len(manifest),bit=audit['bit'],resources=audit['resources'],timing=audit['timing'],head=head),ensure_ascii=False,indent=2))
