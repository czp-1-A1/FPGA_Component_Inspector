from pathlib import Path
import os,winreg,subprocess
p=Path(__file__).resolve().parent;env=dict(os.environ)
for key in ['MGLS_LICENSE_FILE','LM_LICENSE_FILE']:
 if not env.get(key):
  for hive,loc in [(winreg.HKEY_CURRENT_USER,'Environment'),(winreg.HKEY_LOCAL_MACHINE,r'SYSTEM\CurrentControlSet\Control\Session Manager\Environment')]:
   try:
    with winreg.OpenKey(hive,loc) as k:env[key]=winreg.QueryValueEx(k,key)[0]
    break
   except OSError:pass
env['TEMP']=env['TMP']=str(p);sim=Path('E:/Modelsim/win64');td=Path('E:/TD/sim_release')
def run(tool,args,name):
 with (p/name).open('w') as log:r=subprocess.run([str(sim/(tool+'.exe')),*args],cwd=p,env=env,stdout=log,stderr=subprocess.STDOUT,timeout=300)
 assert r.returncode==0,(name,(p/name).read_text()[-2500:])
run('vlib',['work'],'setup.log')
lib=['common/al_map_basic.v','common/al_map_lut.v','common/al_map_seq.v','common/al_map_adder.v','common/al_phy_glbl.v','ph1p/ph1p_phy_gsr.v','ph1p/ph1p_phy_lslice.v','ph1p/ph1p_logic_slice.v','ph1p/ph1p_phy_eram_v2.v']
run('vlog',['-work','work',*[str(td/n) for n in lib],'camera_cone.v'],'compile.log')
run('vlog',['-sv','-work','work','tb_camera_gate.sv'],'compile_tb.log')
run('vsim',['-c','-voptargs=+acc=rn+/tb_camera_gate','-onfinish','stop','work.tb_camera_gate','work.glbl','work.PH1P_PHY_GSR','-do','onerror {quit -code 3}; onbreak {quit -code 2}; run -all; quit -code 0'],'camera_gate.log')
log=(p/'camera_gate.log').read_text();print(log[-2500:]);assert 'PASS ACTUAL V2 SYNTH CAMERA BUS:' in log and '** Fatal:' not in log
