from pathlib import Path
import argparse,hashlib,json,os,re,shutil,subprocess,winreg

a=argparse.ArgumentParser();a.add_argument('name');a.add_argument('--rtl',nargs='+',required=True);a.add_argument('--benches',nargs='+',required=True);a.add_argument('--fixtures',nargs='*',default=[]);a.add_argument('--vendor',action='store_true');a.add_argument('--timeout',type=int,default=1800);args=a.parse_args()
out=Path('D:/FpgaWork/r28_field_20261102')/args.name;out.mkdir(exist_ok=False)
shutil.copy2(__file__,out/'RUNNER.py')
env=os.environ.copy()
for name in ['MGLS_LICENSE_FILE','LM_LICENSE_FILE']:
 if not env.get(name):
  for hive,key in [(winreg.HKEY_CURRENT_USER,'Environment'),(winreg.HKEY_LOCAL_MACHINE,r'SYSTEM\CurrentControlSet\Control\Session Manager\Environment')]:
   try:
    with winreg.OpenKey(hive,key) as h:env[name]=winreg.QueryValueEx(h,name)[0]
    break
   except OSError:pass
sim=Path('D:/modelsim/win64');inputs=out/'inputs';inputs.mkdir()
manifest={}
def seal(f):
 f=Path(f);dest=inputs/f.name;assert not dest.exists();shutil.copy2(f,dest);manifest[str(f.resolve())]=hashlib.sha256(dest.read_bytes()).hexdigest();return str(dest)
rtl=list(map(seal,args.rtl));benches=list(map(seal,args.benches))
for file in args.fixtures:
 frozen=Path(seal(file));shutil.copy2(frozen,out/frozen.name)
def run(tool,arguments,name):
 with (out/name).open('w',encoding='utf8') as log:r=subprocess.run([str(sim/(tool+'.exe')),*arguments],cwd=out,env=env,stdout=log,stderr=subprocess.STDOUT,timeout=args.timeout)
 text=(out/name).read_text(encoding='utf8',errors='replace')
 if r.returncode or re.search(r'\*\* (?:Fatal|Error):',text):print(text[-4000:]);raise SystemExit(1)
run('vlib',['work'],'setup.log')
if args.vendor:
 run('vlib',['anlogic_sim'],'vendor_setup.log')
 vendor=[seal(Path('D:/AAA/FPGA.....YZW/sim_release')/x) for x in ['common/al_phy_glbl.v','ph1p/ph1p_phy_gsr.v','ph1p/ph1p_phy_eram_v2.v']]
 run('vlog',['-work','anlogic_sim',*vendor],'vendor_compile.log')
v=[f for f in rtl if f.endswith('.v')];sv=[f for f in rtl if not f.endswith('.v')]
if v:run('vlog',['-work','work',*v],'compile_rtl.log')
run('vlog',['-sv','-work','work',*sv,*benches],'compile.log')
tests=[]
for bench in benches:
 top=Path(bench).stem
 run('vsim',['-c',*(['-L','anlogic_sim'] if args.vendor else []),'-onfinish','stop','work.'+top,*(['anlogic_sim.glbl','anlogic_sim.PH1P_PHY_GSR'] if args.vendor else []),'-do','onerror {quit -code 3}; onbreak {quit -code 2}; run -all; quit -code 0'],top+'.log')
 text=(out/(top+'.log')).read_text(encoding='utf8');assert 'PASS ' in text
 tests.append({'top':top,'sha256':hashlib.sha256((out/(top+'.log')).read_bytes()).hexdigest()});print(text[-900:],flush=True)
for f,h in manifest.items():assert hashlib.sha256(Path(f).read_bytes()).hexdigest()==h
(out/'verification.json').write_text(json.dumps({'status':'PASS','inputs':manifest,'tests':tests},indent=2),encoding='utf8')
