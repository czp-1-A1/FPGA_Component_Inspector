from pathlib import Path
import hashlib, json, subprocess

root = Path(__file__).resolve().parent.parent
project = root / 'fpga/component_inspector'
record = root / '开发实施/验收记录/20261009_A固定白平衡调参版_轮次1'
release = project / 'release/fixed_wb_tuning_v1_20261009'
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
load = lambda p: json.loads(p.read_text(encoding='utf-8-sig'))
d = load(record / 'manifest.json')
for e in d['copies']:
    p = record / e['path']
    assert p.stat().st_size == e['bytes'] and sha(p) == e['sha256'], p
inputs = load(record / 'inputs.json')
for e in inputs:
    assert sha(record / 'source_snapshot' / e['path']) == e['sha256'] == sha(project / e['path']), e['path']
for label, manifest in [('attempt1', 'attempt1/inputs.json'), ('before', 'before/inputs.json')]:
    for e in load(record / manifest):
        p = record / label / 'source_changes' / e['path']
        if not p.exists(): p = record / 'source_snapshot' / e['path']
        assert p.stat().st_size == e['bytes'] and sha(p) == e['sha256'], p
assert (release / 'build_inputs.json').read_bytes() == (record / 'inputs.json').read_bytes()
assert sha(release / 'camera_to_dsi_display.bit') == d['bit']['sha256']
assert (release / 'camera_to_dsi_display.bit').stat().st_size == d['bit']['bytes']
assert (release / 'SHA256.txt').read_text(encoding='ascii').split()[0] == d['bit']['sha256']
assert load(release / 'manifest.json') == {k: v for k, v in d.items() if k != 'copies'}
assert (release / 'README.md').read_bytes() == (record / 'release_README.md').read_bytes()
metadata = load(project / 'td_project/current_codex_build.json')
assert metadata['release'] == d['bit'] and metadata['source_commit'] is None
assert (project / 'td_project/current_codex_build.json').read_bytes() == (record / 'current_codex_build.json').read_bytes()
assert (root / 'AGENTS.md').read_bytes() == (record / 'AGENTS_checkpoint.md').read_bytes()
assert record.with_suffix('.md').read_bytes() == (record / '验收记录.md').read_bytes()
for p in (record / 'documents').glob('*.md'):
    assert p.read_bytes() == (root / '开发实施' / p.name).read_bytes(), p
for p in (record / 'simulation/source').rglob('*'):
    if p.is_file(): assert sha(p) == sha(project / 'sim' / p.relative_to(record / 'simulation/source')), p
for e in d['vendor_model_hashes']:
    assert sha(Path(e['path'])) == e['sha256'], e['path']
assert sha(Path(metadata['flow'])) == d['flow_sha256']
previous = {}
for name in ['20261008_A灰度边缘独立判定_轮次1', '20261009_A成像参数冻结与计划修订_轮次1']:
    folder = root / '开发实施/验收记录' / name
    m = load(folder / 'manifest.json')
    entries = m.get('copies', m.get('files'))
    for e in entries:
        p = folder / e['path']
        assert p.stat().st_size == e['bytes'] and sha(p) == e['sha256'], p
    previous[name] = len(entries)
assert sha(root / d['rollback']['path']) == d['rollback']['sha256']
assert sha(project / 'release/led_presence_demo_v2_r2_20261008/camera_to_dsi_display.bit') == 'c70ad59e63051e71c3ba0d73c4fd7a3ab4f0b38b495d9e43f496f0aa0e057ae9'
head = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=root, text=True).strip()
assert head == d['base_head']
assert not subprocess.check_output(['git', 'diff', '--cached', '--name-only'], cwd=root, text=True).strip()
check = subprocess.run(['git', '-c', 'core.whitespace=cr-at-eol', 'diff', '--check'], cwd=root, text=True, capture_output=True)
assert check.returncode == 0, check.stdout + check.stderr
process = subprocess.run(['powershell', '-NoProfile', '-Command',
    "Get-CimInstance Win32_Process | Where-Object { $_.Name -match '^(td|bw|hwserver|td_commands_prompt|vsim|vsimk|vlog|vopt)\\.exe$' } | Select-Object Name,ProcessId | ConvertTo-Json -Compress"],
    text=True, capture_output=True)
assert process.returncode == 0, process.stderr
processes = json.loads(process.stdout.strip()) if process.stdout.strip() else []
if isinstance(processes, dict): processes = [processes]
assert not [p for p in processes if p['Name'] in ['td_commands_prompt.exe', 'vsim.exe', 'vsimk.exe', 'vlog.exe', 'vopt.exe']], processes
result = dict(status='PASS', frozen_copies=len(d['copies']), production_inputs=len(inputs),
              previous_evidence_copies=previous, release_sha256=d['bit']['sha256'], head_unchanged=head,
              staging_empty=True, diff_check_passed=True, metadata_docs_checkpoint_match=True,
              rollback_unchanged=True, no_assistant_build_or_simulation_running=True,
              process_snapshot_user_tools_untouched=processes, board_validation='not_performed')
(record / 'verification.json').write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print(json.dumps(result, ensure_ascii=True))
