from pathlib import Path
from collections import Counter
import hashlib,json,re
root=Path(__file__).resolve().parent.parent;project=root/'fpga/component_inspector'
build=root/'tmp/tracking_publish_diag_r2_td_20261011';prior=root/'tmp/tracking_black_fix_r2_td_20261011'
oldtests=root/'tmp/tracking_black_fix_r3_td_20261011'
read=lambda p:p.read_text(encoding='utf-8-sig',errors='replace')
load=lambda p:json.loads(read(p));sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
inputs=load(build/'inputs.json');assert len(inputs)==210
for e in inputs:assert sha(build/e['path'])==e['sha256']==sha(project/e['path']),e['path']
for name in ['stage_inputs.json','simulation_inputs.json']:
 for e in load(build/name):assert sha(build/e['path'])==e['sha256'],e['path']
old={e['path']:e['sha256'] for e in load(prior/'inputs.json')}
changed=[e['path'] for e in inputs if old[e['path']]!=e['sha256']]
assert set(changed)=={'td_project/camera_to_dsi_display.sdc','user_source/hdl_source/design_top_wrapper.v','user_source/hdl_source/experiment_osd.v','user_source/hdl_source/video_in.v'},changed
# Remove only the explicit read-only observer additions, then prove that the
# entire capture/MC/FIFO/publication implementation is still exactly v2.
v=read(build/'user_source/hdl_source/video_in.v')
v=v.replace(',\n output reg [24:0] O_publish_diagnostic','')
start=v.index('// Read-only previous-frame evidence.')
end=v.index('reg S_ddr_wr_valid;',start);v=v[:start]+v[end:]
start=v.index('always @(posedge I_ddr_clk or negedge I_rst_n) begin\n if(!I_rst_n) begin publish_seen')
end=v.index('endmodule',start);v=v[:start]+v[end:]
assert v==read(prior/'user_source/hdl_source/video_in.v'),'video transport changed beyond observer'
runs=build/'td_project/camera_to_dsi_display_Runs';phy=runs/'phy_1'
for stage,last in [('syn_1','opt_gate'),('phy_1','bitgen')]:
 p=runs/stage;assert read(p/'build_exit_code.txt').strip()=='0'
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
assert resources['slice_percent']<80 and resources['eram_used']==48 and resources['dsp_used']==8
def delays(p):
 return [dict(total=int(m[1]),dominated=int(m[2]),shadowed=int(m[3]),ignored=int(m[4]),constraint=m[5]) for m in re.finditer(r'^\s*(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(set_max_delay .+)$',read(p).split('MCP/SMD Details')[0],re.M)]
canonical=delays(phy/'camera_to_dsi_display_exception.timing')
old_delays=delays(prior/'td_project/camera_to_dsi_display_Runs/phy_1/camera_to_dsi_display_exception.timing')
assert len(canonical)==37 and all(e['total']>0 and e['ignored']==0 for e in canonical)
assert Counter(e['constraint'] for e in canonical if 'u_publish_display/' not in e['constraint'])==Counter(e['constraint'] for e in old_delays)
assert sum('u_publish_display/' in e['constraint'] for e in canonical)==3
def warnings(p):
 return Counter(re.sub(r'(\.v)\(\d+\)',r'\1(LINE)',s) for s in read(p).splitlines() if re.match(r'^\w+-\d+ (?:CRITICAL-)?WARNING:',s))
review={}
for stage in ['syn_1','phy_1']:
 a=warnings(runs/stage/'build_console.log');b=warnings(prior/'td_project/camera_to_dsi_display_Runs'/stage/'build_console.log')
 review[stage]=dict(lines=sum(a.values()),prior_lines=sum(b.values()),added=list((a-b).elements()),removed=list((b-a).elements()))
 assert not review[stage]['added'] and not review[stage]['removed'],review[stage]
coverage=[s.strip() for s in read(phy/'constraint_coverage.txt').splitlines() if re.match(r'^\d+\. checking .*\(\d+\)',s)]
assert read(build/'sim/regression_exit_code.txt').strip()=='0'
old_audit=load(oldtests/'audit.json');previous={e['name']:e for e in old_audit['tests']}
names=re.findall(r'Name="([^"]+)"; Pass=',read(build/'sim/run_modelsim.ps1'));assert len(names)==len(set(names))==34
fresh={'publish_diag','tracking_osd','osd','frame_metadata','isp_metadata_stop','isp_writer_stop'}
tests=[]
for name in names:
 if name in fresh:
  p=build/'sim/modelsim_work'/name
  console=read(p/'console.log');compiled_text=read(p/'compile.log')
  assert 'PASS ' in console and 'Errors: 0' in console and not re.search(r'(?m)^#?\s*\*\* (Fatal|Error):',console+compiled_text),name
  compiled=[]
  for command in re.findall(r'(?m)^vlog .+$',compiled_text):
   for token in command.split():
    if token.endswith('.v'):
     src=(build/'sim'/token).resolve();rel=src.relative_to(build)
     assert sha(src)==sha(project/rel),(name,rel)
     compiled.append(dict(path=rel.as_posix(),sha256=sha(src)))
  assert compiled,name
  tests.append(dict(name=name,execution='fresh_D3_R2',source=build.relative_to(root).as_posix(),compiled_inputs=compiled,console_sha256=sha(p/'console.log'),compile_sha256=sha(p/'compile.log'),pass_lines=[s for s in console.splitlines() if 'PASS ' in s]))
 else:
  e=previous[name];p=root/e['source']/'sim/modelsim_work'/name
  assert sha(p/'console.log')==e['console_sha256'] and sha(p/'compile.log')==e['compile_sha256']
  for i in e['compiled_inputs']:assert sha(build/i['path'])==i['sha256'],(name,i['path'])
  tests.append(dict(e,execution='prior_verified_unchanged_source_closure'))
bit=phy/'camera_to_dsi_display.bit'
data=dict(status='PASS_diagnostic_logic_and_build_only',onsite='PENDING',build_root=build.relative_to(root).as_posix(),input_count=210,changed_production_inputs=changed,transport_unchanged_after_observer_removal=True,timing=metrics,resources=resources,canonical_max_delays=canonical,warnings=review,coverage_summary=coverage,tests=tests,fresh_tests=6,reused_unchanged_tests=28,bit=dict(bytes=bit.stat().st_size,sha256=sha(bit)))
(build/'audit.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({k:data[k] for k in ['status','timing','resources','bit','warnings','fresh_tests','reused_unchanged_tests']},ensure_ascii=False))
