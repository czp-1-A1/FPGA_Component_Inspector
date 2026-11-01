"""Frozen-source display-only equivalence to the immutable Demo V1."""
from pathlib import Path
import argparse,hashlib,json,os,re,shutil,subprocess,winreg
repo=Path(__file__).resolve().parents[1]
ap=argparse.ArgumentParser();ap.add_argument('--out',type=Path,required=True)
ap.add_argument('--source',type=Path,default=repo/'fpga/component_inspector')
ap.add_argument('--only',nargs='+',default=['tb_uiopt_font','tb_uiopt_pixels'])
args=ap.parse_args();src=args.source.resolve();out=args.out.resolve()
out.mkdir(parents=True,exist_ok=False);frozen=out/'inputs';frozen.mkdir()
env=dict(os.environ);env['TEMP']=env['TMP']=str(out)
for key in ['MGLS_LICENSE_FILE','LM_LICENSE_FILE']:
 if not env.get(key):
  for hive,location in [(winreg.HKEY_CURRENT_USER,'Environment'),(winreg.HKEY_LOCAL_MACHINE,r'SYSTEM\CurrentControlSet\Control\Session Manager\Environment')]:
   try:
    with winreg.OpenKey(hive,location) as k:env[key]=winreg.QueryValueEx(k,key)[0]
    break
   except OSError:pass
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
names=['contest_latency_clock','compact_inspector_osd','rl7_shared_font_rom','compact_ascii_rom','compact_cjk_rom','compact_template_rom','osd_logo_rom']
inputs={};fixtures={};files=[]
for n in names:
 rel='user_source/hdl_source/'+n+'.v';p=src/rel;q=frozen/p.name
 shutil.copy2(p,q);inputs[rel]=sha(q);files.append(q)
for p in sorted((repo/'tests/ui_opt_v2').iterdir()):
 if p.suffix in ['.v','.sv']:
  q=frozen/p.name;shutil.copy2(p,q);fixtures[p.name]=sha(q);files.append(q)
sim=Path('E:/Modelsim/win64')
def run(tool,argv,name,timeout=300):
 with (out/name).open('w',encoding='utf-8') as log:
  r=subprocess.run([str(sim/(tool+'.exe')),*map(str,argv)],cwd=out,env=env,stdout=log,stderr=subprocess.STDOUT,timeout=timeout)
 text=(out/name).read_text(errors='replace')
 assert r.returncode==0 and not re.search(r'\*\* (?:Fatal|Error):|Errors:\s*[1-9]',text),(name,text[-2400:])
 return text
run('vlib',['work'],'setup.log');run('vlog',['-sv','-work','work',*files],'compile.log')
proof=[]
for n in args.only:
 text=run('vsim',['-c','-onfinish','stop','work.'+n,'-do','onerror {quit -code 3}; onbreak {quit -code 2}; run -all; quit -code 0'],n+'.log',1200)
 lines=[s for s in text.splitlines() if 'PASS ' in s];assert lines,n
 print('\n'.join(lines),flush=True);proof.append({'name':n,'log_sha256':sha(out/(n+'.log'))})
for rel,h in inputs.items():assert sha(src/rel)==h,rel
for n,h in fixtures.items():assert sha(repo/'tests/ui_opt_v2'/n)==h,n
(out/'verification.json').write_text(json.dumps({'status':'PASS','inputs':inputs,'fixtures':fixtures,'tests':proof,'board_operated':False},indent=2)+'\n')
print('PASS UIOPT V2 '+str(len(proof))+' frozen-source checks',flush=True)
