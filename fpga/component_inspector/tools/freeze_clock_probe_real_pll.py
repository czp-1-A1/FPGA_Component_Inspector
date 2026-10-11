"""Freeze actual-PLL full F pin test, byte-bound to immutable F release."""
from pathlib import Path
import argparse, hashlib, json, shutil, subprocess, zipfile

engine = Path(__file__).resolve().parents[1]
ap = argparse.ArgumentParser()
ap.add_argument('destination', type=Path)
args = ap.parse_args()
dest = args.destination.resolve()
if dest.exists():
    raise SystemExit('Refusing existing destination')
release = engine / 'release/native_1080p30/clock_probe_diagnostic_20261011'
meta = json.loads((release / 'input_snapshot.json').read_text(encoding='utf-8'))
bit = json.loads((release / 'diagnostic.json').read_text(encoding='utf-8'))

def sha(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()

assert sha(release / bit['bit']) == bit['sha256']
manifest = []
with zipfile.ZipFile(release / 'input_snapshot.zip') as z:
    for e in meta['inputs']:
        rel = e['path']
        if rel.startswith(('diagnostics/', 'user_source/')) or rel in (
            'sim/hdmi_decode.vh', 'sim/clock_probe_reference.vh',
            'sim/clock_probe_font.mem', 'sim/clock_probe_reference.json'):
            data = z.read(rel)
            assert hashlib.sha256(data).hexdigest() == e['sha256']
            p = dest / rel
            p.parent.mkdir(parents=True, exist_ok=True)
            p.write_bytes(data)
            manifest.append(e)
for rel in ('sim/tb_clock_probe_real_pll.v', 'sim/run_clock_probe_real_pll.ps1',
            'tools/freeze_clock_probe_real_pll.py'):
    p = dest / rel
    p.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(engine / rel, p)
    manifest.append(dict(path=rel, sha256=sha(p), bytes=p.stat().st_size))
for e in meta['vendor_models']:
    assert sha(Path(e['path'])) == e['sha256']
(dest / 'freeze.json').write_text(json.dumps(dict(
    head=subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=engine.parents[1], text=True).strip(),
    bound_f_bit_sha256=bit['sha256'],
    purpose='F actual vendor PLL/ODDR full serial720/FHD/720; unchanged released production RTL; startup receiver reset accounting only, same timing/raster/RGB reference. No new bit.',
    inputs=manifest, vendor_models=meta['vendor_models']), indent=2) + '\n', encoding='utf-8')
print(dest)
