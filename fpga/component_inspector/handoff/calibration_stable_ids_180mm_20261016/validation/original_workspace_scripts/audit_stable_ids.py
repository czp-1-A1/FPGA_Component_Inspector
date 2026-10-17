from pathlib import Path
from collections import Counter
import hashlib,json,re,sys
root=Path.cwd();p=root/'fpga/component_inspector';rd=root/'tmp'/sys.argv[1];w=rd/'work'
sha=lambda q:hashlib.sha256(q.read_bytes()).hexdigest()
def read(q):
 b=q.read_bytes();return b.decode('utf-16' if b.startswith((b'\xff\xfe',b'\xfe\xff')) else 'utf-8-sig')
load=lambda q:json.loads(read(q))
inputs=load(rd/'source_snapshot/inputs.json');base=load(p/'handoff/calibration_pending_180mm_20261016/source_snapshot/inputs.json')
assert len(inputs)==358
for n,h in inputs.items():
 assert sha(rd/'source_snapshot'/n)==h,n
 if n.startswith(('user_source/','sim/')) and not n.endswith('.log'):assert sha(w/n)==h and sha(p/n)==h,n
assert sha(w/'td_project/camera_to_dsi_display.sdc')==base['td_project/camera_to_dsi_display.sdc']
changes=[n for n in inputs if n.startswith('user_source/') and inputs[n]!=base[n]]
assert set(changes)=={'user_source/hdl_source/roi_statistics.v','user_source/hdl_source/experiment_osd.v','user_source/hdl_source/inspection_region_config.v','user_source/hdl_source/frame_shape_search.v'}
previous=p/'handoff/calibration_pose_trial_180mm_20261016'
prior=load(previous/'source_snapshot/inputs.json')
delta=[n for n in inputs if n not in prior or inputs[n]!=prior[n]]
assert set(delta)=={'user_source/hdl_source/experiment_osd.v','sim/tb_calibration_osd.v','sim/run_modelsim.ps1','sim/tb_stable_ids_osd.v'}
tests=[]
for name in ['calibration_osd','regions_osd','stable_ids_osd']:
 q=w/'sim/modelsim_work'/name/'console.log';s=read(q)
 assert 'PASS ' in s and 'Errors: 0,' in s and not re.search(r'\*\* (?:Error|Fatal):',s),name
 tests.append(dict(name=name,status='PASS',console_sha256=sha(q)))
assert load(w/'replay_sim.result.json')['exit_code']==0 and 'PASS ModelSim: all 3 tests' in read(w/'replay_sim.log')
assert 'fixed yellow16px pink32px and old64px outlines absent' in read(w/'sim/modelsim_work/calibration_osd/console.log')
assert 'OUT32/core16 measurement values unchanged' in read(w/'sim/modelsim_work/calibration_osd/console.log')
assert '5 rasters/3498240 independent pixels' in read(w/'sim/modelsim_work/regions_osd/console.log')
assert 'weak-gray FIT CHK' in read(w/'sim/modelsim_work/regions_osd/console.log')
prior_audit=load(previous/'validation/final_audit.json')
assert prior_audit['source_manifest_sha256']==sha(previous/'source_snapshot/inputs.json') and len(prior_audit['tests'])==10
for t in prior_audit['tests']:assert sha(previous/'validation/tests'/t['name']/'console.log')==t['console_sha256']
stable_log=read(w/'sim/modelsim_work/stable_ids_osd/console.log')
assert '16 states, 2 full rasters/39936 independent number-summary pixels' in stable_log
red=root/'tmp/stable_ids_repro_r2_20261016';red_inputs=load(red/'source_snapshot/inputs.json')
assert [n for n in inputs if inputs[n]!=red_inputs[n]]==['user_source/hdl_source/experiment_osd.v']
assert load(red/'work/replay_sim.result.json')['exit_code']!=0
assert 'Fatal: stable IDs regression: 7338 failures' in read(red/'work/sim/modelsim_work/stable_ids_osd/console.log')
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
result=dict(status='PASS_STABLE_IDS_SOFTWARE_ROUTED_PHYSICAL_VALIDATION_PENDING',base_commit=prior_audit['base_commit'],source_manifest_sha256=sha(rd/'source_snapshot/inputs.json'),input_count=358,build_round=rd.name,test_round=rd.name,display_match_pipeline_clocks=4,failed_timing_round='stable_ids_r1_20261016 setup-1.037ns; not delivered',production_changes_from_previous=['user_source/hdl_source/experiment_osd.v'],test_changes_from_previous=['sim/tb_calibration_osd.v','sim/run_modelsim.ps1','sim/tb_stable_ids_osd.v'],tests=tests,previous_validation=dict(source_manifest_sha256=prior_audit['source_manifest_sha256'],tests=prior_audit['tests'],field_runtime=prior_audit['field_runtime'],scope='Prior revision ten tests and27FPS chain retained as provenance, not rerun or claimed against this UI-only snapshot. All detector,recipe,measurement,video/CDC/SDC sources byte-identical.'),td_version='6.2.168116',routed_sta=dict(setup_ns=v[0],setup_tns_ns=v[1],hold_ns=v[2],hold_tns_ns=v[3],sta_percent=float(re.search(r'STA coverage\s*:\s*([\d.]+)%',timing)[1])),resources=resources,warnings=warnings,max_delays_matched=len(rows),max_delays_ignored=0,gray_bits=gray,gray_constraint_counts=list(counts),gray_physical_paths=list(fanout.values()),sdc_changed=False,bit=dict(bytes=bit.stat().st_size,sha256=sha(bit)),hardware='NOT_PROGRAMMED_BY_ASSISTANT',change='Match current display records to previous positions per zone; remove ambiguous bottom-left recent sample summary and fixed16x16 core paint. Never hold missing targets or old state/reason. Preserve detector/recipe/video/CDC/SDC.',display_matching=dict(max_manhattan_processing_px=32,acquisition_vertical_x_band_px=16,persistent_tape_identity=False),regression_repro=dict(source_manifest_sha256=sha(red/'source_snapshot/inputs.json'),fatal='7338 failures',same_test_truth=True),quality_display='PRESENT retains 有件. Nonzero reason is yellow with SIZE/ASP/FILL/REF;0xF is FIT CHK/REVIEW. These are review diagnostics, not a confirmed quality-defect subtype.',warning_boundary=prior_audit['warning_boundary'],resource_assessment='Required display-jitter correction only, no new image RAM or detector architecture. Internal80% budget still limits feature expansion.')
(rd/'final_audit.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({k:result[k] for k in ['status','source_manifest_sha256','routed_sta','resources','bit']},indent=2))
