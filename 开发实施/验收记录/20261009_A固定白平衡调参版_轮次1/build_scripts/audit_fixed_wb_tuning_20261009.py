from pathlib import Path
from collections import Counter
import hashlib, json, re

root = Path(__file__).resolve().parent.parent
project = root / 'fpga/component_inspector'
first = root / 'tmp/fixed_wb_tuning_td_20261009'
build = root / 'tmp/fixed_wb_tuning_r2_td_20261009'
prior = root / 'tmp/presence_modes_v3_td_20261008'
read = lambda p: p.read_text(encoding='utf-8-sig', errors='replace')
load = lambda p: json.loads(read(p))
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
syn = build / 'td_project/camera_to_dsi_display_Runs/syn_1'
phy = syn.parent / 'phy_1'
old_phy = prior / 'td_project/camera_to_dsi_display_Runs/phy_1'

for stage, end in [(syn, 'opt_gate'), (phy, 'bitgen')]:
    assert read(stage / 'command_exit_code.txt').strip() == '0', stage
    assert (stage / ('.' + end + '.end.f')).exists(), stage
    assert not list(stage.glob('.*.error.f')), stage
    assert not re.search(r'(?m)^\w+-\d+\s+(?:CRITICAL-)?ERROR:', read(stage / 'build_console.log'))
inputs = load(build / 'inputs.json')
assert len(inputs) == 209
for e in inputs:
    assert sha(build / e['path']) == e['sha256'] == sha(project / e['path']), e['path']
for e in load(build / 'stage_inputs.json'):
    assert sha(build / e['path']) == e['sha256'], e['path']
old_inputs = {e['path']: e['sha256'] for e in load(prior / 'inputs.json')}
changed = [e['path'] for e in inputs if old_inputs[e['path']] != e['sha256']]
assert sorted(changed) == sorted(['user_source/hdl_source/awb.v', 'user_source/hdl_source/isp/isp_top.v'])

timing = read(phy / 'camera_to_dsi_display_pr.timing')
assert 'Confidence          : Routed' in timing and 'Check Corner        : Both (Slow and Fast)' in timing
corners = re.findall(r'^(Slow|Fast)\s*\|\s*yes\s+yes', timing, re.M)
assert corners == ['Slow', 'Fast']
metrics = {k: float(re.search(label + r'\s*:\s*([-\d.]+)ns', timing)[1]) for k, label in [
    ('setup_wns_ns', 'SWNS'), ('setup_tns_ns', 'STNS'), ('hold_wns_ns', 'HWNS'), ('hold_tns_ns', 'HTNS')]}
assert all(float(v) >= 0 for v in re.findall(r'(?:SWNS|HWNS)\s*:\s*([-\d.]+)ns', timing))
assert metrics['setup_tns_ns'] == metrics['hold_tns_ns'] == 0
assert all(int(v) == 0 for v in re.findall(r'(\d+) Viol Endpoints', timing))
metrics['sta_coverage_percent'] = float(re.search(r'STA coverage\s*:\s*([\d.]+)%', timing)[1])

def resources(path):
    text, data = read(path), {}
    for name in ['slice', 'eram', 'dsp']:
        m = re.search(r'^#' + name + r'\*?\s+(\d+)\s+out of\s+(\d+)\s+([\d.]+)%', text, re.M)
        assert m, name
        data[name + '_used'], data[name + '_total'], data[name + '_percent'] = int(m[1]), int(m[2]), float(m[3])
    for name in ['lut6', 'reg']:
        data[name + '_used'] = int(re.search(r'^#' + name + r'\s+(\d+)', text, re.M)[1])
    return data

area = resources(phy / 'camera_to_dsi_display_phy.area')
old_area = resources(old_phy / 'camera_to_dsi_display_phy.area')
assert area['slice_percent'] < 80 and area['eram_used'] == old_area['eram_used']

def max_delays(path):
    table = read(path).split('MCP/SMD Details')[0]
    return [dict(total=int(m[1]), dominated=int(m[2]), shadowed=int(m[3]), ignored=int(m[4]), constraint=m[5])
            for m in re.finditer(r'^\s*(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(set_max_delay .+)$', table, re.M)]

canonical = max_delays(phy / 'camera_to_dsi_display_exception.timing')
old_canonical = max_delays(old_phy / 'camera_to_dsi_display_exception.timing')
assert len(canonical) == 31
assert [e['constraint'] for e in canonical] == [e['constraint'] for e in old_canonical]
assert all(e['total'] > 0 and e['ignored'] == 0 for e in canonical)
assert [e['constraint'] for e in canonical if e['shadowed']] == [e['constraint'] for e in old_canonical if e['shadowed']]
coverage = read(phy / 'constraint_coverage.txt')
assert all(s in coverage for s in ['checking invalid constraint(0)', 'checking no clock(0)', 'checking combinational loops(0)'])
summary = lambda p: [s.strip() for s in read(p).splitlines() if re.match(r'^\d+\. checking .*\(\d+\)', s)]
coverage_summary = summary(phy / 'constraint_coverage.txt')
old_coverage_summary = summary(old_phy / 'constraint_coverage.txt')
assert [s for s in coverage_summary if 'checking dummy node(' not in s] == [s for s in old_coverage_summary if 'checking dummy node(' not in s]
assert '3. checking dummy node(3) (HIGH)' in coverage_summary
assert '3. checking dummy node(4) (HIGH)' in old_coverage_summary
dummy_section = lambda p: read(p).split('3. checking dummy nodes. (HIGH)')[1].split('4. checking invalid constraints. (HIGH)')[0]
old_dummy, new_dummy = dummy_section(old_phy / 'constraint_coverage.txt'), dummy_section(phy / 'constraint_coverage.txt')
assert 'PH1P_PHY_DSPSIOU_V2' in old_dummy and 'PH1P_PHY_DSPSIOU_V2' not in new_dummy
assert 'u_isp_top/u_awb/divide_G_B_r1' in old_dummy and 'u_isp_top/u_awb' not in new_dummy
assert 'rd_to_wr_cross_inst/sync_r1_reg[7]_syn_2.ofa' in new_dummy
coverage_review = dict(dummy_model_categories_v3=4, dummy_model_categories_now=3,
    removed='AWB DSP mode pins and divider dangling output disappear with fixed-gain synthesis pruning.',
    changed_lslice_output='u_video_in/U_w128_d512_fifo/soft_fifo_al_4057d6b76aa6_Inst/rd_to_wr_cross_inst/sync_r1_reg[7]_syn_2.ofa',
    review='Mapped dangling output changed; FIFO RTL is byte-identical, relevant integrated ISP/writer tests pass. No claim that every physical pin is independently verified.',
    other_13_coverage_categories_unchanged=True, old_dummy_section=old_dummy, new_dummy_section=new_dummy)

def warnings(path):
    # Source line locations shift when parameters are added; diagnostic text is retained.
    return Counter(re.sub(r'(\.v)\(\d+\)', r'\1(LINE)', s) for s in read(path).splitlines()
                   if re.match(r'^\w+-\d+ (?:CRITICAL-)?WARNING:', s))

warning_comparison = {}
for name in ['syn_1', 'phy_1']:
    now = warnings(syn.parent / name / 'build_console.log')
    then = warnings(prior / 'td_project/camera_to_dsi_display_Runs' / name / 'build_console.log')
    warning_comparison[name] = dict(lines=sum(now.values()), prior_lines=sum(then.values()),
                                    added=list((now - then).elements()), removed=list((then - now).elements()))
    assert not warning_comparison[name]['added'], 'New warnings require review'

assert 'PASS ModelSim: all 11 tests, including original vendor ERAM model' in read(first / 'sim/suite_console.log')
first_syn = first / 'td_project/camera_to_dsi_display_Runs/syn_1'
first_added = list((warnings(first_syn / 'build_console.log') - warnings(prior / 'td_project/camera_to_dsi_display_Runs/syn_1/build_console.log')).elements())
assert len(first_added) == 2 and all(s.startswith('HDL-7238 CRITICAL-WARNING:') for s in first_added)
first_inputs = {e['path']: e['sha256'] for e in load(first / 'inputs.json')}
assert [e['path'] for e in inputs if first_inputs[e['path']] != e['sha256']] == ['user_source/hdl_source/awb.v']

tests = ['fixed_wb', 'presence_modes', 'isp_writer_stop', 'observation', 'stop_recovery',
         'display_state', 'controls', 'osd', 'pixel_interface', 'classifier', 'roi_chain']
assert 'PASS ModelSim: all 4 tests, including original vendor ERAM model' in read(build / 'sim/suite_console.log')
retests = {'fixed_wb', 'pixel_interface', 'isp_writer_stop', 'roi_chain'}
# These seven benches do not instantiate AWB/ISP; their exact production inputs are unchanged.
shared = ['roi_classifier.v', 'roi_result_snapshot.v', 'roi_display_state.v', 'status_cdc.v']
unaffected_sources = {
    'presence_modes': shared + ['roi_mode_classifier.v', 'roi_tape_guard.v'],
    'observation': ['observation_controls.v', 'roi_observation_snapshot.v', 'roi_display_state.v', 'status_cdc.v'],
    'stop_recovery': ['input_monitor.v', 'roi_result_snapshot.v', 'roi_display_state.v', 'status_cdc.v'],
    'display_state': shared,
    'controls': ['uiisp_beta/ae_set.v', 'uics500_cfg/uicfgcs500.v', 'uics500_cfg/uics500reg.v', 'uics500_cfg/uics500regAE.v', 'uics500_cfg/SC500GainTbl.v'],
    'osd': ['bin16_bcd.v', 'osd_ascii_rom.v', 'osd_cjk_rom.v', 'osd_logo_rom.v', 'experiment_osd.v'],
    'classifier': ['roi_frame_guard.v', 'roi_statistics.v', 'roi_classifier.v', 'status_cdc.v']}
test_results = []
for name in tests:
    attempt = build if name in retests else first
    if name not in retests:
        for source in unaffected_sources[name]:
            rel = 'user_source/hdl_source/' + source
            assert sha(first / rel) == sha(build / rel) == sha(project / rel), rel
    folder = attempt / 'sim/modelsim_work' / name
    console = folder / 'console.log'
    text = read(console)
    assert 'PASS' in text and 'Errors: 0' in text and not re.search(r'(?m)^#?\s*\*\* (Fatal|Error):', text), name
    assert not re.search(r'(?m)^#?\s*\*\* (Fatal|Error):', read(folder / 'compile.log')), name
    assert sha(first / 'sim' / ('tb_' + name + '.v')) == sha(build / 'sim' / ('tb_' + name + '.v')) == sha(project / 'sim' / ('tb_' + name + '.v')), name
    test_results.append(dict(name=name, attempt=attempt.name, console_sha256=sha(console),
                             pass_lines=[s for s in text.splitlines() if 'PASS ' in s]))
assert sha(build / 'sim/run_modelsim.ps1') == sha(project / 'sim/run_modelsim.ps1')
assert sha(first / 'sim/run_modelsim.ps1') == sha(build / 'sim/run_modelsim.ps1')
bit = phy / 'camera_to_dsi_display.bit'
assert bit.stat().st_size == 1789539

# Verify immutable prior evidence, independently of the intentionally changed working RTL/docs.
prior_evidence = {}
for name in ['20261008_A灰度边缘独立判定_轮次1', '20261009_A成像参数冻结与计划修订_轮次1']:
    folder = root / '开发实施/验收记录' / name
    d = load(folder / 'manifest.json')
    entries = d.get('copies', d.get('files'))
    assert entries is not None, name
    for e in entries:
        p = folder / e['path']
        assert p.stat().st_size == e['bytes'] and sha(p) == e['sha256'], p
    prior_evidence[name] = len(entries)
rollback = project / 'release/presence_modes_v3_20261008/camera_to_dsi_display.bit'
assert sha(rollback) == '87703eeb66262a4ebecd6f27ea57be78c4993204396250d24c04604f52842398'

data = dict(status='PASS_logic_and_build_only', timing=metrics, corners=corners, resources=area,
            resource_delta_v3={k: area[k] - old_area[k] for k in ['slice_used', 'lut6_used', 'reg_used', 'eram_used', 'dsp_used']},
            canonical_max_delays=canonical, coverage_summary=coverage_summary, coverage_categories_unchanged=False,
            coverage_review=coverage_review,
            warnings=warning_comparison, tests=test_results, input_count=len(inputs), changed_production_inputs=changed,
            attempts=dict(first=dict(software_tests_passed=11, release_accepted=False, added_warnings=first_added,
                          reason='HDL-7238 clocked constant gain assignments'),
                          second=dict(relevant_tests_passed=4, unchanged_tests_reused=7,
                          change='Elaboration-time constant gain nets; original automatic path retained')),
            bit=dict(sha256=sha(bit), bytes=bit.stat().st_size), prior_evidence_copies=prior_evidence,
            limits=['No board flashing, cold-start, long-duration stability or optical accuracy acceptance.',
                    'Fixed red/blue gains 1.0 are a tuning trial, not a calibrated final optical recipe.',
                    'Existing MEAN, EC/GS and dark-strip thresholds are uncalibrated and need new paired samples.',
                    'Black background/locator hole/wrong ROI may pass the tape guard; transparent tape unsupported.',
                    'PLL/I/O/exception limitations retained; STA coverage is not 100 percent.',
                    'Recent acquisition result is not DDR display-frame bound; runtime recipe lifecycle not implemented.'])
(build / 'audit.json').write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print(json.dumps({k: data[k] for k in ['status', 'timing', 'resources', 'resource_delta_v3', 'bit', 'warnings', 'prior_evidence_copies']}, ensure_ascii=True))
