from pathlib import Path
from collections import Counter
import json,re,hashlib

root=Path.cwd();build=root/'tmp/presence_v7_r1_20261014';prior=root/'tmp/local_v6_r11_20261014';project=root/'fpga/component_inspector'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
read=lambda p:p.read_text(encoding='utf-8-sig',errors='replace')
load=lambda p:json.loads(read(p))
inputs=load(build/'inputs.json');old={e['path']:e['sha256'] for e in load(prior/'inputs.json')}
changed=[e['path'] for e in inputs if old.get(e['path'])!=e['sha256']]
for e in inputs:assert sha(build/e['path'])==e['sha256']==sha(project/e['path']),e['path']
assert len(inputs)==213
old_sdc=set(read(prior/'td_project/camera_to_dsi_display.sdc').splitlines())
new_sdc=set(read(build/'td_project/camera_to_dsi_display.sdc').splitlines())
assert not [s for s in old_sdc-new_sdc if s.strip() and not s.lstrip().startswith('#')]
additions=[s for s in new_sdc-old_sdc if s.strip() and not s.lstrip().startswith('#')]
v3=set(read(root/'tmp/upper_holes_v3_r2_20261013/td_project/camera_to_dsi_display.sdc').splitlines())
assert len(additions)==0 and set(additions)<=v3 and all(s.startswith('set_max_delay ') for s in additions)
warnings={};deltas={}
for stage,last in [('syn_1','opt_gate'),('phy_1','bitgen')]:
 d=build/'td_project/camera_to_dsi_display_Runs'/stage
 assert read(d/'build_exit_code.txt').strip()=='0' and (d/('.'+last+'.end.f')).exists() and not list(d.glob('.*.error.f'))
 assert not re.search(r'(?m)^\w+-\d+\s+(?:CRITICAL-)?ERROR:',read(d/'build_console.log'))
 def w(path):return Counter(re.sub(r'(\.v)\(\d+\)',r'\1(LINE)',s) for s in read(path).splitlines() if re.match(r'^\w+-\d+ (?:CRITICAL-)?WARNING:',s))
 cur=w(d/'build_console.log');prev=w(prior/'td_project/camera_to_dsi_display_Runs'/stage/'build_console.log')
 warnings[stage]=sum(cur.values());deltas[stage]={'added':list((cur-prev).elements()),'removed':list((prev-cur).elements())}
phy=build/'td_project/camera_to_dsi_display_Runs/phy_1';timing=read(phy/'camera_to_dsi_display_pr.timing')
assert 'Confidence          : Routed' in timing and 'Check Corner        : Both (Slow and Fast)' in timing
m=re.search(r'SWNS:\s*([-\d.]+)ns, STNS:\s*([-\d.]+)ns\s+HWNS:\s*([-\d.]+)ns, HTNS:\s*([-\d.]+)ns',timing);assert m
values=list(map(float,m.groups()));assert min(values)>=0 and values[1]==values[3]==0
assert all(int(v)==0 for v in re.findall(r'(\d+) Viol Endpoints',timing))
metrics=dict(setup_wns_ns=values[0],setup_tns_ns=values[1],hold_wns_ns=values[2],hold_tns_ns=values[3],sta_coverage_percent=float(re.search(r'STA coverage\s*:\s*([\d.]+)%',timing)[1]))
area=read(phy/'camera_to_dsi_display_phy.area');resources={}
for name in ['slice','eram','dsp']:
 m=re.search(r'^#'+name+r'\*?\s+(\d+)\s+out of\s+(\d+)\s+([\d.]+)%',area,re.M);assert m
 resources[name]=dict(used=int(m[1]),total=int(m[2]),percent=float(m[3]))
assert resources['slice']['percent']<70 and resources['eram']['used']<=108 and resources['dsp']['used']<=40
exception=read(phy/'camera_to_dsi_display_exception.timing').split('MCP/SMD Details')[0]
delays=[(int(m[1]),int(m[2]),m[3]) for m in re.finditer(r'^\s*(\d+)\s+\d+\s+\d+\s+(\d+)\s+(set_max_delay .+)$',exception,re.M)]
assert len(delays)==37 and not [(n,i,c) for n,i,c in delays if n==0 or i]
commands=re.findall(r'^set_max_delay .+$',read(build/'td_project/camera_to_dsi_display.sdc'),re.M)
assert len(commands)==35 and set(commands)<={c for _,_,c in delays}
bit=phy/'camera_to_dsi_display.bit'
audit=dict(status='PASS_BUILD_TESTS_PENDING',onsite='PENDING',variant='3528_PRESENCE_REVIEW_V7',changed_inputs=changed,unchanged_inputs=len(inputs)-len(changed),timing=metrics,resources=resources,resource_delta_from_v6=dict(slice=resources['slice']['used']-13659,eram=resources['eram']['used']-53,dsp=resources['dsp']['used']-17),warnings=warnings,warning_deltas=deltas,sdc_unchanged_from_v6=True,explicit_max_delays=35,vendor_fifo_max_delays=2,max_delays_matched=len(delays),max_delays_ignored=0,bit=dict(bytes=bit.stat().st_size,sha256=sha(bit)))
(build/'build_audit.json').write_text(json.dumps(audit,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(audit,ensure_ascii=False,indent=2))
