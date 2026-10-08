"""Verify diagnostic payloads, frozen inputs and optional desktop AL/bit."""
from pathlib import Path
import argparse,hashlib,json,re,zipfile
engine=Path(__file__).resolve().parents[1]
ap=argparse.ArgumentParser();ap.add_argument('--desktop',type=Path);args=ap.parse_args()
root=engine/'release/native_1080p30/hdmi_tpg_diagnostic_20261008'
def sha(data):return hashlib.sha256(data).hexdigest()
count=0
for line in (root/'SHA256SUMS.txt').read_text().splitlines():
 expected,name=line.split('  ',1);assert sha((root/name).read_bytes())==expected,name;count+=1
meta=json.loads((root/'input_snapshot.json').read_text())
with zipfile.ZipFile(root/'input_snapshot.zip') as z:
 for e in meta['inputs']:assert sha(z.read(e['path']))==e['sha256'],e['path']
 al=z.read('td_project/hdmi_tpg.al').decode()
 assert 'native_hdmi_pll.v' in al and 'hdmi_ideal_pll.v' not in al
 if args.desktop:
  folder=args.desktop.resolve();al_path=folder/'td_project/hdmi_tpg.al'
  for name in re.findall(r'<File Path="([^"]+)"',al_path.read_text()):
   target=(al_path.parent/name).resolve();assert target.is_relative_to(folder) and target.is_file(),name
  for e in meta['inputs']:
   if e['path']!='td_project/hdmi_tpg.al':assert sha((folder/e['path']).read_bytes())==e['sha256']
  assert sha((folder/'hdmi_tpg.bit').read_bytes())==sha((root/'hdmi_tpg.bit').read_bytes())
assert sha((root/'hdmi_tpg.bit').read_bytes())=='8d0098b11012e22f8ae9eae329106534e1060505f24e88658749504a681836a0'
print(f'PASS diagnostic integrity: {count} payload files, {len(meta["inputs"])} frozen inputs; native PLL selected for synthesis')
