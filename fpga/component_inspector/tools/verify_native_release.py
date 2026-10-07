"""Verify a finalized candidate's checksum file, frozen inputs and toolchain."""
from pathlib import Path
import argparse,hashlib,json,zipfile

ap=argparse.ArgumentParser()
ap.add_argument('release',type=Path)
args=ap.parse_args();root=args.release.resolve()
def digest(data):return hashlib.sha256(data).hexdigest()
listed=set()
for line in (root/'SHA256SUMS.txt').read_text().splitlines():
    expected,rel=line.split('  ',1);path=(root/rel).resolve()
    assert path.is_relative_to(root),rel
    assert path.is_file() and digest(path.read_bytes())==expected,rel
    listed.add(rel)
files={p.relative_to(root).as_posix() for p in root.rglob('*') if p.is_file() and p.name!='SHA256SUMS.txt'}
assert listed==files,(listed^files)
inputs=json.loads((root/'input_snapshot.json').read_text())
with zipfile.ZipFile(root/'input_snapshot.zip') as archive:
    assert archive.read('freeze.json')==(root/'input_snapshot.json').read_bytes()
    for entry in inputs['inputs']:
        data=archive.read(entry['path'])
        assert len(data)==entry['bytes'] and digest(data)==entry['sha256'],entry['path']
toolchain=json.loads((root/'toolchain.json').read_text())
for entry in toolchain:
    path=Path(entry['path'])
    assert path.stat().st_size==entry['bytes'] and digest(path.read_bytes())==entry['sha256'],path
release=json.loads((root/'release.json').read_text())
assert digest((root/'camera_to_dsi_display.bit').read_bytes())==release['bit_sha256']
assert digest((root/'rollback.bit').read_bytes())==release['rollback_sha256']
assert release['status']=='DIAGNOSTIC_CANDIDATE_NOT_ACCEPTED'
tests=json.loads((root/'tests/results.json').read_text())
assert len(tests)==25 and all(t['status']=='PASS' for t in tests)
for test in tests:
    assert digest((root/'tests'/test['name']/'console.log').read_bytes())==test['console_sha256']
print(f'PASS release integrity: {len(files)} files, {len(inputs["inputs"])} frozen inputs, {len(tests)} test logs, {len(toolchain)} tool/model hashes')
