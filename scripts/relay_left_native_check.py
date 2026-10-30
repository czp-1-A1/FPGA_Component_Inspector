from pathlib import Path
import argparse,hashlib,json,os,re,shutil,subprocess,winreg
r=Path(__file__).resolve().parents[1];a=argparse.ArgumentParser();a.add_argument('--out',type=Path,required=True);a.add_argument('--source',type=Path);a.add_argument('--v3',action='store_true');a.add_argument('--bench-dir',type=Path);a.add_argument('--bench');a.add_argument('--pass-token');a.add_argument('--extra-rtl',nargs='*',default=[]);args=a.parse_args()
bench=args.bench or ('tb_relay_v3_native' if args.v3 else 'tb_relay_left_native')
p=(args.source or r/'fpga/component_inspector').resolve();out=args.out.resolve();out.mkdir(parents=True,exist_ok=False);env=dict(os.environ)
for key in ['MGLS_LICENSE_FILE','LM_LICENSE_FILE']:
 if not env.get(key):
  for hive,location in [(winreg.HKEY_CURRENT_USER,'Environment'),(winreg.HKEY_LOCAL_MACHINE,r'SYSTEM\CurrentControlSet\Control\Session Manager\Environment')]:
   try:
    with winreg.OpenKey(hive,location) as k:env[key]=winreg.QueryValueEx(k,key)[0]
    break
   except OSError:pass
env['TEMP']=env['TMP']=str(out);sim=Path('E:/Modelsim/win64');td=Path('E:/TD/sim_release')
text=(p/'sim/run_modelsim.ps1').read_text(encoding='utf8');block=text.split('$ispSources = @(',1)[1].split('    $tests = @(',1)[0]
hdl=p/'user_source/hdl_source';ip=p/'user_source/ip_source';demosaic=hdl/'isp/demosaic_4x_2_0'
files=[Path(t.replace('$demosaic',str(demosaic)).replace('$hdl',str(hdl)).replace('$ip',str(ip))).resolve() for t in re.findall(r'"([^"]+\.v)"',block)]
files += [hdl/(n+'.v') for n in ['pocket_relay_stop','pocket_relay_stop_v2','count_record_view','image_correction','status_cdc','video_in','video_out']]
files += [hdl/(n+'.v') for n in args.extra_rtl]
files += [p/'sim/reference/classified_pocket_counter_R9.v',p/('sim/'+bench+'.sv')]
vendor=['common/al_map_basic.v','common/al_map_lut.v','common/al_map_adder.v','common/al_phy_glbl.v','ph1p/ph1p_logic_eram.v','ph1p/ph1p_phy_gsr.v','ph1p/ph1p_logic_bufg.v','ph1p/ph1p_phy_pll_v2.v','ph1p/ph1p_logic_hrio.v','ph1p/ph1p_phy_hr_pad.v']
manifest={};extra_inputs={};frozen=[]
for file in files:
 rel=file.relative_to(p.resolve()).as_posix();dest=out/'inputs/project'/rel;dest.parent.mkdir(parents=True,exist_ok=True)
 external=args.bench_dir is not None and file==files[-1]
 shutil.copy2(args.bench_dir/file.name if external else file,dest);frozen.append(dest)
 (extra_inputs if external else manifest)[rel]=hashlib.sha256(dest.read_bytes()).hexdigest()
vfiles=[];vmanifest={}
for rel in vendor:
 dest=out/'inputs/vendor'/rel;dest.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(td/rel,dest);vfiles.append(dest);vmanifest[rel]=hashlib.sha256(dest.read_bytes()).hexdigest()
(out/'INPUT_SHA256.json').write_text(json.dumps({'source':manifest,'extra_inputs':extra_inputs,'vendor':vmanifest},indent=2)+'\n')
def run(tool,arguments,name,timeout=300):
 with (out/name).open('w',encoding='utf8') as log:
  x=subprocess.run([str(sim/(tool+'.exe')),*map(str,arguments)],cwd=out,env=env,stdout=log,stderr=subprocess.STDOUT,timeout=timeout)
 assert x.returncode==0,(tool,name,(out/name).read_text()[-2500:])
run('vlib',['work'],'setup.log');run('vlib',['anlogic_sim'],'vendor_setup.log')
run('vlog',['-work','anlogic_sim',*vfiles],'vendor_compile.log')
run('vlog',['-work','work',*frozen[:-1]],'compile_rtl.log')
run('vlog',['-sv','-work','work',frozen[-1]],'compile_bench.log')
run('vsim',['-c','-L','anlogic_sim','-voptargs=+acc=rn+/'+bench,'-onfinish','stop','work.'+bench,'anlogic_sim.glbl','anlogic_sim.PH1P_PHY_GSR','-do','onerror {quit -code 3}; onbreak {quit -code 2}; run -all; quit -code 0'],'console.log',2400)
log=(out/'console.log').read_text();assert (args.pass_token or ('PASS V3_NATIVE_MODE1:' if args.v3 else 'PASS LEFT_NATIVE_MODE1:')) in log and not re.search(r'\*\* (Fatal|Error):',log),log[-2500:]
for rel,d in manifest.items():assert hashlib.sha256((p/rel).read_bytes()).hexdigest()==d,rel
for rel,d in extra_inputs.items():assert hashlib.sha256((args.bench_dir/Path(rel).name).read_bytes()).hexdigest()==d,rel
(out/'verification.json').write_text(json.dumps({'status':'PASS','name':bench,'inputs':manifest,'extra_inputs':extra_inputs,'vendor':vmanifest,'console_sha256':hashlib.sha256((out/'console.log').read_bytes()).hexdigest(),'board_acceptance':False},indent=2)+'\n')
print(log[-2200:],flush=True)
