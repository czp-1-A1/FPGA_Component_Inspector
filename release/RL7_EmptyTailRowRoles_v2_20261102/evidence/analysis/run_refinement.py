from pathlib import Path
import hashlib,json,os,re,subprocess,winreg
root=Path(__file__).resolve().parent;src=root/'refine_phase_r1';out=root/'refine_run_r1';out.mkdir(exist_ok=False)
env=dict(os.environ);env['TEMP']=env['TMP']=str(out)
for key in ['MGLS_LICENSE_FILE','LM_LICENSE_FILE']:
 if not env.get(key):
  for hive,loc in [(winreg.HKEY_CURRENT_USER,'Environment'),(winreg.HKEY_LOCAL_MACHINE,r'SYSTEM\CurrentControlSet\Control\Session Manager\Environment')]:
   try:
    with winreg.OpenKey(hive,loc) as k:env[key]=winreg.QueryValueEx(k,key)[0]
    break
   except OSError:pass
sim=Path('D:/modeltech64_10.5/win64')
def run(tool,argv,name):
 with (out/name).open('w',encoding='utf8') as f:r=subprocess.run([str(sim/(tool+'.exe')),*map(str,argv)],cwd=out,env=env,stdout=f,stderr=subprocess.STDOUT,timeout=1200)
 t=(out/name).read_text(errors='replace');assert r.returncode==0 and not re.search(r'\*\* (?:Error|Fatal):|Errors:\s*[1-9]',t),(name,t[-2500:])
 return t
run('vlib',['work'],'setup.log');run('vlog',['-work','work',*src.glob('*.v')],'compile_rtl.log');run('vlog',['-sv','-work','work',*src.glob('*.sv')],'compile_bench.log')
tests=[]
for n in ['tb_pocket_row_phases','tb_pocket_row_contract','tb_tail_29_plus_7_rgb','tb_small_tail_closed_loop']:
 t=run('vsim',['-c','-onfinish','stop','work.'+n,'-do','onerror {quit -code 3}; onbreak {quit -code 2}; run -all; quit -code 0'],n+'.log')
 lines=[l for l in t.splitlines() if 'PASS ' in l];assert lines,n
 print('\n'.join(lines),flush=True);tests.append({'bench':n,'console_sha256':hashlib.sha256((out/(n+'.log')).read_bytes()).hexdigest()})
inputs=json.loads((src/'INPUT_SHA256.json').read_text())
for n,d in inputs.items():assert hashlib.sha256((src/n).read_bytes()).hexdigest()==d,n
(out/'verification.json').write_text(json.dumps({'status':'PASS_ISOLATED_REFINEMENT_NOT_YET_PRODUCTION','inputs':inputs,'tests':tests,'prior_phase_failure_retained':True,'original_assertions_unchanged':True,'board_operated':False},indent=2)+'\n')
