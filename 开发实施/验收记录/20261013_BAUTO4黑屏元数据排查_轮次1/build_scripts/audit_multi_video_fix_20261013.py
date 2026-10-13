from pathlib import Path
from collections import Counter
import json,re,hashlib
root=Path(__file__).resolve().parent.parent;project=root/'fpga/component_inspector'
build=root/'tmp/multi_video_fix_r2_20261013';prior=root/'tmp/multi_pocket_r5_td_20261012'
read=lambda p:p.read_text(encoding='utf-8-sig',errors='replace')
load=lambda p:json.loads(read(p));sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
inputs=load(build/'inputs.json')
for e in inputs:assert sha(build/e['path'])==e['sha256']==sha(project/e['path']),e['path']
for name in ['stage_inputs.json','simulation_inputs.json']:
 for e in load(build/name):assert sha(build/e['path'])==e['sha256'],e['path']
old={e['path']:e['sha256'] for e in load(prior/'inputs.json')}
changed=[e['path'] for e in inputs if old[e['path']]!=e['sha256']]
assert sorted(changed)==sorted(['user_source/hdl_source/video_in.v','user_source/hdl_source/design_top_wrapper.v','user_source/hdl_source/experiment_osd.v'])
assert sha(build/'td_project/camera_to_dsi_display.sdc')==sha(prior/'td_project/camera_to_dsi_display.sdc')
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
assert resources['slice']['percent']<=75
assert resources['eram']['used']==48 and resources['dsp']['used']==8
exception=read(phy/'camera_to_dsi_display_exception.timing').split('MCP/SMD Details')[0]
delays=[(int(m[1]),int(m[2]),m[3]) for m in re.finditer(r'^\s*(\d+)\s+\d+\s+\d+\s+(\d+)\s+(set_max_delay .+)$',exception,re.M)]
assert len(delays)==37 and all(total>0 and ignored==0 for total,ignored,_ in delays)
bit=phy/'camera_to_dsi_display.bit'
audit=dict(status='PASS_routed_build_software_tests_pending',onsite='PENDING',changed_inputs=changed,unchanged_inputs=208,
 timing=metrics,resources=resources,warnings=warnings,warning_deltas=deltas,max_delays_declared=37,max_delays_matched=37,max_delays_ignored=0,
 sdc_unchanged=True,bit=dict(bytes=bit.stat().st_size,sha256=sha(bit)))
(build/'build_audit.json').write_text(json.dumps(audit,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps(audit,ensure_ascii=False,indent=2))
