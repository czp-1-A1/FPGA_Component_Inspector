from pathlib import Path
import hashlib,json,re
import numpy as np
root=Path(__file__).resolve().parent
artifacts=[]
for pattern in ('*.v','*.py','*.ps1','*.md','*.json','*.console.log','*.compile.log','compile.log','*.hex','tested_rtl/*.v','initial_tb_wait_bug/*.log'):
    for path in root.glob(pattern):
        if path.name=='manifest.json': continue
        rel=path.relative_to(root).as_posix()
        if any(item['path']==rel for item in artifacts): continue
        artifacts.append(dict(path=rel,bytes=path.stat().st_size,sha256=hashlib.sha256(path.read_bytes()).hexdigest()))
results={}
for name in ('mode_0','mode_1','mode_2','mode_3','faults'):
    log=(root/f'{name}.console.log').read_text(errors='replace')
    results[name]={'pass_lines':[line for line in log.splitlines() if 'PASS:' in line], 'fatal_lines':[line for line in log.splitlines() if '** Fatal:' in line]}
    if len(results[name]['pass_lines'])!=1 or results[name]['fatal_lines']: raise SystemExit(f'{name} does not pass')
manifest=dict(date='2026-10-06',model='ModelSim 2019.2',numpy=np.__version__,clocks_ns={'CSI':8.888,'DDR':15,'HDMI':19.23},tested_inputs=json.loads((root/'tested_inputs.json').read_text(encoding='utf-8-sig')),results=results,artifacts=sorted(artifacts,key=lambda i:i['path']))
(root/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('PASS',len(artifacts),'artifacts; 4 full modes and faults; independent input hashes recorded')
