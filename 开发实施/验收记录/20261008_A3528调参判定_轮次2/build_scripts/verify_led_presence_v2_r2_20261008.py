from pathlib import Path
import hashlib,json,subprocess
root=Path(__file__).resolve().parent.parent
project=root/'fpga/component_inspector'
record=root/'开发实施/验收记录/20261008_A3528调参判定_轮次2'
release=project/'release/led_presence_demo_v2_r2_20261008'
load=lambda p:json.loads(p.read_text(encoding='utf-8-sig'))
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
dump=lambda p,d:p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
data=load(record/'manifest.json');inputs=load(release/'build_inputs.json')
for x in data['copies']:
    p=record/x['path'];assert sha(p)==x['sha256'] and p.stat().st_size==x['bytes'],x['path']
for x in inputs:
    assert sha(project/x['path'])==sha(record/'source_snapshot'/x['path'])==x['sha256'],x['path']
assert sha(release/'camera_to_dsi_display.bit')==data['bit']['sha256']
assert (release/'camera_to_dsi_display.bit').stat().st_size==data['bit']['bytes']
assert (release/'SHA256.txt').read_text().split()[0]==data['bit']['sha256']
assert load(release/'manifest.json')['bit']==data['bit']
assert load(project/'td_project/current_codex_build.json')['release']==data['bit']
assert len(data['register_max_delay_summary'])==24
assert load(record/'warning_gate.json')['new_calibration_port_width_warning_absent']
old_counts={}
for name in ['20261007_A3528临时判定_轮次1','20261008_A3528调参判定_轮次1']:
    old=root/'开发实施/验收记录'/name;manifest=load(old/'manifest.json')
    for x in manifest['copies']:
        p=old/x['path'];assert sha(p)==x['sha256'] and p.stat().st_size==x['bytes'],x['path']
    old_counts[name]=len(manifest['copies'])
for x in data['rollback']:
    assert sha(root/x['path'])==x['sha256']
assert subprocess.check_output(['git','diff','--cached','--name-only'],cwd=root).strip()==b''
subprocess.run(['git','-c','core.whitespace=cr-at-eol','diff','--check'],cwd=root,check=True)
assert subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip()==data['base_head']
process_command="Get-Process | Where-Object { $_.ProcessName -in @('td','bw','hwserver','td_commands_prompt','vsim','vlog') } | Select-Object ProcessName,Id | ConvertTo-Json -Compress"
process_text=subprocess.check_output(['powershell','-NoProfile','-Command',process_command],text=True,encoding='utf-8').strip()
processes=json.loads(process_text) if process_text else []
if isinstance(processes,dict):processes=[processes]
assert not any(x['ProcessName'] in ['td_commands_prompt','vsim','vlog'] for x in processes),'Assistant tool still running'
agents=root/'AGENTS.md';text=agents.read_text(encoding='utf-8')
assert 'VERIFY_PENDING' in text
agents.write_text(text.replace('最终校验待执行VERIFY_PENDING。',f"最终{len(data['copies'])}主证据、207输入、旧v1 364/R1 372证据、镜像/JSON/diff/暂存区及工具退出检查全部通过，见verification.json。"),encoding='utf-8')
(record/'AGENTS_checkpoint.md').write_bytes(agents.read_bytes())
main={x['path'] for x in data['copies']}|{'manifest.json','verification.json'}
supplemental=[{'path':p.relative_to(record).as_posix(),'bytes':p.stat().st_size,'sha256':sha(p)} for p in record.rglob('*') if p.is_file() and p.relative_to(record).as_posix() not in main]
documents=[agents,record.with_suffix('.md'),root/'开发实施/31_A3528调参后自动判定_第二版说明.md',release/'README.zh-CN.md']
verified={'status':'PASS','main_evidence_files_verified':len(data['copies']),'build_inputs_verified':len(inputs),'old_evidence_files_verified':old_counts,'old_bits_unchanged':True,'release_bit_sha256':data['bit']['sha256'],'canonical_mailbox_rules':24,'supplemental_files':supplemental,'final_documents':[{'path':p.relative_to(root).as_posix(),'sha256':sha(p)} for p in documents],'process_snapshot':processes,'commit_status':'uncommitted_unpushed_staging_empty','physical_status':'not_flashed_not_board_tested','simulation_scope':'R1 seven module regressions reused after compiled-source SHA identity; R2 actual top rebuilt and extracted bindings rerun.','verification_helper_repair':'Initial named Get-Process query returned exit1 because assistant process names were absent, despite SilentlyContinue. Enumerate all processes then filter names; still reject any td_commands_prompt/vsim/vlog left running. Prior helper preserved.'}
dump(record/'verification.json',verified)
print(json.dumps({k:v for k,v in verified.items() if k not in ['supplemental_files','final_documents']},ensure_ascii=True))
