"""Recreate a portable TD download folder from the frozen D release."""
from pathlib import Path
import argparse, hashlib, json, re, shutil, zipfile
engine = Path(__file__).resolve().parents[1]
ap = argparse.ArgumentParser()
ap.add_argument('destination', type=Path)
args = ap.parse_args()
dest = args.destination.resolve()
out = engine / 'release/native_1080p30/hdmi_avi_diagnostic_20261009'
if dest.exists():
    raise SystemExit('Refusing existing destination')
if not str(dest).isascii() or ' ' in str(dest):
    raise SystemExit('Use an ASCII destination without spaces')
def sha(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()
for line in (out / 'SHA256SUMS.txt').read_text().splitlines():
    expected, rel = line.split('  ', 1)
    p = (out / rel).resolve()
    assert p.is_relative_to(out.resolve()) and sha(p) == expected, rel
meta = json.loads((out / 'input_snapshot.json').read_text(encoding='utf-8-sig'))
name = meta['project']
assert name == 'avi_fhd30'
with zipfile.ZipFile(out / 'input_snapshot.zip') as z:
    assert set(z.namelist()) == set(e['path'] for e in meta['inputs'])
    for e in meta['inputs']:
        data = z.read(e['path'])
        assert hashlib.sha256(data).hexdigest() == e['sha256'], e['path']
        p = (dest / e['path']).resolve()
        assert p.is_relative_to(dest), e['path']
    dest.mkdir(parents=True)
    z.extractall(dest)
prj = dest / 'td_project'
for run in ('syn_1', 'phy_1'):
    target = prj / (name + '_Runs') / run
    target.mkdir(parents=True)
    for label in ('settings.cfg', 'build.tcl', name + '.prj'):
        shutil.copy2(out / 'reports' / run / label, target / label)
for p in [prj / (name + '.al'), *list((prj / (name + '_Runs')).glob('*/*.prj'))]:
    p.write_text(re.sub(r'(<Project[^>]* Path=")[^"]+', lambda m: m[1] + prj.as_posix(), p.read_text(), count=1))
    for ref in re.findall(r'<File Path="([^"]+)"', p.read_text()):
        q = (p.parent / ref).resolve()
        assert q.is_relative_to(dest) and q.exists(), ref
summary = json.loads((out / 'diagnostic.json').read_text())
bit = out / summary['bit']
assert sha(bit) == summary['sha256']
shutil.copy2(bit, dest / summary['bit'])
shutil.copy2(bit, prj / (name + '_Runs') / 'phy_1' / (name + '.bit'))
shutil.copy2(out / 'README.md', dest / 'README.md')
rollback = engine / 'release/native_1080p30/stage2_base_20261008/rollback.bit'
assert sha(rollback) == 'bb6a71443b74790c64ceec562236799dc5b9418c07f4634c141b4df2a8bb9d65'
shutil.copy2(rollback, dest / 'rollback.bit')
print(json.dumps(dict(bit=(dest / summary['bit']).as_posix(),
    al=(prj / (name + '.al')).as_posix(), sha256=summary['sha256']), indent=2))
