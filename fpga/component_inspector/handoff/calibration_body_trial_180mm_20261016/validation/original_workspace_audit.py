from pathlib import Path
from collections import Counter
import hashlib,json,re

root=Path.cwd();p=root/'fpga/component_inspector';rd=root/'tmp/body180_r2_20261016';work=rd/'work'
base=p/'handoff/calibration_pending_180mm_20261016'
build_rd=root/'tmp/body180_r1_20261016';build_work=build_rd/'work'
def read(q):
 b=q.read_bytes();return b.decode('utf-16' if b.startswith((b'\xff\xfe',b'\xfe\xff')) else 'utf-8-sig')
load=lambda q:json.loads(read(q));sha=lambda q:hashlib.sha256(q.read_bytes()).hexdigest()
inputs=load(rd/'source_snapshot/inputs.json');prior=load(base/'source_snapshot/inputs.json')
assert len(inputs)==353
for name,want in inputs.items():
 assert sha(rd/'source_snapshot'/name)==want,name
 if name.startswith(('user_source/','sim/')) and not name.endswith('.log'):
  assert sha(p/name)==want and sha(work/name)==want,name
changed=[n for n in inputs if n.startswith('user_source/') and inputs[n]!=prior[n]]
assert set(changed)=={'user_source/hdl_source/roi_statistics.v','user_source/hdl_source/experiment_osd.v','user_source/hdl_source/inspection_region_config.v'},changed
assert sha(work/'td_project/camera_to_dsi_display.sdc')==prior['td_project/camera_to_dsi_display.sdc']
tests=['cal180_body','local_wait','calibration_chain','regions_osd','regions']
evidence=[]
for name in tests:
 q=work/'sim/modelsim_work'/name/'console.log';s=read(q)
 assert re.search(r'PASS .*:',s) and 'Errors: 0,' in s and not re.search(r'\*\* (?:Error|Fatal):',s),name
 evidence.append({'name':name,'status':'PASS','console_sha256':sha(q)})
assert 'old-minimum counterfactual' in read(work/'sim/modelsim_work/cal180_body/console.log')
assert 'zero-mask and one-cell not EMPTY' in read(work/'sim/modelsim_work/cal180_body/console.log')
assert load(work/'replay_sim.result.json')['exit_code']==0 and 'PASS ModelSim: all 5 tests' in read(work/'replay_sim.log')
repro=root/'tmp/body180_repro_r0_20261016/work/sim/modelsim_work/cal180_body/console.log'
assert '** Fatal: measured body class pattern0 slot0 got1 expected2' in read(repro)
reference=load(rd/'independent_calibration_chain.json');assert reference['status']=='PASS' and len(reference['frames'])==5
build_inputs=load(build_rd/'source_snapshot/inputs.json')
assert set(build_inputs)==set(inputs)
assert [n for n in inputs if inputs[n]!=build_inputs[n]]==['sim/tb_cal180_body.v']
for n in inputs:
 if n.startswith('user_source/'):
  assert sha(build_rd/'source_snapshot'/n)==inputs[n] and sha(build_work/n)==inputs[n],n
assert 'measured feature mismatch slot1' in read(build_work/'sim/modelsim_work/cal180_body/console.log')
runs=build_work/'td_project/camera_to_dsi_display_Runs';warnings={};deltas={}
for stage,last in [('syn_1','opt_gate'),('phy_1','bitgen')]:
 d=runs/stage;assert read(d/'build_exit_code.txt').strip()=='0' and (d/('.'+last+'.end.f')).is_file(),stage
 s=read(d/'build_console.log');assert not re.search(r'(?m)^\w+-\d+\s+(?:CRITICAL-)?ERROR:',s)
 counts=Counter(re.findall(r'(?m)^(\w+-\d+) (?:CRITICAL-)?WARNING:',s));warnings[stage]=dict(counts)
 old=Counter(re.findall(r'(?m)^(\w+-\d+) (?:CRITICAL-)?WARNING:',read(base/'build_evidence'/stage/'build_console.log')))
 deltas[stage]={'added':dict(counts-old),'removed':dict(old-counts)}
phy=runs/'phy_1';timing=read(phy/'camera_to_dsi_display_pr.timing');area=read(phy/'camera_to_dsi_display_phy.area')
assert 'Confidence          : Routed' in timing and 'Check Corner        : Both (Slow and Fast)' in timing
m=re.search(r'SWNS:\s*([-\d.]+)ns, STNS:\s*([-\d.]+)ns\s+HWNS:\s*([-\d.]+)ns, HTNS:\s*([-\d.]+)ns',timing);assert m
v=list(map(float,m.groups()));assert min(v)>=0 and v[1]==v[3]==0
assert all(int(n)==0 for n in re.findall(r'(\d+) Viol Endpoints',timing))
resources={}
for name in ['slice','eram','dsp','pll']:
 m=re.search(r'^#'+name+r'\*?\s+(\d+)\s+out of\s+(\d+)\s+([\d.]+)%',area,re.M);assert m,name
 resources[name]={'used':int(m[1]),'total':int(m[2]),'percent':float(m[3])}
assert resources['slice']['percent']<80 and resources['eram']['used']==94 and resources['dsp']['used']==26
assert all(q['used']<=q['total'] for q in resources.values())
audit=build_work/'audit_v3';summary=read(audit/'exceptions.timing').split('MCP/SMD Details')[0]
rows=[(int(m[1]),int(m[2]),int(m[3]),int(m[4]),m[5]) for m in re.finditer(r'^\s*(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(set_max_delay .+)$',summary,re.M)]
commands=re.findall(r'^set_max_delay .+$',read(work/'td_project/camera_to_dsi_display.sdc'),re.M)
assert len(commands)==38 and len(rows)==40 and all(n>0 and i==0 for n,d,s,i,c in rows)
assert set(commands)<={c for n,d,s,i,c in rows}
ptr=next(c for c in commands if 'continuous_processing*bridge/write_gray' in c)
assert next(row[:4] for row in rows if row[4]==ptr)==(22,22,0,0)
fanout=load(rd/'gray_constraint_paths.json');assert fanout['status']=='PASS' and fanout['logical_bits']==20 and fanout['constraint_matched_paths']==22 and fanout['reported_paths']==29
assert not re.search(r'(?m)^\w+-\d+ (?:CRITICAL-)?ERROR:',read(build_work/'routed_audit_v3.log'))
assert read(build_work/'routed_audit_v3_exit.txt').strip()=='0'
bindings=re.findall(r'^GRAY_BIND (write|read) (\d+) SOURCE \{([^}]+)\} DESTINATION \{([^}]+)\}',read(build_work/'routed_audit_v3.log'),re.M)
assert len(bindings)==20 and len({(d,int(b)) for d,b,s,e in bindings})==20
gray=[]
for direction,bit,src,dst in bindings:
 text=read(audit/f'gray_{direction}_{bit}.timing')
 sections=[s for s in text.split('Path Group') if ptr in s and 'Type           :     SMD' in s]
 assert len(sections)==1 and src in sections[0] and dst in sections[0] and 'Budget              : 8.000ns' in sections[0]
 slack=float(re.search(r'Slack\s*:\s*([-\d.]+)ns',sections[0])[1]);assert slack>=0
 gray.append({'direction':direction,'bit':int(bit),'source':src,'destination':dst,'budget_ns':8,'slack_ns':slack})
coverage=read(audit/'constraint_coverage.txt')
for topic in ['no clock','clock definition','invalid constraint','combinational loops','no path constraints']:
 assert re.search(r'checking '+topic+r'\(0\)',coverage),topic
bit=phy/'camera_to_dsi_display.bit';assert bit.stat().st_size==1789539
result={'status':'PASS_BODY_MINIMUM_TRIAL_SOFTWARE_ROUTED_PHYSICAL_CLASSIFICATION_PENDING','base_commit':'ae04f76db1e6c28441d30b375be9f9c04b6fbba4',
 'source_commit_at_build':None,'source_manifest_sha256':sha(rd/'source_snapshot/inputs.json'),'input_count':353,'build_source_manifest_sha256':sha(build_rd/'source_snapshot/inputs.json'),'build_round':'r1','test_round':'r2','production_identical_between_rounds':True,'production_changes':changed,
 'measurement_window':32,'core_window':16,'thresholds':[100,80,120,140],'metadata_bits':631,'classifier_changed':True,'recipe_delta':{'body_long_min':[26,22],'body_short_min':[20,18],'other_fields_changed':False,'basis':'CAL64 observed internal long22/23 short18; observed minima only, no new tolerance inferred'},'sdc_changed':False,
 'tests':evidence,'independent_calibration_reference':reference,'td_version':'6.2.168116','routed_sta':{'setup_ns':v[0],'hold_ns':v[2],'setup_tns_ns':v[1],'hold_tns_ns':v[3],'sta_percent':float(re.search(r'STA coverage\s*:\s*([\d.]+)%',timing)[1])},
 'resources':resources,'warnings':warnings,'warning_count_delta_from_ae_observer':deltas,'max_delays_matched':40,'max_delays_ignored':0,'gray_bits':gray,'gray_physical_report':fanout,
 'warning_boundary':'Historical camera-output local routing, PLL feedback, and incomplete I/O-delay coverage remain; review clock-net identities in actual logs. No all-interface timing-proof claim.',
 'bit':{'bytes':bit.stat().st_size,'sha256':sha(bit)},'hardware':'NO_JTAG_OR_FLASH_PHYSICAL_DATA_PENDING',
 'scope':'Body-minimum-only trial because user is away from board; T100, maxima, empty/feed/ref unchanged. CAL32 retained. Not a complete180mm calibration or physical-accuracy claim.'}
(rd/'final_audit.json').write_bytes((json.dumps(result,ensure_ascii=False,indent=2)+'\n').encode('utf-8'))
print(json.dumps({k:result[k] for k in ['status','routed_sta','resources','bit']},indent=2))
