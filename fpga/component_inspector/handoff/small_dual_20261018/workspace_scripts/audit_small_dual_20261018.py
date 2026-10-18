from pathlib import Path
from collections import Counter
import hashlib,json,re
r=Path.cwd();p=r/'fpga/component_inspector';rd=r/'tmp/small_dual_r3_20261018';w=rd/'work';base=p/'handoff/threshold180_20261018';neg=r/'tmp/small_dual_handoff_negative_20261018'
sha=lambda q:hashlib.sha256(q.read_bytes()).hexdigest()
def read(q):
 b=q.read_bytes();return b.decode('utf-16' if b.startswith((b'\xff\xfe',b'\xfe\xff')) else 'utf-8-sig').replace('\r\n','\n')
load=lambda q:json.loads(read(q))
inputs=load(rd/'source_snapshot/inputs.json');bm=load(base/'source_snapshot/inputs.json');ninputs=len(inputs)
assert ninputs==372
for n,h in inputs.items():
 assert sha(rd/'source_snapshot'/n)==h,n
 if n.startswith(('user_source/','sim/')):assert sha(w/n)==h,n
for n,h in load(rd/'baseline.json')['live_before'].items():assert sha(p/n)==h,n
changed={n for n in inputs if inputs[n]!=bm.get(n)}
assert {n for n in changed if n.startswith('user_source/')}=={'user_source/hdl_source/experiment_osd.v','user_source/hdl_source/frame_shape_search.v','user_source/hdl_source/inspection_region_config.v','user_source/hdl_source/isp/isp_top.v'}
assert all(sha(w/n)==h for n,h in bm.items() if n.startswith('user_source/') and n not in changed)
# Original non-compact OSD remains unchanged. No hidden deletion of tests or
# pixel/clock/DDR/Sobel code, no numeric classification threshold adjustments.
old=(base/'source_snapshot/user_source/hdl_source/experiment_osd.v').read_text('utf-8')
new=(w/'user_source/hdl_source/experiment_osd.v').read_text('utf-8')
start=new.index('module experiment_osd_legacy #(')
legacy=new[start:new.index('// Two current-frame lane results.')].strip()
assert legacy==old[old.index('module experiment_osd #('):].replace('module experiment_osd #(','module experiment_osd_legacy #(',1).strip()
for n in ['user_source/hdl_source/inspection_region_config.v']:
 a=read(base/'source_snapshot'/n);b=read(w/n)
 assert re.findall(r"parameter \[119:0\] RECIPE[01]=([^\n]+)",a)==re.findall(r"parameter \[119:0\] RECIPE[01]=([^\n]+)",b)
sd0=read(base/'source_snapshot/td_project/camera_to_dsi_display.sdc');sd=read(w/'td_project/camera_to_dsi_display.sdc')
removed=load(rd/'baseline.json')['removed_dead_display_constraints']
c0=re.findall(r'^set_max_delay .+$',sd0,re.M);c1=re.findall(r'^set_max_delay .+$',sd,re.M)
assert len(c0)==38 and len(c1)==32 and set(c0)-set(c1)==set(removed) and not set(c1)-set(c0)
assert all(any(x in c for x in ['u_publish_display/','u_wb_process/']) for c in removed)
assert [x for x in sd0.splitlines() if x and not x.startswith(('#','set_max_delay '))]==[x for x in sd.splitlines() if x and not x.startswith(('#','set_max_delay '))]
nm=load(neg/'source_snapshot/inputs.json');assert set(nm)==set(inputs)
assert {n for n in inputs if inputs[n]!=nm[n]}=={'user_source/hdl_source/frame_shape_search.v'}
assert load(neg/'work/replay_sim.result.json')['exit_code']==1
assert 'handoff switched identity frame2 lane0 center612 expected676' in read(neg/'work/sim/modelsim_work/lane_handoff/console.log')
assert load(w/'replay_sim.result.json')['exit_code']==0 and 'PASS ModelSim: all 14 tests' in read(w/'replay_sim.log')
names=['lane_handoff','lane_search','lane_osd','lane_hd_pins','threshold180','pose180','field180','cal180_holes','cal180_body','regions_osd','hd_pins','sobel_view','sobel_tail','dynamic_sobel'];tests=[]
for name in names:
 q=w/'sim/modelsim_work'/name/'console.log';t=read(q)
 assert 'PASS ' in t and 'Errors: 0,' in t and not re.search(r'\*\* (?:Error|Fatal)',t),name
 tests.append(dict(name=name,status='PASS',console_sha256=sha(q)))
assert '7 frames/14 records' in read(w/'sim/modelsim_work/lane_handoff/console.log')
assert '24 full frames/42 current records' in read(w/'sim/modelsim_work/lane_search/console.log')
assert '4 full rasters/3686400 independent pixels' in read(w/'sim/modelsim_work/lane_osd/console.log')
source=(r/'tmp/audit_search_stages.py').read_text('utf-8');a=source.index("runs=w/'td_project/camera_to_dsi_display_Runs'");b=source.index('result=dict(',a)
checks=source[a:b].replace("len(commands)==38 and len(rows)==40","len(commands)==32 and len(rows)==34").replace("resources['slice']['percent']<=80","resources['slice']['percent']<=73")
exec(compile(checks,'small_dual_actual_routed_checks','exec'))
assert resources['eram']['used']<=101 and resources['dsp']['used']==26 and resources['pll']['used']==5
net=read(w/'audit_v3/routed_netlist.v')
assert 'u_publish_display/D_data' not in net and 'u_wb_process/D_data' not in net
assert re.search(r'\|12\s*\|',next(x for x in area.splitlines() if '|    u_roi_sobel_view ' in x))
base_a=load(base/'handoff.json');delta={}
for k,z in resources.items():
 old=base_a['resources'][k];delta[k]=dict(before=old['used'],after=z['used'],saved=old['used']-z['used'],percentage_points_saved=round(old['percent']-z['percent'],2))
result=dict(status='PASS_SMALL_DUAL_MOVING_LABELS_SOFTWARE_ROUTED_FIELD_PENDING',base_bit_sha256=load(rd/'baseline.json')['base_bit_sha256'],source_manifest_sha256=sha(rd/'source_snapshot/inputs.json'),input_count=ninputs,changed_files=sorted(changed),roi=[dict(lane=1,bounds=[560,248,720,352]),dict(lane=2,bounds=[560,368,720,472])],objects_per_lane=1,labels='Follow current measured object rectangles; only WAIT is fixed to empty lane origin.',classification_thresholds_changed=False,isp_pixel_pipeline_changed=False,sobel_four_views_retained=True,metadata_port_width_changed=False,frame_bound=True,holds_old_results=False,handoff_preference=load(rd/'baseline.json')['handoff_preference'],tests=tests,negative_baseline=dict(manifest_sha256=sha(neg/'source_snapshot/inputs.json'),counterexample='Without preference,4px jitter switches identity on frame2; same frozen oracle passes after fix.'),routed_sta=dict(setup_ns=v[0],setup_tns_ns=v[1],hold_ns=v[2],hold_tns_ns=v[3],sta_percent=float(re.search(r'STA coverage\s*:\s*([\d.]+)%',timing)[1])),resources=resources,resource_delta=delta,warnings=warnings,removed_dead_constraints=removed,max_delays_matched=len(rows),max_delays_ignored=0,gray_bits=gray,gray_constraint_counts=list(counts),gray_physical_paths=list(fanout.values()),bit=dict(bytes=bit.stat().st_size,sha256=sha(bit)),physical_validation=False,all_parts_guaranteed=False,all_flipped_detected=False,raw_jitter_fixed=False,hardware='NOT_PROGRAMMED_BY_ASSISTANT',warning_boundary='Original camera/DDR/IP/PLL/I/O warnings retained. Removed only six named max_delay commands for two synthesized-away display-only CDC destinations; all32live commands and2vendor commands match,ignored0,and20Gray paths/all fanout meet original8ns.',validation_boundary='Synthetic motion and jitter,full-pixel moving UI and actual serialized HDMI; previous classification and four-view Sobel regressions retained. No new real conveyor speed,blur,lighting or physical coverage evidence.')
(rd/'final_audit.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({k:result[k] for k in ['status','routed_sta','resource_delta','bit']},indent=2))
