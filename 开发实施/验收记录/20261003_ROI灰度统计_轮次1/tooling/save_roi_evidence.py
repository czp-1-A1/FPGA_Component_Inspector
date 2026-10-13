from pathlib import Path
import hashlib
import json
import re
import shutil

root = Path(__file__).resolve().parents[2]
project = root / 'fpga/component_inspector'
build = root / 'tmp/roi_statistics_cdc_td_build_20261003'
failed = root / 'tmp/roi_statistics_td_build_20261003'
failed_constraints = root / 'tmp/roi_statistics_pipeline_td_build_20261003'
evidence = root / '开发实施/验收记录/20261003_ROI灰度统计_轮次1'
release = project / 'release/roi_statistics_20261003'
previous = json.loads((project / 'release/experiment_ramfix_20261003/manifest.json').read_text(encoding='utf-8'))
paths = [entry['path'] for entry in previous['verified_build_inputs']]
paths += ['user_source/hdl_source/roi_frame_guard.v', 'user_source/hdl_source/roi_statistics.v']
assert len(set(paths)) == 197

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def copy(source, target):
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, target)

def reports(source_build, target):
    for stage in ['syn_1', 'phy_1']:
        source = source_build / 'td_project/camera_to_dsi_display_Runs' / stage
        assert not list(source.glob('*.error.f')), source
        assert (source / ('.opt_gate.end.f' if stage == 'syn_1' else '.bitgen.end.f')).exists(), source
        for p in source.iterdir():
            if p.is_file() and (p.suffix in ['.area', '.timing', '.qor', '.cfg', '.prj', '.tcl', '.txt', '.status']
                                or p.name == 'build_console.log'):
                copy(p, target / stage / p.name)

phy = build / 'td_project/camera_to_dsi_display_Runs/phy_1'
timing_text = (phy / 'camera_to_dsi_display_pr.timing').read_text(encoding='utf-8')
setup, setup_tns, hold, hold_tns = map(float, re.search(
    r'SWNS:\s*([-\d.]+)ns, STNS:\s*([-\d.]+)ns\s*HWNS:\s*([-\d.]+)ns, HTNS:\s*([-\d.]+)ns', timing_text).groups())
assert setup >= 0 and hold >= 0 and setup_tns == hold_tns == 0
coverage = float(re.search(r'STA coverage\s*:\s*([\d.]+)%', timing_text)[1])
constraint_text = (phy / 'constraint_coverage.txt').read_text(encoding='utf-8')
pll_checks = int(re.search(r'checking pll/clock buffer clock constraints\((\d+)\)', constraint_text)[1])
assert 'checking invalid constraint(0)' in constraint_text
assert 'checking no clock(0)' in constraint_text
qor = (phy / 'route.qor').read_text(encoding='utf-8')
slice_count = int(re.search(r'#slices\s*\|\s*(\d+)', qor)[1])
slice_percent = float(re.search(r'slices percentage\s*\|\s*([\d.]+)%', qor)[1])
exception = (phy / 'camera_to_dsi_display_exception.timing').read_text(encoding='utf-8')
for name in ['u_camera_receive/payload', 'u_camera_receive/req', 'u_camera_receive/ack',
             'u_roi_display/payload', 'u_roi_display/req', 'u_roi_display/ack']:
    assert name in exception, name
    line = next(line for line in exception.splitlines() if 'set_max_delay' in line and name in line)
    values = [int(s) for s in line.split()[:4]]
    assert values[0] > 0 and values[0] == values[1] and values[2:] == [0, 0], line

inputs = []
old_hashes = {e['path']: e['sha256'] for e in previous['verified_build_inputs']}
changes = []
for relative in paths:
    source = project / relative
    assert sha(source) == sha(build / relative), relative
    copy(source, evidence / 'source_snapshot' / relative)
    copy(failed / relative, evidence / 'failed_td/source_snapshot' / relative)
    copy(failed_constraints / relative, evidence / 'failed_cdc/source_snapshot' / relative)
    inputs.append({'path': relative, 'sha256': sha(source), 'bytes': source.stat().st_size})
    if sha(source) != old_hashes.get(relative):
        changes.append({'path': relative, 'old_sha256': old_hashes.get(relative), 'new_sha256': sha(source)})
for relative in ['td_project/camera_to_dsi_display.al']:
    assert sha(project / relative) == sha(build / relative)
    copy(project / relative, evidence / 'source_snapshot' / relative)
    copy(failed / relative, evidence / 'failed_td/source_snapshot' / relative)
    copy(failed_constraints / relative, evidence / 'failed_cdc/source_snapshot' / relative)
for p in (project / 'sim').iterdir():
    if p.is_file() and (p.suffix in ['.v', '.do', '.ps1'] or p.name in ['README.md', '.gitignore']):
        copy(p, evidence / 'source_snapshot/sim' / p.name)
reports(build, evidence / 'td_final')
reports(failed, evidence / 'failed_td/reports')
reports(failed_constraints, evidence / 'failed_cdc/reports')
for name in ['probe_constraints.tcl', 'probe_constraints_console.log', 'probe_constraints.timing', 'probe_exceptions.timing', 'probe_coverage.txt']:
    copy(failed_constraints / 'td_project/camera_to_dsi_display_Runs/phy_1' / name, evidence / 'cdc_constraint_probe' / name)
for name in ['save_roi_evidence.py', 'finish_roi_docs.py']:
    copy(Path(__file__).parent / name, evidence / 'tooling' / name)

tests = ['controls', 'cdc', 'monitor', 'csi_monitor', 'i2c', 'osd', 'pack_boundary', 'pixel_interface', 'roi_guard', 'roi_chain']
for test in tests:
    folder = project / 'sim/modelsim_work' / test
    text = (folder / 'console.log').read_text(encoding='utf-8-sig')
    assert 'PASS ' in text and '** Fatal:' not in text and '** Error:' not in text, test
    for name in ['compile.log', 'console.log', 'transcript.log', 'wave.wlf']:
        copy(folder / name, evidence / 'modelsim' / test / name)
for name in ['regression_roi_final_console.log', 'regression_roi_pipeline_console.log', 'regression_roi_cancel_console.log']:
    copy(root / 'tmp/modelsim_probe' / name, evidence / name)
copy(project / 'sim/osd.ppm', evidence / 'roi_osd_preview.ppm')

bit = phy / 'camera_to_dsi_display.bit'
assert bit.stat().st_size > 1_000_000
copy(bit, release / bit.name)
(release / 'camera_to_dsi_display.bit.sha256').write_text(sha(bit) + '  camera_to_dsi_display.bit\n', encoding='ascii')
vendor = Path('D:/AAA/FPGA.....YZW/sim_release')
library_paths = ['common/al_map_basic.v', 'common/al_map_lut.v', 'common/al_map_adder.v',
                 'common/al_phy_glbl.v', 'ph1p/ph1p_logic_eram.v', 'ph1p/ph1p_phy_gsr.v']
manifest = {
    'date': '2026-10-03', 'scope': 'Frame protection, temporary central grayscale ROI and mean/min/max; no classification',
    'branch': 'hx1p35a-contest-work', 'head': 'f87ccf1c6a38e84b58a4f86cecd532a71ae56e89',
    'working_tree_uncommitted': True, 'td_version': '6.2.168116', 'modelsim_version': 'SE-64 2019.2',
    'device': 'PH1P35MDG324', 'speed_grade': 3,
    'bitstream': {'path': str((release / bit.name).relative_to(root)).replace('\\', '/'),
                  'sha256': sha(bit), 'bytes': bit.stat().st_size, 'compressed': False},
    'roi': {'x0': 384, 'x1_exclusive': 640, 'y0': 236, 'y1_exclusive': 364, 'pixels': 32768, 'temporary': True},
    'timing': {'setup_wns_ns': setup, 'setup_tns_ns': setup_tns, 'hold_wns_ns': hold,
               'hold_tns_ns': hold_tns, 'sta_coverage_percent': coverage},
    'resources': {'slice': slice_count, 'slice_percent': slice_percent, 'eram': 31, 'dsp': 8},
    'verification': {'modelsim': '10 tests passed; two affected ROI tests rerun after pipelining, plus pending sample cancellation test',
                     'synthesis': 'passed', 'place_route': 'passed', 'hardware': 'not tested for this ROI release',
                     'failed_build': 'setup WNS -2.760ns/TNS -63.328ns; not released, input snapshot and reports preserved'},
    'constraints_pending': {'dummy_nodes': 4, 'pll_clock_constraints': pll_checks, 'shadowed_or_ignored_exceptions': 2,
                            'no_input_delay': 37, 'no_output_delay': 63, 'partial_input_delay': 1,
                            'generic_physical_delay_bounds_shadowed_by_specific_mailbox_bounds': 2},
    'limitations': ['temporary ROI, no classification/accuracy result', 'latest capture statistics not bound to DDR display frame',
                    'initial frame may be rejected during demosaic learning', 'stopped CSI clock causes WAIT after about 1-2 seconds',
                    'physical MIPI/DDR/HDMI and 30 minute/Flash/cold boot require hardware verification'],
    'build_directory': str(build), 'verified_build_inputs': inputs, 'changes_vs_previous_release': changes,
    'project_sha256': sha(project / 'td_project/camera_to_dsi_display.al'),
    'simulation_library': [{'path': str(vendor / p), 'sha256': sha(vendor / p)} for p in library_paths],
    'previous_bit_sha256': previous['bitstream']['sha256'], 'previous_release_preserved': True,
}
(release / 'manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
manifest['evidence_files'] = [{'path': str(p.relative_to(evidence)).replace('\\', '/'), 'sha256': sha(p), 'bytes': p.stat().st_size}
                             for p in sorted(evidence.rglob('*')) if p.is_file() and p.name != 'manifest.json']
(evidence / 'manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print('Saved 197 verified current/build inputs, failed/final TD reports, 10 ModelSim tests and frozen bit')
print('Bit SHA-256:', sha(bit))
print('Final timing/resources:', manifest['timing'], manifest['resources'])
