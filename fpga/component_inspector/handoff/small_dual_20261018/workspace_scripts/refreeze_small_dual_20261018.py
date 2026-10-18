from pathlib import Path
import hashlib,json,shutil,subprocess,sys
r=Path.cwd();old=r/'tmp/small_dual_r1_20261018';rd=r/'tmp/small_dual_r2_20261018'
sha=lambda q:hashlib.sha256(q.read_bytes()).hexdigest()
for n in ['source_snapshot','scripts']:shutil.copytree(old/n,rd/n)
shutil.copy2(old/'baseline.json',rd/'baseline.json')
q=rd/'source_snapshot/sim/run_modelsim.ps1';t=q.read_text('utf-8')
# Same native GSR/glbl and access policy as the established actual-HDMI test.
assert t.count('"hd_pins", "hd_pll"')==4
t=t.replace('"hd_pins", "hd_pll"','"hd_pins", "lane_hd_pins", "hd_pll"');q.write_text(t,encoding='utf-8')
q=rd/'source_snapshot/td_project/camera_to_dsi_display.sdc';t=q.read_text('utf-8');lines=t.splitlines(keepends=True)
removed=[x for x in lines if x.startswith('set_max_delay ') and any(n in x for n in ['u_publish_display/','u_wb_process/'])]
assert len(removed)==6
t=''.join(x for x in lines if x not in removed)
t+='\n# SMALL DUAL R1 removes display-only publish-diagnostic and WB-status consumers.\n# Their six obsolete mailbox constraints are omitted; all remaining budgets,\n# clocks, I/O delays, exceptions and both10-bit bridge Gray constraints persist.\n'
q.write_text(t,encoding='utf-8')
baseline=json.loads((rd/'baseline.json').read_text('utf-8'));baseline['removed_dead_display_constraints']=[x.strip() for x in removed]
baseline['round_notes']=['r0 reserved dist test identifier failed; r1 removed declaration only and passed search/UI.','r1 actual HDMI elaboration missed native vendor global instances; r2 uses identical GSR/glbl policy to old hd_pins, no oracle changes.','r0 mapping eliminated two obsolete display-only CDC consumers; six dead max_delay targets were unmatched. r2 removes exactly these6 commands, no change to live-path budgets. r0 logs/source retained; full synthesis/route/simulation repeated.']
(rd/'baseline.json').write_text(json.dumps(baseline,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
m=json.loads((rd/'source_snapshot/inputs.json').read_text('utf-8'))
for name in m:m[name]=sha(rd/'source_snapshot'/name)
(rd/'source_snapshot/inputs.json').write_text(json.dumps(m,indent=2)+'\n',encoding='utf-8')
cmd=[sys.executable,'-X','utf8',str(rd/'scripts/replay.py')];common=['--work',str(rd/'work'),'--td-root','D:/AAA/FPGA.....YZW']
subprocess.run(cmd+['--action','prepare',*common],check=True);procs={}
for action,extra in [('sim',['--modelsim-bin','D:/modelsim/win64']),('build',[])]:
 with (rd/(action+'.log')).open('w',encoding='utf-8') as out,(rd/(action+'.err')).open('w',encoding='utf-8') as err:z=subprocess.Popen(cmd+['--action',action,*common,*extra],stdout=out,stderr=err,creationflags=0x08000000)
 procs[action]=z.pid
(rd/'processes.json').write_text(json.dumps(procs,indent=2)+'\n',encoding='utf-8')
q=r/'AGENTS.md';t=q.read_text('utf-8');t+='\n- 当前r2冻结完整重建/重测：manifest'+sha(rd/'source_snapshot/inputs.json')+'，进程'+json.dumps(procs)+'。r1搜索24帧/42记录与UI4栅格3686400像素已PASS，实际HDMI测试需要沿用原厂GSR/glbl顶层（r2runner修复，无输入/期望变化）。r0综合发现u_publish_display/u_wb_process两个已无显示消费者的邮箱被优化掉，原六条max_delay失配，不能交付。r2仅删这六个失效命令，其余32条max_delay、两个vendor约束、Gray8ns预算/时钟/I/O不变，重新实际布线；旧轮保存。\n';q.write_text(t,encoding='utf-8')
print(json.dumps(dict(manifest=sha(rd/'source_snapshot/inputs.json'),processes=procs),indent=2))
