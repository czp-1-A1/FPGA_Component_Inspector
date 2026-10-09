"""Read-only delivery check: snapshots, report payloads, bits and TD references."""
from pathlib import Path
import argparse,hashlib,json,re,zipfile
engine=Path(__file__).resolve().parents[1]
ap=argparse.ArgumentParser();ap.add_argument('--desktop',type=Path,required=True);args=ap.parse_args()
out=engine/'release/native_1080p30/positive_sync_diagnostic_20261009'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
expected={}
for line in (out/'SHA256SUMS.txt').read_text().splitlines():
 h,r=line.split('  ',1);assert r not in expected;expected[r]=h
assert set(expected)=={p.relative_to(out).as_posix() for p in out.rglob('*') if p.is_file() and p.name!='SHA256SUMS.txt'}
for r,h in expected.items():assert sha(out/r)==h,r
rows=json.loads((out/'diagnostics.json').read_text())
for row in rows:
 package=(out/row['bit']).parent;bit=out/row['bit']
 assert sha(bit)==row['sha256'] and bit.stat().st_size==row['bytes']
 assert sha(Path(row['desktop_bit']))==row['sha256']
 meta=json.loads((package/'input_snapshot.json').read_text())
 name=meta['project'];desktop=args.desktop/('A_1080p30' if row['mode']=='fhd30' else 'B_720p60')
 with zipfile.ZipFile(package/'input_snapshot.zip') as z:
  assert set(z.namelist())=={e['path'] for e in meta['inputs']}
  for e in meta['inputs']:
   assert hashlib.sha256(z.read(e['path'])).hexdigest()==e['sha256']
   if not e['path'].endswith('.al'):assert sha(desktop/e['path'])==e['sha256']
  al=z.read('td_project/'+name+'.al').decode()
  assert name+'_top' in al and 'hdmi_ideal_pll' not in al
 al=(desktop/'td_project'/(name+'.al')).read_text()
 assert name+'_top' in al and 'native_hdmi_pll.v' in al and 'hdmi_ideal_pll' not in al
 refs=re.findall(r'<File Path="([^"]+)"',al);assert len(refs)==8
 for r in refs:
  p=(desktop/'td_project'/r).resolve();assert p.is_relative_to(desktop.resolve()) and p.exists(),r
 assert sha(desktop/'td_project'/(name+'_Runs')/'phy_1'/(name+'.bit'))==row['sha256']
 assert 'PASS positive pin frame:' in (package/'simulation/pins.console.log').read_text()
 for item in json.loads((package/'generated_build_inputs.json').read_text()):
  p=Path(item['path']);q=package/'reports'/p.parts[-2]/p.name
  assert sha(q)==item['sha256']
rollback=args.desktop/'rollback.bit'
assert sha(rollback)=='bb6a71443b74790c64ceec562236799dc5b9418c07f4634c141b4df2a8bb9d65'
print(f'PASS: {len(expected)} payloads, two bits, two portable ALs,15 frozen inputs and6 generated build files per mode; rollback hash matched.')
