from pathlib import Path
import subprocess,sys,json
r=Path.cwd();rd=r/'tmp'/sys.argv[1];rp=rd/'scripts/replay.py';ps=json.loads((rd/'long_processes.json').read_text('utf-8')) if (rd/'long_processes.json').exists() else []
for spec in sys.argv[2:]:
 tag,tt=spec.split(':',1);tests=tt.split(',');w=rd/('work_'+tag)
 subprocess.run([sys.executable,'-X','utf8',str(rp),'--action','prepare','--work',str(w),'--td-root','D:/AAA/FPGA.....YZW'],check=True)
 f=(rd/(tag+'.log')).open('w',encoding='utf-8');e=(rd/(tag+'.err')).open('w',encoding='utf-8')
 z=subprocess.Popen([sys.executable,'-X','utf8',str(rp),'--action','sim','--work',str(w),'--td-root','D:/AAA/FPGA.....YZW','--modelsim-bin','D:/modelsim/win64','--tests',*tests],stdout=f,stderr=e,creationflags=0x08000000)
 ps.append(dict(pid=z.pid,tag=tag,tests=tests))
(rd/'long_processes.json').write_bytes((json.dumps(ps,indent=2)+'\n').encode('utf-8'));print(ps)
