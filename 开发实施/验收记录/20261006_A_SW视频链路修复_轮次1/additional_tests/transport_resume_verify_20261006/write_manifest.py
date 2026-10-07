from pathlib import Path
import hashlib,json,re
import numpy as np
root=Path(__file__).resolve().parent
artifacts=[]
for pattern in ('*.v','*.py','*.ps1','*.md','*.json','*.console.log','*.compile.log','compile.log','*.hex','tested_rtl/*.v','initial_edge_to_four_modes/*'):
    for path in root.glob(pattern):
        if path.name=='manifest.json': continue
        rel=path.relative_to(root).as_posix()
        if any(item['path']==rel for item in artifacts): continue
        artifacts.append(dict(path=rel,bytes=path.stat().st_size,sha256=hashlib.sha256(path.read_bytes()).hexdigest()))
results={}
for name in ('mode_0','mode_1','mode_2','mode_3','faults','pre_sof_four_modes'):
    log=(root/f'{name}.console.log').read_text(errors='replace')
    results[name]={'pass_lines':[line for line in log.splitlines() if 'PASS:' in line], 'fatal_lines':[line for line in log.splitlines() if '** Fatal:' in line], 'error_lines':[line for line in log.splitlines() if '** Error:' in line], 'warning_lines':[line for line in log.splitlines() if '** Warning:' in line]}
    marker='PASS: PRE_SOF_FOUR_MODES' if name=='pre_sof_four_modes' else 'PASS: TRANSPORT_FAULTS' if name=='faults' else 'PASS: FULL_TRANSPORT'
    if sum(marker in line for line in results[name]['pass_lines'])!=1 or results[name]['fatal_lines'] or results[name]['error_lines']: raise SystemExit(f'{name} does not pass')
inputs=json.loads((root/'tested_inputs.json').read_text(encoding='utf-8-sig'))
after=[]
for item in inputs:
    current=hashlib.sha256((root.parent.parent/item['path']).read_bytes()).hexdigest()
    copied=hashlib.sha256((root/item['copy']).read_bytes()).hexdigest()
    if current!=item['sha256'] or copied!=item['sha256']: raise SystemExit(f"Source drift: {item['path']}")
    after.append(dict(item,sha256_after=current,sha256_snapshot=copied))
(root/'tested_inputs_after.json').write_text(json.dumps(after,indent=2)+'\n',encoding='utf-8')
after_path=root/'tested_inputs_after.json'
artifacts.append(dict(path=after_path.name,bytes=after_path.stat().st_size,sha256=hashlib.sha256(after_path.read_bytes()).hexdigest()))
manifest=dict(date='2026-10-06',model='ModelSim 2019.2',numpy=np.__version__,clocks_ns={'CSI':8.888,'DDR':15,'HDMI':19.23},tested_inputs=inputs,source_hashes_unchanged_after=True,runner_requires_exit_zero_and_explicit_marker=True,results=results,artifacts=sorted(artifacts,key=lambda i:i['path']))
(root/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('PASS',len(artifacts),'artifacts; 4 full modes, faults, 4 stale-preamble modes; source hashes unchanged')
