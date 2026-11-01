"""Freeze and simulate the requested stop policy and unchanged legacy mode."""
from pathlib import Path
import argparse, hashlib, json, os, re, shutil, subprocess, winreg

ap=argparse.ArgumentParser()
ap.add_argument('--out',type=Path,required=True)
ap.add_argument('--modelsim',type=Path,default=Path('D:/modeltech64_10.5/win64'))
ap.add_argument('--real-second',action='store_true')
args=ap.parse_args()
repo=Path(__file__).resolve().parents[1];src=repo/'fpga/component_inspector'
out=args.out.resolve();out.mkdir(parents=True,exist_ok=False)
sealed=out/'inputs';sealed.mkdir()
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
top=(src/'user_source/hdl_source/design_top_wrapper.v').read_text()
isp=(src/'user_source/hdl_source/isp/isp_top.v').read_text()
assert 'parameter EMPTY_ONLY_STOP=1,' in top
assert 'isp_top #(.EMPTY_ONLY_STOP(EMPTY_ONLY_STOP),' in top
assert 'pocket_relay_stop_v2 #(.EMPTY_ONLY_STOP(EMPTY_ONLY_STOP),' in isp
motor=(repo/'tests/shift_alarm_v7/extracted_production_motor.sv').read_text()
body=top[top.index('reg motor_output;'):top.index('assign O_relay_control=motor_output;')+len('assign O_relay_control=motor_output;')]
assert body in motor,'Motor test must bind exact production register body'
files=[src/'user_source/hdl_source'/n for n in ['pocket_relay_stop_v2.v','pocket_run_controls.v','status_cdc.v']]
files += [repo/'tests/shift_alarm_v7/extracted_production_motor.sv',repo/'tests/empty_only_stop/tb_empty_only_stop.sv',
          src/'sim/tb_relay_v3_stop.sv',src/'sim/tb_relay_v3_keys.sv']
if args.real_second:files += [repo/'tests/empty_only_stop/tb_empty_only_real_second.sv']
files += [src/'user_source/hdl_source/design_top_wrapper.v',src/'user_source/hdl_source/isp/isp_top.v']
inputs={str(p.relative_to(repo)).replace('\\','/'):sha(p) for p in files}
for p in files:shutil.copy2(p,sealed/p.name)
(out/'INPUT_SHA256.json').write_text(json.dumps(inputs,indent=2)+'\n')
env=dict(os.environ);env['TEMP']=env['TMP']=str(out)
for key in ['MGLS_LICENSE_FILE','LM_LICENSE_FILE']:
 if not env.get(key):
  for hive,location in [(winreg.HKEY_CURRENT_USER,'Environment'),(winreg.HKEY_LOCAL_MACHINE,r'SYSTEM\CurrentControlSet\Control\Session Manager\Environment')]:
   try:
    with winreg.OpenKey(hive,location) as k:env[key]=winreg.QueryValueEx(k,key)[0]
    break
   except OSError:pass
def run(tool,argv,name):
 with (out/name).open('w',encoding='utf8') as log:
  r=subprocess.run([str(args.modelsim/(tool+'.exe')),*map(str,argv)],cwd=out,env=env,stdout=log,stderr=subprocess.STDOUT,timeout=300)
 text=(out/name).read_text(errors='replace')
 assert r.returncode==0 and not re.search(r'\*\* (?:Fatal|Error):|Errors:\s*[1-9]',text),(name,text[-2500:])
 return text
run('vlib',['work'],'setup.log')
run('vlog',['-sv','-work','work',*[sealed/p.name for p in files[:-2]]],'compile.log')
results=[]
for bench in (['tb_empty_only_real_second'] if args.real_second else ['tb_empty_only_stop','tb_relay_v3_stop','tb_relay_v3_keys']):
 text=run('vsim',['-c','-onfinish','stop','work.'+bench,'-do','onerror {quit -code 3}; onbreak {quit -code 2}; run -all; quit -code 0'],bench+'.log')
 lines=[line for line in text.splitlines() if 'PASS ' in line];assert lines
 print('\n'.join(lines),flush=True);results.append({'bench':bench,'log_sha256':sha(out/(bench+'.log'))})
for rel,digest in inputs.items():assert sha(repo/rel)==digest
(out/'verification.json').write_text(json.dumps({'status':'PASS','inputs':inputs,'tests':results,'production_parameter_chain_checked':True,'exact_motor_body_checked':True,'board_operated':False},indent=2)+'\n')
