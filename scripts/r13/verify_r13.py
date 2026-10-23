"""Verify the immutable R13 upload without TD/ModelSim or changing files."""
from pathlib import Path, PurePosixPath
import argparse, hashlib, json, re, zipfile

NAME = 'PocketCount_SW3_CompactResource_r13_20261023'
MANIFEST_SHA = '243651b68a39160cfb81efe91b11836bcb32109750ecd29793530fca1bc98c65'
BIT_SHA = '2350b5985afa679df3d8bfd1a5fa2aba9f355468f284704d10dd46beeda402a7'

def sha(data):
    return hashlib.sha256(data).hexdigest()

def read_json(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))

def check(condition, message):
    if not condition:
        raise RuntimeError(message)

def verify(repo):
    project = repo / 'fpga/component_inspector'
    release = repo / 'releases/r13_20261023'
    manifest_path = release / 'frozen_inputs.json'
    check(sha(manifest_path.read_bytes()) == MANIFEST_SHA, 'Changed R13 manifest')
    manifest = read_json(manifest_path)
    check(len(manifest) == 471, 'R13 needs471 inputs')
    check((project / 'R13_FROZEN_INPUTS.json').read_bytes() == manifest_path.read_bytes(), 'Project/release manifest mismatch')
    for rel, expected in manifest.items():
        path = project / rel
        path.resolve().relative_to(project.resolve())
        check(sha(path.read_bytes()) == expected, 'Changed source: ' + rel)
    receipt = read_json(release / (NAME + '_交付回执.json'))
    checked_payloads = 0
    for original, record in receipt['desktop'].items():
        name = original.replace('\\', '/').rsplit('/', 1)[-1]
        data = (release / name).read_bytes()
        check(len(data) == record['bytes'] and sha(data) == record['sha256'], 'Changed delivery: ' + name)
        checked_payloads += 1
    check(sha((release / (NAME + '.bit')).read_bytes()) == BIT_SHA, 'Wrong bit')
    with zipfile.ZipFile(release / (NAME + '_full.zip')) as archive:
        check(archive.testzip() is None, 'ZIP CRC mismatch')
        names = archive.namelist()
        check(len(names) == len(set(names)), 'Duplicate ZIP member')
        for name in names:
            member = PurePosixPath(name)
            check(not member.is_absolute() and '..' not in member.parts and '\\' not in name, 'Unsafe ZIP path')
        inventory = json.loads(archive.read('PAYLOAD_SHA256.json'))
        check(len(inventory) == 1225, 'Wrong archive inventory count')
        check(set(names) == set(inventory) | {'PAYLOAD_SHA256.json'}, 'Unlisted ZIP payload')
        for name, record in inventory.items():
            data = archive.read(name)
            check(len(data) == record['bytes'] and sha(data) == record['sha256'], 'Changed ZIP payload: ' + name)
        check(sha(archive.read('frozen_inputs.json')) == MANIFEST_SHA, 'ZIP manifest mismatch')
        for rel, expected in manifest.items():
            check(sha(archive.read('fpga/component_inspector/' + rel)) == expected, 'ZIP source mismatch: ' + rel)
        check(sha(archive.read('candidate/' + NAME + '.bit')) == BIT_SHA, 'ZIP bit mismatch')
        software = json.loads(archive.read('validation/software_verification.json'))
        check(software['status'] == 'PASS72_FROZEN_ACTUAL_COMPILED_INPUTS_NO_EXCLUSIONS' and len(software['tests']) == 72, 'Software evidence missing')
        check(software['manifest_sha256'] == MANIFEST_SHA, 'Software manifest mismatch')
    area = (release / 'evidence/final_routed.area').read_text(encoding='utf-8-sig')
    check(re.search(r'^#slice\s+19708\s+out of\s+21216', area, re.M), 'Wrong final routed area')
    physical = read_json(release / 'evidence/routed_verification.json')
    check(physical['timing_ns'] == {'SWNS':0.002,'HWNS':0.02,'STNS':0.0,'HTNS':0.0}, 'Wrong routed timing')
    check(physical['max_delays_matched'] == 46 and physical['max_delays_ignored'] == 0 and physical['gray_bits_dominating'] == 20 and physical['new_mailbox_groups'] == 6, 'Incomplete CDC audit')
    delta = read_json(release / 'evidence/project_dependency_delta.json')
    expected = {rel: manifest[rel] for rel in delta['expected_dependencies']}
    check(len(expected) == 98, 'Wrong project dependency closure')
    check(set(expected) == set(delta['baseline_inputs']) | set(delta['added']), 'Expected original94 plus four new modules')
    for rel, digest in expected.items():
        check(sha((project / rel).read_bytes()) == digest, 'Wrong project dependency: ' + rel)
    return {'status':'PASS_R13_GIT_SOURCE471_DESKTOP_PAYLOADS_ARCHIVE1225_SOFTWARE72_ROUTED_AND_DEPENDENCIES98', 'source_count':471, 'payloads':checked_payloads, 'archive_payloads':1225, 'project_dependencies':98, 'bit_sha256':BIT_SHA, 'manifest_sha256':MANIFEST_SHA, 'new_simulation_or_build':False}

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--repo', type=Path, default=Path(__file__).resolve().parents[2])
    args = parser.parse_args()
    print(json.dumps(verify(args.repo.resolve()), indent=2))
