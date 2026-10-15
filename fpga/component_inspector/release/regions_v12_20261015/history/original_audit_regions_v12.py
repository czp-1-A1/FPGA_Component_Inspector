from pathlib import Path
from collections import Counter
import hashlib,json,re,sys

root=Path.cwd();p=root/'fpga/component_inspector'
r3=root/'tmp/regions_v12_r3_20261015';r4=root/'tmp/regions_v12_r4_20261015'
old=p/'release/hd720_v11_r9_20261015'
def read(path):
 b=path.read_bytes()
 return b.decode('utf-16' if b.startswith((b'\xff\xfe',b'\xfe\xff')) else 'utf-8-sig',errors='strict')
load=lambda path:json.loads(read(path))
sha=lambda path:hashlib.sha256(path.read_bytes()).hexdigest()
a=load(r3/'source_snapshot/inputs.json');b=load(r4/'source_snapshot/inputs.json')
assert [name for name in a if a[name]!=b[name]]==['sim/tb_regions.v']
for name,want in b.items():
 assert sha(r4/'source_snapshot'/name)==want,name
 if name.startswith(('user_source/','sim/')) and not name.endswith('.log'):
  assert sha(p/name)==want,name
for name,want in a.items():
 assert sha(r3/'source_snapshot'/name)==want,name
 if name.startswith(('user_source/','sim/')) and name!='sim/tb_regions.v' and not name.endswith('.log'):
  assert sha(r3/'work'/name)==want,name
assert sha(r3/'work/td_project/camera_to_dsi_display.sdc')==sha(old/'source_snapshot/td_project/camera_to_dsi_display.sdc')
base=load(old/'source_snapshot/inputs.json')
changed=[name for name in b if name.startswith('user_source/') and base.get(name)!=b[name]]
assert set(changed)=={'user_source/hdl_source/design_top_wrapper.v','user_source/hdl_source/experiment_osd.v','user_source/hdl_source/frame_shape_search.v','user_source/hdl_source/inspection_region_config.v','user_source/hdl_source/isp/isp_top.v'},changed
stage_warnings={};warning_deltas={}
for stage,last in [('syn_1','opt_gate'),('phy_1','bitgen')]:
 d=r3/'work/td_project/camera_to_dsi_display_Runs'/stage
 assert read(d/'build_exit_code.txt').strip()=='0' and (d/('.'+last+'.end.f')).is_file(),stage
 text=read(d/'build_console.log')
 assert not re.search(r'(?m)^\w+-\d+\s+(?:CRITICAL-)?ERROR:',text)
 warnings=[line for line in text.splitlines() if re.match(r'^\w+-\d+ (?:CRITICAL-)?WARNING:',line)]
 stage_warnings[stage]={'count':len(warnings),'categories':dict(Counter(re.match(r'^(\w+-\d+)',s)[1] for s in warnings))}
 prior=read(old/'built_project/td_project/camera_to_dsi_display_Runs'/stage/'build_local.log')
 old_cats=Counter(re.findall(r'(?m)^(\w+-\d+) (?:CRITICAL-)?WARNING:',prior))
 new_cats=Counter(stage_warnings[stage]['categories'])
 warning_deltas[stage]={'added_codes':dict(new_cats-old_cats),'removed_codes':dict(old_cats-new_cats)}
phy=r3/'work/td_project/camera_to_dsi_display_Runs/phy_1'
timing=read(phy/'camera_to_dsi_display_pr.timing');area=read(phy/'camera_to_dsi_display_phy.area')
assert 'Confidence          : Routed' in timing and 'Check Corner        : Both (Slow and Fast)' in timing
m=re.search(r'SWNS:\s*([-\d.]+)ns, STNS:\s*([-\d.]+)ns\s+HWNS:\s*([-\d.]+)ns, HTNS:\s*([-\d.]+)ns',timing);assert m
v=list(map(float,m.groups()));assert min(v)>=0 and v[1]==v[3]==0
assert all(int(n)==0 for n in re.findall(r'(\d+) Viol Endpoints',timing))
resources={}
for name in ['slice','eram','dsp','pll']:
 m=re.search(r'^#'+name+r'\*?\s+(\d+)\s+out of\s+(\d+)\s+([\d.]+)%',area,re.M);assert m,name
 resources[name]={'used':int(m[1]),'total':int(m[2]),'percent':float(m[3])}
assert resources['slice']['percent']<80 and all(q['used']<=q['total'] for q in resources.values())
assert resources['eram']['used']==94 and resources['dsp']['used']==26
audit=r3/'work/audit'
exceptions=read(audit/'exceptions.timing');summary=exceptions.split('MCP/SMD Details')[0]
rows=[(int(m[1]),int(m[2]),int(m[3]),int(m[4]),m[5]) for m in re.finditer(r'^\s*(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(set_max_delay .+)$',summary,re.M)]
commands=re.findall(r'^set_max_delay .+$',read(phy.parent.parent/'camera_to_dsi_display.sdc'),re.M)
assert len(commands)==38 and len(rows)==40 and all(n>0 and ignored==0 for n,dom,shadow,ignored,c in rows)
assert set(commands)<={c for n,d,s,i,c in rows}
ptr=next(c for c in commands if 'continuous_processing*bridge/write_gray' in c)
assert next(row[:4] for row in rows if row[4]==ptr)==(20,20,0,0)
assert read(r3/'work/routed_audit_exit.txt').strip()=='0'
bind=re.findall(r'^GRAY_BIND (write|read) (\d+) SOURCE \{([^}]+)\} DESTINATION \{([^}]+)\}',read(r3/'work/routed_audit.log'),re.M)
assert len(bind)==20 and len({(d,int(bit)) for d,bit,s,e in bind})==20
gray=[]
for direction,bit,source,dest in bind:
 text=read(audit/f'gray_{direction}_{bit}.timing')
 # Take the individually resolved primary SMD section, rather than a shadowed
 # generic clock-domain group that can occur first in the report.
 segments=[s for s in text.split('Path Group') if ptr in s and 'Type           :     SMD' in s]
 assert len(segments)==1,(direction,bit)
 segment=segments[0]
 assert source in segment and dest in segment and 'Budget              : 8.000ns' in segment,(direction,bit)
 slack=float(re.search(r'Slack\s*:\s*([-\d.]+)ns',segment)[1]);assert slack>=0
 gray.append({'direction':direction,'bit':int(bit),'source':source,'destination':dest,'budget_ns':8,'slack_ns':slack})
coverage=read(audit/'constraint_coverage.txt')
for topic in ['no clock','clock definition','invalid constraint','combinational loops','no path constraints']:
 assert re.search(r'checking '+topic+r'\(0\)',coverage),topic
bit=phy/'camera_to_dsi_display.bit'
assert bit.stat().st_size==1789539
result={'status':'PASS_ROUTED_BUILD_TESTS_PENDING','source_base_head':'2fc4c4318027832f3feda9f193d34565af59a32b',
 'source_commit_at_build':None,'build_round':str(r3.relative_to(root)),'corrected_test_round':str(r4.relative_to(root)),
 'frozen_input_count':len(b),'changed_production_inputs':changed,'r3_r4_input_difference':['sim/tb_regions.v'],
 'test_fixture_fix':'Undefined loop variable removed and intended upper feed hole placed inside its zone; assertions/expected counts unchanged. Failed original fixtures/logs retained.',
 'td_version':'6.2.168116','timing':{'setup_ns':v[0],'setup_tns_ns':v[1],'hold_ns':v[2],'hold_tns_ns':v[3],'sta_percent':float(re.search(r'STA coverage\s*:\s*([\d.]+)%',timing)[1])},
 'resources':resources,'resource_delta_from_v11':{'slice':resources['slice']['used']-14724,'eram':resources['eram']['used']-94,'dsp':resources['dsp']['used']-26},
 'sdc_changed_from_v11':False,'explicit_max_delays':38,'all_max_delays_matched':40,'all_max_delays_ignored':0,
 'gray_bits':gray,'warnings':stage_warnings,'warning_code_count_deltas_from_v11_other_tool':warning_deltas,
 'warning_boundary':'TD 6.2.168116 retains PHY-5079 on pll_clk_24m / O_cam_24m clock-output routing (0 clock sinks, 1 data sink, 3 local wires). The same camera-clock net warning is present in V11 r8 built with this TD version, but absent in V11 r9 built with 6.2.178840. PHY-5088 covers this camera clock-output data sink and the existing camera/DDR PLL feedback cascades; USR-6135 covers the two existing local PLL feedbacks. Partial/missing I/O delay warnings remain. No claim of all physical interfaces proved or zero added warnings relative to the other-tool V11 r9.',
 'bit':{'bytes':bit.stat().st_size,'sha256':sha(bit)},
 'onsite':'PENDING_V12','recipe':'Same white 3528 feature recipe; shared foreground threshold 100; old geometry seeds not calibrated to latest wider view. No automatic model identification or calibrated defect classes.'}
if '--build-only' not in sys.argv:
 baseline=['process_bridge','frame_search','frame_osd','shape_snapshot','shape_model','frame_tailproof','frame_stop','frame_process','shape_osd','video_fallback_display','frame_wait_metadata','video_metadata_fallback','writer_epoch','wb_epoch','observation','display_state','roi_guard','video_first','video_late_display','frame_cadence','hd_resize','hd_guard','hd_scaled_guard','hd_osd','hd_search','hd_chain','hd_pins','hd_pll']
 tests=[]
 for name in baseline+['regions','regions_osd','regions_chain']:
  origin=r3 if name in ['regions_osd','regions_chain'] else r4
  log=origin/'work/sim/modelsim_work'/name/'console.log';text=read(log)
  assert re.search(r'PASS .*:',text) and 'Errors: 0,' in text and not re.search(r'\*\* (Fatal|Error):',text),name
  assert sha(origin/'source_snapshot/sim'/f'tb_{name}.v')==b[f'sim/tb_{name}.v'],name
  tests.append({'name':name,'status':'PASS','origin':str(origin.relative_to(root)),'console_sha256':sha(log)})
 assert 'PASS ModelSim: all 29 tests' in read(r4/'remaining_tests.log')
 assert '26-FPS source start-to-start' in read(r3/'work/sim/modelsim_work/regions_chain/console.log')
 refs=load(r4/'work/independent_regions_reference.json');old_refs=load(r4/'work/independent_reference_results.json')
 assert len(refs)==13 and len(old_refs)==18 and all(q['status']=='PASS' for q in refs+old_refs)
 result.update(status='PASS_SOFTWARE_AND_ROUTED_ONSITE_PENDING',tests=tests,independent_region_images=13,independent_legacy_hd_images=18,independent_images_total=31)
(r3/'final_audit.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({k:result[k] for k in ['status','td_version','timing','resources','bit']},indent=2))
