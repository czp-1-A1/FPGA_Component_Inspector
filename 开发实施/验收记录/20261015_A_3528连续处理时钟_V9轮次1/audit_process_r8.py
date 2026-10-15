from pathlib import Path
from collections import Counter
import json,re,hashlib
r=Path.cwd();build=r/'tmp/process_v9_r8_20261015';tests=r/'tmp/process_v9_r7_20261015';prior=r/'tmp/process_v9_r3_20261014';p=r/'fpga/component_inspector'
read=lambda f:f.read_text(encoding='utf-8-sig',errors='replace')
sha=lambda f:hashlib.sha256(f.read_bytes()).hexdigest()
load=lambda f:json.loads(read(f))
inputs=load(build/'inputs.json');assert len(inputs)==215
for e in inputs:assert sha(build/e['path'])==e['sha256']==sha(p/e['path']),e['path']
old={e['path']:e['sha256'] for e in load(tests/'inputs.json')}
changed=[e['path'] for e in inputs if old[e['path']]!=e['sha256']]
assert changed==['td_project/camera_to_dsi_display.sdc']
# All tests were freshly run on this exact production and simulation freeze.
for e in load(tests/'simulation_inputs.json'):assert sha(build/e['path'])==e['sha256'],e['path']
names=['process_bridge','frame_search','frame_osd','shape_snapshot','shape_model','frame_tailproof','frame_stop','frame_process','shape_osd','video_fallback_display','frame_wait_metadata','video_metadata_fallback','writer_epoch','wb_epoch','observation','display_state','roi_guard']
test_results=[]
for n in names:
 f=tests/'sim/modelsim_work'/n/'console.log';s=read(f)
 assert 'Errors: 0,' in s and re.search(r'PASS .*:',s) and '** Fatal:' not in s and '** Error:' not in s,n
 test_results.append(dict(name=n,status='PASS',round=tests.name,console_sha256=sha(f)))
refs=load(tests/'independent_reference_results.json');assert len(refs)==19 and all(e['status']=='PASS' for e in refs)
before={s for s in read(prior/'td_project/camera_to_dsi_display.sdc').splitlines() if s.strip() and not s.startswith('#')}
after={s for s in read(build/'td_project/camera_to_dsi_display.sdc').splitlines() if s.strip() and not s.startswith('#')}
removed=before-after;added=after-before
assert len(removed)==1 and all('MIPI_RX_BYTE_CLK' in s and 'u_ph1p35_324_ddr_wrapper/u_ddr2/ddr_clk' in s for s in removed)
assert len(added)==1 and all('continuous_processing*bridge/write_gray' in s and '8.0' in s for s in added)
old_exc=read(prior/'td_project/camera_to_dsi_display_Runs/phy_1/camera_to_dsi_display_exception.timing').split('MCP/SMD Details')[0]
assert any(re.search(r'^\s*0\s+0\s+0\s+0\s+'+re.escape(s)+r'$',old_exc,re.M) for s in removed)
warnings={};deltas={}
for stage,last in [('syn_1','opt_gate'),('phy_1','bitgen')]:
 d=build/'td_project/camera_to_dsi_display_Runs'/stage
 assert read(d/'build_exit_code.txt').strip()=='0' and (d/('.'+last+'.end.f')).exists() and not list(d.glob('.*.error.f'))
 assert not re.search(r'(?m)^\w+-\d+\s+(?:CRITICAL-)?ERROR:',read(d/'build_console.log'))
 def w(f):return Counter(re.sub(r'(\.v)\(\d+\)',r'\1(LINE)',s) for s in read(f).splitlines() if re.match(r'^\w+-\d+ (?:CRITICAL-)?WARNING:',s))
 cur=w(d/'build_console.log');prev=w(prior/'td_project/camera_to_dsi_display_Runs'/stage/'build_console.log')
 warnings[stage]=sum(cur.values());deltas[stage]={'added':list((cur-prev).elements()),'removed':list((prev-cur).elements())}
 assert not any('used before its declaration' in s for s in cur)
phy=build/'td_project/camera_to_dsi_display_Runs/phy_1';timing=read(phy/'camera_to_dsi_display_pr.timing');area=read(phy/'camera_to_dsi_display_phy.area')
assert 'Confidence          : Routed' in timing and 'Check Corner        : Both (Slow and Fast)' in timing
m=re.search(r'SWNS:\s*([-\d.]+)ns, STNS:\s*([-\d.]+)ns\s+HWNS:\s*([-\d.]+)ns, HTNS:\s*([-\d.]+)ns',timing);assert m
v=list(map(float,m.groups()));assert min(v)>=0 and v[1]==v[3]==0 and all(int(e)==0 for e in re.findall(r'(\d+) Viol Endpoints',timing))
metrics=dict(setup_wns_ns=v[0],setup_tns_ns=v[1],hold_wns_ns=v[2],hold_tns_ns=v[3],sta_coverage_percent=float(re.search(r'STA coverage\s*:\s*([\d.]+)%',timing)[1]))
resources={}
for name in ['slice','eram','dsp']:
 m=re.search(r'^#'+name+r'\*?\s+(\d+)\s+out of\s+(\d+)\s+([\d.]+)%',area,re.M);assert m
 resources[name]=dict(used=int(m[1]),total=int(m[2]),percent=float(m[3]))
assert resources['slice']['percent']<70 and resources['eram']['used']<=108 and resources['dsp']['used']<=40
exceptions=read(phy/'camera_to_dsi_display_exception.timing');summary=exceptions.split('MCP/SMD Details')[0]
rows=[(int(m[1]),int(m[2]),m[3]) for m in re.finditer(r'^\s*(\d+)\s+\d+\s+\d+\s+(\d+)\s+(set_max_delay .+)$',summary,re.M)]
cmds=re.findall(r'^set_max_delay .+$',read(build/'td_project/camera_to_dsi_display.sdc'),re.M)
assert len(cmds)==38 and len(rows)==40 and all(n>0 and i==0 for n,i,_ in rows)
assert set(cmds)<={c for _,_,c in rows}
pointer=next(s for s in cmds if 'continuous_processing*bridge/write_gray' in s)
gray_paths=next(n for n,i,c in rows if c==pointer)
binding=read(build/'gray_budget_binding_console.log')
groups={key:set(re.findall(r'\{([^{}]+)\}',re.search(r'^'+key+r' (.+)$',binding,re.M)[1])) for key in ['GRAY_WRITE_PRIMARY','GRAY_READ_PRIMARY','GRAY_WRITE_FIRST','GRAY_READ_FIRST','GRAY_SOURCE_BUDGET','GRAY_DEST_BUDGET']}
assert all(len(groups[key])==10 for key in ['GRAY_WRITE_PRIMARY','GRAY_READ_PRIMARY','GRAY_WRITE_FIRST','GRAY_READ_FIRST'])
assert groups['GRAY_WRITE_PRIMARY']|groups['GRAY_READ_PRIMARY']<=groups['GRAY_SOURCE_BUDGET']
assert groups['GRAY_WRITE_FIRST']|groups['GRAY_READ_FIRST']<=groups['GRAY_DEST_BUDGET']
assert len(groups['GRAY_DEST_BUDGET'])==20 and gray_paths==20
detail=exceptions.split('Constraint     :   '+pointer)[1].split('Constraint     :')[0]
assert int(re.search(r'Dominated\s*:\s*(\d+),',detail)[1])==gray_paths
assert 'Shadowed' not in detail or int(re.search(r'Shadowed\s*:\s*(\d+),',detail)[1])==0
# Vendor fallback remains visible but must not dominate either bridge bus.
for block in exceptions.split('Constraint     :')[1:]:
 if '-datapath_only 999.700' in block.split('Check Type')[0]:
  assert not re.search(r'Dominated\s*:\s*(?!0,)\d+,',block.split('Start Point')[0])
coverage=read(phy/'constraint_coverage.txt')
for topic in ['no clock','clock definition','invalid constraint','combinational loops','no path constraints']:
 assert re.search(r'checking '+re.escape(topic)+r'\(0\)',coverage),topic
clocklog=read(phy/'build_console.log');assert 'start command "analyze_clock -detail"' in clocklog
bit=phy/'camera_to_dsi_display.bit'
audit=dict(status='PASS_SOFTWARE_EXPERIMENT_ONSITE_PENDING',onsite='PENDING_V9',variant='3528_CONTINUOUS_POST_AWB_V9',base_head='3c13af36cfd38656a42fb03bf665e4bd922856d2',source_commit=None,production_inputs=len(inputs),changed_from_test_freeze=changed,tests=test_results,test_reuse_basis='All 17 tests freshly passed on r7 explicit Gray FIFO; r8 changes only SDC exact-bus selectors, all RTL/bench/runner/font bytes identical',independent_reference_images=len(refs),timing=metrics,resources=resources,warnings=warnings,warning_deltas_from_wip=deltas,sdc_removed_proven_empty=sorted(removed),sdc_added_gray_pointer_budget=sorted(added),gray_pointer_logical_bits=20,gray_pointer_paths=gray_paths,gray_pointer_dominated=gray_paths,gray_binding={k:sorted(v) for k,v in groups.items()},gray_pointer_budget_ns=8.0,explicit_max_delays=len(cmds),vendor_fifo_max_delays=len(rows)-len(cmds),max_delays_matched=len(rows),max_delays_ignored=0,scope='Same 3528/tape; full-frame and two independent objects; model diagnostics, no calibrated manufacturing defect labels',bit=dict(bytes=bit.stat().st_size,sha256=sha(bit)))
(build/'build_audit.json').write_text(json.dumps(audit,ensure_ascii=False,indent=2),encoding='utf-8');print(json.dumps(audit,ensure_ascii=False,indent=2))
