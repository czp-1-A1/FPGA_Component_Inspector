from pathlib import Path
import json,re,subprocess,sys
r=Path.cwd();rd=r/'tmp/small_dual_r3_20261018';w=rd/'work';phy=w/'td_project/camera_to_dsi_display_Runs/phy_1'
q=phy/'replay_build.result.json'
if not q.exists():print('WAIT_BUILD');sys.exit(0)
assert json.loads(q.read_text('utf-8'))['exit_code']==0 and (phy/'.bitgen.end.f').exists()
t=(phy/'camera_to_dsi_display_pr.timing').read_text('utf-8');assert all(float(re.search(k+r':\s*([-\d.]+)ns',t)[1])>=0 for k in ['SWNS','HWNS'])
with (w/'routed_audit.log').open('w',encoding='utf-8') as f:z=subprocess.run(['D:/AAA/FPGA.....YZW/bin/td_commands_prompt.exe','audit_routed.tcl'],cwd=w,stdout=f,stderr=subprocess.STDOUT)
(w/'routed_audit_exit.txt').write_text(str(z.returncode),encoding='ascii');assert z.returncode==0
print('PASS_ACTUAL_SMALL_DUAL_ROUTE_AUDIT')
