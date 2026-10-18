from pathlib import Path
import hashlib,json,re,shutil,subprocess,sys
r=Path.cwd();base=r/'tmp/small_dual_r2_20261018';rd=r/'tmp/small_dual_handoff_negative_20261018'
for n in ['source_snapshot','scripts']:shutil.copytree(base/n,rd/n)
shutil.copy2(r/'tmp/tb_lane_handoff.v.txt',rd/'source_snapshot/sim/tb_lane_handoff.v')
q=rd/'source_snapshot/sim/run_modelsim.ps1';t=q.read_text('utf-8');line=next(x for x in t.splitlines() if 'Name="lane_search"' in x);new=line.replace('lane_search','lane_handoff').replace('PASS lane search:','PASS lane handoff:');t=t.replace('    $tests = @(\n','    $tests = @(\n'+new+'\n',1);q.write_text(t,encoding='utf-8')
m=json.loads((rd/'source_snapshot/inputs.json').read_text('utf-8'));m['sim/tb_lane_handoff.v']=''
for n in m:m[n]=hashlib.sha256((rd/'source_snapshot'/n).read_bytes()).hexdigest()
(rd/'source_snapshot/inputs.json').write_text(json.dumps(m,indent=2)+'\n',encoding='utf-8')
q=rd/'scripts/replay.py';t=q.read_text('utf-8').replace("TESTS = [", "TESTS = ['lane_handoff',",1);q.write_text(t,encoding='utf-8')
cmd=[sys.executable,'-X','utf8',str(rd/'scripts/replay.py')];common=['--work',str(rd/'work'),'--td-root','D:/AAA/FPGA.....YZW']
subprocess.run(cmd+['--action','prepare',*common],check=True)
with (rd/'sim.log').open('w',encoding='utf-8') as out,(rd/'sim.err').open('w',encoding='utf-8') as err:z=subprocess.Popen(cmd+['--action','sim',*common,'--modelsim-bin','D:/modelsim/win64','--tests','lane_handoff'],stdout=out,stderr=err,creationflags=0x08000000)
print('Negative handoff test PID',z.pid)
