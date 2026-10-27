"""Read-only portable verification of the exact R23 source and delivery archive.

Python standard library only. This verifies identity/evidence, not a fresh
simulation, implementation run or hardware acceptance.
"""
from pathlib import Path, PurePosixPath
import argparse, hashlib, json, zipfile

NAME = 'PocketCount_SW3_PresentTrace_r23_20261027'
MANIFEST_SHA = '075d48c42753f488ce0d2ae15761c3bad189022175190368261d2b503a1c5ae2'
ACTUAL_SHA = '152202701bd6fb143b8f7184739aa6715c5d0fe1de8cf218fbc00888d7b9b4bb'
BIT_SHA = '103ea4c37393f6eaf71a91c7740eaa14544e7d2e1b6c0fbc2cf98d25dafd93d7'
ZIP_SHA = '77c4eedc21c8ce5f0fe9142dd3a30165571e865eec40945855aad2fdb9a7e8e0'

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def load(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))

def verify(root, archive=None):
    release = root / 'releases/r23_20261028'
    source = root / 'fpga/component_inspector'
    frozen = release / 'frozen_inputs.json'
    assert sha(frozen) == MANIFEST_SHA, 'Frozen manifest identity mismatch'
    manifest = load(frozen)
    assert len(manifest) == 636
    for name, digest in manifest.items():
        assert sha(source / name) == digest, ('source', name)
    assert sha(release / 'actual_execution_inputs.json') == ACTUAL_SHA
    actual = load(release / 'actual_execution_inputs.json')
    assert actual.keys() == manifest.keys()
    assert [n for n in manifest if manifest[n] != actual[n]] == ['tools/check_present_raw.py']
    assets = load(release / 'ASSETS_SHA256.json')
    assert len(assets) == 5
    for name, row in assets.items():
        path = release / name
        assert path.stat().st_size == row['bytes'] and sha(path) == row['sha256'], name
    assert sha(release / (NAME + '.bit')) == BIT_SHA
    archive = archive or release / (NAME + '_full.zip')
    assert sha(archive) == ZIP_SHA
    with zipfile.ZipFile(archive) as z:
        names = z.namelist()
        assert len(names) == len(set(names)) and z.testzip() is None
        assert all(not PurePosixPath(n).is_absolute() and '..' not in PurePosixPath(n).parts for n in names)
        payload = json.loads(z.read('PAYLOAD_SHA256.json'))
        assert len(payload) == 4884 and set(names) == set(payload) | {'PAYLOAD_SHA256.json'}
        for name, row in payload.items():
            data = z.read(name)
            assert len(data) == row['bytes'] and hashlib.sha256(data).hexdigest() == row['sha256'], ('payload', name)
        assert json.loads(z.read('frozen_inputs.json')) == manifest
        for name, digest in manifest.items():
            assert hashlib.sha256(z.read('fpga/component_inspector/' + name)).hexdigest() == digest, name
        assert hashlib.sha256(z.read(NAME + '.bit')).hexdigest() == BIT_SHA
        hardware = json.loads(z.read('hardware_inputs.json'))
        assert len(hardware) == 102
        for name, digest in hardware.items():
            assert manifest[name] == digest, name
        tests = json.loads(z.read('validation/test_archive_map.json'))
        assert len(tests) == 151
        for name, row in tests.items():
            for rel, digest in {**row['inputs'], **row['runtime_inputs']}.items():
                assert manifest[rel] == digest, (name, rel)
            for log, key in [('compile.log', 'compile_sha256'), ('console.log', 'console_sha256')]:
                assert hashlib.sha256(z.read(row['archive_project'] + '/sim/modelsim_work/' + name + '/' + log)).hexdigest() == row[key], (name, log)
        verified = json.loads(z.read('validation/verification.json'))
        assert verified['tests'] == 151 and verified['independent_references'] == 53
        assert verified['resources'] == {'slice': 19010, 'eram': 101, 'dsp': 27, 'pll': 5}
        assert verified['slice_percent'] < 90
        timing = verified['timing_ns']
        assert timing['SWNS'] >= 0 and timing['HWNS'] >= 0 and timing['STNS'] == timing['HTNS'] == 0
        assert verified['diagnostic_only'] and not verified['field_false_review_fixed']
        assert verified['actual_execution_manifest_sha256'] == ACTUAL_SHA
    feedback = load(release / 'FIELD_FEEDBACK.json')
    assert feedback['board_acceptance'] == 'HUMAN_PENDING'
    assert feedback['diagnostic_only'] and not feedback['field_false_review_fixed']
    return {'status': 'PASS_R23_636_SOURCE_4884_PAYLOAD_151_LOG_102_DEPENDENCY_IDENTITY',
            'manifest_sha256': MANIFEST_SHA, 'bit_sha256': BIT_SHA, 'zip_sha256': ZIP_SHA,
            'diagnostic_only': True, 'board_acceptance': 'HUMAN_PENDING',
            'scope': 'Identity/evidence verification; no fresh build or field acceptance asserted'}

if __name__ == '__main__':
    p = argparse.ArgumentParser()
    p.add_argument('--root', type=Path, default=Path(__file__).resolve().parents[2])
    p.add_argument('--archive', type=Path)
    p.add_argument('--output', type=Path)
    a = p.parse_args()
    result = verify(a.root.resolve(), a.archive.resolve() if a.archive else None)
    if a.output:
        a.output.write_text(json.dumps(result, indent=2) + '\n', encoding='utf8')
    print(json.dumps(result, indent=2))
