"""Use official place/route step boundaries to inspect placement before routing.

No changed seed, strategy, clock or constraint. Route consumes the exact saved
placement DB, not a second placement. No programming or hardware operations.
"""
from pathlib import Path
import argparse,csv,datetime,hashlib,io,json,os,re,subprocess,time

a=argparse.ArgumentParser();a.add_argument('--work',type=Path,required=True);a.add_argument('--stage',choices=['place','route'],required=True)
a.add_argument('--stage-timeout',type=int,help='Software watchdog seconds; default place=1800, route=7200. Does not change hardware timing.')
x=a.parse_args()
if x.stage_timeout is not None and not 60 <= x.stage_timeout <= 14400:a.error('--stage-timeout must be between 60 and 14400 seconds')
w=x.work.resolve();run=w/'runs/phy_1';sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
load=lambda p:json.loads(p.read_text())
manifest=load(w/'frozen_inputs.json')
if (w/'EXACT_SYNTHESIS_REUSE.json').is_file():
 reuse=load(w/'EXACT_SYNTHESIS_REUSE.json');assert reuse['source_files_identical']==705
 synthesis_mode='EXACT_DATABASE_REUSE'
else:
 syn=load(w/'synthesis_result.json')
 assert syn['status']=='SYNTHESIS_ONLY_NOT_ROUTED_NOT_DELIVERABLE' and syn['sources']==705
 assert syn['stages'][0]['console_sha256']==sha(w/'runs/syn_1/console.log')
 reuse={'synthesis_database_sha256':sha(w/'runs/syn_1/camera_to_dsi_display_gate.db'),'source_work':str(w)}
 synthesis_mode='ACTUAL_CANDIDATE_SYNTHESIS'
assert len(manifest)==705
software=load(Path('D:/FpgaWork/r59_field_20261102/R59_SOFTWARE_VERIFICATION.json'))
assert software['actual_tests'] in [29,30] and software['historical_pass_reused']==0
assert software['source_manifest_sha256']==sha(w/'frozen_inputs.json')
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
source {D:/AAA/FPGA.....YZW/doc/scripts/DefaultFlow.tcl}
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
if x.stage_timeout is not None:timeout=x.stage_timeout
state_file=w/('RUN_STATE_'+x.stage.upper()+'.json')
assert not log.exists() and not result_file.exists() and not state_file.exists()
cfg.write_bytes(active.encode());started=time.monotonic();(w/'temp').mkdir(exist_ok=True)
env=dict(os.environ);env['TEMP']=env['TMP']=str(w/'temp')
now=datetime.datetime.now().astimezone()
stage_receipt={'stage':x.stage,'synthesis_mode':synthesis_mode,'original_settings_sha256':hashlib.sha256(original.encode()).hexdigest(),'active_settings_sha256':sha(cfg),'official_flow_sha256':sha(Path('D:/AAA/FPGA.....YZW/doc/scripts/DefaultFlow.tcl')),'source_manifest_sha256':sha(w/'frozen_inputs.json'),'placement_database_before_sha256':sha(db) if db.exists() else None,'physical_stage_seed_strategy_clocks_constraints_changed':False,'board_operated':False,'timeout_seconds':timeout,'started_at':now.isoformat(),'deadline':(now+datetime.timedelta(seconds=timeout)).isoformat(),'runner_pid':os.getpid()}
(w/('STAGE_'+x.stage.upper()+'.json')).write_text(json.dumps(stage_receipt,indent=2)+'\n')
state={**stage_receipt,'status':'STARTING','resource_or_timing_acceptance':False}
def save_state(**updates):
 state.update(updates);pending=state_file.with_suffix('.tmp');pending.write_text(json.dumps(state,indent=2)+'\n');pending.replace(state_file)
save_state()
try:
 with log.open('w') as output:
  with subprocess.Popen(['D:/AAA/FPGA.....YZW/bin/td_commands_prompt.exe'],stdin=subprocess.PIPE,text=True,cwd=run,env=env,stdout=output,stderr=subprocess.STDOUT) as p:
   save_state(status='RUNNING',tool_pid=p.pid)
   try:p.communicate(input='source {'+script.name+'}\n',timeout=timeout)
   except subprocess.TimeoutExpired:
    p.kill();p.communicate();save_state(status='TIMED_OUT',returncode=p.returncode);raise
   save_state(status='TOOL_EXITED_NEEDS_VALIDATION',returncode=p.returncode)
except BaseException as error:
 save_state(status='TIMED_OUT' if isinstance(error,subprocess.TimeoutExpired) else 'RUNNER_FAILED',error_type=type(error).__name__,error=str(error))
 raise
finally:
 cfg.write_bytes(original.encode())
 save_state(settings_restored_sha256=sha(cfg),seconds=round(time.monotonic()-started,1),finished_at=datetime.datetime.now().astimezone().isoformat(),console_sha256=sha(log) if log.exists() else None)
text=log.read_text(errors='replace')
if p.returncode!=0 or re.search(r'(?mi)^\s*(?:ERROR|\w+-\d+\s*:\s*Error)',text):
 save_state(status='TOOL_FAILED');raise AssertionError(str(log))
for rel,d in manifest.items():assert sha(w/'project'/rel)==d,rel
result={**stage_receipt,'seconds':round(time.monotonic()-started,1),'console_sha256':sha(log),'resource_or_timing_acceptance':False}
if x.stage=='place':
 assert db.is_file()
 result.update(status='PLACED_ONLY_NOT_ROUTED_NOT_DELIVERABLE',placement_database_sha256=sha(db),area_sha256=sha(run/'placed_intermediate.area'),timing_sha256=sha(run/'camera_to_dsi_display_place.timing'))
else:
 bit=run/'camera_to_dsi_display.bit';assert bit.is_file() and sha(db)==stage_receipt['placement_database_before_sha256']
 result.update(status='BUILT_NEEDS_RESOURCE_TIMING_AND_IO_AUDIT',bit=str(bit),bit_sha256=sha(bit),sources=705,seed=re.search(r'place seed (\d+)',original)[1],stages=[{'stage':'syn_1','mode':synthesis_mode,'source_build':reuse['source_work']},{'stage':'phy_1','mode':'SAVED_PLACEMENT_THEN_ROUTE','placement_receipt_sha256':sha(w/'PLACEMENT_RESULT.json'),'seconds':round(time.monotonic()-started+placed['seconds'],1),'console_sha256':sha(log)}])
result_file.write_text(json.dumps(result,indent=2)+'\n');save_state(status=result['status']);print(json.dumps(result),flush=True)
