"""Run another physical seed from byte-identical immutable synthesized inputs."""
from pathlib import Path
import argparse,hashlib,json,os,shutil,subprocess,time
r=Path(__file__).resolve().parents[1]
a=argparse.ArgumentParser();a.add_argument('--from-work',type=Path,required=True);a.add_argument('--work',type=Path,required=True);a.add_argument('--seed',type=int,required=True);a.add_argument('--physical-strategy',default='Default');a.add_argument('--prepare-only',action='store_true');x=a.parse_args()
old=x.from_work.resolve();w=x.work.resolve();manifest=json.loads((old/'frozen_inputs.json').read_text())
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
for rel,d in manifest.items():assert sha(old/'project'/rel)==d
syn_strategy=json.loads((old/'BUILD_STRATEGY.json').read_text())['strategy'] if (old/'BUILD_STRATEGY.json').is_file() else 'Default'
subprocess.run(['D:/Python3.10.11/python.exe','-X','utf8',str(r/'scripts/build_r22_relay.py'),'--source',str(old/'project'),'--prepare-only','--keys-v3','--seed',str(x.seed),'--synthesis-strategy',syn_strategy,'--physical-strategy',x.physical_strategy,'--baseline-label','R27B-user-confirmed-handoff','--baseline-manifest','E:/2026FPGA/.codex_tmp/r27b_dual_merge_handoff_20261030/R27B_DualColumn_Code_and_Handoff/fpga/component_inspector/R27_FROZEN_INPUTS.json','--extra-source','user_source/hdl_source/observed_classified_pocket_counter.v','user_source/hdl_source/global_empty_position_tracker.v','user_source/hdl_source/dual_lane_parking.v','--work',str(w)],cwd=r,check=True)
assert json.loads((w/'frozen_inputs.json').read_text())==manifest
copied={}
for p in (old/'runs/syn_1').iterdir():
 if p.is_file() and p.name not in ['settings.cfg','build.tcl','camera_to_dsi_display.prj']:
  dest=w/'runs/syn_1'/p.name;shutil.copy2(p,dest);assert sha(dest)==sha(p);copied[p.name]=sha(p)
assert 'camera_to_dsi_display_gate.db' in copied
(w/'EXACT_SYNTHESIS_REUSE.json').write_text(json.dumps({'source_work':str(old),'source_files_identical':len(manifest),'synthesis_database_sha256':copied['camera_to_dsi_display_gate.db'],'copied_files':copied,'new_physical_seed':x.seed},indent=2)+'\n')
if (old/'CAMERA_EXPORT.json').is_file():
 for name in ['CAMERA_EXPORT.json','d3_camera_gate.v','export_camera.tcl','export_camera.log']:shutil.copy2(old/name,w/name)
 if 'gate_database_sha256' in (proof:=json.loads((w/'CAMERA_EXPORT.json').read_text())):assert proof['gate_database_sha256']==sha(w/'runs/syn_1/camera_to_dsi_display_gate.db')
if x.prepare_only:
 print(json.dumps({'status':'PREPARED_EXACT_SYNTHESIS_REUSE_NO_PHYSICAL_JOB_STARTED','work':str(w),'physical_strategy':x.physical_strategy}),flush=True);raise SystemExit(0)
(w/'temp').mkdir();env=dict(os.environ);env['TEMP']=env['TMP']=str(w/'temp');started=time.monotonic()
with (w/'runs/phy_1/console.log').open('w') as log:
 p=subprocess.run(['E:/TD/bin/td_commands_prompt.exe'],input='source {build.tcl}\n',text=True,cwd=w/'runs/phy_1',env=env,stdout=log,stderr=subprocess.STDOUT,timeout=7200)
assert p.returncode==0,('Physical build failed',p.returncode)
bit=w/'runs/phy_1/camera_to_dsi_display.bit';assert bit.is_file()
for rel,d in manifest.items():assert sha(w/'project'/rel)==d
result={'status':'BUILT_NEEDS_RESOURCE_TIMING_AND_IO_AUDIT','bit':str(bit),'bit_sha256':sha(bit),'sources':len(manifest),'seed':x.seed,'stages':[{'stage':'syn_1','mode':'EXACT_DATABASE_REUSE','source_build':str(old)},{'stage':'phy_1','seconds':round(time.monotonic()-started,1),'console_sha256':sha(w/'runs/phy_1/console.log')}],'board_operated':False}
(w/'build_result.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result),flush=True)
