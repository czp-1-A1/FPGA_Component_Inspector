from pathlib import Path
from collections import Counter
import json,re,hashlib,sys
root=Path(__file__).resolve().parent.parent;project=root/'fpga/component_inspector'
build=root/'tmp'/sys.argv[1];prior=root/'tmp/upper_holes_v3_r2_20261013'
read=lambda p:p.read_text(encoding='utf-8-sig',errors='replace')
load=lambda p:json.loads(read(p));sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
inputs=load(build/'inputs.json')
for e in inputs:assert sha(build/e['path'])==e['sha256']==sha(project/e['path']),e['path']
for name in ['stage_inputs.json','simulation_inputs.json']:
 for e in load(build/name):assert sha(build/e['path'])==e['sha256'],e['path']
old={e['path']:e['sha256'] for e in load(prior/'inputs.json')}
changed=[e['path'] for e in inputs if old[e['path']]!=e['sha256']]
expected=['user_source/hdl_source/design_top_wrapper.v','user_source/hdl_source/experiment_osd.v','user_source/hdl_source/isp/isp_top.v','user_source/hdl_source/roi_mode_classifier.v','td_project/camera_to_dsi_display.sdc']
assert sorted(changed)==sorted(expected),changed
current_sdc=read(build/'td_project/camera_to_dsi_display.sdc');old_sdc=read(prior/'td_project/camera_to_dsi_display.sdc')
old_commands=re.findall(r'^set_max_delay .+$',old_sdc,re.M);new_commands=re.findall(r'^set_max_delay .+$',current_sdc,re.M)
removed=[c for c in old_commands if c not in new_commands]
assert len(removed)==6 and all('*crossing/' in c or 'u_active_frame_display/' in c for c in removed)
assert all(c in old_commands for c in new_commands) and len(new_commands)==29
assert [s for s in current_sdc.splitlines() if s.strip() and not s.startswith('#') and not s.startswith('set_max_delay')]==[s for s in old_sdc.splitlines() if s.strip() and not s.startswith('#') and not s.startswith('set_max_delay')]
warnings={};deltas={}
for stage,last in [('syn_1','opt_gate'),('phy_1','bitgen')]:
 d=build/'td_project/camera_to_dsi_display_Runs'/stage
 assert read(d/'build_exit_code.txt').strip()=='0' and (d/('.'+last+'.end.f')).exists() and not list(d.glob('.*.error.f'))
 assert not re.search(r'(?m)^\w+-\d+\s+(?:CRITICAL-)?ERROR:',read(d/'build_console.log'))
 def warning_set(path):return Counter(re.sub(r'(\.v)\(\d+\)',r'\1(LINE)',s) for s in read(path).splitlines() if re.match(r'^\w+-\d+ (?:CRITICAL-)?WARNING:',s))
 current=warning_set(d/'build_console.log');previous=warning_set(prior/'td_project/camera_to_dsi_display_Runs'/stage/'build_console.log')
 warnings[stage]=sum(current.values());deltas[stage]={'added':list((current-previous).elements()),'removed':list((previous-current).elements())}
phy=build/'td_project/camera_to_dsi_display_Runs/phy_1';timing=read(phy/'camera_to_dsi_display_pr.timing')
assert 'Confidence          : Routed' in timing and 'Check Corner        : Both (Slow and Fast)' in timing
metrics={}
for key,label in [('setup_wns_ns','SWNS'),('setup_tns_ns','STNS'),('hold_wns_ns','HWNS'),('hold_tns_ns','HTNS')]:
 values=[float(v) for v in re.findall(label+r'\s*:\s*([-\d.]+)ns',timing)];assert values and all(v>=0 for v in values),(key,values)
 if 'tns' in key:assert all(v==0 for v in values)
 metrics[key]=min(values)
assert all(int(v)==0 for v in re.findall(r'(\d+) Viol Endpoints',timing))
metrics['sta_coverage_percent']=float(re.search(r'STA coverage\s*:\s*([\d.]+)%',timing)[1])
area=read(phy/'camera_to_dsi_display_phy.area');resources={}
for name in ['slice','eram','dsp']:
 m=re.search(r'^#'+name+r'\*?\s+(\d+)\s+out of\s+(\d+)\s+([\d.]+)%',area,re.M)
 resources[name]=dict(used=int(m[1]),total=int(m[2]),percent=float(m[3]))
assert resources['slice']['percent']<=75 and resources['eram']['used']<=48 and resources['dsp']['used']==8
exception=read(phy/'camera_to_dsi_display_exception.timing').split('MCP/SMD Details')[0]
delays=[(int(m[1]),int(m[2]),m[3]) for m in re.finditer(r'^\s*(\d+)\s+\d+\s+\d+\s+(\d+)\s+(set_max_delay .+)$',exception,re.M)]
unmatched=[cmd for total,ignored,cmd in delays if total==0 or ignored]
assert len(delays)==31 and not unmatched,unmatched
reported={c for _,_,c in delays};assert all(c in reported for c in new_commands)
assert len(reported-set(new_commands))==2 and all('primary_addr_gray_reg' in c for c in reported-set(new_commands))
bit=phy/'camera_to_dsi_display.bit'
audit=dict(status='PASS_routed_build_tests_pending',onsite='PENDING',changed_inputs=changed,unchanged_inputs=len(inputs)-len(changed),
 timing=metrics,resources=resources,warnings=warnings,warning_deltas=deltas,max_delays_declared=len(delays),max_delays_matched=len(delays),max_delays_ignored=0,
 sdc_active_budgets_unchanged=True,inactive_constraints_removed=removed,explicit_max_delays=29,vendor_fifo_max_delays=2,
 variant='FIXED_DIRECT_V4_GRAY_EDGE_INDEPENDENT_NO_FUSION',bit=dict(bytes=bit.stat().st_size,sha256=sha(bit)))
(build/'build_audit.json').write_text(json.dumps(audit,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps(audit,ensure_ascii=False,indent=2))
