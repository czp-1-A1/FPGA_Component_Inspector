"""Read-only package/SHA/input/portable-AL verification for C diagnostic."""
from pathlib import Path
import argparse,hashlib,json,re,zipfile
engine=Path(__file__).resolve().parents[1]
ap=argparse.ArgumentParser();ap.add_argument('--desktop',type=Path,required=True);args=ap.parse_args()
out=engine/'release/native_1080p30/sync_aligned_diagnostic_20261009';desktop=args.desktop.resolve()
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
payload=0
for line in (out/'SHA256SUMS.txt').read_text().splitlines():
 expected,rel=line.split('  ',1);p=(out/rel).resolve()
 assert p.is_relative_to(out.resolve()) and sha(p)==expected,rel;payload+=1
count=0;metadata=[]
for directory,n in [(out,15),(out/'legacy_a_negative',15),(out/'vendor_avi_observation',8)]:
 meta=json.loads((directory/'input_snapshot.json').read_text(encoding='utf-8-sig'))
 assert len(meta['inputs'])==n
 with zipfile.ZipFile(directory/'input_snapshot.zip') as z:
  assert set(z.namelist())==set(e['path'] for e in meta['inputs'])
  for e in meta['inputs']:
   data=z.read(e['path']);assert hashlib.sha256(data).hexdigest()==e['sha256'],e['path']
   count+=1
 metadata.append(meta)
c,neg,avi=metadata
for e in c['inputs']:
 if not e['path'].endswith('.al'):
  assert next(n for n in neg['inputs'] if n['path']==e['path'])['sha256']==e['sha256'],e['path']
summary=json.loads((out/'diagnostic.json').read_text())
assert sha(out/summary['bit'])==summary['sha256']==sha(desktop/summary['bit'])
assert (out/summary['bit']).stat().st_size==summary['bytes']
name=c['project'];prj=desktop/'td_project'
al=(prj/(name+'.al')).read_text()
assert name+'_top' in al and 'native_hdmi_pll.v' in al and 'hdmi_ideal_pll' not in al
refs=re.findall(r'<File Path="([^"]+)"',al);assert len(refs)==9
for r in refs:
 p=(prj/r).resolve();assert p.is_relative_to(desktop) and p.exists(),r
for e in c['inputs']:
 if not e['path'].endswith('.al'):assert sha(desktop/e['path'])==e['sha256'],e['path']
for e in json.loads((out/'generated_build_inputs.json').read_text()):
 p=desktop/e['path']
 report=out/'reports'/p.parent.name/p.name
 assert sha(report)==e['sha256'],e['path']
 if p.suffix=='.prj':
  text=p.read_text();assert name+'_top' in text
  for r in re.findall(r'<File Path="([^"]+)"',text):
   q=(p.parent/r).resolve();assert q.is_relative_to(desktop) and q.exists()
 else:assert sha(p)==e['sha256'],e['path']
assert sha(prj/(name+'_Runs')/'phy_1'/(name+'.bit'))==summary['sha256']
assert sha(desktop/'rollback.bit')=='bb6a71443b74790c64ceec562236799dc5b9418c07f4634c141b4df2a8bb9d65'
positive=(out/'simulation/aligned_pins.console.log').read_text(errors='replace')
assert 'PASS aligned pin frame: words2475000 pixels2073600 lines1080' in positive
negative=(out/'legacy_a_negative/simulation/legacy_negative.console.log').read_text(errors='replace')
assert '** Fatal: VS leading edge does not coincide with HS leading edge' in negative
assert 'PASS aligned pin frame:' not in negative
observation=(out/'vendor_avi_observation/simulation/avi.console.log').read_text(errors='replace')
assert 'PASS AVI actual encrypted core:' in observation
assert summary['physical_acceptance']=='NOT_RUN' and not summary['all_paths_timing_accepted']
assert summary['setup_tns_ns']==summary['hold_tns_ns']==summary['violating_endpoints']==0
final=(out/'reports/phy_1/final_timing.rpt').read_text()
assert float(re.search(r'SWNS:\s*([\d.-]+)ns',final)[1])==summary['setup_wns_ns']
assert float(re.search(r'HWNS:\s*([\d.-]+)ns',final)[1])==summary['hold_wns_ns']
print(f'PASS C release: {payload} payload files, {count} frozen input entries, bit/Desktop/phy_1 SHA, native PLL portable AL, build files, logs and rollback.')
