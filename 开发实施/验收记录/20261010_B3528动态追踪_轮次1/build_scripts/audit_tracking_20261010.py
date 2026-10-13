from pathlib import Path
from collections import Counter
import hashlib, json, re, sys

root = Path(__file__).resolve().parent.parent
project = root / 'fpga/component_inspector'
build = root / 'tmp/dynamic_tracking_v1_r5_td_20261010'
first = root / 'tmp/dynamic_tracking_v1_r3_td_20261010'
retest = root / 'tmp/dynamic_tracking_v1_r4_td_20261010'
prior = root / 'tmp/manual_wb_v1_td_20261009'
read = lambda p: p.read_text(encoding='utf-8-sig', errors='replace')
load = lambda p: json.loads(read(p))
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
runs = build / 'td_project/camera_to_dsi_display_Runs'
phy = runs / 'phy_1'
for stage, last in [('syn_1', 'opt_gate'), ('phy_1', 'bitgen')]:
    p = runs / stage
    assert read(p / 'command_exit_code.txt').strip() == '0'
    assert (p / ('.' + last + '.end.f')).exists() and not list(p.glob('.*.error.f'))
    assert not re.search(r'(?m)^\w+-\d+\s+(?:CRITICAL-)?ERROR:', read(p / 'build_console.log'))
inputs = load(build / 'inputs.json')
assert len(inputs) == 210
for e in inputs:
    assert sha(build / e['path']) == e['sha256'] == sha(project / e['path']), e['path']
assert load(retest / 'inputs.json') == load(first / 'inputs.json')
first_inputs = {e['path']: e['sha256'] for e in load(first / 'inputs.json')}
assert [e['path'] for e in inputs if e['sha256'] != first_inputs[e['path']]] == ['user_source/hdl_source/experiment_osd.v']
for snapshot in [first, retest]:
    for e in load(snapshot / 'inputs.json'):
        assert sha(snapshot / e['path']) == e['sha256'], e['path']
original_sim = {e['path']: e['sha256'] for e in load(first / 'simulation_inputs.json')}
retest_sim = {e['path']: e['sha256'] for e in load(retest / 'simulation_inputs.json')}
final_sim = {e['path']: e['sha256'] for e in load(build / 'simulation_inputs.json')}
assert original_sim.keys() == retest_sim.keys()
assert [p for p in original_sim if original_sim[p] != retest_sim[p]] == ['sim/tb_presence_modes.v']
assert [p for p in retest_sim if retest_sim[p] != final_sim[p]] == ['sim/tb_tracking_osd.v']
for path, digest in final_sim.items():
    assert sha(build / path) == digest == sha(project / path), path
for path, digest in retest_sim.items():
    assert sha(retest / path) == digest, path
for path, digest in original_sim.items():
    assert sha(first / path) == digest, path
for e in load(build / 'stage_inputs.json'):
    assert sha(build / e['path']) == e['sha256'], e['path']
old = {e['path']: e['sha256'] for e in load(prior / 'inputs.json')}
changed = [e['path'] for e in inputs if old.get(e['path']) != e['sha256']]
for stage in ['syn_1', 'phy_1']:
    assert len(re.findall(r'<File Path=', read(runs / stage / 'camera_to_dsi_display.prj'))) == 70

timing = read(phy / 'camera_to_dsi_display_pr.timing')
assert 'Confidence          : Routed' in timing and 'Check Corner        : Both (Slow and Fast)' in timing
assert re.findall(r'^(Slow|Fast)\s*\|\s*yes\s+yes', timing, re.M) == ['Slow', 'Fast']
metrics = {k: float(re.search(label + r'\s*:\s*([-\d.]+)ns', timing)[1]) for k, label in [
    ('setup_wns_ns', 'SWNS'), ('setup_tns_ns', 'STNS'), ('hold_wns_ns', 'HWNS'), ('hold_tns_ns', 'HTNS')]}
assert all(float(v) >= 0 for v in re.findall(r'(?:SWNS|HWNS)\s*:\s*([-\d.]+)ns', timing))
assert metrics['setup_tns_ns'] == metrics['hold_tns_ns'] == 0
assert all(int(v) == 0 for v in re.findall(r'(\d+) Viol Endpoints', timing))
metrics['sta_coverage_percent'] = float(re.search(r'STA coverage\s*:\s*([\d.]+)%', timing)[1])
area = read(phy / 'camera_to_dsi_display_phy.area')
resources = {}
for name in ['slice', 'eram', 'dsp']:
    m = re.search(r'^#' + name + r'\*?\s+(\d+)\s+out of\s+(\d+)\s+([\d.]+)%', area, re.M)
    resources.update({name + '_used': int(m[1]), name + '_total': int(m[2]), name + '_percent': float(m[3])})
for name in ['lut6', 'reg']:
    resources[name + '_used'] = int(re.search(r'^#' + name + r'\s+(\d+)', area, re.M)[1])
assert resources['slice_percent'] < 80 and resources['eram_used'] == 48 and resources['dsp_used'] == 8

def delays(p):
    return [dict(total=int(m[1]), dominated=int(m[2]), shadowed=int(m[3]), ignored=int(m[4]), constraint=m[5])
        for m in re.finditer(r'^\s*(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(set_max_delay .+)$',
            read(p).split('MCP/SMD Details')[0], re.M)]
canonical = delays(phy / 'camera_to_dsi_display_exception.timing')
previous = delays(prior / 'td_project/camera_to_dsi_display_Runs/phy_1/camera_to_dsi_display_exception.timing')
assert len(canonical) == 34 and all(e['total'] > 0 and e['ignored'] == 0 for e in canonical)
new_constraints = [e['constraint'] for e in canonical if e['constraint'] not in {x['constraint'] for x in previous}]
removed_constraints = [e['constraint'] for e in previous if e['constraint'] not in {x['constraint'] for x in canonical}]
assert len(new_constraints) == 6 and len(removed_constraints) == 3
assert all('u_roi_display/' in e for e in removed_constraints)
assert all('crossing/' in e or 'u_active_frame_display/' in e for e in new_constraints)
summary = lambda p: [s.strip() for s in read(p).splitlines() if re.match(r'^\d+\. checking .*\(\d+\)', s)]
coverage = summary(phy / 'constraint_coverage.txt')
old_coverage = summary(prior / 'td_project/camera_to_dsi_display_Runs/phy_1/constraint_coverage.txt')
assert [s for s in coverage if 'dummy node(' not in s] == [s for s in old_coverage if 'dummy node(' not in s]

def warnings(p):
    return Counter(re.sub(r'(\.v)\(\d+\)', r'\1(LINE)', s) for s in read(p).splitlines()
        if re.match(r'^\w+-\d+ (?:CRITICAL-)?WARNING:', s))
warning_review = {}
for stage in ['syn_1', 'phy_1']:
    a = warnings(runs / stage / 'build_console.log')
    old_log = 'codex_syn.log' if stage == 'syn_1' else 'codex_phy.log'
    b = warnings(prior / 'td_project/camera_to_dsi_display_Runs' / stage / old_log)
    warning_review[stage] = dict(lines=sum(a.values()), prior_lines=sum(b.values()),
        added=list((a-b).elements()), removed=list((b-a).elements()))
    assert not warning_review[stage]['added'] and not warning_review[stage]['removed']

if '--build-only' in sys.argv:
    print(json.dumps(dict(timing=metrics, resources=resources, constraints=len(canonical),
        warnings=warning_review, coverage=coverage), ensure_ascii=False))
    sys.exit(0)
assert read(retest / 'sim/regression_exit_code.txt').strip() == '0'
assert read(build / 'sim/regression_exit_code.txt').strip() == '0'
names = re.findall(r'Name="([^"]+)"; Pass=', read(retest / 'sim/run_modelsim.ps1'))
assert len(names) == len(set(names)) == 29
tests = []
for name in names:
    # The first ten passed before a positional legacy test adapter failed.
    # R4 changes only that adapter, keeps every assertion and all production RTL.
    test_build = build if name in ['tracking_osd', 'osd'] else first if name in names[:10] else retest
    p = test_build / 'sim/modelsim_work' / name
    console, compile_text = read(p / 'console.log'), read(p / 'compile.log')
    assert 'PASS ' in console and 'Errors: 0' in console, name
    assert not re.search(r'(?m)^#?\s*\*\* (Fatal|Error):', console + compile_text), name
    # Reuse a result only when EVERY actual compiled RTL/testbench source is
    # byte-identical to the final snapshot, not just when the test name matches.
    for command in re.findall(r'(?m)^vlog .+$', compile_text):
        for token in command.split():
            if token.endswith('.v'):
                source = (test_build / 'sim' / token).resolve()
                rel = source.relative_to(test_build).as_posix()
                assert sha(source) == sha(build / rel), (name, rel)
    tests.append(dict(name=name, build_root=test_build.relative_to(root).as_posix(),
        console_sha256=sha(p / 'console.log'), compile_sha256=sha(p / 'compile.log'),
        pass_lines=[s for s in console.splitlines() if 'PASS ' in s]))
rollback = project / 'release/manual_wb_tuning_v1_20261009/camera_to_dsi_display.bit'
assert sha(rollback) == 'f71b8d6cc7e8d90c04a84c9ce4916403e2d763c49c5d2c57a1ebf511e8e02800'
old_record = root / '开发实施/验收记录/20261009_A可调白平衡_轮次1'
old_copies = load(old_record / 'manifest.json')['copies']
for e in old_copies:
    assert sha(old_record / e['path']) == e['sha256'] and (old_record / e['path']).stat().st_size == e['bytes']
bit = phy / 'camera_to_dsi_display.bit'
assert bit.stat().st_size == 1789539
data = dict(status='PASS_logic_and_build_only', input_count=210, source_entries=70, changed_production_inputs=changed,
    timing=metrics, resources=resources, canonical_max_delays=canonical, new_constraints=new_constraints,
    removed_constraints=removed_constraints, coverage_summary=coverage, prior_coverage_summary=old_coverage,
    warnings=warning_review, tests=tests, bit=dict(sha256=sha(bit), bytes=bit.stat().st_size),
    rollback_sha256=sha(rollback), prior_evidence_copies=len(old_copies),
    limits=['Hardware tracking/classification/cold start/long run pending.',
        'Upper hole band and fixed vertical alignment required; slow horizontal manual motion only.',
        'Trial pitch/brightness/shape/step values need physical measurement.',
        'Periodic-pattern full-pitch motion can alias to another pocket; no industrial identity guarantee.',
        'Paired static/moving left-middle-right samples and optical freeze still required.',
        'Existing PLL/I/O/exception coverage limitations remain; no Flash recipe or full CAL lifecycle.'])
(build / 'audit.json').write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print(json.dumps({k: data[k] for k in ['status', 'timing', 'resources', 'bit', 'warnings', 'prior_evidence_copies']}, ensure_ascii=False))
