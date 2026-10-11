"""Read-only F archive/ZIP/portable TD/source/simulation-binding verifier."""
from pathlib import Path
import argparse, hashlib, json, re, zipfile

ap = argparse.ArgumentParser()
ap.add_argument('release', type=Path)
ap.add_argument('desktop', type=Path)
args = ap.parse_args()
release, desktop = args.release.resolve(), args.desktop.resolve()

def sha(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()

checked = 0
for line in (release / 'SHA256SUMS.txt').read_text(encoding='utf-8').splitlines():
    digest, rel = line.split('  ', 1)
    p = (release / rel).resolve()
    assert p.is_relative_to(release) and sha(p) == digest, rel
    checked += 1
archives = []
for manifest in release.rglob('input_snapshot.json'):
    data = json.loads(manifest.read_text(encoding='utf-8'))
    with zipfile.ZipFile(manifest.with_suffix('.zip')) as z:
        assert z.testzip() is None
        assert set(z.namelist()) == {e['path'] for e in data['inputs']}
        for e in data['inputs']:
            content = z.read(e['path'])
            assert len(content) == e['bytes'] and hashlib.sha256(content).hexdigest() == e['sha256']
    archives.append(dict(path=manifest.parent.relative_to(release).as_posix(), inputs=len(data['inputs'])))
final = json.loads((release / 'input_snapshot.json').read_text(encoding='utf-8'))
sim = json.loads((release / 'simulation_freeze/input_snapshot.json').read_text(encoding='utf-8'))
build_map, sim_map = ({e['path']: e for e in m['inputs']} for m in (final, sim))
binding = json.loads((release / 'simulation_binding.json').read_text(encoding='utf-8'))
assert len(binding['byte_identical_production_and_test_inputs']) == 17
for e in binding['byte_identical_production_and_test_inputs']:
    assert e == build_map[e['path']] == sim_map[e['path']]
for e in final['inputs']:
    if e['path'].startswith(('diagnostics/', 'user_source/', 'sim/')) or e['path'].endswith('.sdc') or e['path'].endswith('.adc'):
        assert sha(desktop / e['path']) == e['sha256'], e['path']
meta = json.loads((release / 'diagnostic.json').read_text(encoding='utf-8'))
assert meta['physical_acceptance'] == 'NOT_RUN' and meta['all_paths_timing_accepted'] is False
for p in [release / meta['bit'], desktop / meta['bit'], desktop / 'td_project/clock_probe_Runs/phy_1/clock_probe.bit']:
    assert sha(p) == meta['sha256'] and p.stat().st_size == meta['bytes']
assert sha(desktop / 'OLD_user_identified_working.bit') == 'c3a1cce7d4a19d6750c0e6f3e36395a3c2f3d31901834a1b13a76f497a9230f8'
al = (desktop / 'td_project/clock_probe.al').read_text()
refs = re.findall(r'<File Path="([^"]+)"', al)
assert len(refs) == 11 and 'hdmi_ideal_pll' not in al
for ref in refs:
    p = (desktop / 'td_project' / ref).resolve()
    assert p.is_relative_to(desktop) and p.exists(), ref
    rel = p.relative_to(desktop).as_posix()
    assert rel in build_map and sha(p) == build_map[rel]['sha256']
for p in (desktop / 'td_project/clock_probe_Runs').glob('*/*.prj'):
    for ref in re.findall(r'<File Path="([^"]+)"', p.read_text()):
        target = (p.parent / ref).resolve()
        assert target.is_relative_to(desktop) and target.exists()
for item in json.loads((release / 'generated_build_inputs.json').read_text()):
    parts = Path(item['path']).parts
    assert sha(release / 'reports' / parts[-2] / parts[-1]) == item['sha256']
print(json.dumps(dict(status='PASS', payloads=checked, archives=archives, binding_inputs=17,
    portable_al_references=11, bit_sha256=meta['sha256'], physical='NOT_RUN'), indent=2))
