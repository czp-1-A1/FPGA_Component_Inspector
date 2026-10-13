from pathlib import Path
import hashlib,json,subprocess
root=Path(__file__).resolve().parent.parent
record=root/'开发实施/验收记录/20261008_A灰度边缘独立判定_轮次1'
project=root/'fpga/component_inspector'
release=project/'release/presence_modes_v3_20261008'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
load=lambda p:json.loads(p.read_text(encoding='utf-8-sig'))
data=load(record/'manifest.json')
for e in data['copies']:
 p=record/e['path'];assert p.stat().st_size==e['bytes'] and sha(p)==e['sha256'],p
inputs=load(record/'inputs.json')
for e in inputs:
 assert sha(record/'source_snapshot'/e['path'])==e['sha256']==sha(project/e['path']),e['path']
assert (release/'build_inputs.json').read_bytes()==(record/'inputs.json').read_bytes()
assert sha(release/'camera_to_dsi_display.bit')==data['bit']['sha256']
assert (release/'camera_to_dsi_display.bit').stat().st_size==data['bit']['bytes']
assert (release/'SHA256.txt').read_text(encoding='ascii').split()[0]==data['bit']['sha256']
metadata=load(project/'td_project/current_codex_build.json')
assert metadata['release']==data['bit'] and metadata['source_commit'] is None
assert (project/'td_project/current_codex_build.json').read_bytes()==(record/'current_codex_build.json').read_bytes()
assert (root/'AGENTS.md').read_bytes()==(record/'AGENTS_checkpoint.md').read_bytes()
assert (root/'开发实施/32_A灰度与边缘独立判定_第三版说明.md').read_bytes()==(record/'实施说明.md').read_bytes()
assert record.with_suffix('.md').read_bytes()==(record/'验收记录.md').read_bytes()
release_data=load(release/'manifest.json')
assert release_data=={k:v for k,v in data.items() if k!='copies'}
old={}
for name in ['20261007_A3528临时判定_轮次1','20261008_A3528调参判定_轮次1','20261008_A3528调参判定_轮次2','20261008_A均值误判与边缘判定核查_轮次1']:
 folder=root/'开发实施/验收记录'/name;d=load(folder/'manifest.json')
 entries=d['files'] if d.get('kind')=='photo_and_source_diagnosis_only' else d['copies']
 for e in entries:
  p=folder/e['path'];assert p.stat().st_size==e['bytes'] and sha(p)==e['sha256'],p
 old[name]=len(entries)
assert sha(root/data['rollback']['path'])==data['rollback']['sha256']
head=subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip()
assert head==data['base_head']
assert not subprocess.check_output(['git','diff','--cached','--name-only'],cwd=root,text=True).strip()
check=subprocess.run(['git','-c','core.whitespace=cr-at-eol','diff','--check'],cwd=root,text=True,capture_output=True)
assert check.returncode==0,check.stdout+check.stderr
process=subprocess.run(['powershell','-NoProfile','-Command',"Get-Process td,bw,hwserver,td_commands_prompt,vsim,vlog -ErrorAction SilentlyContinue | Select-Object ProcessName,Id | ConvertTo-Json -Compress"],text=True,capture_output=True)
processes=json.loads(process.stdout.strip()) if process.stdout.strip() else []
if isinstance(processes,dict):processes=[processes]
assert not [p for p in processes if p['ProcessName'] in ['td_commands_prompt','vsim','vlog']],processes
result={'status':'PASS','frozen_main_copies':len(data['copies']),'production_inputs':len(inputs),'previous_evidence_copies':old,'release_sha256':data['bit']['sha256'],'head_unchanged':head,'staging_empty':True,'diff_check_passed':True,'metadata_docs_checkpoint_match':True,'rollback_unchanged':True,'no_assistant_td_or_modelsim_running':True,'process_snapshot_user_tools_untouched':processes,'board_validation':'not_performed'}
(record/'verification.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps(result,ensure_ascii=True))
