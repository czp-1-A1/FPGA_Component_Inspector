from pathlib import Path
import json,hashlib,shutil,subprocess,sys
r=Path.cwd();p=r/'fpga/component_inspector';base=r/'tmp/base_jitter_creditfix_r6_20261017';rd=r/'tmp'/sys.argv[1];rd.mkdir(exist_ok=False);shutil.copytree(base/'source_snapshot',rd/'source_snapshot');shutil.copytree(base/'scripts',rd/'scripts');m=json.loads((rd/'source_snapshot/inputs.json').read_text('utf-8'));sha=lambda q:hashlib.sha256(q.read_bytes()).hexdigest()
for n in m:
 if n.startswith(('user_source/','sim/')) and not n.endswith('.log'):
  q=p/n
  if q.exists():shutil.copy2(q,rd/'source_snapshot'/n);m[n]=sha(q)
(rd/'source_snapshot/inputs.json').write_bytes((json.dumps(m,indent=2)+'\n').encode('utf-8'));meta=json.loads((base/'baseline.json').read_text('utf-8'));meta['source_manifest_sha256']=sha(rd/'source_snapshot/inputs.json');(rd/'baseline.json').write_bytes((json.dumps(meta,indent=2)+'\n').encode('utf-8'));rp=rd/'scripts/replay.py';ps=[]
rp.write_text(rp.read_text('utf-8').replace("'hd_pins']", "'hd_pins', 'isp_writer_stop', 'isp_metadata_stop', 'frame_tailproof']"),encoding='utf-8')
for spec in sys.argv[2:]:
 tag,tt=spec.split(':',1);tests=tt.split(',');w=rd/('work_'+tag);subprocess.run([sys.executable,str(rp),'--action','prepare','--work',str(w),'--td-root','D:/AAA/FPGA.....YZW'],check=True)
 f=(rd/(tag+'.log')).open('w',encoding='utf-8');e=(rd/(tag+'.err')).open('w',encoding='utf-8');pr=subprocess.Popen([sys.executable,'-X','utf8',str(rp),'--action','sim','--work',str(w),'--td-root','D:/AAA/FPGA.....YZW','--modelsim-bin','D:/modelsim/win64','--tests',*tests],stdout=f,stderr=e,creationflags=0x08000000);ps.append({'pid':pr.pid,'tag':tag,'tests':tests})
(rd/'processes.json').write_bytes((json.dumps(ps,indent=2)+'\n').encode('utf-8'));print(meta['source_manifest_sha256'],ps)
