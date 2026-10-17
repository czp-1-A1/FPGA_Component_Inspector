from pathlib import Path
from collections import Counter
import hashlib,json,re
root=Path.cwd();p=root/'fpga/component_inspector';rd=root/'tmp/base_jitter_creditfix_r15_20261017';build_rd=root/'tmp/base_jitter_creditfix_r13_20261017';w=build_rd/'work'
sha=lambda q:hashlib.sha256(q.read_bytes()).hexdigest()
def read(q):
 b=q.read_bytes();return b.decode('utf-16' if b.startswith((b'\xff\xfe',b'\xfe\xff')) else 'utf-8-sig')
load=lambda q:json.loads(read(q))
inputs=load(rd/'source_snapshot/inputs.json');previous=p/'handoff/calibration_stable_ids_180mm_20261016';base=load(previous/'source_snapshot/inputs.json')
assert len(inputs)==360
production=['user_source/hdl_source/awb.v','user_source/hdl_source/signal_delay.v','user_source/hdl_source/isp/demosaic_4x_2_0/zhenghe.v','user_source/hdl_source/isp/demosaic_4x_2_0/raw_matrix_3x3_buffer.v','user_source/hdl_source/isp/demosaic_4x_2_0/line_buffer_demosaic.v']
changes=[n for n in inputs if n.startswith('user_source/') and inputs[n]!=base[n]]
assert set(changes)==set(production),changes
oracle_delta={'sim/tb_isp_metadata_stop.v','sim/tb_isp_writer_stop.v'}
test_delta=[*oracle_delta,'sim/run_modelsim.ps1','sim/tb_field_chain.v','sim/tb_frame_tailproof.v','sim/tb_hd_pins.v','sim/tb_base_picture_repeatability.v','sim/tb_raw_timing_probe.v']
assert set(n for n in inputs if n.startswith('sim/') and inputs[n]!=base.get(n))==set(test_delta)
for n,h in inputs.items():
 assert sha(rd/'source_snapshot'/n)==h,n
 if n.startswith(('user_source/','sim/')) and not n.endswith('.log'):assert sha(p/n)==h,n
 if n.startswith(('user_source/','sim/')) and n not in oracle_delta and not n.endswith('.log'):assert sha(w/n)==h,n
build_inputs=load(build_rd/'source_snapshot/inputs.json')
assert {n for n in inputs if inputs[n]!=build_inputs[n]}==oracle_delta
for n,h in build_inputs.items():
 assert sha(build_rd/'source_snapshot'/n)==h,n
 if n.startswith(('user_source/','sim/')) and not n.endswith('.log'):assert sha(w/n)==h,n
assert sha(w/'td_project/camera_to_dsi_display.sdc')==base['td_project/camera_to_dsi_display.sdc']
tests=[]
groups={'raw':['raw_timing_probe'],'repeat':['base_picture_repeatability'],'field':['field_chain'],'safety':['frame_tailproof','isp_metadata_stop','isp_writer_stop'],'hd':['hd_pins','hd_scaled_guard','hd_resize','manual_wb','fixed_wb']}
for tag,names in groups.items():
 owner=rd if tag=='safety' else build_rd
 tw=owner/('work_'+tag)
 assert load(tw/'replay_sim.result.json')['exit_code']==0
 assert f'PASS ModelSim: all {len(names)} tests' in read(tw/'replay_sim.log')
 for n,h in inputs.items():
  if n.startswith(('user_source/','sim/')) and not n.endswith('.log') and (tag=='safety' or n not in oracle_delta):assert sha(tw/n)==h,(tag,n)
 for name in names:
  assert sha(tw/'sim'/('tb_'+name+'.v'))==inputs['sim/tb_'+name+'.v']
  q=tw/'sim/modelsim_work'/name/'console.log';s=read(q)
  assert 'PASS ' in s and 'Errors: 0,' in s and not re.search(r'\*\* (?:Error|Fatal):',s),name
  assert not re.search(r'DIFF static|PROBE_DIFF|REPACK_DIFF',s),name
  tests.append(dict(name=name,status='PASS',work_tag=tag,source_round=owner.name,console_sha256=sha(q)))
repeat=read(build_rd/'work_repeat/sim/modelsim_work/base_picture_repeatability/console.log')
assert 'cold plus5 full FHD source frames' in repeat and '3686400 identical ordered1280x720 pixels' in repeat
obs=re.findall(r'OBS static frame epoch(\d+) schedule(\d+) groups(\d+) rows(\d+) words(\d+) mismatched_groups(\d+)',repeat)
assert [(int(a),int(b)) for a,b,*_ in obs]==[(1,0),(2,0),(3,1),(4,2),(5,3),(6,0)]
assert all(tuple(map(int,c))==(230400,720,172800,0) for _,_,*c in obs)
nominal=build_rd/'work_repeat/sim/static_baseline_rgb.txt';legacy=root/'tmp/base_jitter_diagnostics_r3_20261017/work_repeat/sim/static_baseline_rgb.txt'
assert nominal.read_bytes()==legacy.read_bytes() and len(nominal.read_text().splitlines())==230400
field=read(build_rd/'work_field/sim/modelsim_work/field_chain/console.log')
assert 'OF=0 UF=0' in field and len(re.findall(r'CADENCE frame=',field))==7
fm=re.search(r'full exact RGB rasters=(\d+) pixels=(\d+)',field);assert fm and int(fm[1])>=4 and int(fm[2])>=3686400
transitions=load(build_rd/'transitions/results.json');assert len(transitions)==21 and all(t['status']=='PASS' for t in transitions)
assert {(t['previous'],t['schedule']) for t in transitions if 'previous' in t}=={(a,b) for a in range(4) for b in range(4)}
assert {t['extra'] for t in transitions if 'extra' in t}=={0,8,32,64,128}
for t in transitions:
 q=build_rd/t['log'];s=read(q);assert 'PASS raw timing probe:' in s and not re.search(r'\*\* (?:Error|Fatal):',s)
 lines=[z for z in s.splitlines() if 'PROBE frame' in z];assert len(lines)==3
 assert all(re.search(r'outputs26880 diffs0 first-1 last-1 repack_groups26880 repack_changed0 repack_wrong0 baseline_wrong0',z) for z in lines)
 t['console_sha256']=sha(q)
red=root/'tmp/base_jitter_diagnostics_r3_20261017';redlog=read(red/'work_repeat/sim/modelsim_work/base_picture_repeatability/console.log')
assert 'Fatal: stationary RAW differs: 14813 groups' in redlog
assert 'DIFF static epoch3 x1196 y0' in redlog
negative_truth=load(root/'tmp/base_jitter_20261017/full_fhd_repeatability.json')
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

result=dict(status='PASS_RAW_VIDEO_CREDIT_SOFTWARE_ROUTED_PHYSICAL_VALIDATION_PENDING',base_commit='4556e9a99f3ce720f2d58e3f86619c0a625fdc5b',source_manifest_sha256=sha(rd/'source_snapshot/inputs.json'),input_count=360,build_round=rd.name,tests=tests,production_changes_from_previous=production,test_changes_from_previous=test_delta,td_version='6.2.168116',routed_sta=dict(setup_ns=v[0],setup_tns_ns=v[1],hold_ns=v[2],hold_tns_ns=v[3],sta_percent=float(re.search(r'STA coverage\s*:\s*([\d.]+)%',timing)[1])),resources=resources,warnings=warnings,max_delays_matched=len(rows),max_delays_ignored=0,gray_bits=gray,gray_constraint_counts=list(counts),gray_physical_paths=list(fanout.values()),sdc_changed=False,bit=dict(bytes=bit.stat().st_size,sha256=sha(bit)),hardware='NOT_PROGRAMMED_BY_ASSISTANT',change='Read committed current-frame pixels, preserve matrix neighbors across bubbles, qualify line-buffer valid by actual read requests and count AWB EOL by accepted groups. Five RTL files; no new memories, thresholds, gains, UI, CDC or constraints.',timing_transitions=transitions,nominal_pixels=dict(groups=230400,bytes=nominal.stat().st_size,sha256=sha(nominal),equal_to_old_nominal=True),field_runtime=dict(source_fps=27,accepted_frames=7,rasters=int(fm[1]),exact_ddr_pixels=int(fm[2]),overflows=0,underflows=0),original_repro=dict(round=red.name,source_manifest_sha256=sha(red/'source_snapshot/inputs.json'),changed_groups=14813,changed_pixels=57957,processing_bbox=[1199,0,1279,719]),physical_boundary='Reproduced right-tail corruption under changed CSI valid spacing. Phone registration mixes OIS/moire; user confirms RAW jitter. Neither reproduction nor simulations prove all field jitter has one cause. Original sensor/HDMI physical stability requires this exact new bit on-board.',warning_boundary=prior_audit['warning_boundary'],resource_assessment='Required video-integrity repair only; no new image RAM. Internal80% budget still prevents feature expansion. Existing interface timing coverage limits are retained.',osd_title='180MM STABLE IDS unchanged; identify this trial by filename/SHA')
result.update(build_round=build_rd.name,build_source_manifest_sha256=sha(build_rd/'source_snapshot/inputs.json'),test_only_changes_after_build=sorted(oracle_delta))
(rd/'final_audit.json').write_bytes((json.dumps(result,ensure_ascii=False,indent=2)+'\n').encode('utf-8'))
print(json.dumps({k:result[k] for k in ['status','source_manifest_sha256','routed_sta','resources','bit','nominal_pixels','field_runtime']},ensure_ascii=False,indent=2))
