from pathlib import Path
from collections import Counter
import json,re,hashlib
r=Path.cwd();b=r/'tmp/process_v9_r3_20261014';prior=r/'tmp/fullframe_v8_r12_20261014';p=r/'fpga/component_inspector'
sha=lambda f:hashlib.sha256(f.read_bytes()).hexdigest()
read=lambda f:f.read_text(encoding='utf-8-sig',errors='replace')
inputs=json.loads(read(b/'inputs.json'));old={e['path']:e['sha256'] for e in json.loads(read(prior/'inputs.json'))}
assert len(inputs)==215
for e in inputs:assert e['sha256']==sha(b/e['path'])==sha(p/e['path']),e['path']
before={s for s in read(prior/'td_project/camera_to_dsi_display.sdc').splitlines() if s.strip() and not s.startswith('#')}
after={s for s in read(b/'td_project/camera_to_dsi_display.sdc').splitlines() if s.strip() and not s.startswith('#')}
assert before<=after and len(after-before)==3
assert all(s.startswith('set_max_delay -datapath_only ') and 'u_wb_process/' in s for s in after-before)
warnings={};deltas={}
for stage,last in [('syn_1','opt_gate'),('phy_1','bitgen')]:
 d=b/'td_project/camera_to_dsi_display_Runs'/stage
 assert read(d/'build_exit_code.txt').strip()=='0' and (d/('.'+last+'.end.f')).exists() and not list(d.glob('.*.error.f'))
 assert not re.search(r'(?m)^\w+-\d+\s+(?:CRITICAL-)?ERROR:',read(d/'build_console.log'))
 def warning(path):return Counter(re.sub(r'(\.v)\(\d+\)',r'\1(LINE)',s) for s in read(path).splitlines() if re.match(r'^\w+-\d+ (?:CRITICAL-)?WARNING:',s))
 cur=warning(d/'build_console.log');prev=warning(prior/'td_project/camera_to_dsi_display_Runs'/stage/'build_console.log')
 warnings[stage]=sum(cur.values());deltas[stage]={'added':list((cur-prev).elements()),'removed':list((prev-cur).elements())}
phy=b/'td_project/camera_to_dsi_display_Runs/phy_1';t=read(phy/'camera_to_dsi_display_pr.timing')
assert 'Confidence          : Routed' in t and 'Check Corner        : Both (Slow and Fast)' in t
m=re.search(r'SWNS:\s*([-\d.]+)ns, STNS:\s*([-\d.]+)ns\s+HWNS:\s*([-\d.]+)ns, HTNS:\s*([-\d.]+)ns',t);assert m
v=list(map(float,m.groups()));assert min(v)>=0 and v[1]==v[3]==0
assert all(int(v)==0 for v in re.findall(r'(\d+) Viol Endpoints',t))
timing=dict(setup_wns_ns=v[0],setup_tns_ns=v[1],hold_wns_ns=v[2],hold_tns_ns=v[3],sta_coverage_percent=float(re.search(r'STA coverage\s*:\s*([\d.]+)%',t)[1]))
a=read(phy/'camera_to_dsi_display_phy.area');resources={}
for name in ['slice','eram','dsp']:
 m=re.search(r'^#'+name+r'\*?\s+(\d+)\s+out of\s+(\d+)\s+([\d.]+)%',a,re.M);assert m
 resources[name]=dict(used=int(m[1]),total=int(m[2]),percent=float(m[3]))
assert resources['slice']['percent']<70 and resources['eram']['used']<=108 and resources['dsp']['used']<=40
exc=read(phy/'camera_to_dsi_display_exception.timing').split('MCP/SMD Details')[0]
delays=[(int(m[1]),int(m[2]),m[3]) for m in re.finditer(r'^\s*(\d+)\s+\d+\s+\d+\s+(\d+)\s+(set_max_delay .+)$',exc,re.M)]
commands=re.findall(r'^set_max_delay .+$',read(b/'td_project/camera_to_dsi_display.sdc'),re.M)
assert len(commands)==38 and len(delays)==42 and all(n>0 and i==0 for n,i,_ in delays)
assert set(commands)<={c for _,_,c in delays}
bit=phy/'camera_to_dsi_display.bit'
audit=dict(status='PASS_BUILD_TESTS_PENDING',onsite='PENDING_V9',variant='3528_CONTINUOUS_POST_AWB_V9',changed_inputs=[e['path'] for e in inputs if old.get(e['path'])!=e['sha256']],timing=timing,resources=resources,resource_delta_from_v8={k:resources[k]['used']-n for k,n in [('slice',14298),('eram',69),('dsp',20)]},warnings=warnings,warning_deltas=deltas,sdc_existing_constraints_preserved=True,sdc_added_wb_mailbox_constraints=sorted(after-before),explicit_max_delays=len(commands),vendor_fifo_max_delays=len(delays)-len(commands),max_delays_ignored=0,bit=dict(bytes=bit.stat().st_size,sha256=sha(bit)))
(b/'build_audit.json').write_text(json.dumps(audit,ensure_ascii=False,indent=2),encoding='utf-8');print(json.dumps(audit,ensure_ascii=False,indent=2))
