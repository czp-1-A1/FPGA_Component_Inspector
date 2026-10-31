"""Use official place/route step boundaries to inspect placement before routing.

No changed seed, strategy, clock or constraint. Route consumes the exact saved
placement DB, not a second placement. No programming or hardware operations.
"""
from pathlib import Path
import argparse,csv,hashlib,io,json,os,re,subprocess,time

a=argparse.ArgumentParser();a.add_argument('--work',type=Path,required=True);a.add_argument('--stage',choices=['place','route'],required=True);x=a.parse_args()
w=x.work.resolve();run=w/'runs/phy_1';sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
load=lambda p:json.loads(p.read_text())
manifest=load(w/'frozen_inputs.json');reuse=load(w/'EXACT_SYNTHESIS_REUSE.json')
assert len(manifest)==704 and reuse['source_files_identical']==704
for rel,d in manifest.items():assert sha(w/'project'/rel)==d,rel
for rel,d in load(w/'hardware_inputs.json').items():assert sha(w/'project'/rel)==d,rel
assert sha(w/'runs/syn_1/camera_to_dsi_display_gate.db')==reuse['synthesis_database_sha256']
tasks=subprocess.run(['tasklist','/fi','IMAGENAME eq td_commands_prompt.exe','/fo','csv'],capture_output=True,check=True).stdout.decode('utf8',errors='replace')
assert not any(row and row[0].lower()=='td_commands_prompt.exe' for row in csv.reader(io.StringIO(tasks))),'Another TD CLI job is active'
cfg=run/'settings.cfg';original=cfg.read_text()
assert 'set start_step opt_place\nset end_step bitgen' in original
db=run/'camera_to_dsi_display_place.db'
if x.stage=='place':
 assert not db.exists() and not (w/'PLACEMENT_RESULT.json').exists()
 active=original.replace('set end_step bitgen','set end_step opt_place',1)
 script=run/'place_build.tcl';script.write_text('''if {[catch {
source {E:/TD/doc/scripts/DefaultFlow.tcl}
check_timing -file placement_constraint_coverage.txt -verbose
report_timing_summary -file placement_diagnostic.timing
report_area -io_info -file placed_intermediate.area
} reason]} {puts stderr $reason; exit 1}
exit 0
''')
 log=run/'place_console.log';result_file=w/'PLACEMENT_RESULT.json';timeout=1800
else:
 placed=load(w/'PLACEMENT_RESULT.json')
 assert placed['status']=='PLACED_ONLY_NOT_ROUTED_NOT_DELIVERABLE'
 assert sha(db)==placed['placement_database_sha256'] and placed['source_manifest_sha256']==sha(w/'frozen_inputs.json')
 active=original.replace('set start_step opt_place','set start_step opt_route',1)
 script=run/'build.tcl';log=run/'console.log';result_file=w/'build_result.json';timeout=7200
assert not log.exists() and not result_file.exists()
cfg.write_bytes(active.encode());started=time.monotonic();(w/'temp').mkdir(exist_ok=True)
env=dict(os.environ);env['TEMP']=env['TMP']=str(w/'temp')
stage_receipt={'stage':x.stage,'original_settings_sha256':hashlib.sha256(original.encode()).hexdigest(),'active_settings_sha256':sha(cfg),'official_flow_sha256':sha(Path('E:/TD/doc/scripts/DefaultFlow.tcl')),'source_manifest_sha256':sha(w/'frozen_inputs.json'),'placement_database_before_sha256':sha(db) if db.exists() else None,'seed_strategy_clocks_constraints_changed':False,'board_operated':False}
(w/('STAGE_'+x.stage.upper()+'.json')).write_text(json.dumps(stage_receipt,indent=2)+'\n')
try:
 with log.open('w') as output:
  p=subprocess.run(['E:/TD/bin/td_commands_prompt.exe'],input='source {'+script.name+'}\n',text=True,cwd=run,env=env,stdout=output,stderr=subprocess.STDOUT,timeout=timeout)
finally:
 cfg.write_bytes(original.encode())
text=log.read_text(errors='replace')
assert p.returncode==0 and not re.search(r'(?mi)^\s*(?:ERROR|\w+-\d+\s*:\s*Error)',text),str(log)
for rel,d in manifest.items():assert sha(w/'project'/rel)==d,rel
result={**stage_receipt,'seconds':round(time.monotonic()-started,1),'console_sha256':sha(log),'resource_or_timing_acceptance':False}
if x.stage=='place':
 assert db.is_file()
 result.update(status='PLACED_ONLY_NOT_ROUTED_NOT_DELIVERABLE',placement_database_sha256=sha(db),area_sha256=sha(run/'placed_intermediate.area'),timing_sha256=sha(run/'camera_to_dsi_display_place.timing'))
else:
 bit=run/'camera_to_dsi_display.bit';assert bit.is_file() and sha(db)==stage_receipt['placement_database_before_sha256']
 result.update(status='BUILT_NEEDS_RESOURCE_TIMING_AND_IO_AUDIT',bit=str(bit),bit_sha256=sha(bit),sources=704,seed=re.search(r'place seed (\d+)',original)[1],stages=[{'stage':'syn_1','mode':'EXACT_DATABASE_REUSE','source_build':reuse['source_work']},{'stage':'phy_1','mode':'SAVED_PLACEMENT_THEN_ROUTE','placement_receipt_sha256':sha(w/'PLACEMENT_RESULT.json'),'seconds':round(time.monotonic()-started+placed['seconds'],1),'console_sha256':sha(log)}])
result_file.write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result),flush=True)
