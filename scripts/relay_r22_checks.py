from pathlib import Path
import argparse,hashlib,json,os,re,shutil,subprocess,winreg

root=Path(__file__).resolve().parents[1]
a=argparse.ArgumentParser();a.add_argument('--out',type=Path,required=True);a.add_argument('--source',type=Path)
a.add_argument('--modelsim',type=Path,default=Path('E:/Modelsim/win64'));args=a.parse_args()
p=args.source.resolve() if args.source else root/'fpga/component_inspector'
out=args.out.resolve();out.mkdir(parents=True,exist_ok=False)
env=dict(os.environ)
for key in ['MGLS_LICENSE_FILE','LM_LICENSE_FILE']:
 if not env.get(key):
  for hive,location in [(winreg.HKEY_CURRENT_USER,'Environment'),(winreg.HKEY_LOCAL_MACHINE,r'SYSTEM\CurrentControlSet\Control\Session Manager\Environment')]:
   try:
    with winreg.OpenKey(hive,location) as k:env[key]=winreg.QueryValueEx(k,key)[0]
    break
   except OSError:pass
env['TEMP']=env['TMP']=str(out)
sim=args.modelsim.resolve()
files=['user_source/hdl_source/pocket_relay_stop.v','user_source/hdl_source/classified_pocket_counter.v',
       'user_source/hdl_source/classified_count_pipeline.v','sim/tb_pocket_relay_stop.sv','sim/tb_relay_numbered_pipeline.sv','sim/tb_relay_real_second.sv']
sealed=out/'inputs';sealed.mkdir()
manifest={}
for rel in files:
 target=sealed/Path(rel).name;shutil.copy2(p/rel,target)
 manifest[rel]=hashlib.sha256(target.read_bytes()).hexdigest()
(out/'INPUT_SHA256.json').write_text(json.dumps(manifest,indent=2)+'\n')
def run(name,arguments,log):
 with (out/log).open('w',encoding='utf8') as f:
  result=subprocess.run([str(sim/(name+'.exe')),*arguments],cwd=out,env=env,stdout=f,stderr=subprocess.STDOUT,timeout=300)
 assert result.returncode==0,(name,log)
run('vlib',['work'],'setup.log')
run('vlog',['-work','work',*[str(sealed/Path(r).name) for r in files if r.endswith('.v')]],'compile_rtl.log')
run('vlog',['-sv','-work','work',*[str(sealed/Path(r).name) for r in files if r.endswith('.sv')]],'compile_bench.log')
results=[]
for bench,sentinel in [('tb_pocket_relay_stop','PASS pocket relay controller:'),('tb_relay_numbered_pipeline','PASS numbered relay pipeline:'),('tb_relay_real_second','PASS real one second:')]:
 run('vsim',['-c','-onfinish','stop','work.'+bench,'-do','onerror {quit -code 3}; onbreak {quit -code 2}; run -all; quit -code 0'],bench+'.log')
 text=(out/(bench+'.log')).read_text();assert sentinel in text and not re.search(r'\*\* (Fatal|Error):',text),text[-2000:]
 results.append({'bench':bench,'log_sha256':hashlib.sha256((out/(bench+'.log')).read_bytes()).hexdigest()})
 print(text[-650:])
for rel,digest in manifest.items():assert hashlib.sha256((p/rel).read_bytes()).hexdigest()==digest
(out/'verification.json').write_text(json.dumps({'status':'PASS_ACTUAL_RELAY_AND_NUMBERED_PIPELINE_SIMULATION','inputs':manifest,'tests':results,'board_acceptance':False},indent=2)+'\n')
