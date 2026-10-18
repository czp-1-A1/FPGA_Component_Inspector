from pathlib import Path
import hashlib,json,shutil,subprocess,sys
r=Path.cwd();old=r/'tmp/small_dual_handoff_negative_20261018';rd=r/'tmp/small_dual_r3_20261018'
sha=lambda q:hashlib.sha256(q.read_bytes()).hexdigest()
for n in ['source_snapshot','scripts']:shutil.copytree(old/n,rd/n)
shutil.copy2(r/'tmp/small_dual_r2_20261018/baseline.json',rd/'baseline.json')
q=rd/'source_snapshot/user_source/hdl_source/frame_shape_search.v';t=q.read_text('utf-8')
anchor='localparam SLOTS=REGIONS && !LANE_SINGLE ? 4 : 2;'
extra='''
// Preference only: every output still comes from this frame's measured contour.
// Within the central80-pixel band, a current candidate within32 pixels of the
// preceding selection wins over a similarly valid neighbor. Release outside
// this band permits the next horizontal pocket to take over without starvation.
reg [10:0] previous_x[0:1],previous_y[0:1];reg [1:0] previous_valid;
reg candidate_follow;reg follow_bank[0:SLOTS-1];
wire [10:0] follow_dx=center_x>previous_x[candidate_region] ? center_x-previous_x[candidate_region] : previous_x[candidate_region]-center_x;
wire [10:0] follow_dy=center_y>previous_y[candidate_region] ? center_y-previous_y[candidate_region] : previous_y[candidate_region]-center_y;
'''
assert t.count(anchor)==1;t=t.replace(anchor,anchor+extra)
oldexpr='''((candidate_preferred==(state_bank[bank0]>=2)) && (distance<distance_bank[bank0] ||
 (distance==distance_bank[bank0] && component_count>count_bank[bank0])));'''
newexpr='''((candidate_preferred==(state_bank[bank0]>=2)) &&
 ((candidate_follow && !follow_bank[bank0]) || ((candidate_follow==follow_bank[bank0]) &&
 (distance<distance_bank[bank0] || (distance==distance_bank[bank0] && component_count>count_bank[bank0])))));'''
assert oldexpr in t;t=t.replace(oldexpr,newexpr)
t=t.replace('found_bank[bank1]<=1;distance_bank[bank1]<=distance_bank[bank0];','follow_bank[bank1]<=follow_bank[bank0];found_bank[bank1]<=1;distance_bank[bank1]<=distance_bank[bank0];')
t=t.replace('found_bank[bank0]<=1;distance_bank[bank0]<=distance;','follow_bank[bank0]<=candidate_follow;found_bank[bank0]<=1;distance_bank[bank0]<=distance;')
t=t.replace('found_bank[bank1]<=1;distance_bank[bank1]<=distance;','follow_bank[bank1]<=candidate_follow;found_bank[bank1]<=1;distance_bank[bank1]<=distance;')
t=t.replace('small_pass<=0;ready<=0;sample_new<=0;located<=0;state<=1;review_required<=0;objects<=0;region_objects<=0;foreground_count<=0;box_width<=0;box_height<=0;',
 'previous_valid<=0;candidate_follow<=0;for(bi=0;bi<2;bi=bi+1)begin previous_x[bi]<=0;previous_y[bi]<=0;end\n  small_pass<=0;ready<=0;sample_new<=0;located<=0;state<=1;review_required<=0;objects<=0;region_objects<=0;foreground_count<=0;box_width<=0;box_height<=0;')
t=t.replace('state_bank[bi]<=0;reason_bank[bi]<=0;','state_bank[bi]<=0;reason_bank[bi]<=0;follow_bank[bi]<=0;')
t=t.replace('if(frame_start || invalidate)begin small_pass<=0;', 'if(frame_start || invalidate)begin if(invalidate)previous_valid<=0;small_pass<=0;')
t=t.replace('distance<=distance_now;',"distance<=distance_now;\n     candidate_follow<=REGIONS && LANE_SINGLE && previous_valid[candidate_region] && dx<=40 && ({1'b0,follow_dx}+follow_dy)<=32;")
t=t.replace('PUBLISH:begin\n', '''PUBLISH:begin
     if(REGIONS && LANE_SINGLE)for(bi=0;bi<2;bi=bi+1)begin
      previous_valid[bi]<=found_bank[bi] && state_bank[bi]>=2;
      previous_x[bi]<={1'b0,xmin_bank[bi]}+xmax_bank[bi];previous_y[bi]<={1'b0,ymin_bank[bi]}+ymax_bank[bi];
     end
''')
q.write_text(t,encoding='utf-8')
m=json.loads((rd/'source_snapshot/inputs.json').read_text('utf-8'))
for n in m:m[n]=sha(rd/'source_snapshot'/n)
(rd/'source_snapshot/inputs.json').write_text(json.dumps(m,indent=2)+'\n',encoding='utf-8')
baseline=json.loads((rd/'baseline.json').read_text('utf-8'));baseline['handoff_preference']=dict(central_halfwidth_processing_px=40,match_manhattan_processing_px=32,holds_old_results=False,cleared_by_invalidate=True,new_reg_bits='2x11-bit previous x/y plus2 valid and per-candidate preference; compile eliminated outside lane mode')
(rd/'baseline.json').write_text(json.dumps(baseline,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
cmd=[sys.executable,'-X','utf8',str(rd/'scripts/replay.py')];common=['--work',str(rd/'work'),'--td-root','D:/AAA/FPGA.....YZW']
subprocess.run(cmd+['--action','prepare',*common],check=True);procs={}
for action,extra in [('sim',['--modelsim-bin','D:/modelsim/win64']),('build',[])]:
 with (rd/(action+'.log')).open('w',encoding='utf-8') as out,(rd/(action+'.err')).open('w',encoding='utf-8') as err:z=subprocess.Popen(cmd+['--action',action,*common,*extra],stdout=out,stderr=err,creationflags=0x08000000)
 procs[action]=z.pid
(rd/'processes.json').write_text(json.dumps(procs,indent=2)+'\n',encoding='utf-8')
q=r/'AGENTS.md';t=q.read_text('utf-8');t+='\n- r3补充交接防抢框：r2空间最近策略的4px往返双目标身份反例单独冻结为small_dual_handoff_negative_20261018（不得改其输入/期望），必须复现frame2切换。r3仅加当前测量候选优先：中央±40px内、与前次完整选择曼哈顿≤32px时优先同一目标，离开中央带交给下一件；不保留旧框/旧结果，invalidate撤销优先。新lane_handoff7帧14记录，连同原13共14测试。r3manifest'+sha(rd/'source_snapshot/inputs.json')+'，进程'+json.dumps(procs)+'；r0/r1/r2证据均保留。\n';q.write_text(t,encoding='utf-8')
print(json.dumps(dict(manifest=sha(rd/'source_snapshot/inputs.json'),processes=procs),indent=2))
