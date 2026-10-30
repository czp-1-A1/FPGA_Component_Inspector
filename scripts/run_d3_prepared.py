"""Run PHY for an already prepared exact-synthesis D3 candidate."""
from pathlib import Path
import argparse,hashlib,json,os,re,subprocess,time
a=argparse.ArgumentParser();a.add_argument('--work',type=Path,required=True);x=a.parse_args()
w=x.work.resolve();sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
manifest=json.loads((w/'frozen_inputs.json').read_text());reuse=json.loads((w/'EXACT_SYNTHESIS_REUSE.json').read_text())
old=Path(reuse['source_work']);assert reuse['source_files_identical']==len(manifest)==704
assert json.loads((old/'frozen_inputs.json').read_text())==manifest
for rel,d in manifest.items():assert sha(w/'project'/rel)==sha(old/'project'/rel)==d,rel
assert sha(w/'runs/syn_1/camera_to_dsi_display_gate.db')==sha(old/'runs/syn_1/camera_to_dsi_display_gate.db')==reuse['synthesis_database_sha256']
for rel,d in json.loads((w/'hardware_inputs.json').read_text()).items():assert sha(w/'project'/rel)==d,rel
run=w/'runs/phy_1';assert not (run/'console.log').exists() and not (w/'build_result.json').exists()
(w/'temp').mkdir();env=dict(os.environ);env['TEMP']=env['TMP']=str(w/'temp');start=time.monotonic()
with (run/'console.log').open('w') as log:
 p=subprocess.run(['E:/TD/bin/td_commands_prompt.exe'],input='source {build.tcl}\n',text=True,cwd=run,env=env,stdout=log,stderr=subprocess.STDOUT,timeout=7200)
log=(run/'console.log').read_text(errors='replace')
assert p.returncode==0 and not re.search(r'(?mi)^\s*(?:ERROR|\w+-\d+\s*:\s*Error)',log)
bit=run/'camera_to_dsi_display.bit';assert bit.is_file()
for rel,d in manifest.items():assert sha(w/'project'/rel)==d,rel
seed=json.loads((w/'PHYSICAL_STRATEGY.json').read_text())['seed'] if (w/'PHYSICAL_STRATEGY.json').is_file() else reuse['new_physical_seed']
result={'status':'BUILT_NEEDS_RESOURCE_TIMING_AND_IO_AUDIT','bit':str(bit),'bit_sha256':sha(bit),'sources':704,'seed':seed,
 'stages':[{'stage':'syn_1','mode':'EXACT_DATABASE_REUSE','source_build':str(old),'database_sha256':reuse['synthesis_database_sha256']},
 {'stage':'phy_1','seconds':round(time.monotonic()-start,1),'console_sha256':sha(run/'console.log')}],'board_operated':False}
(w/'build_result.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result),flush=True)
