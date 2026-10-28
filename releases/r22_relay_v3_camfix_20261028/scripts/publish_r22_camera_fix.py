"""Publish an immutable V3 camera fix, distinguishing new and reused evidence."""
from pathlib import Path
import argparse, hashlib, json, re, shutil, subprocess, zipfile


def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def load(p): return json.loads(p.read_text(encoding='utf8'))
def write(p, value):
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(json.dumps(value, indent=2, ensure_ascii=False)+'\n', encoding='utf8')
def copy(src, dst):
    dst.parent.mkdir(parents=True, exist_ok=True); shutil.copy2(src, dst)
def passed(path, sentinel='PASS '):
    text = path.read_text(encoding='utf-8-sig')
    assert sentinel in text and not re.search(r'\*\* (?:Fatal|Error):|Errors:\s*[1-9]', text), path


def check_reuse(base, source):
    previous = load(base/'VERIFICATION.json'); rows = []
    for group in ['r22_relay_v3_final_unit_20261027', 'r22_relay_v3_final_closed_20261027', 'native']:
        folder = base/'tests'/group; proof = load(folder/'verification.json')
        assert proof['status'] == 'PASS'
        for rel, digest in proof['inputs'].items(): assert source[rel] == digest, (group, rel)
        tests = proof.get('tests', [{'name': proof.get('name'), 'sha256': proof.get('console_sha256')}])
        for test in tests:
            log = folder/('console.log' if group == 'native' else test['name']+'.log')
            assert sha(log) == test['sha256']; passed(log)
            rows.append({'name': test['name'], 'mode': 'REUSED_EXACT_COMPILED_INPUT_SHA256',
                         'inputs': proof['inputs'], 'log': log.relative_to(base).as_posix(), 'log_sha256': sha(log)})
    for item in previous['legacy']:
        folder = base/'tests/legacy'/item['name']
        for rel, digest in item['inputs'].items(): assert source[rel] == digest, (item['name'], rel)
        assert sha(folder/'compile.log') == item['compile_sha256']
        assert sha(folder/'console.log') == item['console_sha256']; passed(folder/'console.log')
        rows.append({'name': item['name'], 'mode': 'REUSED_EXACT_COMPILED_INPUT_SHA256',
                     'inputs': item['inputs'], 'log': (folder/'console.log').relative_to(base).as_posix(),
                     'log_sha256': item['console_sha256']})
    assert len(rows) == 17 and len({r['name'] for r in rows}) == 17
    assert all('user_source/hdl_source/uics500_cfg/SC500GainTbl.v' not in row['inputs'] for row in rows)
    return rows


def main():
    ap = argparse.ArgumentParser(); ap.add_argument('--work', type=Path, required=True)
    ap.add_argument('--check-only', action='store_true'); args = ap.parse_args()
    repo = Path(__file__).resolve().parents[1]; work = args.work.resolve(); project = work/'project'
    base = repo/'releases/r22_relay_left_v3_20261027'
    source = load(work/'frozen_inputs.json'); original = load(base/'SOURCE_SHA256.json')
    assert len(source) == 636 and set(source) == set(original)
    changed = [p for p in source if source[p] != original[p]]
    assert changed == ['user_source/hdl_source/uics500_cfg/SC500GainTbl.v'], changed
    for rel, digest in source.items():
        assert sha(project/rel) == sha(repo/'fpga/component_inspector'/rel) == digest, rel
    reused = check_reuse(base, source)
    rtl = Path('E:/2026FPGA/.codex_tmp/r22_camfix_rtl_20261028')
    gate = Path('E:/2026FPGA/.codex_tmp/r22_camfix_gate_r3_20261028')
    new_tests = []
    for directory in [rtl, gate]:
        proof = load(directory/'verification.json'); assert proof['status'] == 'PASS'
        for rel, digest in proof['inputs'].items(): assert source[rel] == digest, rel
        for name, digest in proof['fixture_sha256'].items(): assert sha(repo/'tests/camera_gain_fix'/name) == digest
        for name, digest in proof['simulation_input_sha256'].items(): assert sha(directory/'inputs'/name) == digest
        for item in proof['tests']:
            log = directory/(item['name']+'.log'); assert sha(log) == item['log_sha256']; passed(log)
            new_tests.append({**item, 'mode': 'NEW_RUN', 'directory': directory.name})
    assert len(new_tests) == 3
    diag = Path('E:/2026FPGA/.codex_tmp/v3_camera_black_20261028')
    netlist = diag/'fix_r2_camera_gate.v'
    assert sha(netlist) == load(gate/'verification.json')['gate_netlist_sha256']
    positive = diag/'v2_positive/camera_gate.log'; passed(positive, 'PASS ACTUAL V2 SYNTH CAMERA BUS:')
    negative = Path('E:/2026FPGA/.codex_tmp/r22_camfix_old_v3_negative_r2_20261028')
    negative_log = (negative/'tb_camera_gate.log').read_text()
    assert '** Fatal: write125 actual6c3e0800 expected6c3e0803' in negative_log
    assert 'PASS CAMERA GATE BUS:' not in negative_log
    physical = load(work/'physical_verification.json'); build = load(work/'build_result.json')
    assert physical['status'].startswith('PASS_R22_RELAY_V3_ROUTED_')
    assert physical['max_delays_matched'] == 49 and physical['max_delays_ignored'] == 0
    assert physical['control_mailbox_bits'] == 20
    assert all(physical['timing_ns'][key] >= 0 for key in ['SWNS', 'HWNS', 'STNS', 'HTNS'])
    bit = work/'runs/phy_1/camera_to_dsi_display.bit'
    assert sha(bit) == physical['bit_sha256'] == build['bit_sha256']
    protected = Path('E:/2026FPGA/BIT_FLASH/LATEST_READONLY.bit')
    protected_sha = '30d067cef0667893fe548ba04e423cd6618b76f119cb2e0ecf48b96ba6a5b20f'
    assert sha(protected) == protected_sha
    name = 'R22_RelayAuto_Left_V3_CamFix_20261028'
    release = repo/'releases/r22_relay_v3_camfix_20261028'; archive = release.with_suffix('.zip')
    flash = Path('E:/2026FPGA/BIT_FLASH')/(name+'.bit')
    assert not release.exists() and not archive.exists() and not flash.exists()
    if args.check_only:
        print(json.dumps({'status': 'READY_TO_PUBLISH', 'new_tests': 3, 'reused_tests': 17,
                          'bit_sha256': sha(bit), 'resources': physical['resources'], 'timing_ns': physical['timing_ns']}, indent=2)); return
    release.mkdir(parents=True)
    for rel in source: copy(project/rel, release/'project'/rel)
    write(release/'SOURCE_SHA256.json', source)
    copy(repo/'releases/r22_20261027/frozen_inputs.json', release/'baseline/r22_frozen_inputs.json')
    for p in (base/'tests').rglob('*'):
        if p.is_file(): copy(p, release/'tests/reused_v3'/p.relative_to(base/'tests'))
    for p in (repo/'tests/camera_gain_fix').iterdir():
        if p.is_file(): copy(p, release/'tests/camera_gain_fix'/p.name)
    for directory, label in [(rtl, 'new_rtl'), (gate, 'new_gate'), (negative, 'old_v3_expected_failure')]:
        for p in directory.rglob('*'):
            if p.is_file() and ('inputs' in p.relative_to(directory).parts or p.suffix in ['.json', '.log', '.hex']):
                copy(p, release/'tests'/label/p.relative_to(directory))
    for p in [diag/'export_fix_r2_ready.tcl', diag/'export_fix_r2_ready.log', netlist,
              diag/'v3_cone_closure.json', diag/'camera_gate_all_values.log']:
        copy(p, release/'diagnostics'/p.name)
    for n in ['camera_gate.log', 'compile.log', 'compile_tb.log', 'tb_camera_gate.sv', 'run_gate.py']:
        copy(diag/'v2_positive'/n, release/'diagnostics/v2_positive'/n)
    # Preserve rejected trials explicitly as diagnostics, never as PASS evidence.
    for directory, label in [(Path('E:/2026FPGA/.codex_tmp/r22_camfix_gate_r2_20261028'), 'harness_timescale_failure'),
                             (diag/'fix_serial', 'case_default_only_still_wrong')]:
        for p in directory.glob('*.log'): copy(p, release/'diagnostics'/label/p.name)
    for script in ['build_r22_relay.py', 'audit_r22_relay.py', 'check_camera_gain_fix.py', 'publish_r22_camera_fix.py']:
        copy(repo/'scripts'/script, release/'scripts'/script)
    for p in work.iterdir():
        if p.is_file() and p.suffix in ['.json', '.py', '.tcl', '.log']: copy(p, release/'build'/p.name)
    for stage in ['syn_1', 'phy_1']:
        for p in (work/'runs'/stage).iterdir():
            if p.is_file() and (p.suffix in ['.log', '.cfg', '.tcl', '.prj', '.rpt', '.area', '.timing', '.db'] or p.name == 'constraint_coverage.txt'):
                copy(p, release/'build/runs'/stage/p.name)
    for directory in ['classified_audit', 'gray_packing_audit']:
        for p in (project/directory).iterdir():
            if p.is_file(): copy(p, release/'build'/directory/p.name)
    copy(repo/'docs/R22_V3_CAMERA_FIX.md', release/'CAMERA_FIX.md')
    copy(repo/'docs/R22_RELAY_V3_FIELD_GUIDE.md', release/'FIELD_GUIDE.md')
    copy(base/'WEAK_NATIVE_BOUNDARY.json', release/'WEAK_NATIVE_BOUNDARY.json')
    copy(bit, release/(name+'.bit'))
    verification = {'status': 'PASS_NEW_CAMERA_CHECKS_AND_ROUTED_AUDIT', 'new_tests': new_tests, 'reused_tests': reused,
                    'reused_log_root': 'tests/reused_v3 (log paths omit the leading tests/)',
                    'v2_positive_sha256': sha(positive), 'old_v3_expected_failure_sha256': sha(negative/'tb_camera_gate.log'),
                    'physical': physical, 'changed_frozen_files': changed, 'unchanged_frozen_files': 635,
                    'sensor_optical_readback': False, 'board_image_acceptance': 'PENDING_HUMAN_REFLASH',
                    'position_accuracy_acceptance': False, 'physical_hold_acceptance': False,
                    'speed_adaptive': False, 'actual_refill_actuator_implemented': False, 'board_operated': False,
                    'known_boundary': 'Original weak RAW280 miss retained; not counted PASS. Old V3 black-image regression has a synthesized-bus fix; board confirmation pending.'}
    write(release/'VERIFICATION.json', verification)
    receipt = {'version': name, 'branch': 'codex/r22-v3-camera-gain-fix',
               'source_commit': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=repo, text=True).strip(),
               'parent_source': '119c276', 'source_worktree': str(repo), 'build_work': str(work),
               'bit_sha256': sha(bit), 'bit_bytes': bit.stat().st_size, 'td_version': 'V6.2.168116', 'seed': 2,
               'resources': physical['resources'], 'slice_percent': physical['slice_percent'], 'timing_ns': physical['timing_ns'],
               'source_files': 636, 'hardware_dependencies': 104, 'production_delta': changed,
               'gpio': 'right J2 pin1/V2 HIGH; board5V; original ADC/SDC; no LED',
               'keys': 'K1 fresh RUN / K2 pause-resume / K3 clear-stop / K4 stop / SW3 up stop down fresh RUN',
               'layout': 'single row, right count / left refill', 'parameters': {'target_x': 160, 'advance_px': 32, 'tolerance_px': 8, 'hold_ms': 1000},
               'source_manifest_sha256': sha(release/'SOURCE_SHA256.json'), 'verification_sha256': sha(release/'VERIFICATION.json'),
               'board_acceptance': 'PENDING_HUMAN_IMAGE_AND_PARKING_TEST', 'pushed': False}
    write(release/'RELEASE.json', receipt)
    (release/'README.md').write_text('V3 camera-init fix. Read CAMERA_FIX.md before FIELD_GUIDE.md. Full frozen project; three new camera tests and 17 exact-input reused tests, not 20 newly rerun tests. Gate evidence is a simulated ACK slave, not sensor readback. Rebuild in a new ASCII path: scripts/build_r22_relay.py --keys-v3 --source project --baseline-manifest baseline/r22_frozen_inputs.json --work E:/2026FPGA/R22_CamFix_rebuild --td E:/TD. Then scripts/audit_r22_relay.py --keys-v3 --work same_path. Camera RTL: scripts/check_camera_gain_fix.py --project project --out a_new_path. For gate check export gate.db with diagnostics/export_fix_r2_ready.tcl adapted to your new build and use --gate-netlist. Never overwrite this frozen release. The diagnostics/camera_gate_all_values.log old probe contains a misleading final message; only its logged values show zero gain, not a PASS. Rejected trials remain diagnostics.\n', encoding='utf8')
    payload = {p.relative_to(release).as_posix(): {'bytes': p.stat().st_size, 'sha256': sha(p)} for p in release.rglob('*') if p.is_file()}
    write(release/'PAYLOAD_SHA256.json', payload)
    with zipfile.ZipFile(archive, 'w', zipfile.ZIP_DEFLATED, compresslevel=6) as z:
        for p in release.rglob('*'):
            if p.is_file(): z.write(p, p.relative_to(release).as_posix())
    with zipfile.ZipFile(archive) as z:
        assert z.testzip() is None
        for rel, row in payload.items(): assert hashlib.sha256(z.read(rel)).hexdigest() == row['sha256']
    copy(release/(name+'.bit'), flash)
    copy(release/'CAMERA_FIX.md', flash.with_name(name+'_说明.md'))
    write(flash.with_name(name+'_RELEASE.json'), {**receipt, 'release_directory': str(release), 'archive': str(archive), 'archive_sha256': sha(archive)})
    assert sha(flash) == sha(bit) and sha(protected) == protected_sha
    delivery = {'status': 'DELIVERED_FOR_HUMAN_IMAGE_CONFIRMATION', 'release': str(release), 'archive': str(archive),
                'archive_sha256': sha(archive), 'flash_copy': str(flash), 'bit_sha256': sha(bit),
                'payload_count': len(payload), 'new_tests': 3, 'reused_tests': 17}
    write(repo/'docs/R22_CAMERA_FIX_DELIVERY.json', delivery); print(json.dumps(delivery, indent=2), flush=True)


if __name__ == '__main__': main()
