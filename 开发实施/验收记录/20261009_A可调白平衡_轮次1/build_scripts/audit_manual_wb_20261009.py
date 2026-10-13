from pathlib import Path
from collections import Counter
import hashlib, json, re, sys

root = Path(__file__).resolve().parent.parent
project = root / 'fpga/component_inspector'
build = root / 'tmp/manual_wb_v1_td_20261009'
prior = root / 'tmp/fixed_wb_tuning_r2_td_20261009'
read = lambda p: p.read_text(encoding='utf-8-sig', errors='replace')
load = lambda p: json.loads(read(p))
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
dump = lambda p,d: p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
runs = build / 'td_project/camera_to_dsi_display_Runs'
old_runs = prior / 'td_project/camera_to_dsi_display_Runs'
phy = runs / 'phy_1'
for name, end, log in [('syn_1','opt_gate','codex_syn.log'),('phy_1','bitgen','codex_phy.log')]:
    p = runs / name
    assert read(p/'command_exit_code.txt').strip()=='0'
    assert (p/('.'+end+'.end.f')).exists() and not list(p.glob('.*.error.f'))
    assert not re.search(r'(?m)^\w+-\d+\s+(?:CRITICAL-)?ERROR:',read(p/log))
inputs = load(build/'inputs.json')
assert len(inputs)==209
for e in inputs:
    assert sha(build/e['path'])==e['sha256']==sha(project/e['path']),e['path']
for manifest in ['stage_inputs.json','simulation_inputs.json']:
    for e in load(build/manifest):
        assert sha(build/e['path'])==e['sha256'],e['path']
        if manifest=='simulation_inputs.json':
            assert sha(project/e['path'])==e['sha256'],e['path']
old = {e['path']:e['sha256'] for e in load(prior/'inputs.json')}
changed = [e['path'] for e in inputs if old[e['path']]!=e['sha256']]
assert changed==load(build/'preparation.json')['changed_production_inputs'] and len(changed)==8
assert not any(e['path'].endswith(('.sdc','.adc')) and old[e['path']]!=e['sha256'] for e in inputs)

timing = read(phy/'camera_to_dsi_display_pr.timing')
assert 'Confidence          : Routed' in timing and 'Check Corner        : Both (Slow and Fast)' in timing
assert re.findall(r'^(Slow|Fast)\s*\|\s*yes\s+yes',timing,re.M)==['Slow','Fast']
metrics = {k:float(re.search(label+r'\s*:\s*([-\d.]+)ns',timing)[1]) for k,label in [
    ('setup_wns_ns','SWNS'),('setup_tns_ns','STNS'),('hold_wns_ns','HWNS'),('hold_tns_ns','HTNS')]}
assert all(float(v)>=0 for v in re.findall(r'(?:SWNS|HWNS)\s*:\s*([-\d.]+)ns',timing))
assert metrics['setup_tns_ns']==metrics['hold_tns_ns']==0
assert all(int(v)==0 for v in re.findall(r'(\d+) Viol Endpoints',timing))
metrics['sta_coverage_percent']=float(re.search(r'STA coverage\s*:\s*([\d.]+)%',timing)[1])
area = read(phy/'camera_to_dsi_display_phy.area')
resources={}
for name in ['slice','eram','dsp']:
    m=re.search(r'^#'+name+r'\*?\s+(\d+)\s+out of\s+(\d+)\s+([\d.]+)%',area,re.M)
    resources.update({name+'_used':int(m[1]),name+'_total':int(m[2]),name+'_percent':float(m[3])})
for name in ['lut6','reg']:
    resources[name+'_used']=int(re.search(r'^#'+name+r'\s+(\d+)',area,re.M)[1])
assert resources['slice_percent']<80 and resources['eram_used']==48 and resources['dsp_used']==8
assert '|    u_awb ' in area and '|divider ' not in area

def delays(p):
    return [dict(total=int(m[1]),dominated=int(m[2]),shadowed=int(m[3]),ignored=int(m[4]),constraint=m[5])
        for m in re.finditer(r'^\s*(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(set_max_delay .+)$',read(p).split('MCP/SMD Details')[0],re.M)]
canonical=delays(phy/'camera_to_dsi_display_exception.timing')
previous=delays(old_runs/'phy_1/camera_to_dsi_display_exception.timing')
assert len(canonical)==31 and [e['constraint'] for e in canonical]==[e['constraint'] for e in previous]
assert all(e['total']>0 and e['ignored']==0 for e in canonical)
assert [e['constraint'] for e in canonical if e['shadowed']]==[e['constraint'] for e in previous if e['shadowed']]
payload_deltas=[]
for a,b in zip(canonical,previous):
    if a['total']!=b['total']:
        payload_deltas.append(dict(constraint=a['constraint'],before=b['total'],now=a['total']))
coverage=read(phy/'constraint_coverage.txt')
summary=lambda p:[s.strip() for s in read(p).splitlines() if re.match(r'^\d+\. checking .*\(\d+\)',s)]
new_summary,old_summary=summary(phy/'constraint_coverage.txt'),summary(old_runs/'phy_1/constraint_coverage.txt')
assert [s for s in new_summary if 'dummy node(' not in s]==[s for s in old_summary if 'dummy node(' not in s]
assert '3. checking dummy node(4) (HIGH)' in new_summary
dummy=lambda p:read(p).split('3. checking dummy nodes. (HIGH)')[1].split('4. checking invalid constraints. (HIGH)')[0]
new_dummy=dummy(phy/'constraint_coverage.txt')
assert 'u_isp_top/u_awb/mult0_' in new_dummy and 'divide_G_B' not in new_dummy
assert 'u_monitor_display/payload_reg[94]_syn_2.ofb' in new_dummy

def warnings(p):
    return Counter(re.sub(r'(\.v)\(\d+\)',r'\1(LINE)',s) for s in read(p).splitlines() if re.match(r'^\w+-\d+ (?:CRITICAL-)?WARNING:',s))
warning_review={}
for name,log in [('syn_1','codex_syn.log'),('phy_1','codex_phy.log')]:
    a,b=warnings(runs/name/log),warnings(old_runs/name/'build_console.log')
    added,removed=list((a-b).elements()),list((b-a).elements())
    if name=='syn_1': assert not added and not removed
    else:
        assert len(added)==len(removed)==1
        assert added[0].startswith('PHY-5060 CRITICAL-WARNING:') and '419 clock pins; 1 data/ctrl pins' in added[0]
        assert '307 clock pins; 1 data/ctrl pins' in removed[0]
    warning_review[name]=dict(lines=sum(a.values()),prior_lines=sum(b.values()),added=added,removed=removed)

prior_evidence={}
for name in ['20261008_A灰度边缘独立判定_轮次1','20261009_A成像参数冻结与计划修订_轮次1',
             '20261009_A固定白平衡调参版_轮次1','20261009_A固定白平衡偏青反馈_轮次1']:
    p=root/'开发实施/验收记录'/name
    manifest=load(p/'manifest.json');entries=manifest.get('copies',manifest.get('files'))
    assert entries is not None
    for e in entries:
        assert sha(p/e['path'])==e['sha256'] and (p/e['path']).stat().st_size==e['bytes']
    prior_evidence[name]=len(entries)
bit=phy/'camera_to_dsi_display.bit'
assert bit.stat().st_size==1789539
data=dict(status='PASS_build_only_tests_pending',timing=metrics,resources=resources,input_count=209,
    changed_production_inputs=changed,canonical_max_delays=canonical,max_delay_path_count_changes=payload_deltas,
    coverage_summary=new_summary,coverage_review=dict(old_dummy=dummy(old_runs/'phy_1/constraint_coverage.txt'),new_dummy=new_dummy,
        reason='8 manual-color DSP multipliers restore DSP mode-pin model category; mapped LSLICE dangling output changes to monitor payload[94]. Divider output category remains absent. Other 13 categories unchanged; existing PLL/I/O/exception limitations retained.'),
    warnings=warning_review,warning_reason='Existing mixed clock/data O_cam_24m clock fanout 307 -> 419 due control and wider mailbox registers; same warning class and one data/control sink. All final routed setup/hold checks pass. No claim that pre-existing clock topology is fixed.',
    bit=dict(sha256=sha(bit),bytes=bit.stat().st_size),prior_evidence_copies=prior_evidence,
    limits=['Board color calibration, cold-start, long-run and classification accuracy pending.','Reset restores R/B 64; no Flash persistence.',
            'LOCK controls WB editing only; exposure/gain remain tunable.','Old thresholds require paired hardware samples under frozen optical settings.',
            'Recent observation is not bound to DDR display frame; full recipe/CAL/INVALID/UNCERTAIN lifecycle not implemented.',
            'STA coverage 92.59%; pre-existing PLL/I/O and timing exception limitations remain.'])
if '--build-only' not in sys.argv:
    names=re.findall(r'Name="([^"]+)"; Pass=',read(build/'sim/run_modelsim.ps1'))
    assert len(names)==23 and len(set(names))==23
    tests=[]
    for name in names:
        p=build/'sim/modelsim_work'/name
        console=read(p/'console.log');compile_text=read(p/'compile.log')
        assert 'PASS ' in console and 'Errors: 0' in console,name
        assert not re.search(r'(?m)^#?\s*\*\* (Fatal|Error):',console+compile_text),name
        tests.append(dict(name=name,console_sha256=sha(p/'console.log'),compile_sha256=sha(p/'compile.log'),
            pass_lines=[s for s in console.splitlines() if 'PASS ' in s]))
    data.update(status='PASS_logic_and_build_only',tests=tests)
    dump(build/'audit.json',data)
else: dump(build/'build_audit.json',data)
print(json.dumps({k:data[k] for k in ['status','timing','resources','bit','prior_evidence_copies']},ensure_ascii=True))
