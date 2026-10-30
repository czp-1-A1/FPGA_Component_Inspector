"""Synthesize one previously frozen D3 candidate without any hardware action."""
from pathlib import Path
import argparse,csv,hashlib,io,json,os,re,subprocess,time

a=argparse.ArgumentParser();a.add_argument('--work',type=Path,required=True);x=a.parse_args()
w=x.work.resolve();sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
source=json.loads((w/'frozen_inputs.json').read_text())
assert len(source)==704
for rel,d in source.items():assert sha(w/'project'/rel)==d,rel
for rel,d in json.loads((w/'hardware_inputs.json').read_text()).items():assert sha(w/'project'/rel)==d,rel
# Full TD jobs share this machine's limited RAM. Refuse to start a second one.
tasks=subprocess.run(['tasklist','/fi','IMAGENAME eq td_commands_prompt.exe','/fo','csv'],capture_output=True,check=True).stdout.decode('utf8',errors='replace')
assert not any(row and row[0].lower()=='td_commands_prompt.exe' for row in csv.reader(io.StringIO(tasks))),'Another TD job is active'
run=w/'runs/syn_1';assert not (run/'console.log').exists() and not (w/'synthesis_result.json').exists()
(w/'temp').mkdir();env=dict(os.environ);env['TEMP']=env['TMP']=str(w/'temp');started=time.monotonic()
with (run/'console.log').open('w') as log:
 p=subprocess.run(['E:/TD/bin/td_commands_prompt.exe'],input='source {build.tcl}\n',text=True,cwd=run,env=env,stdout=log,stderr=subprocess.STDOUT,timeout=1200)
text=(run/'console.log').read_text(errors='replace')
assert p.returncode==0 and not re.search(r'(?mi)^\s*(?:ERROR|\w+-\d+\s*:\s*Error)',text),str(run/'console.log')
assert (run/'camera_to_dsi_display_gate.db').is_file()
for rel,d in source.items():assert sha(w/'project'/rel)==d,rel
result={'status':'SYNTHESIS_ONLY_NOT_ROUTED_NOT_DELIVERABLE','sources':len(source),'board_operated':False,
 'source_manifest_sha256':sha(w/'frozen_inputs.json'),'stages':[{'stage':'syn_1','seconds':round(time.monotonic()-started,1),'console_sha256':sha(run/'console.log')}],
 'gate_database_sha256':sha(run/'camera_to_dsi_display_gate.db'),'gate_area_sha256':sha(run/'camera_to_dsi_display_gate.area')}
(w/'synthesis_result.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result),flush=True)
