from pathlib import Path
import hashlib,json,re

root=Path(__file__).resolve().parent
inputs=json.loads((root/'tested_inputs.json').read_text(encoding='utf-8-sig'))
for item in inputs:
    copy_hash=hashlib.sha256((root/item['copy']).read_bytes()).hexdigest()
    if copy_hash!=item['sha256']: raise SystemExit(f"Compiled snapshot drift: {item['path']}")
    item['sha256_current_engineering']=hashlib.sha256((root.parent.parent/item['path']).read_bytes()).hexdigest()
    item['engineering_unchanged']=item['sha256_current_engineering']==item['sha256']
cases=[]
for result_path in sorted(root.glob('*/result.json')):
    item=json.loads(result_path.read_text(encoding='utf-8-sig'))
    item['uses_real_mc_bridge']=item['case'].startswith('mc_')
    log=(result_path.parent/'console.log').read_text(errors='replace')
    if re.search(r'\*\* (Fatal|Error):',log): raise SystemExit(f"Simulator/checker failure: {item['case']}")
    marker=re.findall(r'^# (PASS|FAIL): SWITCH_TRANSPORT.*$',log,re.M)
    if len(marker)!=1 or marker[0]!=item['functional_status'] or item['exit_code']!=0: raise SystemExit(f"Invalid classification: {item['case']}")
    item['key_lines']=[line.rstrip() for line in log.splitlines() if re.search(r'CASE |SOURCE_PHASE|CAPTURE_RESULT|FIRST_CACHE_OVERRUN|FREEZE_REPRO|MC_PAUSE_START|MC_DIAGNOSTIC|(?:PASS|FAIL): SWITCH_TRANSPORT',line) and not line.startswith('# vsim')]
    item['warnings']=sum('** Warning:' in line for line in log.splitlines())
    cases.append(item)
artifacts=[]
for path in sorted(root.rglob('*')):
    if not path.is_file() or path.name=='manifest.json' or path.suffix not in ('.v','.py','.ps1','.md','.json','.log','.csv','.hex'): continue
    artifacts.append(dict(path=path.relative_to(root).as_posix(),bytes=path.stat().st_size,sha256=hashlib.sha256(path.read_bytes()).hexdigest()))
manifest=dict(date='2026-10-07',source_policy='Engineering read-only; compiled pinned snapshots; old evidence retained',clocks_ns={'CSI':8.888,'DDR':15,'DSI':19.23},active_awb_row_beats=256,realistic_minimum_line_gap=384,synthetic_frame_good=True,real_mc_bridge_and_command_fifo=True,default_camera_offset_dsi_cycles=4500,inputs=inputs,cases=cases,artifacts=artifacts,experimental_candidate_rtl_created=False)
(root/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(f"Recorded {len(cases)} cases: {sum(i['functional_status']=='PASS' for i in cases)} functional PASS, {sum(i['functional_status']=='FAIL' for i in cases)} functional FAIL; no simulator/checker Fatal or Error")
print('Pinned Sobel',inputs[0]['sha256'])
