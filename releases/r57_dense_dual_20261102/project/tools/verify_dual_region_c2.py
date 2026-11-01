"""Check the exact C2 execution, unchanged-test reuse and routed evidence."""
from pathlib import Path
import argparse
import hashlib
import json
import re


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read(path):
    data = path.read_bytes()
    return data.decode('utf-16' if data.startswith(b'\xff\xfe') else 'utf-8-sig')


def load(path):
    return json.loads(path.read_text(encoding='utf8'))


def verify(source, build):
    frozen = source / 'C2_FROZEN_INPUTS.json'
    assert sha(frozen) == 'd726f624132ea610b5d2010648f50f765dbc3b151e26de44ffce88ee23f19e9e'
    initial = load(frozen)
    manifest = load(source / 'R24_FROZEN_INPUTS.json')
    assert len(initial) == 652
    for name, digest in manifest.items():
        assert sha(source / name) == digest, ('changed source', name)
    assert all(manifest[n] == d for n, d in initial.items()), 'Executed source changed after freeze'
    changed = {n for n, d in initial.items() if sha(build / n) != d}
    relocated = {'td_project/camera_to_dsi_display.al'} | {
        'td_project/camera_to_dsi_display_Runs/' + stage + '/camera_to_dsi_display.prj'
        for stage in ['syn_1', 'phy_1']
    }
    assert changed == relocated, ('unexpected executed input change', changed)
    normalize = lambda text: re.sub(r'(<Project\b[^>]*\bPath=")[^"]*', r'\1<LOCAL_PATH>',
                                    text.replace('\r\n', '\n').replace('\r', '\n'), count=1)
    entry = 'td_project/camera_to_dsi_display.al'
    assert normalize(read(source / entry)) == normalize(read(build / entry))
    dependencies = load(build / 'portable_preparation.json')['inputs']
    assert len(dependencies) == 102
    for name, digest in dependencies.items():
        assert sha(build / name) == digest == manifest[name], ('hardware dependency', name)
    for stage in ['syn_1', 'phy_1']:
        folder = build / 'td_project/camera_to_dsi_display_Runs' / stage
        for relative in re.findall(r'<File Path="([^"]+)"', read(folder / 'camera_to_dsi_display.prj')):
            path = (folder / relative).resolve()
            assert sha(path) == manifest[path.relative_to(build).as_posix()], relative
    assert 'place seed 2 ' in read(build / 'td_project/camera_to_dsi_display_Runs/phy_1/settings.cfg')
    reuse = load(source / 'validation/r24/unchanged_test_reuse.json')
    assert reuse['status'] == 'PASS_REUSE_ONLY_EXACT_UNCHANGED_COMPILED_AND_FROZEN_RUNTIME_INPUTS'
    assert len(reuse['tests']) == 7 and len(reuse['frozen_runtime_inputs']) == 45
    assert reuse['source_manifest_sha256'] == '7f09976d95a8f0a6afb6294ead1c69a098c06cd94926fa131c2af118fd85c2cb'
    for name, record in reuse['tests'].items():
        assert not record['rerun_in_candidate']
        assert 'user_source/hdl_source/classified_pocket_counter.v' not in record['compiled_inputs']
        for relative, digest in record['compiled_inputs'].items():
            assert sha(source / relative) == digest == initial[relative], (name, relative)
        for filename, key in [('compile.log', 'compile_sha256'), ('console.log', 'console_sha256')]:
            assert sha(source / 'sim/modelsim_work' / name / filename) == record[key], (name, filename)
    for relative, digest in reuse['frozen_runtime_inputs'].items():
        assert sha(source / relative) == digest == initial[relative], relative
    fresh = ['counter_timing_equivalence'] + ['counter_timing_case' + str(i) for i in range(1, 5)] + [
        'two_region_count', 'classified_counter', 'local_pipeline', 'velocity_pipeline',
        'local_recovery', 'result_recorder_pipeline', 'two_region_raw',
    ]
    logs = {}
    for name in fresh + list(reuse['tests']):
        project = build if name == 'two_region_raw' else source
        folder = project / 'sim/modelsim_work' / name
        compile_log, console = read(folder / 'compile.log'), read(folder / 'console.log')
        assert re.search(r'Errors:\s*0\b', compile_log), name
        assert re.search(r'(?m)^# PASS ', console), name
        assert not re.search(r'(?m)^#\s*\*\* (Fatal|Error):', console), name
        logs[name] = {'execution': 'identity_reused' if name in reuse['tests'] else 'C2_actual',
                      'compile_sha256': sha(folder / 'compile.log'),
                      'console_sha256': sha(folder / 'console.log')}
    reports = {
        'dual_ui': source / 'sim/two_region_ui_verification.json',
        'legacy_ui': source / 'sim/present_motion/independent_pixels/verification.json',
        'trace_unit': source / 'sim/present_motion/unit_independent_result.json',
        'trace_detector': source / 'sim/present_motion/detector_independent_reference.json',
        'dual_detector': source / 'validation/r24/dual_detector_equivalence.json',
        'native': build / 'validation/r24/native_reference.json',
    }
    for name, path in reports.items():
        assert load(path)['status'].startswith('PASS'), name
    from verify_classified_physical import verify as physical_verify
    physical = physical_verify(build)
    final_log = build / 'r24_finalization_console.log'
    final_text = read(final_log)
    assert 'PASS R24 ROUTED FINALIZATION:' in final_text, 'Final bit was not accepted/exported'
    assert 'No multi-drive.' in final_text and 'No abnormal timing path.' in final_text
    assert not re.search(r'(?m)^\S+\s+ERROR:', final_text), 'Finalization command error'
    from verify_classified_physical import timing
    final_timing = timing(read(build / 'td_project/camera_to_dsi_display_Runs/phy_1/camera_to_dsi_display_pr.timing'))
    assert final_timing == physical['timing_ns'], 'Audited DB differs from delivered implementation'
    area = read(build / 'td_project/camera_to_dsi_display_Runs/phy_1/camera_to_dsi_display_phy.area')
    resources = {}
    for name, capacity in [('slice', 21216), ('eram', 108), ('dsp', 40), ('pll', 6)]:
        match = re.search(r'^#' + name + r'\s+(\d+)\s+out of\s+' + str(capacity) + r'\b', area, re.M)
        assert match and int(match[1]) <= capacity, name
        resources[name] = int(match[1])
    result = {
        'status': 'PASS_R24_C2_12_ACTUAL_TESTS_7_IDENTITY_REUSED_TESTS_AND_ROUTED_PHYSICAL_AUDIT',
        'source_inputs': len(manifest), 'executed_frozen_inputs': len(initial),
        'source_manifest_sha256': sha(source / 'R24_FROZEN_INPUTS.json'),
        'executed_manifest_sha256': sha(frozen), 'relocated_descriptors': sorted(relocated),
        'actual_candidate_tests': len(fresh), 'identity_reused_tests': len(reuse['tests']),
        'tests': logs, 'references': {name: sha(path) for name, path in reports.items()},
        'resources': resources, 'timing_ns': physical['timing_ns'],
        'gate_db_sha256': sha(build / 'td_project/camera_to_dsi_display_Runs/syn_1/camera_to_dsi_display_gate.db'),
        'routed_db_sha256': sha(build / 'td_project/camera_to_dsi_display_Runs/phy_1/camera_to_dsi_display_pr.db'),
        'bit_sha256': sha(build / 'td_project/camera_to_dsi_display_Runs/phy_1/camera_to_dsi_display.bit'),
        'finalization_log_sha256': sha(final_log),
        'board_acceptance': 'HUMAN_PENDING', 'field_false_review_fixed': False,
    }
    (source / 'validation/r24/verification.json').write_text(json.dumps(result, indent=2), encoding='utf8')
    return result


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('source', type=Path)
    parser.add_argument('build', type=Path)
    args = parser.parse_args()
    print(verify(args.source.resolve(), args.build.resolve())['status'])
