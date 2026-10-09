"""Archive unchanged frozen phase-probe inputs/logs, including failures."""
from pathlib import Path
import argparse,hashlib,json,shutil,zipfile
ap=argparse.ArgumentParser();ap.add_argument('freeze',type=Path);ap.add_argument('output',type=Path);args=ap.parse_args()
root=args.freeze.resolve();out=args.output.resolve()
if out.exists():raise SystemExit('Refusing existing evidence output')
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
meta=json.loads((root/'freeze.json').read_text())
for e in meta['inputs']:assert sha(root/e['path'])==e['sha256'],e['path']
for e in meta['vendor_models']:assert sha(Path(e['path']))==e['sha256'],e['path']
log=(root/'sim/native_pins.console.log').read_text(errors='replace')
status='PASS' if 'PASS native PLL pins:16' in log and '** Fatal:' not in log and '** Error:' not in log else 'FAIL'
assert 'End time:' in log,'Simulation still running or missing completion'
out.mkdir(parents=True)
shutil.copy2(root/'freeze.json',out/'input_snapshot.json')
with zipfile.ZipFile(out/'input_snapshot.zip','w',zipfile.ZIP_DEFLATED) as z:
 for e in meta['inputs']:z.write(root/e['path'],e['path'])
for p in (root/'sim').glob('*.log'):shutil.copy2(p,out/p.name)
(out/'result.json').write_text(json.dumps(dict(status=status,source_freeze=root.name,
 scope='Vendor PLL/ODDR startup and16 early complete RGB rows; full-frame/AVI/VS/analog quality not proven',
 bound_d_bit_sha256=meta['bound_d_bit_sha256'],production_rtl_changed=False,
 physical_acceptance='FAILED_HDMI_INPUT_UNSUPPORTED_USER_CONFIRMED'),indent=2)+'\n')
(out/'SHA256SUMS.txt').write_text(''.join(sha(p)+'  '+p.name+'\n' for p in sorted(out.iterdir()) if p.is_file()))
print(status,out)
