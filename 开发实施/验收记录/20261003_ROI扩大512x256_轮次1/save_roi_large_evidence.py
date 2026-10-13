from pathlib import Path
import hashlib
import json
import re
import shutil

root = Path(__file__).resolve().parents[2]
project = root / 'fpga/component_inspector'
build = root / 'tmp/roi_statistics_large_td_build_20261003'
evidence = root / '开发实施/验收记录/20261003_ROI扩大512x256_轮次1'
release = project / 'release/roi_statistics_large_20261003'
previous = json.loads((project / 'release/roi_statistics_20261003/manifest.json').read_text(encoding='utf-8'))

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def copy(source, target):
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, target)

phy = build / 'td_project/camera_to_dsi_display_Runs/phy_1'
timing = (phy / 'camera_to_dsi_display_pr.timing').read_text(encoding='utf-8')
setup, stns, hold, htns = map(float, re.search(
    r'SWNS:\s*([-\d.]+)ns, STNS:\s*([-\d.]+)ns\s*HWNS:\s*([-\d.]+)ns, HTNS:\s*([-\d.]+)ns', timing).groups())
assert setup >= 0 and hold >= 0 and stns == htns == 0
qor = (phy / 'route.qor').read_text(encoding='utf-8')
slice_count = int(re.search(r'#slices\s*\|\s*(\d+)', qor)[1])
slice_percent = float(re.search(r'slices percentage\s*\|\s*([\d.]+)%', qor)[1])
exception = (phy / 'camera_to_dsi_display_exception.timing').read_text(encoding='utf-8')
for name in ['u_camera_receive/payload', 'u_camera_receive/req', 'u_camera_receive/ack',
             'u_roi_display/payload', 'u_roi_display/req', 'u_roi_display/ack']:
    line = next(line for line in exception.splitlines() if 'set_max_delay' in line and name in line)
    numbers = [int(s) for s in line.split()[:4]]
    assert numbers[0] > 0 and numbers[0] == numbers[1] and numbers[2:] == [0, 0]

inputs = []
changed = []
for entry in previous['verified_build_inputs']:
    relative = entry['path']; source = project / relative
    assert sha(source) == sha(build / relative), relative
    copy(source, evidence / 'source_snapshot' / relative)
    inputs.append({'path': relative, 'sha256': sha(source), 'bytes': source.stat().st_size})
    if sha(source) != entry['sha256']:
        changed.append({'path': relative, 'old_sha256': entry['sha256'], 'new_sha256': sha(source)})
assert len(inputs) == 197
assert {e['path'] for e in changed} == {
    'user_source/hdl_source/design_top_wrapper.v', 'user_source/hdl_source/experiment_osd.v',
    'user_source/hdl_source/isp/isp_top.v', 'user_source/hdl_source/roi_statistics.v'}
relative = 'td_project/camera_to_dsi_display.al'
assert sha(project / relative) == sha(build / relative)
copy(project / relative, evidence / 'source_snapshot' / relative)
for p in (project / 'sim').iterdir():
    if p.is_file() and (p.suffix in ['.v', '.do', '.ps1'] or p.name in ['README.md', '.gitignore']):
        copy(p, evidence / 'source_snapshot/sim' / p.name)
for stage in ['syn_1', 'phy_1']:
    source = build / 'td_project/camera_to_dsi_display_Runs' / stage
    assert not list(source.glob('*.error.f'))
    assert (source / ('.opt_gate.end.f' if stage == 'syn_1' else '.bitgen.end.f')).exists()
    for p in source.iterdir():
        if p.is_file() and (p.suffix in ['.area', '.timing', '.qor', '.cfg', '.prj', '.tcl', '.txt', '.status']
                            or p.name == 'build_console.log'):
            copy(p, evidence / 'td' / stage / p.name)
for test in ['osd', 'roi_guard', 'roi_chain']:
    folder = project / 'sim/modelsim_work' / test
    text = (folder / 'console.log').read_text(encoding='utf-8-sig')
    assert 'PASS ' in text and '** Fatal:' not in text and '** Error:' not in text
    for name in ['compile.log', 'console.log', 'transcript.log', 'wave.wlf']:
        copy(folder / name, evidence / 'modelsim' / test / name)
console = root / 'tmp/modelsim_probe/regression_roi_large_console.log'
assert 'PASS ModelSim: all 3 tests' in console.read_text(encoding='utf-8-sig')
copy(console, evidence / 'regression_console.log')
copy(project / 'sim/osd.ppm', evidence / 'roi_osd_preview.ppm')
copy(Path(__file__), evidence / 'save_roi_large_evidence.py')
bit = phy / 'camera_to_dsi_display.bit'
copy(bit, release / bit.name)
(release / 'camera_to_dsi_display.bit.sha256').write_text(sha(bit) + '  camera_to_dsi_display.bit\n', encoding='ascii')
constraint_text = (phy / 'constraint_coverage.txt').read_text(encoding='utf-8')
assert 'checking no clock(0)' in constraint_text and 'checking invalid constraint(0)' in constraint_text
manifest = {
    'date': '2026-10-03', 'scope': 'Resize temporary central observation ROI from 256x128 to 512x256; no classification',
    'branch': previous['branch'], 'head': previous['head'], 'working_tree_uncommitted': True,
    'td_version': previous['td_version'], 'modelsim_version': previous['modelsim_version'],
    'device': previous['device'], 'speed_grade': 3,
    'bitstream': {'path': str((release / bit.name).relative_to(root)).replace('\\', '/'), 'bytes': bit.stat().st_size, 'sha256': sha(bit)},
    'roi': {'x0': 256, 'x1_exclusive': 768, 'y0': 172, 'y1_exclusive': 428, 'pixels': 131072, 'temporary': True},
    'timing': {'setup_wns_ns': setup, 'setup_tns_ns': stns, 'hold_wns_ns': hold, 'hold_tns_ns': htns,
               'sta_coverage_percent': float(re.search(r'STA coverage\s*:\s*([\d.]+)%', timing)[1])},
    'resources': {'slice': slice_count, 'slice_percent': slice_percent, 'eram': 31, 'dsp': 8},
    'verification': {'modelsim': 'Affected OSD, ROI guard and real 7-frame ROI chain all passed; prior 7 unaffected tests preserved in previous release evidence',
                     'synthesis': 'passed', 'place_route': 'passed', 'hardware': 'not tested for large ROI version'},
    'constraints_pending': previous['constraints_pending'], 'limitations': previous['limitations'],
    'build_directory': str(build), 'verified_build_inputs': inputs, 'changes_vs_previous_release': changed,
    'project_sha256': sha(project / relative), 'simulation_library': previous['simulation_library'],
    'previous_bit_sha256': previous['bitstream']['sha256'], 'previous_release_preserved': True,
}
(release / 'manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
manifest['evidence_files'] = [{'path': str(p.relative_to(evidence)).replace('\\', '/'), 'sha256': sha(p), 'bytes': p.stat().st_size}
                             for p in sorted(evidence.rglob('*')) if p.is_file() and p.name != 'manifest.json']
(evidence / 'manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print('Large ROI bit:', sha(bit))
print('Final timing/resources:', manifest['timing'], manifest['resources'])
print('197 build inputs verified; exactly four RTL files changed from previous release')
