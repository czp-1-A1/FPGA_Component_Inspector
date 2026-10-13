from pathlib import Path
from collections import Counter
import hashlib,json,re,sys
root=Path(__file__).resolve().parent.parent
project=root/'fpga/component_inspector'
build=root/'tmp/tracking_late_r1_td_20261011'
tests_root=root/'tmp/tracking_late_r3_td_20261011'
prior=root/'tmp/dynamic_tracking_v1_r5_td_20261010'
read=lambda p:p.read_text(encoding='utf-8-sig',errors='replace')
load=lambda p:json.loads(read(p))
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
runs=build/'td_project/camera_to_dsi_display_Runs';phy=runs/'phy_1'
inputs=load(tests_root/'inputs.json')
assert inputs==load(build/'inputs.json') and len(inputs)==210
for e in inputs:
 for p in [build/e['path'],tests_root/e['path'],project/e['path']]:assert sha(p)==e['sha256'],p
for e in load(tests_root/'simulation_inputs.json'):
 assert sha(tests_root/e['path'])==e['sha256']==sha(project/e['path']),e['path']
for e in load(build/'stage_inputs.json'):assert sha(build/e['path'])==e['sha256'],e['path']
for stage,last in [('syn_1','opt_gate'),('phy_1','bitgen')]:
 p=runs/stage
 assert read(p/'command_exit_code.txt').strip()=='0'
 assert (p/('.'+last+'.end.f')).exists() and not list(p.glob('.*.error.f'))
 assert not re.search(r'(?m)^\w+-\d+\s+(?:CRITICAL-)?ERROR:',read(p/'build_console.log'))
 assert len(re.findall(r'<File Path=',read(p/'camera_to_dsi_display.prj')))==70
timing=read(phy/'camera_to_dsi_display_pr.timing')
assert 'Confidence          : Routed' in timing and 'Check Corner        : Both (Slow and Fast)' in timing
assert re.findall(r'^(Slow|Fast)\s*\|\s*yes\s+yes',timing,re.M)==['Slow','Fast']
metrics={k:float(re.search(label+r'\s*:\s*([-\d.]+)ns',timing)[1]) for k,label in [('setup_wns_ns','SWNS'),('setup_tns_ns','STNS'),('hold_wns_ns','HWNS'),('hold_tns_ns','HTNS')]}
assert all(float(v)>=0 for v in re.findall(r'(?:SWNS|HWNS)\s*:\s*([-\d.]+)ns',timing))
assert metrics['setup_tns_ns']==metrics['hold_tns_ns']==0
assert all(int(v)==0 for v in re.findall(r'(\d+) Viol Endpoints',timing))
metrics['sta_coverage_percent']=float(re.search(r'STA coverage\s*:\s*([\d.]+)%',timing)[1])
area=read(phy/'camera_to_dsi_display_phy.area');resources={}
for name in ['slice','eram','dsp']:
 m=re.search(r'^#'+name+r'\*?\s+(\d+)\s+out of\s+(\d+)\s+([\d.]+)%',area,re.M)
 resources.update({name+'_used':int(m[1]),name+'_total':int(m[2]),name+'_percent':float(m[3])})
for name in ['lut6','reg']:resources[name+'_used']=int(re.search(r'^#'+name+r'\s+(\d+)',area,re.M)[1])
assert resources['slice_percent']<80 and resources['eram_used']<=49 and resources['dsp_used']==8
def delays(p):
 return [dict(total=int(m[1]),dominated=int(m[2]),shadowed=int(m[3]),ignored=int(m[4]),constraint=m[5]) for m in re.finditer(r'^\s*(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(set_max_delay .+)$',read(p).split('MCP/SMD Details')[0],re.M)]
canonical=delays(phy/'camera_to_dsi_display_exception.timing')
old_delays=delays(prior/'td_project/camera_to_dsi_display_Runs/phy_1/camera_to_dsi_display_exception.timing')
assert len(canonical)==34 and all(e['total']>0 and e['ignored']==0 for e in canonical)
assert [e['constraint'] for e in canonical]==[e['constraint'] for e in old_delays]
def warnings(p):
 return Counter(re.sub(r'(\.v)\(\d+\)',r'\1(LINE)',s) for s in read(p).splitlines() if re.match(r'^\w+-\d+ (?:CRITICAL-)?WARNING:',s))
warning_review={}
for stage in ['syn_1','phy_1']:
 a=warnings(runs/stage/'build_console.log');b=warnings(prior/'td_project/camera_to_dsi_display_Runs'/stage/'build_console.log')
 warning_review[stage]=dict(lines=sum(a.values()),prior_lines=sum(b.values()),added=list((a-b).elements()),removed=list((b-a).elements()))
 assert not warning_review[stage]['added'] and not warning_review[stage]['removed']
coverage=[s.strip() for s in read(phy/'constraint_coverage.txt').splitlines() if re.match(r'^\d+\. checking .*\(\d+\)',s)]
old_coverage=[s.strip() for s in read(prior/'td_project/camera_to_dsi_display_Runs/phy_1/constraint_coverage.txt').splitlines() if re.match(r'^\d+\. checking .*\(\d+\)',s)]
assert [s for s in coverage if 'dummy node(' not in s]==[s for s in old_coverage if 'dummy node(' not in s]
old_hashes={e['path']:e['sha256'] for e in load(prior/'inputs.json')}
changed=[e['path'] for e in inputs if old_hashes[e['path']]!=e['sha256']]
assert set(changed)=={'user_source/hdl_source/design_top_wrapper.v','user_source/hdl_source/experiment_osd.v','user_source/hdl_source/isp/isp_top.v','user_source/hdl_source/tape_hole_tracker.v'}
bit=phy/'camera_to_dsi_display.bit'
data=dict(status='PASS_build_only',build_root=build.relative_to(root).as_posix(),simulation_root=tests_root.relative_to(root).as_posix(),
 input_count=210,source_entries=70,changed_production_inputs=changed,timing=metrics,resources=resources,canonical_max_delays=canonical,warnings=warning_review,
 coverage_summary=coverage,prior_coverage_summary=old_coverage,bit=dict(bytes=bit.stat().st_size,sha256=sha(bit)))
if '--build-only' not in sys.argv:
 assert read(tests_root/'sim/regression_exit_code.txt').strip()=='0'
 names=re.findall(r'Name="([^"]+)"; Pass=',read(tests_root/'sim/run_modelsim.ps1'))
 assert len(names)==len(set(names))==32
 data['tests']=[]
 for name in names:
  p=tests_root/'sim/modelsim_work'/name;console=read(p/'console.log');compile_text=read(p/'compile.log')
  assert 'PASS ' in console and 'Errors: 0' in console and not re.search(r'(?m)^#?\s*\*\* (Fatal|Error):',console+compile_text),name
  for command in re.findall(r'(?m)^vlog .+$',compile_text):
   for token in command.split():
    if token.endswith('.v'):
     source=(tests_root/'sim'/token).resolve();rel=source.relative_to(tests_root)
     assert sha(source)==sha(project/rel),rel
  data['tests'].append(dict(name=name,console_sha256=sha(p/'console.log'),compile_sha256=sha(p/'compile.log'),pass_lines=[s for s in console.splitlines() if 'PASS ' in s]))
 old_record=root/'开发实施/验收记录/20261010_B3528动态追踪_轮次1'
 old_copies=load(old_record/'manifest.json')['copies']
 for e in old_copies:assert sha(old_record/e['path'])==e['sha256'] and (old_record/e['path']).stat().st_size==e['bytes'],e['path']
 rollback=project/'release/dynamic_tracking_v1_20261010/camera_to_dsi_display.bit'
 assert sha(rollback)=='a93d219750d3d76564a4677895f63c8f3b811277fcc8007a9828f38c4608a379'
 data.update(status='PASS_logic_and_build_only',rollback_sha256=sha(rollback),prior_evidence_copies=len(old_copies))
 (tests_root/'audit.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({k:data[k] for k in ['status','timing','resources','bit','warnings']},ensure_ascii=False))
