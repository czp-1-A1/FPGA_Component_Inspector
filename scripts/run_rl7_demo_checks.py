"""Fresh frozen-input RL7 demo tests. Does not build/flash or access hardware."""
from pathlib import Path
import argparse, hashlib, json, os, re, shutil, subprocess, winreg

repo=Path(__file__).resolve().parents[1]
ap=argparse.ArgumentParser()
ap.add_argument('--out',type=Path,required=True)
ap.add_argument('--source',type=Path,default=repo/'fpga/component_inspector')
ap.add_argument('--only',nargs='+',default=['tb_demo_buzzer','tb_demo_latency','tb_demo_osd'])
ap.add_argument('--ui-opt-v2',action='store_true')
args=ap.parse_args();src=args.source.resolve();out=args.out.resolve()
out.mkdir(parents=True,exist_ok=False);sealed=out/'inputs';sealed.mkdir()
env=dict(os.environ);env['TEMP']=env['TMP']=str(out)
for key in ['MGLS_LICENSE_FILE','LM_LICENSE_FILE']:
 if not env.get(key):
  for hive,location in [(winreg.HKEY_CURRENT_USER,'Environment'),(winreg.HKEY_LOCAL_MACHINE,r'SYSTEM\CurrentControlSet\Control\Session Manager\Environment')]:
   try:
    with winreg.OpenKey(hive,location) as k:env[key]=winreg.QueryValueEx(k,key)[0]
    break
   except OSError:pass
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
names=['contest_latency_clock','compact_inspector_osd','compact_ascii_rom','compact_cjk_rom','compact_template_rom','osd_logo_rom']
if args.ui_opt_v2:names+=['rl7_shared_font_rom']
inputs={};fixtures={};files=[]
for name in names:
 rel='user_source/hdl_source/'+name+'.v';p=src/rel;dest=sealed/(name+'.v')
 shutil.copy2(p,dest);inputs[rel]=sha(p);files.append(dest)
for name in args.only:
 p=repo/'tests/demo_rl7'/(name+'.sv');dest=sealed/p.name
 shutil.copy2(p,dest);fixtures[p.name]=sha(p);files.append(dest)
sim=Path('E:/Modelsim/win64')
def run(tool,argv,name,timeout=300):
 with (out/name).open('w',encoding='utf-8') as f:
  r=subprocess.run([str(sim/(tool+'.exe')),*map(str,argv)],cwd=out,env=env,stdout=f,stderr=subprocess.STDOUT,timeout=timeout)
 text=(out/name).read_text(errors='replace')
 assert r.returncode==0 and not re.search(r'\*\* (?:Error|Fatal):|Errors:\s*[1-9]',text),(name,text[-3500:])
 return text
run('vlib',['work'],'setup.log')
run('vlog',['-sv','-work','work',*files],'compile.log')
proof=[]
for name in args.only:
 t=run('vsim',['-c','-onfinish','stop','work.'+name,'-do','onerror {quit -code 3}; onbreak {quit -code 2}; run -all; quit -code 0'],name+'.log',900)
 lines=[l for l in t.splitlines() if 'PASS ' in l];assert lines,(name,t[-2000:])
 print('\n'.join(lines),flush=True);proof.append({'name':name,'log_sha256':sha(out/(name+'.log'))})
for rel,d in inputs.items():assert sha(src/rel)==d,rel
for n,d in fixtures.items():assert sha(repo/'tests/demo_rl7'/n)==d,n
(out/'verification.json').write_text(json.dumps({'status':'PASS','inputs':inputs,'fixtures':fixtures,'tests':proof,'board_operated':False},indent=2)+'\n')
print('PASS RL7 DEMO '+str(len(proof))+' fresh checks',flush=True)
