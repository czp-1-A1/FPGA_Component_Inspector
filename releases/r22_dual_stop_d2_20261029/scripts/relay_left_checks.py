from pathlib import Path
import argparse,hashlib,json,os,re,shutil,subprocess,winreg
r=Path(__file__).resolve().parents[1]
a=argparse.ArgumentParser();a.add_argument('--out',type=Path,required=True);a.add_argument('--source',type=Path);a.add_argument('--only',nargs='+');a.add_argument('--support',nargs='+');a.add_argument('--bench-dir',type=Path);a.add_argument('--osd',action='store_true');args=a.parse_args()
p=args.source or r/'fpga/component_inspector';out=args.out.resolve();out.mkdir(parents=True,exist_ok=False);env=dict(os.environ)
for key in ['MGLS_LICENSE_FILE','LM_LICENSE_FILE']:
 if not env.get(key):
  for hive,location in [(winreg.HKEY_CURRENT_USER,'Environment'),(winreg.HKEY_LOCAL_MACHINE,r'SYSTEM\CurrentControlSet\Control\Session Manager\Environment')]:
   try:
    with winreg.OpenKey(hive,location) as k:env[key]=winreg.QueryValueEx(k,key)[0]
    break
   except OSError:pass
env['TEMP']=env['TMP']=str(out);sim=Path('E:/Modelsim/win64')
rtl=['pocket_relay_stop','pocket_relay_stop_v2','classified_pocket_counter','classified_count_pipeline','pocket_run_controls','status_cdc']
benches=args.only or ['tb_relay_left_faults','tb_relay_left_transport','tb_pocket_relay_stop','tb_relay_numbered_pipeline','tb_relay_real_second']
files=['user_source/hdl_source/'+n+'.v' for n in rtl]+['sim/'+n+'.sv' for n in (args.support or [])+benches]

if args.osd or any(n in benches for n in ['tb_relay_left_pixels','tb_relay_left_osd','tb_relay_left_rgb','tb_relay_v3_osd','tb_relay_v3_rgb']):
 rtl+=['inspection_region_config','empty_candidate_probe','present_surface_check','local_edge_surface_check','present_review_probe','frame_shape_search','compact_ascii_rom','compact_cjk_rom','compact_template_rom','osd_logo_rom','compact_inspector_osd']
 files=['user_source/hdl_source/'+n+'.v' for n in rtl]+['sim/'+n+'.sv' for n in (args.support or [])+benches]
sealed=out/'inputs';sealed.mkdir();manifest={};extra_inputs={}
for rel in files:
 external=args.bench_dir is not None and rel.startswith('sim/')
 original=args.bench_dir/Path(rel).name if external else p/rel
 target=sealed/Path(rel).name;shutil.copy2(original,target)
 (extra_inputs if external else manifest)[rel]=hashlib.sha256(target.read_bytes()).hexdigest()
(out/'INPUT_SHA256.json').write_text(json.dumps(manifest,indent=2)+'\n')
def run(tool,arguments,name):
 with (out/name).open('w',encoding='utf8') as log:
  x=subprocess.run([str(sim/(tool+'.exe')),*arguments],cwd=out,env=env,stdout=log,stderr=subprocess.STDOUT,timeout=300)
 assert x.returncode==0,(tool,name,(out/name).read_text()[-1800:])
run('vlib',['work'],'setup.log')
run('vlog',['-work','work',*[str(sealed/(n+'.v')) for n in rtl]],'compile_rtl.log')
run('vlog',['-sv','-work','work',*[str(sealed/(n+'.sv')) for n in (args.support or [])+benches]],'compile_bench.log')
tests=[]
for bench in benches:
 run('vsim',['-c','-onfinish','stop','work.'+bench,'-do','onerror {quit -code 3}; onbreak {quit -code 2}; run -all; quit -code 0'],bench+'.log')
 text=(out/(bench+'.log')).read_text();assert 'PASS ' in text and not re.search(r'\*\* (Fatal|Error):',text),text[-1600:]
 tests.append({'name':bench,'sha256':hashlib.sha256((out/(bench+'.log')).read_bytes()).hexdigest()});print(text[-700:],flush=True)
for rel,d in manifest.items():assert hashlib.sha256((p/rel).read_bytes()).hexdigest()==d
for rel,d in extra_inputs.items():assert hashlib.sha256((args.bench_dir/Path(rel).name).read_bytes()).hexdigest()==d
(out/'verification.json').write_text(json.dumps({'status':'PASS','inputs':manifest,'extra_inputs':extra_inputs,'tests':tests,'board_acceptance':False},indent=2)+'\n')
