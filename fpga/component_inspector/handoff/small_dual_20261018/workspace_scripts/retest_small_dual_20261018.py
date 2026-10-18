from pathlib import Path
import hashlib,json,shutil,subprocess,sys
r=Path.cwd();old=r/'tmp/small_dual_r0_20261018';rd=r/'tmp/small_dual_r1_20261018'
for n in ['source_snapshot','scripts']:shutil.copytree(old/n,rd/n)
shutil.copy2(old/'baseline.json',rd/'baseline.json')
q=rd/'source_snapshot/sim/tb_lane_search.v';b=q.read_bytes();assert b.count(b'expected_state,dist,best;')==1;q.write_bytes(b.replace(b'expected_state,dist,best;',b'expected_state,best;'))
m=json.loads((rd/'source_snapshot/inputs.json').read_text('utf-8'));m['sim/tb_lane_search.v']=hashlib.sha256(q.read_bytes()).hexdigest();(rd/'source_snapshot/inputs.json').write_text(json.dumps(m,indent=2)+'\n',encoding='utf-8')
cmd=[sys.executable,'-X','utf8',str(rd/'scripts/replay.py')];common=['--work',str(rd/'work'),'--td-root','D:/AAA/FPGA.....YZW']
subprocess.run(cmd+['--action','prepare',*common],check=True)
with (rd/'sim.log').open('w',encoding='utf-8') as out,(rd/'sim.err').open('w',encoding='utf-8') as err:z=subprocess.Popen(cmd+['--action','sim',*common,'--modelsim-bin','D:/modelsim/win64'],stdout=out,stderr=err,creationflags=0x08000000)
(rd/'processes.json').write_text(json.dumps(dict(sim=z.pid,build_round=old.name,build_pid=56688),indent=2),encoding='utf-8')
note=dict(build_round=old.name,test_round=rd.name,reason='r0 test compile rejected unused dist identifier (SV keyword); r1 removes only this unused declaration. Hardware,all input fixtures,expectations and pass goals unchanged.',r0_sim_exit_code=1)
(rd/'round_delta.json').write_text(json.dumps(note,indent=2)+'\n',encoding='utf-8')
q=r/'AGENTS.md';t=q.read_text('utf-8');t+='\n- 复测修正：r0测试编译失败证据保留（tb_lane_search无用变量dist是SV保留字）。r1仅删除该无用声明，测试输入/期望/目标与所有硬件源不变；r0实际构建继续，r1执行全部13项测试，进程'+str(z.pid)+'。最终交付必须同时记录r0构建manifest与r1测试manifest以及唯一test-only差异。\n';q.write_text(t,encoding='utf-8')
print(json.dumps(dict(sim=z.pid,round=rd.name,manifest=hashlib.sha256((rd/'source_snapshot/inputs.json').read_bytes()).hexdigest()),indent=2))
