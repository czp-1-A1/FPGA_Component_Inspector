"""Verify R24 frozen inputs and actual completed simulation/physical evidence."""
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


def verify(source, build):
    manifest = json.loads((source / 'R24_FROZEN_INPUTS.json').read_text(encoding='utf8'))
    for name, digest in manifest.items():
        assert sha(source / name) == digest, ('changed source', name)
    initial = json.loads((source / 'validation/r24/candidate0_inputs.json').read_text(encoding='utf8'))
    relocated = {'td_project/camera_to_dsi_display.al'} | {
        'td_project/camera_to_dsi_display_Runs/' + stage + '/' + name
        for stage, names in [
            ('syn_1', ['build.tcl', 'camera_to_dsi_display.prj']),
            ('phy_1', ['build.tcl', 'camera_to_dsi_display.prj', 'settings.cfg']),
        ] for name in names
    }
    different = {name for name, digest in initial.items() if sha(build / name) != digest}
    assert different == relocated, ('unexpected build input difference', different)
    for name, digest in initial.items():
        if name not in relocated:
            assert sha(build / name) == digest, ('changed executed project', name)
    entry = 'td_project/camera_to_dsi_display.al'
    strip_path = lambda value: re.sub(r'(<Project\b[^>]*\bPath=")[^"]*', r'\1<LOCAL_PATH>', value.replace('\r\n', '\n').replace('\r', '\n'), count=1)
    assert strip_path(read(source / entry)) == strip_path(read(build / entry))
    dependencies = json.loads((build / 'portable_preparation.json').read_text(encoding='utf8'))['inputs']
    assert len(dependencies) == 102
    for name, digest in dependencies.items():
        assert sha(build / name) == digest == manifest[name], ('project/IP dependency', name)
    for stage in ['syn_1', 'phy_1']:
        folder = build / 'td_project/camera_to_dsi_display_Runs' / stage
        for name in re.findall(r'<File Path="([^"]+)"', read(folder / 'camera_to_dsi_display.prj')):
            dependency = (folder / name).resolve()
            relative = dependency.relative_to(build).as_posix()
            assert sha(dependency) == manifest[relative], ('relocated descriptor', relative)
    settings = read(build / 'td_project/camera_to_dsi_display_Runs/phy_1/settings.cfg')
    assert 'place seed 2 ' in settings and 'set SDCList {"../../camera_to_dsi_display.sdc"}' in settings
    verification_only = {
        'sim/run_modelsim.ps1', 'tools/check_present_detector.py',
        'tools/check_present_unit.py', 'sim/present_motion/verify_present_ui.py',
    }
    assert {n for n in initial if initial[n] != manifest[n]} == verification_only
    tests = {
        'two_region_count': source, 'two_region_ui': source,
        'two_region_detector': source, 'present_trace_unit': source,
        'present_trace_detector': source, 'present_trace_ui': source,
        'local_recovery': source, 'local_pipeline': source,
        'velocity_pipeline': source, 'result_recorder_pipeline': source,
        'classified_counter': source, 'regions': source,
        'frame_metadata': source, 'two_region_raw': build,
    }
    logs = {}
    for name, project in tests.items():
        folder = project / 'sim/modelsim_work' / name
        compile_log = read(folder / 'compile.log')
        console = read(folder / 'console.log')
        assert re.search(r'Errors:\s*0\b', compile_log), ('compile', name)
        assert re.search(r'(?m)^# PASS ', console), ('missing PASS', name)
        assert not re.search(r'(?m)^#\s*\*\* (Fatal|Error):', console), name
        logs[name] = {n: sha(folder / n) for n in ['compile.log', 'console.log']}
    reports = {
        'dual_ui': source / 'sim/two_region_ui_verification.json',
        'legacy_ui': source / 'sim/present_motion/independent_pixels/verification.json',
        'trace_unit': source / 'sim/present_motion/unit_independent_result.json',
        'trace_detector': source / 'sim/present_motion/detector_independent_reference.json',
        'dual_detector': source / 'validation/r24/dual_detector_equivalence.json',
        'native': build / 'validation/r24/native_reference.json',
    }
    for name, path in reports.items():
        result = json.loads(path.read_text(encoding='utf8'))
        assert result['status'].startswith('PASS'), (name, result['status'])
    from verify_classified_physical import verify as physical_verify
    physical = physical_verify(build)
    area = read(build / 'td_project/camera_to_dsi_display_Runs/phy_1/camera_to_dsi_display_phy.area')
    resources = {}
    for name, capacity in [('slice', 21216), ('eram', 108), ('dsp', 40), ('pll', 6)]:
        match = re.search(r'^#' + name + r'\s+(\d+)\s+out of\s+' + str(capacity) + r'\b', area, re.M)
        assert match, ('resource report', name)
        resources[name] = int(match[1])
        assert resources[name] <= capacity
    result = {
        'status': 'PASS_R24_14_ACTUAL_TESTS_INDEPENDENT_REFERENCES_AND_ROUTED_PHYSICAL_AUDIT',
        'source_inputs': len(manifest), 'executed_original_inputs': len(initial),
        'source_manifest_sha256': sha(source / 'R24_FROZEN_INPUTS.json'),
        'executed_manifest_sha256': sha(source / 'validation/r24/candidate0_inputs.json'),
        'verification_only_changes': sorted(verification_only),
        'relocated_descriptors': sorted(relocated), 'verified_project_ip_dependencies': len(dependencies),
        'tests': logs, 'references': {name: sha(p) for name, p in reports.items()},
        'resources': resources, 'timing_ns': physical['timing_ns'],
        'board_acceptance': 'HUMAN_PENDING', 'field_false_review_fixed': False,
    }
    destination = source / 'validation/r24/verification.json'
    destination.write_text(json.dumps(result, indent=2), encoding='utf8')
    return result


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('source', type=Path)
    parser.add_argument('build', type=Path)
    args = parser.parse_args()
    result = verify(args.source.resolve(), args.build.resolve())
    print(result['status'])
