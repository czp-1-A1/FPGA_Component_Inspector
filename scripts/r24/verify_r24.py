"""Portable identity check of the published R24 source and full evidence zip.

Standard library only. This checks existing evidence, not a new build or board.
"""
from pathlib import Path, PurePosixPath
import argparse
import hashlib
import json
import re
import zipfile

MANIFEST = 'af9915f0910895ef0dc427e4d01b350323bc190e8db3b26a762b2124935123c1'
EXECUTED = 'd726f624132ea610b5d2010648f50f765dbc3b151e26de44ffce88ee23f19e9e'
BIT = '0ce9f60635aa00f2318eb04403e604f166e92a6770606ed323bddc0549f29e20'
ARCHIVE = '2f5f7ce1a620071019013b22e8926b6ec2a7dabee440e4596800f857580b40c4'


def sha(path):
    with path.open('rb') as f:
        return hashlib.file_digest(f, 'sha256').hexdigest()


def load(path):
    return json.loads(path.read_text(encoding='utf-8'))


def verify(root, archive):
    source = root / 'fpga/component_inspector'
    release = root / 'releases/r24_20261028'
    assert sha(source / 'R24_FROZEN_INPUTS.json') == MANIFEST
    assert sha(source / 'C2_FROZEN_INPUTS.json') == EXECUTED
    frozen = load(source / 'R24_FROZEN_INPUTS.json')
    executed = load(source / 'C2_FROZEN_INPUTS.json')
    assert len(frozen) == 654 and len(executed) == 652
    assert all(frozen[n] == d for n, d in executed.items())
    for name, digest in frozen.items():
        assert sha(source / name) == digest, ('source', name)
    receipt = load(release / 'RELEASE.json')
    assert receipt['bit_sha256'] == BIT and receipt['zip_sha256'] == ARCHIVE
    assert sha(archive) == ARCHIVE
    assets = load(release / 'ASSETS_SHA256.json')
    for name, row in assets.items():
        path = archive if name == receipt['zip'] else release / name
        assert path.stat().st_size == row['bytes'] and sha(path) == row['sha256'], name
    with zipfile.ZipFile(archive) as z:
        names = z.namelist()
        assert len(names) == len(set(names)) and z.testzip() is None
        assert all(not PurePosixPath(n).is_absolute() and '..' not in PurePosixPath(n).parts
                   and '\\' not in n and ':' not in n for n in names)
        payload = json.loads(z.read('PAYLOAD_SHA256.json'))
        assert len(payload) == 1560 and set(names) == set(payload) | {'PAYLOAD_SHA256.json'}
        for name, row in payload.items():
            data = z.read(name)
            assert len(data) == row['bytes'] and hashlib.sha256(data).hexdigest() == row['sha256'], name
        for name, digest in frozen.items():
            assert hashlib.sha256(z.read('fpga/component_inspector/' + name)).hexdigest() == digest, name
        assert hashlib.sha256(z.read(receipt['bit'])).hexdigest() == BIT
        result = json.loads(z.read('fpga/component_inspector/validation/r24/verification.json'))
        assert result['status'] == 'PASS_R24_C2_12_ACTUAL_TESTS_7_IDENTITY_REUSED_TESTS_AND_ROUTED_PHYSICAL_AUDIT'
        assert result['actual_candidate_tests'] == 12 and result['identity_reused_tests'] == 7
        assert result['source_manifest_sha256'] == MANIFEST and result['executed_manifest_sha256'] == EXECUTED
        assert result['bit_sha256'] == BIT
        assert result['resources'] == {'slice': 18460, 'eram': 101, 'dsp': 28, 'pll': 5}
        for name, row in result['tests'].items():
            prefix = 'build_evidence/' if name == 'two_region_raw' else 'fpga/component_inspector/'
            for log, key in [('compile.log', 'compile_sha256'), ('console.log', 'console_sha256')]:
                data = z.read(prefix + 'sim/modelsim_work/' + name + '/' + log)
                assert hashlib.sha256(data).hexdigest() == row[key], (name, log)
        audit = json.loads(z.read('build_evidence/classified_audit/verification.json'))
        assert audit['max_delays_matched'] == 46 and audit['max_delays_ignored'] == 0
        assert audit['gray_bits_dominating'] == 20 and audit['new_mailbox_groups'] == 6
        timing_data = z.read('build_evidence/classified_audit/routed_summary.timing').decode('utf-8-sig')
        assert 'Confidence          : Routed' in timing_data and 'Check Corner        : Both (Slow and Fast)' in timing_data
        for key, expected in {'SWNS': .002, 'HWNS': .020, 'STNS': 0., 'HTNS': 0.}.items():
            match = re.search(r'\b' + key + r':\s*([-\d.]+)ns', timing_data)
            assert match and float(match[1]) == expected == result['timing_ns'][key], key
        native = json.loads(z.read('build_evidence/validation/r24/native_reference.json'))
        assert native['status'].startswith('PASS') and native['compared_actual_pixels'] == 844800
        assert (native['accepted_native_frames'], native['classified_frames'], native['canceled_frames']) == (12, 11, 1)
        for bank in range(2):
            assert [e[1:] for e in native['events'] if e[0] == bank] == [[1, 5, 2], [2, 7, 3], [3, 8, 3], [4, 9, 2]]
    return {'status': 'PASS_R24_654_SOURCE_1560_PAYLOAD_12_ACTUAL_7_IDENTITY_REUSED_AND_ROUTED_EVIDENCE',
            'source_manifest_sha256': MANIFEST, 'executed_manifest_sha256': EXECUTED,
            'bit_sha256': BIT, 'zip_sha256': ARCHIVE,
            'board_acceptance': 'HUMAN_PENDING', 'field_false_review_fixed': False,
            'scope': 'Identity and completed evidence only; no fresh simulation, routing or board acceptance'}


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--root', type=Path, default=Path(__file__).resolve().parents[2])
    parser.add_argument('--archive', type=Path, required=True)
    args = parser.parse_args()
    print(json.dumps(verify(args.root.resolve(), args.archive.resolve()), indent=2))
