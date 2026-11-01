from pathlib import Path
import hashlib,json,os,re,subprocess,winreg,sys
root=Path(__file__).resolve().parent;version=sys.argv[1]
src=root/('motion_'+version);out=root/('motion_run_'+version);out.mkdir(exist_ok=False)
env=dict(os.environ);env['TEMP']=env['TMP']=str(out)
for key in ['MGLS_LICENSE_FILE','LM_LICENSE_FILE']:
 if not env.get(key):
  for hive,loc in [(winreg.HKEY_CURRENT_USER,'Environment'),(winreg.HKEY_LOCAL_MACHINE,r'SYSTEM\CurrentControlSet\Control\Session Manager\Environment')]:
   try:
    with winreg.OpenKey(hive,loc) as k:env[key]=winreg.QueryValueEx(k,key)[0]
    break
   except OSError:pass
sim=Path('D:/modeltech64_10.5/win64')
def run(tool,args,name):
 with (out/name).open('w',encoding='utf8') as f:r=subprocess.run([str(sim/(tool+'.exe')),*map(str,args)],cwd=out,env=env,stdout=f,stderr=subprocess.STDOUT,timeout=2100)
 t=(out/name).read_text(errors='replace')
 return r.returncode,t
for tool,args,name in [('vlib',['work'],'setup.log'),('vlog',['-work','work',*src.glob('*.v')],'compile_rtl.log'),('vlog',['-sv','-work','work',src/'tb_tail_29_plus_7_rgb.sv'],'compile_bench.log')]:
 rc,t=run(tool,args,name);assert rc==0 and not re.search(r'\*\* (Error|Fatal):',t),(name,t[-3500:])
rc,t=run('vsim',['-c','-onfinish','stop','work.tb_tail_29_plus_7_rgb','-do','onerror {quit -code 3}; onbreak {quit -code 2}; run -all; quit -code 0'],'console.log')
good=rc==0 and 'PASS TAIL 29+7 RGB' in t and not re.search(r'\*\* (Error|Fatal):',t)
for name,digest in json.loads((src/'INPUT_SHA256.json').read_text()).items():assert hashlib.sha256((src/name).read_bytes()).hexdigest()==digest
result={'status':'PASS' if good else 'FAIL_RETAINED','version':version,'exit_code':rc,'input_hashes':json.loads((src/'INPUT_SHA256.json').read_text()),'observer_motion_independent_of_motor':True,'board_operated':False,'console_sha256':hashlib.sha256((out/'console.log').read_bytes()).hexdigest()}
(out/'verification.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps({k:v for k,v in result.items() if k!='input_hashes'}),flush=True);print(t[-4000:],flush=True)
