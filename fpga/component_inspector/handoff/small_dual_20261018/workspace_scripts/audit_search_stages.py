from pathlib import Path
from collections import Counter
import hashlib,json,re
root=Path.cwd();p=root/'fpga/component_inspector';rd=root/'tmp/video_search_stages_r2_20261018';build_rd=root/'tmp/video_search_stages_r0_20261018';w=build_rd/'work';display_work=rd/'work'
sha=lambda q:hashlib.sha256(q.read_bytes()).hexdigest()
def read(q):
 b=q.read_bytes();return b.decode('utf-16' if b.startswith((b'\xff\xfe',b'\xfe\xff')) else 'utf-8-sig')
load=lambda q:json.loads(read(q))
previous=p/'handoff/video_search_ab_20261018';base_dir=p/'handoff/calibration_video_credit_180mm_20261017'
base=load(base_dir/'source_snapshot/inputs.json');old_inputs=load(previous/'source_snapshot/inputs.json');inputs=load(rd/'source_snapshot/inputs.json')
build_inputs=load(build_rd/'source_snapshot/inputs.json')
assert len(inputs)==len(build_inputs)==364 and len(old_inputs)==363
assert {n for n in inputs if inputs[n]!=build_inputs.get(n)}=={'sim/tb_search_stages_field.v'}
assert (rd/'source_snapshot/sim/tb_search_stages_field.v').read_bytes()==(build_rd/'source_snapshot/sim/tb_search_stages_field.v').read_bytes().replace(b'if(stage<2 && (mready || dut.result_commit || dut.metadata_pending))',b'if(stage<2 && !dut.post_start && (mready || dut.result_commit || dut.metadata_pending))').replace(b'if(dut.local_shape_detection.detector.phase!=0)work_cycles[stage]++;',b'if(!dut.post_start && dut.local_shape_detection.detector.phase!=0)work_cycles[stage]++;').replace(b'$fatal(1,"stage OFF/video coverage");',b'$fatal(1,"stage OFF/video coverage paired%0d off%0d cap%0d work%0d result%0d",paired_pixels,off_accepts,captures[0],work_cycles[0],results[0]);')
assert 'tb_search_stages_field' not in read(w/'td_project/camera_to_dsi_display.al')
production={'user_source/hdl_source/isp/isp_top.v','user_source/hdl_source/experiment_osd.v'}
test_delta={'sim/tb_hd_pins.v','sim/tb_regions_osd.v','sim/tb_search_stages_field.v','sim/run_modelsim.ps1'}
assert {n for n in inputs if inputs[n]!=old_inputs.get(n)}==production|test_delta
for n,h in inputs.items():
 assert sha(rd/'source_snapshot'/n)==h,n
 if n.startswith(('user_source/','sim/')) and not n.endswith('.log'):
  assert sha(display_work/n)==h,n
  assert sha(w/n)==build_inputs[n],n
 if n!='sim/tb_search_stages_field.v':assert build_inputs[n]==h,n
for n,h in base.items():
 if n.startswith('user_source/') and n!='user_source/hdl_source/experiment_osd.v':assert sha(p/n)==h,n
assert sha(p/'user_source/hdl_source/experiment_osd.v')==load(p/'handoff/video_clean_stats_20261018/validation/baseline.json')['normal_live_osd_sha256']
assert sha(w/'td_project/camera_to_dsi_display.sdc')==base['td_project/camera_to_dsi_display.sdc']
assert load(display_work/'replay_sim.result.json')['exit_code']==0 and 'PASS ModelSim: all 3 tests' in read(display_work/'replay_sim.log')
assert load(build_rd/'sim_interrupted.json')['status']=='INTERRUPTED_NOT_PASS'
r1=root/'tmp/video_search_stages_r1_20261018'
assert load(r1/'work/replay_sim.result.json')['exit_code']==1 and 'Fatal: stage OFF/video coverage' in read(r1/'work/sim/modelsim_work/search_stages_field/console.log')
assert all(sha(r1/'source_snapshot'/n)==h for n,h in load(r1/'source_snapshot/inputs.json').items())
tests=[]
for name in ['search_stages_field','hd_pins','regions_osd']:
 run_work=display_work
 q=run_work/'sim/modelsim_work'/name/'console.log';s=read(q)
 assert 'PASS ' in s and 'Errors: 0,' in s and not re.search(r'\*\* (?:Error|Fatal):',s),name
 tests.append(dict(name=name,status='PASS',console_sha256=sha(q),run_round=rd.name,source_manifest_sha256=sha(rd/'source_snapshot/inputs.json')))
field=read(display_work/'sim/modelsim_work/search_stages_field/console.log')
cadence=re.findall(r'CADENCE frame=(\d+) mode=(\d+)',field)
assert cadence==[(str(i+1),str(m)) for i,m in enumerate([0,1,2,3,0,3,1,2])]
assert '6451200 identical grayscale paired pixels' in field and re.search(r'OF=0 UF=0',field)
assert len(re.findall(r'REF region cadence frame=',field))==4
stage_counts=re.findall(r'OBS stage([123]) captures(\d+) nonidle_cycles(\d+) results(\d+)',field)
assert len(stage_counts)==3 and {int(x[0]) for x in stage_counts}=={1,2,3}
assert all(int(c)==115200 and int(w)>1000 and int(r)==2 for s,c,w,r in stage_counts)
search_counts=re.search(r'OBS stages paired_pixels(\d+) off_accepts(\d+)',field)
assert search_counts and int(search_counts[1])==6451200 and int(search_counts[2])==460800
assert '8 rasters/5634048 independent pixels' in read(display_work/'sim/modelsim_work/regions_osd/console.log')
assert 'all three non-display stages suppress stale cards' in read(display_work/'sim/modelsim_work/regions_osd/console.log')
assert 'SW2+SW1 SEARCH STAGES' in read(w/'user_source/hdl_source/experiment_osd.v')
prior_audit=load(previous/'validation/final_audit.json')
runs=w/'td_project/camera_to_dsi_display_Runs';warnings={}
for stage,last in [('syn_1','opt_gate'),('phy_1','bitgen')]:
 d=runs/stage;s=read(d/'replay_build.log')
 assert load(d/'replay_build.result.json')['exit_code']==0 and (d/('.'+last+'.end.f')).exists()
 assert not re.search(r'(?m)^\w+-\d+ (?:CRITICAL-)?ERROR:',s)
 warnings[stage]=dict(Counter(re.findall(r'(?m)^(\w+-\d+) (?:CRITICAL-)?WARNING:',s)))
phy=runs/'phy_1';timing=read(phy/'camera_to_dsi_display_pr.timing');area=read(phy/'camera_to_dsi_display_phy.area')
assert 'Confidence          : Routed' in timing and 'Check Corner        : Both (Slow and Fast)' in timing
m=re.search(r'SWNS:\s*([-\d.]+)ns, STNS:\s*([-\d.]+)ns\s+HWNS:\s*([-\d.]+)ns, HTNS:\s*([-\d.]+)ns',timing);assert m
v=list(map(float,m.groups()));assert min(v)>=0 and v[1]==v[3]==0
assert all(int(n)==0 for n in re.findall(r'(\d+) Viol Endpoints',timing))
resources={}
for n in ['slice','eram','dsp','pll']:
 m=re.search(r'^#'+n+r'\*?\s+(\d+)\s+out of\s+(\d+)\s+([\d.]+)%',area,re.M);assert m,n
 resources[n]=dict(used=int(m[1]),total=int(m[2]),percent=float(m[3]));assert int(m[1])<=int(m[2])
assert resources['slice']['percent']<=80
assert resources['eram']['used']<=104 and resources['dsp']['used']<=26
a=w/'audit_v3';s=read(a/'exceptions.timing').split('MCP/SMD Details')[0]
rows=[(int(m[1]),int(m[2]),int(m[3]),int(m[4]),m[5]) for m in re.finditer(r'^\s*(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(set_max_delay .+)$',s,re.M)]
commands=re.findall(r'^set_max_delay .+$',read(w/'td_project/camera_to_dsi_display.sdc'),re.M)
assert len(commands)==38 and len(rows)==40 and all(n>0 and i==0 for n,d,ss,i,c in rows)
assert set(commands)<={c for n,d,ss,i,c in rows}
ptr=next(c for c in commands if 'continuous_processing*bridge/write_gray' in c)
counts=next(r[:4] for r in rows if r[4]==ptr);assert counts[0]==counts[1] and counts[0]>=20 and counts[2:]==(0,0)
log=read(w/'routed_audit.log');assert not re.search(r'(?m)^\w+-\d+ (?:CRITICAL-)?ERROR:',log)
assert read(w/'routed_audit_exit.txt').strip()=='0'
bindings=re.findall(r'^GRAY_BIND (write|read) (\d+) SOURCE \{([^}]+)\} DESTINATION \{([^}]+)\}',log,re.M)
assert len(bindings)==20 and len({(d,int(b)) for d,b,src,dst in bindings})==20
gray=[]
for d,b,src,dst in bindings:
 s=read(a/f'gray_{d}_{b}.timing');ss=[t for t in s.split('Path Group') if ptr in t and 'Type           :     SMD' in t]
 assert len(ss)==1 and src in ss[0] and dst in ss[0] and 'Budget              : 8.000ns' in ss[0]
 slack=float(re.search(r'Slack\s*:\s*([-\d.]+)ns',ss[0])[1]);assert slack>=0
 gray.append(dict(direction=d,bit=int(b),source=src,destination=dst,budget_ns=8,slack_ns=slack))
fanout={}
for f in a.glob('gray_fanout_*.timing'):
 for chunk in read(f).split('Path Group')[1:]:
  if ptr not in chunk or 'Type           :     SMD' not in chunk:continue
  matches=list(re.finditer(r'^Slack\s*:\s*([-\d.]+)ns',chunk,re.M))
  for i,m in enumerate(matches):
   part=chunk[m.start():matches[i+1].start() if i+1<len(matches) else len(chunk)]
   src=re.search(r'^Begin Point\s*:\s*(\S+)',part,re.M)[1];dst=re.search(r'^End Point\s*:\s*(\S+)',part,re.M)[1]
   budget=float(re.search(r'^Budget\s*:\s*([-\d.]+)ns',part,re.M)[1]);slack=float(m[1]);assert budget==8 and slack>=0
   fanout[(src,dst)]=dict(source=src,destination=dst,budget_ns=budget,slack_ns=slack)
assert len(fanout)>=20
coverage=read(a/'constraint_coverage.txt')
for topic in ['no clock','clock definition','invalid constraint','combinational loops','no path constraints']:assert re.search(r'checking '+topic+r'\(0\)',coverage),topic
bit=phy/'camera_to_dsi_display.bit';assert bit.stat().st_size==1789539




result=dict(status='PASS_SEARCH_STAGES_DIAGNOSTIC_SOFTWARE_ROUTED_PHYSICAL_PENDING',source_manifest_sha256=sha(rd/'source_snapshot/inputs.json'),input_count=364,build_round=build_rd.name,test_round=rd.name,build_source_manifest_sha256=sha(build_rd/'source_snapshot/inputs.json'),test_only_delta=['sim/tb_search_stages_field.v: omit new post_start pre-NBA edge from no-metadata assertion/activity counter; add actual counts to failure message; all8frames/count/pixel/result goals retained'],hardware_inputs_identical=True,tests=tests,production_delta_from_previous=sorted(production),test_delta_from_previous=sorted(test_delta),previous_diagnostic_sha256=prior_audit['bit']['sha256'],base_bit_sha256=prior_audit['base_bit_sha256'],paired_pixels=int(search_counts[1]),search_off_live_pixel_groups=int(search_counts[2]),stage_coverage=[dict(stage=int(s),capture_words=int(c),nonidle_cycles=int(w),results=int(r)) for s,c,w,r in stage_counts],nonidle_semantics='Includes FINISHED wait; not pure computation time',routed_sta=dict(setup_ns=v[0],setup_tns_ns=v[1],hold_ns=v[2],hold_tns_ns=v[3],sta_percent=float(re.search(r'STA coverage\s*:\s*([\d.]+)%',timing)[1])),resources=resources,warnings=warnings,max_delays_matched=len(rows),max_delays_ignored=0,gray_bits=gray,gray_constraint_counts=list(counts),gray_physical_paths=list(fanout.values()),sdc_changed=False,bit=dict(bytes=bit.stat().st_size,sha256=sha(bit)),hardware='NOT_PROGRAMMED_BY_ASSISTANT',meaning='Same-bit four stages {SW2,SW1}:00OFF,01CALC,10META without cards,11FULL. Same live grayscale pixels in all stages, no edge overlay; fresh VIDEO_FIRST publication and frame proof unchanged.',physical_boundary='User confirmed c03b ON jitters/OFF stable/ON jitters/OFF stable. Its combined gating does not identify which segment. This new diagnostic has not yet been field tested.',warning_boundary=prior_audit['warning_boundary'],live_production_change='No new live production edits; all changes isolated in frozen diagnostic snapshot')
(rd/'final_audit.json').write_bytes((json.dumps(result,ensure_ascii=False,indent=2)+'\n').encode('utf-8'))
print(json.dumps({k:result[k] for k in ['status','source_manifest_sha256','paired_pixels','stage_coverage','routed_sta','resources','bit']},indent=2))
