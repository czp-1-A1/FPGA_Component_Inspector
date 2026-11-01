"""Freeze actual V3 RTL and independent alarm/role-display contracts."""
from pathlib import Path
import argparse,hashlib,json,os,re,shutil,subprocess,winreg
repo=Path(__file__).resolve().parents[1]
ap=argparse.ArgumentParser();ap.add_argument('--out',type=Path,required=True)
ap.add_argument('--source',type=Path,default=repo/'fpga/component_inspector')
ap.add_argument('--only',nargs='+',default=['tb_alarm_fault_guard','tb_demo_alarm','tb_alarm_roles_pixels'])
ap.add_argument('--modelsim',type=Path,default=Path('E:/Modelsim/win64'))
args=ap.parse_args();src=args.source.resolve();out=args.out.resolve();out.mkdir(parents=True,exist_ok=False)
sealed=out/'inputs';sealed.mkdir();env=dict(os.environ);env['TEMP']=env['TMP']=str(out)
for key in ['MGLS_LICENSE_FILE','LM_LICENSE_FILE']:
 if not env.get(key):
  for hive,loc in [(winreg.HKEY_CURRENT_USER,'Environment'),(winreg.HKEY_LOCAL_MACHINE,r'SYSTEM\CurrentControlSet\Control\Session Manager\Environment')]:
   try:
    with winreg.OpenKey(hive,loc) as k:env[key]=winreg.QueryValueEx(k,key)[0]
    break
   except OSError:pass
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
names=['contest_latency_clock','pocket_relay_stop_v2','classified_pocket_counter','classified_count_pipeline','pocket_run_controls','status_cdc',
 'inspection_region_config','empty_candidate_probe','present_surface_check','local_edge_surface_check','present_review_probe','frame_shape_search',
 'compact_inspector_osd','rl7_shared_font_rom','compact_ascii_rom','compact_cjk_rom','compact_template_rom','osd_logo_rom']
inputs={};fixtures={};files=[]
for n in names:
 rel='user_source/hdl_source/'+n+'.v';p=src/rel;q=sealed/p.name;shutil.copy2(p,q);inputs[rel]=sha(q);files.append(q)
folder=repo/'tests/rl7_alarm_roles_v3'
for p in sorted(folder.iterdir()):
 if p.suffix in ['.v','.sv']:
  q=sealed/p.name;shutil.copy2(p,q);fixtures[p.name]=sha(q);files.append(q)
sim=args.modelsim
def run(tool,argv,name,timeout=1200):
 with (out/name).open('w',encoding='utf-8') as log:
  res=subprocess.run([str(sim/(tool+'.exe')),*map(str,argv)],cwd=out,env=env,stdout=log,stderr=subprocess.STDOUT,timeout=timeout)
 t=(out/name).read_text(errors='replace')
 assert res.returncode==0 and not re.search(r'\*\* (?:Fatal|Error):|Errors:\s*[1-9]',t),(name,t[-2800:])
 return t
run('vlib',['work'],'setup.log')
run('vlog',['-work','work',*[p for p in files if p.suffix=='.v']],'compile_rtl.log')
run('vlog',['-sv','-work','work',*[p for p in files if p.suffix=='.sv']],'compile_bench.log')
proof=[]
for n in args.only:
 t=run('vsim',['-c','-onfinish','stop','work.'+n,'-do','onerror {quit -code 3}; onbreak {quit -code 2}; run -all; quit -code 0'],n+'.log')
 lines=[s for s in t.splitlines() if 'PASS ' in s];assert lines,n
 print('\n'.join(lines),flush=True);proof.append({'name':n,'log_sha256':sha(out/(n+'.log'))})
for rel,h in inputs.items():assert sha(src/rel)==h,rel
for n,h in fixtures.items():assert sha(folder/n)==h,n
(out/'verification.json').write_text(json.dumps({'status':'PASS','inputs':inputs,'fixtures':fixtures,'tests':proof,'board_operated':False},indent=2)+'\n')
print('PASS ALARM ROLES V3 '+str(len(proof))+' frozen-source checks',flush=True)
