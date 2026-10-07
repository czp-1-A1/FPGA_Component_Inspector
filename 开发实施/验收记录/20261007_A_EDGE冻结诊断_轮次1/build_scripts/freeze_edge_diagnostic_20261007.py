from pathlib import Path
from datetime import datetime
from zoneinfo import ZoneInfo
import hashlib, json, re, shutil, subprocess

root = Path('.').resolve()
project = root / 'fpga/component_inspector'
build = root / 'tmp/edge_diagnostic_td_20261007'
release = project / 'release/edge_diagnostic_20261007'
record = root / '开发实施/验收记录/20261007_A_EDGE冻结诊断_轮次1'
assert not release.exists() and not record.exists(), 'Never overwrite frozen evidence'

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def read_json(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))

def passed(path, marker):
    text = path.read_text(encoding='utf-8', errors='replace')
    assert marker in text and 'Errors: 0' in text, str(path)
    assert not re.search(r'(?m)^#?\s*\*\* (Fatal|Error):', text), str(path)
    return {'path': path.relative_to(root).as_posix(), 'sha256': sha(path),
            'pass_lines': [line for line in text.splitlines() if marker in line]}

inputs = read_json(build / 'inputs.json')
assert len(inputs) == 207
for entry in inputs:
    assert sha(project / entry['path']) == entry['sha256'] == sha(build / entry['path'])
assert re.search(r'CLASS_CALIBRATED\s*=\s*0\s*;',
                 (project / 'user_source/hdl_source/design_top_wrapper.v').read_text(encoding='utf-8'))
audit = read_json(root / 'tmp/edge_diagnostic_final_audit_20261007/final_audit.json')
assert audit['verified_build_inputs'] == 207 and audit['previous_release_unchanged']
assert audit['metrics']['setup_wns_ps'] >= 0 and audit['metrics']['hold_wns_ps'] >= 0
assert audit['metrics']['setup_tns_ps'] == audit['metrics']['hold_tns_ps'] == 0
assert all(item['semantic_warning_multisets_identical'] for item in audit['warning_comparisons'].values())
phy = build / 'td_project/camera_to_dsi_display_Runs/phy_1'
bit = phy / 'camera_to_dsi_display.bit'
assert (phy / '.bitgen.end.f').exists() and sha(bit) == audit['bit']['sha256']
assert bit.stat().st_size == 1789539
old_bit = project / 'release/video_fix_20261006/camera_to_dsi_display.bit'
assert sha(old_bit) == '1584f39b53f315c369feb41617539dbbb944b455ae3fe84a045d7824dcfac0d5'

latest_tests = []
for name, marker in [('sobel_view', 'PASS'), ('osd', 'PASS')]:
    latest_tests.append(passed(project / 'sim/modelsim_work' / name / 'console.log', marker))
for folder, log, marker in [
    ('edge_pipeline_gap_20261007', 'after/console.log', 'PASS'),
    ('edge_cdc52_verify_20261007', 'console.log', 'PASS CDC52:'),
    ('edge_timing_debug_verify_20261007', 'console.log', 'PASS independent timing_debug:'),
    ('edge_freeze_awb_20261007/lifecycle_after_diag', 'life_console.log', 'PASS actual ISP lifecycle:'),
    ('edge_freeze_awb_20261007/lifecycle_after_diag', 'full_g160_console.log', 'PASS actual ISP full epoch:')]:
    latest_tests.append(passed(root / 'tmp' / folder / log, marker))
before = root / 'tmp/edge_pipeline_gap_20261007/before/console.log'
assert '** Fatal:' in before.read_text(encoding='utf-8')
timing = read_json(root / 'tmp/edge_timing_debug_verify_20261007/manifest.json')
for entry in timing['files']:
    assert sha(root / 'tmp/edge_timing_debug_verify_20261007' / entry['path']) == entry['sha256']
transport_dir = root / 'tmp/edge_transport_after_pipeline_20261007'
transport = read_json(transport_dir / 'manifest.json')
assert transport['all_expectations_passed'] and len(transport['cases']) == 4
for entry in transport['inputs']:
    assert sha(root / entry['path']) == entry['sha256'] == sha(transport_dir / entry['copy'])
for entry in transport['artifacts']:
    assert sha(transport_dir / entry['path']) == entry['sha256']
for case in transport['cases']:
    assert case['expectation_passed']
    log = transport_dir / case['case'] / 'console.log'
    text = log.read_text(encoding='utf-8', errors='replace')
    assert not re.search(r'(?m)^#?\s*\*\* (Fatal|Error):', text)
    if case['functional_status'] == 'PASS':
        latest_tests.append(passed(log, 'PASS: SWITCH_TRANSPORT'))
    else:
        assert case['expected_result'] == 'SAFE_REJECTION_AND_FULL_RECOVERY_PASS'
        assert 'recovery_capture=1' in text and 'pixel_errors=0' in text and 'overflow=0 underflow=0' in text
awb_dir = root / 'tmp/edge_freeze_awb_20261007/lifecycle_after_diag'
awb = read_json(awb_dir / 'final_diagnostics_manifest.json')
for name in awb['checked_manifests']:
    for entry in read_json(awb_dir / name):
        assert sha(Path(entry['Path'])) == entry['SHA256']
        if 'SnapshotPath' in entry:
            assert sha(Path(entry['SnapshotPath'])) == entry['SHA256']
assert sha(awb_dir / awb['negative_input_test']['log']) == awb['negative_input_test']['sha256']

release.mkdir(parents=True)
record.mkdir(parents=True)
copies = []

def copy(src, target):
    dst = record / target
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)
    assert sha(src) == sha(dst)
    copies.append({'source': src.relative_to(root).as_posix(), 'copy': dst.relative_to(record).as_posix(),
                   'bytes': dst.stat().st_size, 'sha256': sha(dst)})

for entry in inputs:
    copy(build / entry['path'], Path('source_snapshot') / entry['path'])
copy(build / 'inputs.json', 'build_inputs.json')
for name in ['prepare_video_fix_build.py', 'freeze_edge_diagnostic_20261007.py']:
    copy(root / 'tmp' / name, Path('build_scripts') / name)
for stage in ['syn_1', 'phy_1']:
    for file in (build / 'td_project/camera_to_dsi_display_Runs' / stage).iterdir():
        if file.is_file() and file.suffix.lower() in {'.log', '.logw', '.rpt', '.txt', '.status', '.qor', '.area', '.tcl', '.prj', '.cfg', '.timing', '.bit'}:
            copy(file, Path('td_reports') / stage / file.name)
    for file in (build / 'td_project/camera_to_dsi_display_Runs' / stage).glob('.*.f'):
        copy(file, Path('td_reports') / stage / file.name)
for file in (project / 'sim').iterdir():
    if file.is_file() and file.suffix.lower() in {'.v', '.ps1', '.py', '.do', '.md'}:
        copy(file, Path('simulation') / file.name)
for file in (project / 'sim/osd_assets').rglob('*'):
    if file.is_file():
        copy(file, Path('simulation/osd_assets') / file.relative_to(project / 'sim/osd_assets'))
for name in ['sobel_view', 'osd']:
    for file in (project / 'sim/modelsim_work' / name).glob('*.log'):
        copy(file, Path('simulation/model_logs') / name / file.name)
folders = ['edge_freeze_before_20261007', 'edge_diagnostic_validation_20261007',
           'edge_timing_debug_verify_20261007', 'edge_freeze_awb_20261007',
           'edge_freeze_transport_20261007', 'edge_transport_after_pipeline_20261007',
           'edge_diagnostic_final_audit_20261007']
for name in folders:
    folder = root / 'tmp' / name
    allowed = {'.v', '.sv', '.ps1', '.py', '.md', '.json', '.log', '.csv', '.diff', '.txt', '.area', '.status', '.qor', '.sdc', '.png'}
    if name == 'edge_transport_after_pipeline_20261007':
        allowed.add('.hex')
    for file in folder.rglob('*'):
        if file.is_file() and file.suffix.lower() in allowed:
            copy(file, Path('additional_tests') / name / file.relative_to(folder))
copy(root / 'AGENTS.md', 'AGENTS_checkpoint.md')
for name in ['README.zh-CN.md', '验收记录.md', '交接说明.md']:
    copy(root / 'tmp/edge_diagnostic_delivery_20261007' / name, name)
status = subprocess.check_output(['git', '-c', 'core.quotepath=false', 'status', '--short'], text=True, encoding='utf-8')
(record / 'git_status.txt').write_text(status, encoding='utf-8')
data = {'created_at': datetime.now(ZoneInfo('Asia/Shanghai')).isoformat(timespec='seconds'),
        'status': 'software_verified_diagnostic_candidate_board_validation_pending',
        'branch': subprocess.check_output(['git', 'branch', '--show-current'], text=True).strip(),
        'HEAD': subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip(),
        'commit_status': 'uncommitted_unpushed_workspace_snapshot', 'classification_enabled': False,
        'bit': {'path': (release / bit.name).relative_to(root).as_posix(), 'bytes': bit.stat().st_size, 'sha256': sha(bit)},
        'tool': 'TD6.2.168116 / ModelSim2019.2', 'device': 'PH1P35MDG324 speed3',
        'build_directory': build.relative_to(root).as_posix(), 'build_inputs': inputs,
        'final_audit': audit, 'latest_source_pass_tests': latest_tests,
        'transport_cases': transport['cases'], 'actual_isp_diagnostics': awb,
        'preserved_failures': ['old Sobel zero-row-gap reproduction', 'MC2000 pause safely rejects EDGE and recovers RAW',
                               'actual ISP native gap32 incomplete geometry', 'initial license setup failures'],
        'base_suite_scope': 'Only sobel_view and osd rerun from the default16 suite; actual ISP/transport/diagnostic/CDC regressions added separately.',
        'limits': ['No board or JTAG verification; physical freeze cause remains open.',
                   'Behavioral DDR model does not validate physical DDR PHY.',
                   'Native gap160 normal test is one complete EDGE frame; gap32 negative input remains FAIL.',
                   'Previous PLL/IO/exception coverage findings and warnings retained; STA coverage is not100%.',
                   'Material classification remains uncalibrated.'], 'copies': copies}
(record / 'manifest.json').write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
shutil.copy2(bit, release / bit.name)
shutil.copy2(record / 'README.zh-CN.md', release / 'README.zh-CN.md')
(release / 'build_inputs.json').write_text(json.dumps(inputs, indent=2) + '\n', encoding='utf-8')
(release / 'manifest.json').write_text(json.dumps({k: v for k, v in data.items() if k != 'copies'}, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
(release / 'SHA256.txt').write_text(f'{sha(bit)}  {bit.name}\n', encoding='ascii')
for entry in inputs:
    assert sha(project / entry['path']) == entry['sha256']
assert sha(release / bit.name) == sha(bit) and sha(old_bit) == '1584f39b53f315c369feb41617539dbbb944b455ae3fe84a045d7824dcfac0d5'
print(json.dumps({'release': str(release), 'record': str(record), 'bit': data['bit'], 'metrics': audit['metrics'], 'verified_copies': len(copies)}, ensure_ascii=True))
