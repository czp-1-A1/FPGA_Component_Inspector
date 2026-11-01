from pathlib import Path
import hashlib,json,os,re,subprocess,winreg
root=Path(__file__).resolve().parent;src=root/'frozen_r3';out=root/'run_r3';out.mkdir(exist_ok=False)
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
 with (out/name).open('w',encoding='utf8') as f:r=subprocess.run([str(sim/(tool+'.exe')),*map(str,args)],cwd=out,env=env,stdout=f,stderr=subprocess.STDOUT,timeout=900)
 text=(out/name).read_text(errors='replace');assert r.returncode==0 and not re.search(r'\*\* (Error|Fatal):',text),(name,text[-3000:])
 return text
run('vlib',['work'],'setup.log');run('vlog',['-work','work',*src.glob('*.v')],'compile_rtl.log')
run('vlog',['-sv','-work','work',src/'tb_tail_aperture_sweep.sv'],'compile_bench.log')
text=run('vsim',['-c','-onfinish','stop','work.tb_tail_aperture_sweep','-do','onerror {quit -code 3}; onbreak {quit -code 2}; run -all; quit -code 0'],'console.log')
lines=[line.removeprefix('# ') for line in text.splitlines() if 'ROLE_CASE ' in line]
assert 'DIAG_SWEEP_COMPLETE' in text and lines
rows=[]
for line in lines:rows.append({k:int(v) for k,v in re.findall(r'(\w+)=(-?\d+)',line)})
result={'status':'DIAGNOSTIC_COMPLETE_NOT_BOARD_ACCEPTANCE','cases':rows,'wrong_feed_targets':[r for r in rows if r['feed_E'] or r['feed_P']],
 'fixture_kind':'constructed full RGB source pixels, original production detector; not user camera replay','production_modified':False,'console_sha256':hashlib.sha256((out/'console.log').read_bytes()).hexdigest()}
(out/'diagnostic.json').write_text(json.dumps(result,indent=2)+'\n')
print('Completed',len(rows),'cases;',len(result['wrong_feed_targets']),'cases publish locating-hole pixels as counted E/P candidates',flush=True)
for r in result['wrong_feed_targets'][:10]:print(r,flush=True)
