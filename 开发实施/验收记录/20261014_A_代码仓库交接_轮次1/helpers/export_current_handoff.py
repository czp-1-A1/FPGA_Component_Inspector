from pathlib import Path
import datetime, hashlib, json, re, shutil, subprocess

r = Path.cwd()
p = r / 'fpga/component_inspector'
e = r / '开发实施/验收记录/20261014_A_代码仓库交接_轮次1'
assert not e.exists()
e.mkdir(parents=True)
sha = lambda f: hashlib.sha256(f.read_bytes()).hexdigest()
copy = lambda src, dst: (dst.parent.mkdir(parents=True, exist_ok=True), shutil.copy2(src, dst))
frozen = r / 'tmp/process_v9_r5_20261014'
inputs = json.loads((frozen / 'inputs.json').read_text(encoding='utf-8-sig'))
assert len(inputs) == 215
for item in inputs:
    assert sha(p / item['path']) == item['sha256']
    assert sha(frozen / item['path']) == item['sha256']
    copy(frozen / item['path'], e / 'source_snapshot' / item['path'])
shutil.copytree(frozen / 'sim', e / 'source_snapshot/sim', dirs_exist_ok=True,
                ignore=shutil.ignore_patterns('modelsim_work', '*.log', '*.wlf', '*.pgm', 'transcript', 'modelsim.ini'))
for name in ('inputs.json', 'simulation_inputs.json'):
    copy(frozen / name, e / name)
copy(r / 'AGENTS.md', e / 'previous_checkpoint.md')
statuses = []
for name in ('frame_stop_v8_r1_20261014', 'frame_stop_v8_r2_20261014',
             *(f'process_v9_r{i}_20261014' for i in range(1, 6))):
    q = r / 'tmp' / name
    if not q.exists(): continue
    d = e / 'round_history' / name
    for filename in ('inputs.json', 'simulation_inputs.json', 'tests_console.log', 'build_audit.json'):
        if (q / filename).exists(): copy(q / filename, d / filename)
    for tb in (q / 'sim').glob('tb_*process*.v'):
        copy(tb, d / 'fixtures' / tb.name)
    for tb in (q / 'sim').glob('tb_frame_stop.v'):
        copy(tb, d / 'fixtures' / tb.name)
    if (q / 'sim/run_modelsim.ps1').exists(): copy(q / 'sim/run_modelsim.ps1', d / 'fixtures/run_modelsim.ps1')
    for f in (q / 'sim/modelsim_work').glob('*/*.log'):
        copy(f, d / 'tests' / f.parent.name / f.name)
    for f in (q / 'sim').glob('*.pgm'): copy(f, d / 'native_images' / f.name)
    log = d / 'tests_console.log'
    s = log.read_text(encoding='utf-8-sig', errors='replace') if log.exists() else ''
    statuses.append(dict(round=name, pass_lines=[x.strip() for x in s.splitlines() if 'PASS ' in x],
                         final_runner_pass='PASS ModelSim: all' in s,
                         note='Read-only capture at handoff; absence of final PASS is not a completed verification.'))
build = r / 'tmp/process_v9_r3_20261014'
for stage in ('syn_1', 'phy_1'):
    q = build / 'td_project/camera_to_dsi_display_Runs' / stage
    for f in q.iterdir():
        if f.is_file() and (f.suffix in ('.timing', '.area', '.prj', '.cfg', '.tcl', '.log', '.logw')
                           or f.name in ('constraint_coverage.txt', 'build_exit_code.txt')):
            copy(f, e / 'wip_td_reports' / stage / f.name)
    for name in ('build.tcl', 'settings.cfg', 'camera_to_dsi_display.prj'):
        copy(q / name, e / 'source_snapshot/td_project/camera_to_dsi_display_Runs' / stage / name)
bit = build / 'td_project/camera_to_dsi_display_Runs/phy_1/camera_to_dsi_display.bit'
copy(bit, e / 'wip_build/camera_to_dsi_display.bit')
for f in (r / 'tmp').glob('*.py'):
    if re.search('process|frame_stop', f.name): copy(f, e / 'helpers' / f.name)
copy(Path(__file__), e / 'helpers' / Path(__file__).name)
state = dict(captured_at=datetime.datetime.now().astimezone().isoformat(),
             status='V9_WIP_NOT_RELEASED_NOT_ACCEPTED', branch='lj4747-contest-work',
             base_head=subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=r).decode().strip(),
             production_inputs=215, current_inputs_match_frozen=True, tests=statuses,
             wip_bit=dict(path='wip_build/camera_to_dsi_display.bit', bytes=bit.stat().st_size, sha256=sha(bit)),
             pending=['Complete r5 regression and independent native reference',
                      'Resolve/audit unmatched constraints and new clock/FIFO/declaration-order warnings',
                      'Fresh fully audited V9 build and onsite verification'],
             previous_release='V8 has reported onsite black screen; preserve historical build evidence')
(e / 'handoff_state.json').write_text(json.dumps(state, ensure_ascii=False, indent=2), encoding='utf-8')
(e / 'worktree_diff.patch').write_bytes(subprocess.check_output(['git', 'diff', '--binary'], cwd=r))
manifest = [dict(path=f.relative_to(e).as_posix(), bytes=f.stat().st_size, sha256=sha(f))
            for f in e.rglob('*') if f.is_file()]
(e / 'archive_sha256.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding='utf-8')
for item in manifest: assert sha(e / item['path']) == item['sha256']
print(json.dumps(dict(archive=e.relative_to(r).as_posix(), entries=len(manifest),
                      bytes=sum(x['bytes'] for x in manifest), wip_bit=state['wip_bit']), ensure_ascii=True))
