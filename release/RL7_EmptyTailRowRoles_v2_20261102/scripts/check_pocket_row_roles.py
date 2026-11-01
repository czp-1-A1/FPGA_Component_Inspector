"""Freeze production RTL and exercise actual RGB pocket/feed role contracts."""
from pathlib import Path
import argparse,hashlib,json,os,re,shutil,subprocess,winreg
repo=Path(__file__).resolve().parents[1]
a=argparse.ArgumentParser();a.add_argument('--out',type=Path,required=True)
a.add_argument('--modelsim',type=Path,default=Path('D:/modeltech64_10.5/win64'))
a.add_argument('--only',nargs='+',default=['tb_pocket_row_contract','tb_tail_29_plus_7_rgb','tb_small_tail_closed_loop','tb_pocket_row_phases'])
args=a.parse_args();out=args.out.resolve();out.mkdir(parents=True,exist_ok=False)
sealed=out/'inputs';sealed.mkdir();src=repo/'fpga/component_inspector'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
top=(src/'user_source/hdl_source/design_top_wrapper.v').read_text(encoding='utf8')
isp=(src/'user_source/hdl_source/isp/isp_top.v').read_text(encoding='utf8')
assert 'EMPTY_ONLY_STOP=1,POCKET_ROW_ROLES=1' in top
assert '.EMPTY_ONLY_STOP(EMPTY_ONLY_STOP),.POCKET_ROW_ROLES(POCKET_ROW_ROLES)' in top
assert 'frame_shape_search #(.POCKET_ROW_ROLES(POCKET_ROW_ROLES),' in isp
assert 'pocket_relay_stop_v2 #(.EMPTY_ONLY_STOP(EMPTY_ONLY_STOP),' in isp
names=['contest_latency_clock','pocket_relay_stop_v2','classified_pocket_counter','classified_count_pipeline','pocket_run_controls','status_cdc',
 'inspection_region_config','empty_candidate_probe','present_surface_check','local_edge_surface_check','present_review_probe','frame_shape_search',
 'compact_inspector_osd','rl7_shared_font_rom','compact_ascii_rom','compact_cjk_rom','compact_template_rom','osd_logo_rom']
files=[src/'user_source/hdl_source'/(n+'.v') for n in names]
files += [repo/'tests/pocket_row_roles'/(n+'.sv') for n in args.only]
inputs={p.relative_to(repo).as_posix():sha(p) for p in files}
for p in files:shutil.copy2(p,sealed/p.name)
(out/'INPUT_SHA256.json').write_text(json.dumps(inputs,indent=2)+'\n')
env=dict(os.environ);env['TEMP']=env['TMP']=str(out)
for key in ['MGLS_LICENSE_FILE','LM_LICENSE_FILE']:
 if not env.get(key):
  for hive,loc in [(winreg.HKEY_CURRENT_USER,'Environment'),(winreg.HKEY_LOCAL_MACHINE,r'SYSTEM\CurrentControlSet\Control\Session Manager\Environment')]:
   try:
    with winreg.OpenKey(hive,loc) as k:env[key]=winreg.QueryValueEx(k,key)[0]
    break
   except OSError:pass
def run(tool,argv,name):
 with (out/name).open('w',encoding='utf8') as f:
  r=subprocess.run([str(args.modelsim/(tool+'.exe')),*map(str,argv)],cwd=out,env=env,stdout=f,stderr=subprocess.STDOUT,timeout=1800)
 t=(out/name).read_text(encoding='utf8',errors='replace')
 assert r.returncode==0 and not re.search(r'\*\* (?:Fatal|Error):|Errors:\s*[1-9]',t),(name,t[-3500:])
 return t
run('vlib',['work'],'setup.log')
run('vlog',['-work','work',*[sealed/p.name for p in files if p.suffix=='.v']],'compile_rtl.log')
run('vlog',['-sv','-work','work',*[sealed/p.name for p in files if p.suffix=='.sv']],'compile_bench.log')
tests=[]
for name in args.only:
 t=run('vsim',['-c','-onfinish','stop','work.'+name,'-do','onerror {quit -code 3}; onbreak {quit -code 2}; run -all; quit -code 0'],name+'.log')
 lines=[l for l in t.splitlines() if 'PASS ' in l];assert lines,name
 print('\n'.join(lines),flush=True);tests.append({'bench':name,'console_sha256':sha(out/(name+'.log'))})
for rel,digest in inputs.items():assert sha(repo/rel)==digest,rel
(out/'verification.json').write_text(json.dumps({'status':'PASS','inputs':inputs,'tests':tests,'production_parameter_chain_checked':True,'board_operated':False},indent=2)+'\n')
