"""Archive a frozen real-PLL run or immutable progress checkpoint, never infer PASS."""
from pathlib import Path
import argparse
import datetime
import hashlib
import json
import re
import zipfile

ap = argparse.ArgumentParser()
ap.add_argument('freeze', type=Path)
ap.add_argument('destination', type=Path)
ap.add_argument('--status', required=True, choices=('RUNNING', 'INTERRUPTED', 'PASS', 'FAIL'))
args = ap.parse_args()
src = args.freeze.resolve()
dst = args.destination.resolve()
if dst.exists():
    raise SystemExit('Refusing existing destination; preserve earlier observations')
meta = json.loads((src / 'freeze.json').read_text(encoding='utf-8'))


def digest(data):
    return hashlib.sha256(data).hexdigest()


def decode(data):
    # Windows PowerShell 5 redirection uses UTF-16; do not rewrite raw evidence.
    return data.decode('utf-16' if data.startswith((b'\xff\xfe', b'\xfe\xff')) else 'utf-8-sig', errors='replace')


inputs = {}
for item in meta['inputs']:
    data = (src / item['path']).read_bytes()
    assert digest(data) == item['sha256'], item['path']
    inputs[item['path']] = data
for item in meta['vendor_models']:
    assert digest(Path(item['path']).read_bytes()) == item['sha256'], item['path']

logs = {p.name: p.read_bytes() for p in sorted((src / 'sim').glob('clock_probe_real.*.log'))}
console = decode(logs['clock_probe_real.console.log'])
observations = [line for line in console.splitlines() if 'OBS F ' in line or 'PASS F ' in line]
pass_marker = 'PASS F real PLL full pins:720p60 to1080p30 to720p60' in console
fatal_or_error = bool(re.search(r'(?m)^#?\s*\*\* (Fatal|Error):', console))
if args.status == 'PASS':
    assert pass_marker and not fatal_or_error, 'Cannot mark incomplete/error run PASS'
    assert 'OBS F actualPLL ratio_samples' in console, 'Missing cadence completion'
elif args.status == 'FAIL':
    assert fatal_or_error, 'FAIL requires a simulator failure, not interruption or missing completion'
else:
    assert not pass_marker and not fatal_or_error, 'Use completed result status'

dst.mkdir(parents=True)
with zipfile.ZipFile(dst / 'inputs.zip', 'w', zipfile.ZIP_DEFLATED) as z:
    for rel, data in inputs.items():
        z.writestr(rel, data)
with zipfile.ZipFile(dst / 'inputs.zip') as z:
    assert set(z.namelist()) == set(inputs)
    for rel, data in inputs.items():
        assert digest(z.read(rel)) == digest(data)
(dst / 'freeze.json').write_bytes((src / 'freeze.json').read_bytes())
for name, data in logs.items():
    (dst / name).write_bytes(data)
if (src / 'interruption.json').exists():
    (dst / 'interruption.json').write_bytes((src / 'interruption.json').read_bytes())
result = dict(
    status=args.status, completed=args.status in ('PASS', 'FAIL'),
    snapshot_time=datetime.datetime.now(datetime.timezone.utc).isoformat(),
    source=str(src), bound_f_bit_sha256=meta['bound_f_bit_sha256'],
    inputs_verified=len(inputs), vendor_models_verified=len(meta['vendor_models']),
    observations=observations, fatal_or_error=fatal_or_error,
    scope='Actual vendor PLL+ODDR, serial pins/reference/full raster/5:1 and mode changes; released F RTL and prior reference unchanged. Simulation only, no new bit or hardware action.',
    limitation='RUNNING/INTERRUPTED snapshots are not a completed frame/switch test. One-second live counts and external analog waveform/camera/DDR are outside this test.'
)
(dst / 'result.json').write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
payloads = []
for p in sorted(dst.rglob('*')):
    if p.is_file():
        payloads.append(f'{digest(p.read_bytes())}  {p.relative_to(dst).as_posix()}')
(dst / 'SHA256SUMS.txt').write_text('\n'.join(payloads) + '\n', encoding='utf-8')
print(json.dumps(dict(status=result['status'], inputs=len(inputs), models=len(meta['vendor_models']), observations=observations[-4:]), ensure_ascii=False))
