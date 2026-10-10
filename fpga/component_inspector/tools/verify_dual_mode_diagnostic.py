"""Read-only SHA/freeze/log/portable-AL checks for the E diagnostic."""
from pathlib import Path
import argparse, hashlib, json, re, zipfile
engine = Path(__file__).resolve().parents[1]
ap = argparse.ArgumentParser()
ap.add_argument('--desktop', type=Path, required=True)
args = ap.parse_args()
out = engine / 'release/native_1080p30/dual_mode_diagnostic_20261010'
desktop = args.desktop.resolve()
def sha(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()
payload = 0
for line in (out / 'SHA256SUMS.txt').read_text().splitlines():
    expected, rel = line.split('  ', 1)
    p = (out / rel).resolve()
    assert p.is_relative_to(out.resolve()) and sha(p) == expected, rel
    payload += 1
meta = json.loads((out / 'input_snapshot.json').read_text(encoding='utf-8-sig'))
assert len(meta['inputs']) == 14 and len(meta['vendor_models']) == 9
with zipfile.ZipFile(out / 'input_snapshot.zip') as z:
    assert set(z.namelist()) == set(e['path'] for e in meta['inputs'])
    for e in meta['inputs']:
        assert hashlib.sha256(z.read(e['path'])).hexdigest() == e['sha256'], e['path']
for e in meta['vendor_models']:
    assert sha(Path(e['path'])) == e['sha256'], e['path']
summary = json.loads((out / 'diagnostic.json').read_text())
assert sha(out / summary['bit']) == summary['sha256'] == sha(desktop / summary['bit'])
assert (out / summary['bit']).stat().st_size == summary['bytes']
name = meta['project']
prj = desktop / 'td_project'
al = (prj / (name + '.al')).read_text()
assert name + '_top' in al and 'native_hdmi_pll.v' in al and 'hdmi_ideal_pll' not in al
refs = re.findall(r'<File Path="([^"]+)"', al)
assert len(refs) == 8
for r in refs:
    p = (prj / r).resolve()
    assert p.is_relative_to(desktop) and p.exists(), r
for e in meta['inputs']:
    if not e['path'].endswith('.al'):
        assert sha(desktop / e['path']) == e['sha256'], e['path']
derived = json.loads((out / 'generated_build_inputs.json').read_text())
assert len(derived) == 6
for e in derived:
    p = desktop / e['path']
    report = out / 'reports' / p.parent.name / p.name
    assert sha(report) == e['sha256'], e['path']
    if p.suffix == '.prj':
        text = p.read_text()
        assert name + '_top' in text
        for r in re.findall(r'<File Path="([^"]+)"', text):
            q = (p.parent / r).resolve()
            assert q.is_relative_to(desktop) and q.exists()
    else:
        assert sha(p) == e['sha256'], e['path']
assert sha(prj / (name + '_Runs') / 'phy_1' / (name + '.bit')) == summary['sha256']
assert sha(desktop / 'rollback.bit') == 'bb6a71443b74790c64ceec562236799dc5b9418c07f4634c141b4df2a8bb9d65'
log = (out / 'simulation/dual_pins.console.log').read_text(errors='replace')
assert 'PASS E dual-mode pins:720p60 to1080p30 to720p60' in log and '** Fatal:' not in log and '** Error:' not in log
assert summary['simulated_transitions'] == 2 and summary['simulated_complete_hd_frames'] >= 2 and summary['simulated_complete_fhd_frames'] >= 2
assert summary['physical_acceptance'] == 'NOT_RUN' and not summary['all_paths_timing_accepted']
assert summary['setup_tns_ns'] == summary['hold_tns_ns'] == summary['violating_endpoints'] == 0
final = (out / 'reports/phy_1/final_timing.rpt').read_text()
assert float(re.search(r'SWNS:\s*([\d.-]+)ns', final)[1]) == summary['setup_wns_ns']
assert float(re.search(r'HWNS:\s*([\d.-]+)ns', final)[1]) == summary['hold_wns_ns']
audit = json.loads((out / 'constraint_audit.json').read_text())
assert audit['status'] == 'INTERNAL_TIMING_PASS_EXTERNAL_BUDGETS_OPEN' and len(audit['warnings']) == 3
assert audit['mode_synchronizer']['actual_data_path_ns'] == 0.307
assert audit['full_real_pll_switch_simulation'] == 'NOT_RUN'
for r in summary['resources'].values():
    assert r['used'] <= r['capacity']
print(f'PASS E release: {payload} payloads,14 frozen inputs/9 vendor models/6 build inputs, bit/Desktop/phy_1 SHA, native PLL portable AL, logs and rollback.')
