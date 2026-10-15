from pathlib import Path
from collections import Counter
import hashlib,json,re
r=Path.cwd();build=r/'tmp/video_first_v10_r4_20261015';prior=r/'tmp/process_v9_r8_20261015';p=r/'fpga/component_inspector'
read=lambda f:f.read_text(encoding='utf-8-sig',errors='replace')
sha=lambda f:hashlib.sha256(f.read_bytes()).hexdigest()
load=lambda f:json.loads(read(f))
inputs=load(build/'inputs.json');assert len(inputs)==215
for e in inputs:assert sha(build/e['path'])==e['sha256']==sha(p/e['path']),e['path']
old={e['path']:e['sha256'] for e in load(prior/'inputs.json')}
changed=[e['path'] for e in inputs if old[e['path']]!=e['sha256']]
assert set(changed)=={'user_source/hdl_source/video_in.v','user_source/hdl_source/design_top_wrapper.v','user_source/hdl_source/experiment_osd.v'},changed
assert sha(build/'td_project/camera_to_dsi_display.sdc')==sha(prior/'td_project/camera_to_dsi_display.sdc')
assert '.VIDEO_FIRST(LOCAL_SEARCH)' in read(build/'user_source/hdl_source/design_top_wrapper.v')
for e in load(build/'simulation_inputs.json'):
 assert sha(build/e['path'])==e['sha256'],e['path']
 if e['path']=='sim/run_modelsim.ps1':assert read(build/e['path'])==read(p/e['path'])
 else:assert sha(p/e['path'])==e['sha256'],e['path']
names=['process_bridge','frame_search','frame_osd','shape_snapshot','shape_model','frame_tailproof','frame_stop','frame_process','shape_osd','video_fallback_display','frame_wait_metadata','video_metadata_fallback','writer_epoch','wb_epoch','observation','display_state','roi_guard','video_first','video_late_display','frame_cadence']
assert read(build/'tests_exit_code.txt').strip()=='0'
tests=[]
for n in names:
 f=build/'sim/modelsim_work'/n/'console.log';s=read(f)
 assert 'Errors: 0,' in s and re.search(r'PASS .*:',s) and '** Fatal:' not in s and '** Error:' not in s,n
 tests.append(dict(name=n,status='PASS',console_sha256=sha(f)))
refs=load(build/'independent_reference_results.json');assert len(refs)==24 and all(e['status']=='PASS' for e in refs)
cadence=read(build/'sim/modelsim_work/frame_cadence/console.log')
assert 'accepted_frames!=6' in read(build/'sim/tb_frame_cadence.v')
assert '26-FPS source start-to-start, all four views' in cadence
assert len(re.findall(r'CADENCE frame=',cadence))==7
assert 'live WB-canceled zero-result video' in cadence
repro=r/'tmp/video_first_v10_v9_repro_20261015'
s=read(repro/'sim/modelsim_work/video_first/console.log')
assert 'REPRO video blocked: Pseen=5b words=24 complete=1 wait=15 published=0' in s and '** Fatal:' in s
full_repro=r/'tmp/video_first_v10_v9_cadence_repro_20261015'
s=read(full_repro/'sim/modelsim_work/frame_cadence/console.log')
assert 'REPRO V9 cadence: P=5b W=1c200 complete=1 good=1 bad=0 metadata_ready=0' in s and '** Fatal:' in s
assert read(full_repro/'tests_exit_code.txt').strip()=='1'
warnings={};deltas={}
for stage,last in [('syn_1','opt_gate'),('phy_1','bitgen')]:
 d=build/'td_project/camera_to_dsi_display_Runs'/stage
 assert read(d/'build_exit_code.txt').strip()=='0' and (d/('.'+last+'.end.f')).exists() and not list(d.glob('.*.error.f'))
 assert not re.search(r'(?m)^\w+-\d+\s+(?:CRITICAL-)?ERROR:',read(d/'build_console.log'))
 def warning_lines(f):return Counter(re.sub(r'(\.v)\(\d+\)',r'\1(LINE)',s) for s in read(f).splitlines() if re.match(r'^\w+-\d+ (?:CRITICAL-)?WARNING:',s))
 cur=warning_lines(d/'build_console.log');prev=warning_lines(prior/'td_project/camera_to_dsi_display_Runs'/stage/'build_console.log')
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
assert len(cmds)==38 and len(rows)==40 and all(n>0 and ignored==0 for n,ignored,_ in rows)
assert set(cmds)<={c for _,_,c in rows}
pointer=next(s for s in cmds if 'continuous_processing*bridge/write_gray' in s)
gray_paths=next(n for n,i,c in rows if c==pointer)
binding=read(build/'gray_budget_binding_console.log')
keys=['GRAY_WRITE_PRIMARY','GRAY_READ_PRIMARY','GRAY_WRITE_FIRST','GRAY_READ_FIRST','GRAY_SOURCE_BUDGET','GRAY_DEST_BUDGET']
groups={key:set(re.findall(r'\{([^{}]+)\}',re.search(r'^'+key+r' (.+)$',binding,re.M)[1])) for key in keys}
assert all(len(groups[key])==10 for key in keys[:4])
assert groups['GRAY_WRITE_PRIMARY']|groups['GRAY_READ_PRIMARY']<=groups['GRAY_SOURCE_BUDGET']
assert groups['GRAY_WRITE_FIRST']|groups['GRAY_READ_FIRST']<=groups['GRAY_DEST_BUDGET']
assert len(groups['GRAY_DEST_BUDGET'])==20 and gray_paths==20
detail=exceptions.split('Constraint     :   '+pointer)[1].split('Constraint     :')[0]
assert int(re.search(r'Dominated\s*:\s*(\d+),',detail)[1])==20
assert 'Shadowed' not in detail or int(re.search(r'Shadowed\s*:\s*(\d+),',detail)[1])==0
for block in exceptions.split('Constraint     :')[1:]:
 if '-datapath_only 999.700' in block.split('Check Type')[0]:
  assert not re.search(r'Dominated\s*:\s*(?!0,)\d+,',block.split('Start Point')[0])
coverage=read(phy/'constraint_coverage.txt')
for topic in ['no clock','clock definition','invalid constraint','combinational loops','no path constraints']:
 assert re.search(r'checking '+re.escape(topic)+r'\(0\)',coverage),topic
assert 'start command "analyze_clock -detail"' in read(phy/'build_console.log')
bit=phy/'camera_to_dsi_display.bit'
audit=dict(status='PASS_SOFTWARE_EXPERIMENT_ONSITE_PENDING',onsite='PENDING_V10',previous_v9_onsite='FAIL_BLACK',
 variant='3528_VIDEO_FIRST_V10',base_head='36ef39f2e75be99904c02a5a9a9c9ef693e2da1c',source_commit=None,
 production_inputs=len(inputs),changed_from_v9=changed,tests=tests,independent_reference_images=len(refs),current_runner_eol_only_repair=True,
 timing=metrics,resources=resources,warnings=warnings,warning_deltas_from_v9=deltas,
 gray_pointer_logical_bits=20,gray_pointer_paths=20,gray_pointer_dominated=20,gray_pointer_budget_ns=8.0,
 gray_binding={k:sorted(v) for k,v in groups.items()},explicit_max_delays=38,vendor_fifo_max_delays=2,
 max_delays_matched=40,max_delays_ignored=0,sdc_changed_from_v9=False,
 scope='Same white 3528/tape, full image, up to two objects; resultless complete video allowed, one exact-epoch/slot metadata attachment, atomic display snapshots; no calibrated physical defects',
 prior_black_reproduction='V9 P5B complete pixels waiting for missing metadata; frozen counterexample retained',
 bit=dict(bytes=bit.stat().st_size,sha256=sha(bit)))
(build/'build_audit.json').write_text(json.dumps(audit,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps(audit,ensure_ascii=False,indent=2))
