"""Export the candidate's actual synthesized database, then test its camera cone."""
from pathlib import Path
import argparse,hashlib,json,os,subprocess
r=Path(__file__).resolve().parents[1]
a=argparse.ArgumentParser();a.add_argument('--work',type=Path,required=True);a.add_argument('--check-directory',type=Path,required=True);x=a.parse_args()
w=x.work.resolve();db=w/'runs/syn_1/camera_to_dsi_display_gate.db';net=w/'d3_camera_gate.v'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
assert db.is_file() and not net.exists()
script=w/'export_camera.tcl';script.write_text('''if {[catch {
import_device ph1_35p.db -package PH1P35MDG324 -speed 3
cd WORK/runs/syn_1
open_project camera_to_dsi_display.prj -noanalyze
import_db camera_to_dsi_display_gate.db
write_verilog WORK/d3_camera_gate.v
} reason]} {puts stderr $reason; exit 1}
exit 0
'''.replace('WORK',w.as_posix()))
before=sha(db);env=dict(os.environ);env['TEMP']=env['TMP']=str(w/'temp')
with (w/'export_camera.log').open('w') as log:
 p=subprocess.run(['E:/TD/bin/td_commands_prompt.exe'],input='source {'+script.as_posix()+'}\n',text=True,cwd=w,env=env,stdout=log,stderr=subprocess.STDOUT,timeout=120)
assert p.returncode==0 and net.is_file() and sha(db)==before
receipt={'status':'ACTUAL_SYNTHESIS_EXPORTED_NOT_SIMULATION_VERDICT','gate_database_sha256':before,
 'netlist_sha256':sha(net),'export_tcl_sha256':sha(script),'export_log_sha256':sha(w/'export_camera.log'),
 'check_directory':str(x.check_directory.resolve())}
(w/'CAMERA_EXPORT.json').write_text(json.dumps(receipt,indent=2)+'\n')
subprocess.run(['D:/Python3.10.11/python.exe','-X','utf8',str(r/'scripts/check_camera_gain_fix.py'),
 '--project',str(w/'project'),'--out',str(x.check_directory.resolve()),'--gate-netlist',str(net)],cwd=r,check=True)
print('Actual candidate camera export and serialized-bus check complete')
