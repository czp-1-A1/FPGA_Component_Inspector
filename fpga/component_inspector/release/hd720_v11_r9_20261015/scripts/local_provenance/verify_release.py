"""Evidence checks for V11 r9. This file never changes frozen RTL or tests."""
from collections import Counter
from pathlib import Path
import hashlib
import json
import re

ROOT = Path(__file__).resolve().parent
PACKAGE = Path('C:/Users/Li47/Desktop/aa/V11/v11_handoff_20261015/v11_handoff_20261015')
WORK = ROOT / 'r9/fpga/component_inspector'
SNAPSHOT = ROOT / 'r9/source_snapshot'
PHY = WORK / 'td_project/camera_to_dsi_display_Runs/phy_1'
TESTS = ['process_bridge', 'frame_search', 'frame_osd', 'shape_snapshot', 'shape_model',
         'frame_tailproof', 'frame_stop', 'frame_process', 'shape_osd',
         'video_fallback_display', 'frame_wait_metadata', 'video_metadata_fallback',
         'writer_epoch', 'wb_epoch', 'observation', 'display_state', 'roi_guard',
         'video_first', 'video_late_display', 'frame_cadence',
         'hd_resize', 'hd_guard', 'hd_scaled_guard', 'hd_osd', 'hd_search', 'hd_chain',
         'hd_pins', 'hd_pll']

def read(path):
    data = path.read_bytes()
    return data.decode('utf-16' if data.startswith((b'\xff\xfe', b'\xfe\xff')) else 'utf-8-sig', errors='replace')

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def require(ok, message):
    if not ok:
        raise AssertionError(message)

def warning_codes(path):
    return dict(Counter(re.findall(r'(?m)^(\S+-\d+) (?:CRITICAL[ -])?WARNING:', read(path))))

def constraint_rows(text):
    rows = []
    counts = None
    for line in text.split('Min Check')[0].splitlines():
        match = re.fullmatch(r'\s*(?:(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+)?(set_max_delay.+?)\s*', line)
        if not match:
            continue
        if match[1] is not None:
            counts = tuple(int(match[i]) for i in range(1, 5))
        require(counts is not None, 'Constraint continuation without numeric group')
        # TD178840 prints aliases sharing the same physical path on continuation
        # lines. Each is still one explicit SDC command and must be checked.
        rows.append(dict(zip(['total','dominated','shadowed','ignored'], counts), constraint=match[5]))
    return rows

def main():
    result = {'status': 'AUDIT_PENDING', 'physical_video': 'NOT_TESTED',
              'calibration_220mm': 'PENDING_NEW_TRUTH_SAMPLES', 'tests': {}, 'build': {}}
    manifest = json.loads(read(SNAPSHOT / 'inputs.json'))
    result['source_manifest_sha256'] = sha(SNAPSHOT / 'inputs.json')
    for name, digest in manifest.items():
        require(sha(SNAPSHOT / name) == digest, 'Frozen source changed: ' + name)
        if name.startswith(('user_source/', 'sim/')):
            require(sha(WORK / name) == digest, 'Run input changed: ' + name)
            require(sha(ROOT / 'development/fpga/component_inspector' / name) == digest,
                    'Development no longer matches frozen run: ' + name)
    result['frozen_files'] = len(manifest)
    result['production_files'] = sum(name.startswith('user_source/') for name in manifest)
    original = json.loads(read(PACKAGE / 'source_snapshot/inputs.json'))
    original.update(json.loads(read(PACKAGE / 'source_snapshot/extra_inputs.json')))
    functional_changes = [name for name in manifest if name.startswith(('user_source/', 'sim/'))
                          and manifest[name] != original[name]]
    require(functional_changes == ['user_source/hdl_source/roi_frame_guard.v'], functional_changes)
    result['production_and_test_changes'] = functional_changes
    require(sha(WORK / 'td_project/camera_to_dsi_display.sdc') ==
            original['td_project/camera_to_dsi_display.sdc'], 'SDC changed')
    for project in ['td_project/camera_to_dsi_display.al'] + [
            f'td_project/camera_to_dsi_display_Runs/{stage}/camera_to_dsi_display.prj'
            for stage in ['syn_1', 'phy_1']]:
        path = WORK / project
        for relative in re.findall(r'<File Path="([^"]+)"', read(path)):
            target = (path.parent / relative).resolve()
            require(target.is_file() and target.is_relative_to(WORK), 'Missing project dependency: '+str(target))
    sim_result = json.loads(read(WORK / 'replay_sim.result.json'))
    require(sim_result['exit_code'] == 0, 'Full regression runner failed')
    require('PASS ModelSim: all 28 tests' in read(WORK / 'replay_sim.log'), 'Missing overall 28-test completion')
    runner = read(SNAPSHOT / 'sim/run_modelsim.ps1')
    signatures = dict(re.findall(r'Name="([^"]+)"; Pass="([^"]+)"', runner))
    for test in TESTS:
        log = WORK / 'sim/modelsim_work' / test / 'console.log'
        value = read(log)
        require(signatures[test] in value, 'Missing PASS '+test)
        require(not re.search(r'(?m)^#?\s*\*\* (?:Fatal|Error):', value), 'Simulator fatal '+test)
        result['tests'][test] = {'status': 'PASS', 'console_sha256': sha(log)}
    references = json.loads(read(WORK / 'independent_reference_results.json'))
    require(len(references) == 18, 'Expected 13 search + 5 chain actual images')
    require(all(item['status'] == 'PASS' for item in references), 'Independent image reference failed')
    result['independent_images'] = len(references)
    for stage in ['syn_1', 'phy_1']:
        stage_dir = WORK / 'td_project/camera_to_dsi_display_Runs' / stage
        state = json.loads(read(stage_dir / 'build_local.result.json'))
        require(state['exit_code'] == 0, 'Build exit '+stage)
        local_codes = warning_codes(stage_dir / 'build_local.log')
        old_codes = warning_codes(PACKAGE / 'evidence/r8/td_reports' / stage / 'build_console.log')
        result['build'][stage] = dict(state, warning_code_counts=local_codes,
            r8_warning_code_counts=old_codes,
            new_warning_codes=sorted(set(local_codes) - set(old_codes)))
    timing = read(PHY / 'camera_to_dsi_display_pr.timing')
    require('Routed' in timing and 'Both (Slow and Fast)' in timing, 'Not both routed corners')
    for key in ['SWNS', 'HWNS', 'STNS', 'HTNS']:
        numbers = [float(v) for v in re.findall(r'\b'+key+r':\s*([-\d.]+)ns', timing)]
        require(numbers and min(numbers) >= 0, key+' missing or negative '+str(numbers))
        result[key+'_ns'] = numbers
    coverage = read(WORK / 'audit/constraint_coverage.txt')
    result['coverage'] = {name: int(count) for name, count in re.findall(
        r'(?m)^\d+\. checking ([^\n]+?)\((\d+)\) \(', coverage)}
    for name in ['no clock', 'clock definition', 'invalid constraint', 'combinational loops',
                 'soft fifo timing exception constraints', 'no path constraints']:
        require(result['coverage'].get(name) == 0, 'Unexpected coverage '+name)
    exceptions = read(WORK / 'audit/exceptions.timing')
    rows = constraint_rows(exceptions)
    result['max_delay_constraints'] = rows
    require(len(rows) == 40, 'Expected38 explicit+2 vendor max-delay constraints')
    require(all(row['total'] > 0 and row['ignored'] == 0 for row in rows), 'Unmatched/ignored max-delay')
    explicit = [line.strip() for line in read(WORK / 'td_project/camera_to_dsi_display.sdc').splitlines()
                if line.startswith('set_max_delay')]
    require(len(explicit) == 38 and set(explicit).issubset({row['constraint'] for row in rows}),
            'An explicit SDC command is absent from routed coverage')
    gray = [row for row in result['max_delay_constraints'] if 'continuous_processing' in row['constraint']]
    require(len(gray) == 1 and [gray[0][k] for k in ['total','dominated','shadowed','ignored']] == [20,20,0,0],
            'Gray budget not dominant for all20 paths')
    bindings = read(ROOT / 'r9/routed_audit.log')
    require('PASS GRAY_BINDING 20' in bindings, 'Missing per-bit resolution')
    result['gray_bits'] = {}
    for direction in ['write', 'read']:
        for bit in range(10):
            path = WORK / f'audit/gray_{direction}_{bit}.timing'
            value = read(path)
            require('Begin Point' in value and 'End Point' in value, 'No bit timing '+path.name)
            budgets = [float(v) for v in re.findall(r'Budget\s*:\s*([-\d.]+)ns', value)]
            slacks = [float(v) for v in re.findall(r'Slack\s*:\s*([-\d.]+)ns', value)]
            delays = [float(v) for v in re.findall(r'Data Path Delay\s*:\s*([-\d.]+)ns', value)]
            require(budgets == [8.0] and slacks and min(slacks) >= 0 and delays and max(delays) < 8,
                    '8ns budget/delay/slack failed '+path.name)
            # TD packs multiple logical registers into physical cells with unrelated names.
            # Bind each path using its logical net annotations as well as get_regs resolution.
            source_net = f'{direction}_'+('bin' if bit == 9 else 'gray')+f'[{bit}]'
            require('/'+source_net+',' in value and f'/{direction}_gray_sync1[{bit}],' in value,
                    'Logical Gray net mapping missing '+path.name)
            result['gray_bits'][f'{direction}_{bit}'] = dict(report_sha256=sha(path),
                budgets_ns=budgets, slacks_ns=slacks, data_path_delays_ns=delays)
    result['slice_area_report_sha256'] = sha(PHY / 'camera_to_dsi_display_phy.area')
    bit = PHY / 'camera_to_dsi_display.bit'
    result['bit'] = {'path':str(bit), 'bytes':bit.stat().st_size, 'sha256':sha(bit)}
    require(bit.stat().st_size > 1000000, 'Unexpected bit length')
    result['status'] = 'PASS_SOFTWARE_AND_ROUTED_STA_PHYSICAL_PENDING'
    (ROOT / 'r9/verification.json').write_text(json.dumps(result, indent=2), encoding='utf-8')
    print(result['status'], 'tests',len(result['tests']),'images',len(references),'bit',result['bit']['sha256'])

if __name__ == '__main__':
    main()
