from pathlib import Path
import hashlib, json, shutil, subprocess
root=Path(__file__).resolve().parent.parent
project=root/'fpga/component_inspector'
record=root/'开发实施/验收记录/20261007_A3528临时判定_轮次1'
release=project/'release/led_presence_demo_v1_20261007'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
load=lambda p:json.loads(p.read_text(encoding='utf-8-sig'))
dump=lambda p,d:p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
historical_path='开发实施/验收记录/20261005_80x80单穴反馈_轮次1/manifest.json'
(record/'threshold_source/historical_manifest.json').write_bytes(subprocess.check_output(['git','show','HEAD:'+historical_path],cwd=root))
reports=record/'td_reports/phy_1'
review={'reviewer':'read-only led_history_review agent','status':'current_constrained_paths_meet_timing_no_new_unmatched_or_ignored_budget_found','metrics_confirmed':True,'max_delay_rules':31,'mailbox_register_rules':24,'payload_rules':8,'all_matched':True,'all_ignored_zero':True,'existing_equal_budget_shadowed_rules':['monitor_display req/ack covered by observation_display 19ns','roi_display req/ack covered by overflow_display 19ns/8ns'],'old_local_diagnostic_comparison':'Same TD6.2.168116, coverage summary dummy4/shadowed9/PLL7/no_input_delay39/no_output_delay63/partial_input_delay1 matches. Normalized 808 synthesis warnings and physical warning lines match; not a strict same-source incremental baseline.','dummy_difference':'AWB divider dangling G/R ofa changed to G/B ofb; physical significance remains unresolved.','classifier_in_final_area':'1 LUT, 2 registers','limits':['No classifier-specific per-path report; default endpoint report does not list it.','Different-tool teammate baseline does not establish pure tool causation.','No complete constraint closure or board classification acceptance.'],'report_hashes':[{'path':x,'sha256':sha(reports/x)} for x in ['camera_to_dsi_display_pr.timing','camera_to_dsi_display_phy.area','camera_to_dsi_display_exception.timing','constraint_coverage.txt']]}
dump(record/'independent_review.json',review)
md=record.with_suffix('.md')
s=md.read_text(encoding='utf-8').replace('属于不同工具/优化报告，不能冒称新类比导致回退','涉及不同工具及源码，不能作相同源码的严格增量，也不能仅归因工具')
md.write_text(s,encoding='utf-8')
agents=root/'AGENTS.md'
s=agents.read_text(encoding='utf-8').replace('最终SHA/JSON/diff检查及独立复核写verification.json/independent_review.json后交付。','最终364主证据、207输入、镜像/JSON/diff检查及独立复核已完成，见verification.json/independent_review.json；新bit尚未实物试用。')
agents.write_text(s,encoding='utf-8')
(record/'AGENTS_checkpoint.md').write_bytes(agents.read_bytes())
for name in ['finish_led_presence_v1_docs_20261007.py','verify_led_presence_v1_20261007.py']:
    shutil.copy2(root/'tmp'/name,record/'build_scripts'/name)
data=load(record/'manifest.json')
for x in data['copies']:
    p=record/x['path']
    assert p.stat().st_size==x['bytes'] and sha(p)==x['sha256'],x['path']
inputs=load(release/'build_inputs.json')
for x in inputs:
    assert sha(project/x['path'])==sha(record/'source_snapshot'/x['path'])==x['sha256']
bit=release/'camera_to_dsi_display.bit'
assert sha(bit)==data['bit']['sha256'] and bit.stat().st_size==data['bit']['bytes']
assert sha(project/'release/edge_tail_fix_20261007/camera_to_dsi_display.bit')==data['rollback']['sha256']
assert load(release/'manifest.json')['bit']==data['bit']
assert (release/'SHA256.txt').read_text().split()[0]==sha(bit)
assert subprocess.check_output(['git','diff','--cached','--name-only'],cwd=root).strip()==b''
subprocess.run(['git','-c','core.whitespace=cr-at-eol','diff','--check'],cwd=root,check=True)
supplemental=['README.zh-CN.md','AGENTS_checkpoint.md','independent_review.json','threshold_source/historical_manifest.json','build_scripts/finish_led_presence_v1_docs_20261007.py','build_scripts/verify_led_presence_v1_20261007.py']
verified={'status':'PASS','main_evidence_files_verified':len(data['copies']),'build_inputs_verified':len(inputs),'old_stable_bit_unchanged':True,'release_bit_sha256':sha(bit),'supplemental_files':[{'path':x,'bytes':(record/x).stat().st_size,'sha256':sha(record/x)} for x in supplemental],'final_documents':[{'path':p.relative_to(root).as_posix(),'sha256':sha(p)} for p in [agents,md,root/'开发实施/28_A临时固定条件有件空穴演示_准备协议.md',root/'开发实施/29_A3528_LED临时有件空穴_实施说明.md',release/'README.zh-CN.md']],'commit_status':'uncommitted_unpushed','physical_status':'not_flashed_not_board_tested'}
dump(record/'verification.json',verified)
print(json.dumps({k:v for k,v in verified.items() if k not in ['supplemental_files','final_documents']},ensure_ascii=True))
