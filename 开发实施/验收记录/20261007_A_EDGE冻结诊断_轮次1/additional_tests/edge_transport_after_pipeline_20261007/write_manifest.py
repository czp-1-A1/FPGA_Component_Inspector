from pathlib import Path
import hashlib,json,re

root=Path(__file__).resolve().parent
inputs=json.loads((root/'tested_inputs.json').read_text(encoding='utf-8-sig'))
for item in inputs:
    copied=hashlib.sha256((root/item['copy']).read_bytes()).hexdigest()
    current=hashlib.sha256((root.parent.parent/item['path']).read_bytes()).hexdigest()
    if copied!=item['sha256'] or current!=item['sha256']: raise SystemExit(f"Source drift: {item['path']}")
    item['sha256_after']=current
cases=[]
for path in sorted(root.glob('*/result.json')):
    item=json.loads(path.read_text(encoding='utf-8-sig'))
    log=(path.parent/'console.log').read_text(errors='replace')
    if re.search(r'\*\* (Fatal|Error):',log) or item['exit_code']!=0: raise SystemExit(f"Simulator/checker failure: {item['case']}")
    summary=re.findall(r'^# (?:PASS|FAIL): SWITCH_TRANSPORT.*$',log,re.M)
    if len(summary)!=1: raise SystemExit(f"Missing final classification: {item['case']}")
    pause=int(re.search(r'_pause_(\d+)$',item['case'])[1])
    if pause in (0,1000):
        if item['functional_status']!='PASS' or 'total_writes=345600 checked_pixels=1843200 errors=0 overflow=0 underflow=0 lost=0' not in summary[0]: raise SystemExit('Normal/finite pause did not pass exact transport checks')
        if 'accepted=691200 retired=691200 mc_writes=345600 mc_reads=345600' not in log: raise SystemExit('Real MC command proof incomplete')
        item['expected_result']='EXACT_TRANSPORT_PASS'
    elif pause==2000:
        if item['functional_status']!='FAIL' or 'second_capture=0 recovery_capture=1 view_errors=0 pack_errors=0 write_errors=0 address_errors=0 pixel_errors=0 overflow=0 underflow=0 lost=1' not in summary[0]: raise SystemExit('Unbounded pause did not reject and recover safely')
        if 'latest_slot_retained=3' not in log or 'bad=1 camera_bad=1' not in log or 'CAPTURE_RESULT PASS mode=0 id=1 gap=384 completed_slot=2 candidate_slot=2 pixels=614400 words=115200 written=115200' not in log: raise SystemExit('Rejected slot/recovery proof incomplete')
        item['expected_result']='SAFE_REJECTION_AND_FULL_RECOVERY_PASS'
    else: raise SystemExit(f'Unexpected scenario {pause}')
    item['expectation_passed']=True
    item['key_lines']=[line.rstrip() for line in log.splitlines() if re.search(r'CASE |TIMING_STATS|CAPTURE_RESULT|FIRST_CACHE_OVERRUN|FREEZE_REPRO|MC_PAUSE_START|MC_DIAGNOSTIC|(?:PASS|FAIL): SWITCH_TRANSPORT',line) and not line.startswith('# vsim')]
    cases.append(item)
if len(cases)!=4: raise SystemExit('Expected exactly 4 representative scenarios')
artifacts=[]
for path in sorted(root.rglob('*')):
    if not path.is_file() or path.name=='manifest.json' or path.suffix not in ('.v','.py','.ps1','.md','.json','.log','.csv','.hex'): continue
    artifacts.append(dict(path=path.relative_to(root).as_posix(),bytes=path.stat().st_size,sha256=hashlib.sha256(path.read_bytes()).hexdigest()))
manifest=dict(date='2026-10-07',new_sobel_snapshot_sha256=inputs[0]['sha256'],sources_unchanged_after=True,real_mc_bridge_and_command_fifo=True,all_input_rows_gap=384,clocks_ns={'CSI':8.888,'DDR':15,'DSI':19.23},source_offset_dsi_cycles=4500,input_contract='Synthetic AWB RGB/first-pixel SOF; frame_good generated on final input row',independent_rgb_and_sobel_references=True,all_expectations_passed=True,compiled_tb_snapshot='compiled_tb_edge_freeze_mc.v',current_tb_difference='Only corrected inherited recovery-gap comment after successful simulation',inputs=inputs,cases=cases,artifacts=artifacts)
(root/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('PASS: 4 current-source scenarios; 3 exact transport PASS and 1 expected safe rejection/recovery; all 9 source hashes unchanged')
print('Sobel SHA256',inputs[0]['sha256'])
