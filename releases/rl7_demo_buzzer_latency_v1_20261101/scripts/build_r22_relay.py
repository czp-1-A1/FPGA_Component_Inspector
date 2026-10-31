"""Freeze R22+automatic relay sources, derive TD descriptors, build without flashing."""
from pathlib import Path
import argparse,hashlib,json,os,re,shutil,subprocess,time

def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
 a=argparse.ArgumentParser();a.add_argument('--work',type=Path,required=True);a.add_argument('--prepare-only',action='store_true')
 a.add_argument('--source',type=Path);a.add_argument('--baseline-manifest',type=Path);a.add_argument('--td',type=Path,default=Path('E:/TD'));a.add_argument('--left-v2',action='store_true');a.add_argument('--keys-v3',action='store_true');a.add_argument('--demo-rl7',action='store_true');a.add_argument('--seed',type=int,default=2);a.add_argument('--stage-timeout',type=int,default=2400);a.add_argument('--reuse-synthesis',type=Path);args=a.parse_args()
 assert 1<=args.seed<=1000 and 600<=args.stage_timeout<=7200
 repo=Path(__file__).resolve().parents[1];src=args.source.resolve() if args.source else repo/'fpga/component_inspector';work=args.work.resolve()
 assert not work.exists(),'Refuse to overwrite an existing build'
 assert str(work).isascii() and ' ' not in str(work)
 baseline=json.loads((args.baseline_manifest or repo/'releases/r22_20261027/frozen_inputs.json').read_text())
 names=list(baseline)+['user_source/hdl_source/pocket_relay_stop.v','sim/tb_pocket_relay_stop.sv','sim/tb_relay_numbered_pipeline.sv']
 if args.left_v2 or args.keys_v3:
  names+=['user_source/hdl_source/pocket_relay_stop_v2.v']
  names+=['sim/'+n+'.sv' for n in ['tb_relay_left_transport','tb_relay_left_faults','tb_relay_left_pixels','tb_relay_left_osd','tb_relay_left_rgb','tb_relay_left_real_second','tb_relay_real_second','tb_relay_osd','tb_relay_queue']]
 if args.keys_v3:names+=['sim/'+n+'.sv' for n in ['tb_relay_left_native','tb_relay_v3_keys','tb_relay_v3_stop','tb_relay_v3_osd','tb_relay_v3_transport','tb_relay_v3_rgb','tb_relay_v3_real_second','tb_relay_v3_native']]
 if args.demo_rl7:
  assert args.keys_v3
  names+=['user_source/hdl_source/contest_latency_clock.v']
 manifest={rel:sha(src/rel) for rel in names}
 changes={rel:{'baseline':baseline.get(rel),'candidate':manifest[rel]} for rel in names if baseline.get(rel)!=manifest[rel]}
 project=work/'project';project.mkdir(parents=True)
 for rel in names:
  target=project/rel;target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(src/rel,target)
 (work/'frozen_inputs.json').write_text(json.dumps(manifest,indent=2)+'\n')
 (work/'baseline_delta.json').write_text(json.dumps({'baseline_commit':'a1cceaa','baseline_manifest_sha256':'8e81b47dcd40d88b461aae525e946d5c41bd175691bc66f896b9dc34989541bf','changes':changes},indent=2)+'\n')
 td=args.td.resolve();flow=td/'doc/scripts/DefaultFlow.tcl';assert flow.is_file()
 entry=project/'td_project/camera_to_dsi_display.al';text=entry.read_text()
 deps={}
 for rel in re.findall(r'<File Path="([^"]+)"',text):
  p=(entry.parent/rel).resolve();deps[p.relative_to(project).as_posix()]=sha(p)
 for rel in ['user_source/hdl_source/ph1p35_ddr/ddr2/src/adc/ddr2.adc','user_source/hdl_source/ph1p35_ddr/ddr2/src/sdc/ddr2.sdc','user_source/ip_source/w128_d512_fifo/w128_d512_fifo.tcl']:
  deps[rel]=sha(project/rel)
 (work/'hardware_inputs.json').write_text(json.dumps(deps,indent=2)+'\n')
 for stage in ['syn_1','phy_1']:
  run=work/'runs'/stage;run.mkdir(parents=True)
  prj=re.sub(r'(<Project\b[^>]*\bPath=")[^"]*',lambda m:m[1]+run.as_posix(),text,count=1)
  prj=re.sub(r'<File Path="([^"]+)"',lambda m:'<File Path="'+Path(os.path.relpath((entry.parent/m[1]).resolve(),run)).as_posix()+'"',prj)
  (run/'camera_to_dsi_display.prj').write_text(prj,encoding='utf8')
  cfg='''set ADCList {"../../../user_source/constraints_source/pin.adc"}
set IpADCList { ddr2 ../../../user_source/hdl_source/ph1p35_ddr/ddr2/src/adc/ddr2.adc }
set IpSDCList { ddr2 ../../../user_source/hdl_source/ph1p35_ddr/ddr2/src/sdc/ddr2.sdc w128_d512_fifo ../../../user_source/ip_source/w128_d512_fifo/w128_d512_fifo.tcl }
set SDCList {"../../camera_to_dsi_display.sdc"}
set area_option -packarea
set device_name ph1_35p.db
set package_name PH1P35MDG324
set prj_name camera_to_dsi_display
set speed 3
set top_model_name design_top_wrapper
'''
  if stage=='syn_1':cfg+='set start_step read_design\nset end_step opt_gate\nset run_type syn\n'
  else:cfg+='''set arr_filter false
set phyWildParams {place seed 2 place logic_level_opt on place opt_timing high place effort high place fix_hold on}
set drHoldFix on
set parent ../syn_1
set start_step opt_place
set end_step bitgen
set run_type phy
'''
  cfg=cfg.replace('place seed 2 ',f'place seed {args.seed} ')
  cfg=cfg.replace('../../../user_source',Path(os.path.relpath(project/'user_source',run)).as_posix())
  cfg=cfg.replace('../../camera_to_dsi_display.sdc',Path(os.path.relpath(entry.parent/'camera_to_dsi_display.sdc',run)).as_posix())
  (run/'settings.cfg').write_text(cfg)
  commands='if {[catch {\nsource {'+flow.as_posix()+'}\ncheck_timing -file constraint_coverage.txt -verbose\n'
  if stage=='phy_1':commands+='report_timing_summary -file final_timing.rpt\nreport_area -io_info -file final.area\n'
  commands+='} reason]} {puts stderr $reason; exit 1}\nexit 0\n'
  (run/'build.tcl').write_text(commands)
 print(json.dumps({'status':'FROZEN','project':str(project),'sources':len(manifest),'hardware_dependencies':len(deps),'delta_files':len(changes),'seed':args.seed}),flush=True)
 if args.prepare_only:return
 env=dict(os.environ);(work/'temp').mkdir();env['TEMP']=env['TMP']=str(work/'temp')
 stages=[]
 for stage in ['syn_1','phy_1']:
  run=work/'runs'/stage;started=time.monotonic()
  if stage=='syn_1' and args.reuse_synthesis:
   prior=args.reuse_synthesis.resolve()
   assert json.loads((prior/'frozen_inputs.json').read_text())==manifest,'Reuse source mismatch'
   assert json.loads((prior/'hardware_inputs.json').read_text())==deps,'Reuse hardware dependency mismatch'
   oldresult=json.loads((prior/'build_result.json').read_text())
   assert oldresult['stages'][0]['stage']=='syn_1' and oldresult['stages'][0]['seconds']>0
   for n in ['camera_to_dsi_display_gate.db','camera_to_dsi_display_gate.area','camera_to_dsi_display_rtl.area','console.log']:
    shutil.copy2(prior/'runs/syn_1'/n,run/n)
   proof={'mode':'EXACT_SYNTHESIS_REUSE','source_work':str(prior),'source_manifest_sha256':sha(prior/'frozen_inputs.json'),
    'gate_database_sha256':sha(run/'camera_to_dsi_display_gate.db'),'source_files':len(manifest),'hardware_dependencies':len(deps),
    'rtl_pin_sdc_clock_changes':False,'seed_before':oldresult['seed'],'seed_after':args.seed,'only_physical_seed_changed':True}
   assert sha(run/'camera_to_dsi_display_gate.db')==sha(prior/'runs/syn_1/camera_to_dsi_display_gate.db')
   (work/'SYNTHESIS_REUSE.json').write_text(json.dumps(proof,indent=2)+'\n')
   stages.append({'stage':stage,'seconds':0,'mode':'EXACT_SYNTHESIS_REUSE','console_sha256':sha(run/'console.log')})
   print(json.dumps(proof),flush=True);continue
  with (run/'console.log').open('w',encoding='utf8') as log:
   r=subprocess.run([str(td/'bin/td_commands_prompt.exe')],input='source {build.tcl}\n',text=True,cwd=run,env=env,stdout=log,stderr=subprocess.STDOUT,timeout=args.stage_timeout)
  txt=(run/'console.log').read_text(errors='replace')
  assert r.returncode==0 and not re.search(r'(?mi)^\s*(?:ERROR|\w+-\d+\s*:\s*Error)',txt),(stage,str(run/'console.log'))
  stages.append({'stage':stage,'seconds':round(time.monotonic()-started,1),'console_sha256':sha(run/'console.log')})
  print(json.dumps(stages[-1]),flush=True)
 bit=work/'runs/phy_1/camera_to_dsi_display.bit';assert bit.is_file()
 for rel,digest in manifest.items():assert sha(project/rel)==digest and sha(src/rel)==digest,rel
 result={'status':'BUILT_NEEDS_RESOURCE_TIMING_AND_IO_AUDIT','bit':str(bit),'bit_sha256':sha(bit),'sources':len(manifest),'stages':stages,'seed':args.seed,'board_operated':False}
 (work/'build_result.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result),flush=True)
if __name__=='__main__':main()
