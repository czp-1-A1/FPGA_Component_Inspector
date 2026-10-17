from pathlib import Path
from collections import Counter
import hashlib,json,re,sys
root=Path.cwd();p=root/'fpga/component_inspector';rd=root/'tmp'/sys.argv[1];w=rd/'work'
sha=lambda q:hashlib.sha256(q.read_bytes()).hexdigest()
def read(q):
 b=q.read_bytes();return b.decode('utf-16' if b.startswith((b'\xff\xfe',b'\xfe\xff')) else 'utf-8-sig')
load=lambda q:json.loads(read(q))
inputs=load(rd/'source_snapshot/inputs.json');base=load(p/'handoff/calibration_pending_180mm_20261016/source_snapshot/inputs.json')
assert len(inputs)==356
for n,h in inputs.items():
 assert sha(rd/'source_snapshot'/n)==h,n
 if n.startswith(('user_source/','sim/')) and not n.endswith('.log'):assert sha(w/n)==h and sha(p/n)==h,n
assert sha(w/'td_project/camera_to_dsi_display.sdc')==base['td_project/camera_to_dsi_display.sdc']
changes=[n for n in inputs if n.startswith('user_source/') and inputs[n]!=base[n]]
assert set(changes)=={'user_source/hdl_source/roi_statistics.v','user_source/hdl_source/experiment_osd.v','user_source/hdl_source/inspection_region_config.v','user_source/hdl_source/frame_shape_search.v'}
tests=[]
for name in load(rd/'baseline.json')['tests']:
 q=w/'sim/modelsim_work'/name/'console.log';s=read(q)
 assert re.search(r'PASS .*:',s) and 'Errors: 0,' in s and not re.search(r'\*\* (?:Error|Fatal):',s),name
 tests.append(dict(name=name,status='PASS',console_sha256=sha(q)))
assert len(tests)==9 and load(w/'replay_sim.result.json')['exit_code']==0
assert 'PASS ModelSim: all 9 tests' in read(w/'replay_sim.log')
assert '11 frames, 40 checked results' in read(w/'sim/modelsim_work/field180/console.log')
assert '9 full frames, 27 records' in read(w/'sim/modelsim_work/cal180_holes/console.log')
hole=load(rd/'independent_hole_reference.json');ref=load(rd/'independent_calibration_chain.json')
assert hole['status']==ref['status']=='PASS' and len(ref['frames'])==5
field_log=read(w/'sim/modelsim_work/field_chain/console.log')
assert 'PASS field chain:' in field_log and '27-FPS' in field_log
cadence=[(int(f),float(active),float(latency)) for f,active,latency in re.findall(r'CADENCE frame=(\d+).*?active_ns=([\d.]+).*?result_after_FE_ns=([-\d.]+)',field_log)]
assert len(cadence)==7
latencies=[lat for f,active,lat in cadence if lat>0];tail_budget=37037000-max(active for f,active,lat in cadence)
assert len(latencies)==5 and max(latencies)<tail_budget
unit_log=read(w/'sim/modelsim_work/field180/console.log')
field_cycles=[int(c) for c in re.findall(r'REF field pattern=(?:3|5) .*? cycles=(\d+)',unit_log)]
assert len(field_cycles)==2 and max(field_cycles)<=120000
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
assert resources['eram']['used']==104 and resources['dsp']['used']==26
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
result=dict(status='PASS_FIELD180_TRIAL_SOFTWARE_ROUTED_PHYSICAL_VALIDATION_PENDING',base_commit='ae04f76db1e6c28441d30b375be9f9c04b6fbba4',source_manifest_sha256=sha(rd/'source_snapshot/inputs.json'),input_count=356,production_changes=changes,build_round=rd.name,test_round=rd.name,field_failure_history=['r0 fixed tests failed32, slope743786cycles','r1 classification corrected, deadline242378cycles failed','r2/r3 fixed26FPS synthetic deadline192266cycles; phase_r0 adds failing smallest-hole phase case','r4 phase fixed, real26FPS slope2.22ms; routed SWNS-0.099/TNS-1.31ns fail','r6 reverse scan122436cycles still fails27FPS margin','r8 capture back-certification and pipelined region/distance; expected slope83920cycles under tighter27FPS test'],field_scope='Candidate selection/classification/runtime fixes; no temporal hold, no new row tracker; physical regression pending',field_runtime=dict(unit_slope_cycles=field_cycles,processing_clock_mhz=100,real_chain_fps=27,real_chain_tail_budget_ns=tail_budget,real_chain_result_latency_ns=latencies),sdc_changed=False,metadata_bits=631,tests=tests,independent_hole_reference=hole,independent_calibration_reference=ref,td_version='6.2.168116',routed_sta=dict(setup_ns=v[0],setup_tns_ns=v[1],hold_ns=v[2],hold_tns_ns=v[3],sta_percent=float(re.search(r'STA coverage\s*:\s*([\d.]+)%',timing)[1])),resources=resources,warnings=warnings,max_delays_matched=len(rows),max_delays_ignored=0,gray_bits=gray,gray_constraint_counts=list(counts),gray_physical_paths=list(fanout.values()),bit=dict(bytes=bit.stat().st_size,sha256=sha(bit)),hardware='NOT_PROGRAMMED_BY_ASSISTANT_PHYSICAL_CLASSIFICATION_PENDING',resource_assessment='Temporary CAL candidate: Slice above80% pauses further features. Shared engine and bounded small-hole RAM are already used. No new quality subclass/model is added. Remove CAL logic only after physical verification, then rebuild and assess final resource/timing again.',warning_boundary='Historical local camera routing, PLL/DDR feedback and I/O delay coverage limits remain. No all-interface timing-proof or zero-warning claim.',quality_scope='9 supplied screen photos inventoried; unified placement-abnormal label accepted, not yet implemented as a validated visual classifier')
(rd/'final_audit.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({k:result[k] for k in ['status','source_manifest_sha256','routed_sta','resources','bit']},indent=2))
