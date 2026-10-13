from pathlib import Path
import hashlib,json,re,shutil,subprocess
root=Path(__file__).resolve().parent.parent;project=root/'fpga/component_inspector'
build=root/'tmp/multi_video_fix_r2_20261013';suite=root/'tmp/multi_video_fix_r5_20261013'
record=root/'开发实施/验收记录/20261013_BAUTO4黑屏元数据排查_轮次1'
release=project/'release/multi_pocket_video_fix_v2_20261013'
read=lambda p:p.read_text(encoding='utf-8-sig',errors='replace')
load=lambda p:json.loads(read(p));sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
def dump(path,data):path.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
inputs=load(build/'inputs.json');audit=load(build/'build_audit.json')
assert len(inputs)==211 and audit['status']=='PASS_routed_build_software_tests_pending'
assert not release.exists() and not record.exists()
for e in inputs:assert sha(build/e['path'])==e['sha256']==sha(project/e['path'])==sha(suite/e['path']),e['path']
for fixture in [build,suite,root/'tmp/multi_video_fix_r3_20261013',root/'tmp/multi_video_fix_r4_20261013']:
 for name in ['inputs.json','simulation_inputs.json','stage_inputs.json']:
  for e in load(fixture/name):assert sha(fixture/e['path'])==e['sha256'],(fixture,e['path'])
tests={name:'multi_video_fix_r4_20261013' for name in ['writer_epoch','video_metadata_fallback','publish_diag','frame_metadata','multi_metadata','multi_osd']}
tests.update({name:'multi_video_fix_r3_20261013' for name in ['video_fallback_display','multi_writer']})
tests.update({name:'multi_video_fix_r5_20261013' for name in ['tracking_osd','isp_metadata_stop','isp_writer_stop','wb_epoch','cdc']})
tests['multi_video']='multi_video_fix_r2_20261013'
accepted=[]
for name,fixture in tests.items():
 d=root/'tmp'/fixture;logs=d/'sim/modelsim_work'/name
 console=read(logs/'console.log');compile_log=read(logs/'compile.log')
 assert 'PASS ' in console and not re.search(r'(?m)^#?\s*\*\* (Fatal|Error):',console+compile_log),name
 assert sha(d/'sim'/('tb_'+name+'.v'))==sha(suite/'sim'/('tb_'+name+'.v')),name
 assert [e['sha256'] for e in load(d/'inputs.json')]==[e['sha256'] for e in inputs],name
 accepted.append(dict(test=name,root=d.relative_to(root).as_posix(),passes=[l.strip('# ') for l in console.splitlines() if 'PASS ' in l]))
assert len(accepted)==14
assert 'PASS ModelSim: all 6 tests' in read(root/'tmp/multi_video_fix_r4_20261013/sim/unit_runner.log')
assert 'PASS ModelSim: all 5 tests' in read(suite/'sim/regression_runner.log')
assert 'PASS ModelSim: all 1 tests' in read(build/'sim/integration_runner.log')
assert not audit['warning_deltas']['syn_1']['added'] and not audit['warning_deltas']['phy_1']['added']
assert audit['max_delays_matched']==37 and audit['max_delays_ignored']==0
assert audit['resources']['slice']['percent']<=75
head=subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip()
assert head=='3be3967f2457622566fb20b7cef3aa5038e7d885'
assert not subprocess.check_output(['git','diff','--cached','--name-only'],cwd=root,text=True).strip()
audit.update(status='PASS_source_simulation_and_routed_build',onsite='PENDING',tests=accepted,
 reproduced_defect='coalesced FS permanently offsets independent counters: source3/writer2/received3/ready1/seenP1B; fixed source-bound writer epoch',
 field_root_cause='CONSISTENT_WITH_REPRODUCED_DEFECT_NOT_PHYSICALLY_PROVEN',
 supplementary_epoch_path_query='INCONCLUSIVE_TD_TARGET_QUERY; full routed STA and all 37 original max-delay constraints passed',
 resource_review='74.08% within existing reviewed 70-75% experiment band; preserve four-pocket scope, optimize before expansion')
dump(build/'audit.json',audit)
bit=build/'td_project/camera_to_dsi_display_Runs/phy_1/camera_to_dsi_display.bit'
assert sha(bit)==audit['bit']['sha256']
release.mkdir();shutil.copy2(bit,release/bit.name);shutil.copy2(build/'inputs.json',release/'build_inputs.json');shutil.copy2(build/'audit.json',release/'audit.json')
(release/'SHA256.txt').write_text(sha(bit)+'  '+bit.name+'\n',encoding='ascii')
(release/'README.md').write_text(f'''# AUTO4 黑屏修复实验 v2

镜像：camera_to_dsi_display.bit，{audit['bit']['bytes']}字节。
SHA-256：`{sha(bit)}`。
顶部识别：**AUTO4 EXP V2 / D4**；默认曝光2244、增益48、R100/B100。

修复近FS合并后独立帧号永久漂移；写入端绑定源帧号。仅AUTO4将完整视频与可选结果解耦，缺失/错epoch的槽结果全零，晚到结果不补改已发布槽。坏/短/未写完帧仍拒绝，旧单穴严格元数据模式保留。孔搜索、几何和分类门限不改。

14项冻结仿真/回归PASS：含8种近FS相位/间隔、缺失/迟到/旧epoch/恢复、384像素准确读出、614400像素完整竞争读出、632064个OSD像素及实际ISP/短帧/停钟检查。Slice15717/21216=74.08%，ERAM48/108，DSP8/40；Routed慢快角建立+0.142ns、保持+0.020ns、TNS0，STA覆盖92.66%。原37条max_delay均匹配、ignored0，SDC不改；综合125/物理10告警与v1无差异。

W是DDR写入字数（正常W1C200）；缺结果时M依次显示ready、接收帧号低8位、写入帧号低8位。帧号比较仍为16位。缺结果时显示待检测/METADATA WAIT，视频继续。PFB不代表穴位分类已确认准确。

上板说明：开发实施/47_BAUTO4帧号漂移黑屏修复_v2上板说明.md。现场恢复与分类待人工复核；本轮未执行JTAG/Flash、提交或推送。
''',encoding='utf-8')
record.mkdir()
def copy(src,rel):
 dst=record/rel;assert not dst.exists(),rel;dst.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(src,dst)
for e in inputs:copy(build/e['path'],Path('source_snapshot')/e['path'])
for name in ['inputs.json','build_audit.json','audit.json']:copy(build/name,name)
for name in ['simulation_inputs.json','stage_inputs.json']:copy(suite/name,name)
for e in load(suite/'simulation_inputs.json'):copy(suite/e['path'],Path('simulation/source')/Path(e['path']).relative_to('sim'))
for name,fixture in tests.items():
 for fn in ['console.log','compile.log','transcript.log']:copy(root/'tmp'/fixture/'sim/modelsim_work'/name/fn,Path('simulation/results')/name/fn)
for stage in ['syn_1','phy_1']:
 for f in (build/'td_project/camera_to_dsi_display_Runs'/stage).iterdir():
  if f.is_file() and f.suffix.lower() in {'.log','.logw','.rpt','.txt','.status','.qor','.area','.tcl','.prj','.cfg','.timing','.bit','.f'}:copy(f,Path('td_reports')/stage/f.name)
for fixture,test in [('multi_black_check_r1_20261013','multi_video'),('multi_black_check_r2_20261013','multi_video'),('multi_epoch_repro_r1_20261013','writer_epoch'),('multi_video_fix_r3_20261013','tracking_osd')]:
 d=root/'tmp'/fixture
 for fn in ['console.log','compile.log']:
  f=d/'sim/modelsim_work'/test/fn
  if f.exists():copy(f,Path('failed_tests')/fixture/test/fn)
 copy(d/'sim'/('tb_'+test+'.v'),Path('failed_tests')/fixture/('tb_'+test+'.v'))
 copy(d/'inputs.json',Path('failed_tests')/fixture/'inputs.json')
copy(root/'tmp/multi_epoch_repro_r1_20261013/user_source/hdl_source/video_in.v','failed_tests/old_video_in.v')
copy(root/'tmp/multi_video_fix_r2_20261013/sim/regression_runner.log','failed_tests/r2_empty_selection.log')
copy(root/'tmp/multi_video_fix_r1_20261013/sim/runner.log','failed_tests/r1_argument_string.log')
for fn in ['freeze_multi_video_fix.py','prepare_multi_video_integration_20261013.py','audit_multi_video_fix_20261013.py','finish_multi_video_fix_20261013.py','run_multi_video_fix_r2_20261013.ps1']:
 copy(root/'tmp'/fn,Path('build_scripts')/fn)
guide=root/'开发实施/47_BAUTO4帧号漂移黑屏修复_v2上板说明.md';copy(guide,Path('documents')/guide.name)
metadata=dict(purpose='3528_AUTO4_video_metadata_blackfix_v2',td_version='6.2.168116',base_head=head,source_commit=None,
 source_snapshot=(record.relative_to(root)/'source_snapshot').as_posix(),build_root=build.relative_to(root).as_posix(),
 release=dict(path=(release/bit.name).relative_to(root).as_posix(),**audit['bit']),validation_record=record.with_suffix('.md').relative_to(root).as_posix(),
 fresh_tests=list(tests),onsite='PENDING')
dump(project/'td_project/current_codex_build.json',metadata);copy(project/'td_project/current_codex_build.json','current_build_after.json')
manifest=[dict(path=f.relative_to(record).as_posix(),bytes=f.stat().st_size,sha256=sha(f)) for f in record.rglob('*') if f.is_file()]
dump(record/'manifest.json',manifest)
for e in manifest:assert sha(record/e['path'])==e['sha256']
assert sha(release/bit.name)==sha(bit)
print(json.dumps(dict(release=str(release/bit.name),tests=len(accepted),manifest_files=len(manifest),bit=audit['bit'],resources=audit['resources'],timing=audit['timing']),ensure_ascii=False,indent=2))
