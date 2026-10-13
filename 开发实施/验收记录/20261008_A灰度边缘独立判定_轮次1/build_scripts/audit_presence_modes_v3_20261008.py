from pathlib import Path
from collections import Counter
import hashlib,json,re
root=Path(__file__).resolve().parent.parent
build=root/'tmp/presence_modes_v3_td_20261008'
project=root/'fpga/component_inspector'
prior=root/'tmp/led_presence_demo_v2_r2_td_20261008'
retry=root/'tmp/presence_modes_v3_sim_r2_20261008'
read=lambda p:p.read_text(encoding='utf-8-sig',errors='replace')
load=lambda p:json.loads(read(p))
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
syn=build/'td_project/camera_to_dsi_display_Runs/syn_1'
phy=syn.parent/'phy_1'
old_phy=prior/'td_project/camera_to_dsi_display_Runs/phy_1'
for stage,end in [(syn,'opt_gate'),(phy,'bitgen')]:
 assert (stage/('.'+end+'.end.f')).exists(),str(stage)
 assert not list(stage.glob('.*.error.f'))
 assert not re.search(r'(?m)^\w+-\d+\s+(?:CRITICAL-)?ERROR:',read(stage/'build_console.log'))
for entry in load(build/'inputs.json'):
 assert sha(build/entry['path'])==entry['sha256']==sha(project/entry['path']),entry['path']
timing=read(phy/'camera_to_dsi_display_pr.timing')
assert 'Confidence          : Routed' in timing and 'Check Corner        : Both (Slow and Fast)' in timing
corners=re.findall(r'^(Slow|Fast)\s*\|\s*yes\s+yes',timing,re.M)
assert corners==['Slow','Fast']
metrics={k:float(re.search(label+r'\s*:\s*([-\d.]+)ns',timing)[1]) for k,label in [('setup_wns_ns','SWNS'),('setup_tns_ns','STNS'),('hold_wns_ns','HWNS'),('hold_tns_ns','HTNS')]}
assert all(float(v)>=0 for v in re.findall(r'(?:SWNS|HWNS)\s*:\s*([-\d.]+)ns',timing))
assert metrics['setup_tns_ns']==metrics['hold_tns_ns']==0
assert all(int(v)==0 for v in re.findall(r'(\d+) Viol Endpoints',timing))
metrics['sta_coverage_percent']=float(re.search(r'STA coverage\s*:\s*([\d.]+)%',timing)[1])
def resources(path):
 text=read(path);data={}
 for name in ['slice','eram','dsp']:
  match=re.search(r'^#'+name+r'\*?\s+(\d+)\s+out of\s+(\d+)\s+([\d.]+)%',text,re.M)
  assert match,name
  data[name+'_used'],data[name+'_total'],data[name+'_percent']=int(match[1]),int(match[2]),float(match[3])
 for name in ['lut6','reg']:data[name+'_used']=int(re.search(r'^#'+name+r'\s+(\d+)',text,re.M)[1])
 return data
area=resources(phy/'camera_to_dsi_display_phy.area');old_area=resources(old_phy/'camera_to_dsi_display_phy.area')
assert area['slice_percent']<80 and area['eram_used']==old_area['eram_used'] and area['dsp_used']==old_area['dsp_used']
def max_delays(path):
 table=read(path).split('MCP/SMD Details')[0]
 return [dict(total=int(m[1]),dominated=int(m[2]),shadowed=int(m[3]),ignored=int(m[4]),constraint=m[5]) for m in re.finditer(r'^\s*(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(set_max_delay .+)$',table,re.M)]
canonical=max_delays(phy/'camera_to_dsi_display_exception.timing');old_canonical=max_delays(old_phy/'camera_to_dsi_display_exception.timing')
assert len(canonical)==31
assert [e['constraint'] for e in canonical]==[e['constraint'] for e in old_canonical]
assert all(e['total']>0 and e['ignored']==0 for e in canonical)
assert [e['constraint'] for e in canonical if e['shadowed']]==[e['constraint'] for e in old_canonical if e['shadowed']]
coverage=read(phy/'constraint_coverage.txt')
assert all(s in coverage for s in ['checking invalid constraint(0)','checking no clock(0)','checking combinational loops(0)'])
coverage_summary=[s.strip() for s in coverage.splitlines() if re.match(r'^\d+\. checking .*\(\d+\)',s)]
old_summary=[s.strip() for s in read(old_phy/'constraint_coverage.txt').splitlines() if re.match(r'^\d+\. checking .*\(\d+\)',s)]
assert coverage_summary==old_summary,'Review changed coverage categories'
def warnings(path):
 return Counter(re.sub(r'(design_top_wrapper\.v)\(\d+\)',r'\1(LINE)',s) for s in read(path).splitlines() if re.match(r'^\w+-\d+ (?:CRITICAL-)?WARNING:',s))
warning_comparison={}
for name in ['syn_1','phy_1']:
 now=warnings(syn.parent/name/'build_console.log');then=warnings(prior/'td_project/camera_to_dsi_display_Runs'/name/'build_console.log')
 warning_comparison[name]={'lines':sum(now.values()),'prior_lines':sum(then.values()),'added':list((now-then).elements()),'removed':list((then-now).elements())}
 assert not warning_comparison[name]['added'],'New warnings require review'
tests=['presence_modes','display_state','observation','stop_recovery','classifier','osd','roi_chain','isp_writer_stop']
assert 'PASS ModelSim: all 1 tests, including original vendor ERAM model' in read(retry/'sim/suite_console.log')
failed=read(build/'sim/modelsim_work/roi_chain/console.log')
assert '** Fatal: ROI chain watchdog' in failed and 'frame=10' in failed
assert len(re.findall(r'\*\* Fatal:',failed))==1
old_tb=(build/'sim/tb_roi_chain.v').read_bytes().replace(b'\r\n',b'\n')
new_tb=(retry/'sim/tb_roi_chain.v').read_bytes().replace(b'\r\n',b'\n')
assert old_tb.replace(b'#50000000',b'#70000000')==new_tb
assert new_tb==(project/'sim/tb_roi_chain.v').read_bytes().replace(b'\r\n',b'\n')
for entry in load(build/'inputs.json'):
 assert sha(retry/entry['path'])==entry['sha256']
test_results=[]
for name in tests:
 attempt=retry if name=='roi_chain' else build
 console=attempt/'sim/modelsim_work'/name/'console.log';text=read(console)
 assert 'PASS' in text and 'Errors: 0' in text and not re.search(r'(?m)^#?\s*\*\* (Fatal|Error):',text),name
 if name!='roi_chain':assert sha(build/'sim'/('tb_'+name+'.v'))==sha(project/'sim'/('tb_'+name+'.v'))
 test_results.append({'name':name,'attempt':attempt.name,'console_sha256':sha(console),'pass_lines':[s for s in text.splitlines() if 'PASS ' in s]})
bit=phy/'camera_to_dsi_display.bit';assert bit.stat().st_size==1789539
data={'status':'PASS_logic_and_build_only','timing':metrics,'corners':corners,'resources':area,'resource_delta_r2':{k:area[k]-old_area[k] for k in ['slice_used','lut6_used','reg_used','eram_used','dsp_used']},'canonical_max_delays':canonical,'coverage_summary':coverage_summary,'coverage_categories_unchanged':True,'warnings':warning_comparison,'tests':test_results,'input_count':209,'bit':{'sha256':sha(bit),'bytes':bit.stat().st_size},'limits':['No board flashing, cold-start or optical accuracy acceptance.','All EC/GS and black-tape thresholds are uncalibrated experimental constants.','Black background and locator hole may pass the tape guard; high gain may fail the dark limit.','Transparent tape not supported by this guard.','Existing PLL/I/O/exception limitations retained; STA coverage not 100 percent.','Recent acquisition result is not DDR display-frame bound.']}
data['test_retry']={'initial_roi_watchdog_failure_preserved':True,'initial_passed_tests':7,'retry_passed_tests':1,'semantic_test_change':'50 ms to 70 ms watchdog only; assertions unchanged','retry_details':load(retry/'retry.json')}
(build/'audit.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({k:data[k] for k in ['status','timing','resources','resource_delta_r2','bit']}))
