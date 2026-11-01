"""Bind the authorized visual change and preserved processing to exact inputs."""
from pathlib import Path
import argparse
import hashlib
import json
import re
from d3_raw_edge_rewrite import FILES, rewrite

p = argparse.ArgumentParser()
p.add_argument('--baseline', type=Path, required=True)
p.add_argument('--work', type=Path, required=True)
p.add_argument('--checks', type=Path, required=True)
a = p.parse_args()
root = Path(__file__).resolve().parents[1]
sha = lambda path: hashlib.sha256(path.read_bytes()).hexdigest()
load = lambda path: json.loads(path.read_text(encoding='utf-8-sig'))
before, after = load(a.baseline/'frozen_inputs.json'), load(a.work/'frozen_inputs.json')
changed = {'user_source/hdl_source/'+name for name in FILES}
assert len(before) == len(after) == 704 and set(before) == set(after)
assert {rel for rel in before if before[rel] != after[rel]} == changed
for rel, digest in after.items():
    assert sha(a.work/'project'/rel) == digest, rel
inverse = {}
for name in FILES:
    rel = 'user_source/hdl_source/'+name
    original = (a.baseline/'project'/rel).read_text()
    assert rewrite(name, (a.work/'project'/rel).read_text(), inverse=True) == original
    inverse[rel] = hashlib.sha256(original.encode()).hexdigest()
oracle = root/'tests/dual_stop_d3/r50_reference_roi_sobel_view.sv'
restored = oracle.read_text().replace('module r50_reference_roi_sobel_view #', 'module roi_sobel_view #', 1)
assert re.sub(r'\breference_process_beat\b', 'process', restored) == (a.baseline/'project/user_source/hdl_source/roi_sobel_view.v').read_text()
receipt = load(a.checks/'verification.json')
assert receipt['status'] == 'PASS'
for rel, digest in receipt['inputs'].items():
    assert after[rel] == digest == sha(a.checks/'inputs'/Path(rel).name)
for rel, digest in receipt['extra_inputs'].items():
    assert sha(root/'tests/dual_stop_d3'/Path(rel).name) == digest == sha(a.checks/'inputs'/Path(rel).name)
required = {'tb_d3_raw_edge_controls', 'tb_d3_pure_edge', 'tb_d3_pure_edge_wide'}
assert {t['name'] for t in receipt['tests']} == required
for t in receipt['tests']:
    log = a.checks/(t['name']+'.log')
    text = log.read_text(encoding='utf-8-sig')
    assert sha(log) == t['sha256'] and 'PASS ' in text
    assert not re.search(r'\*\* (?:Fatal|Error):|Errors:\s*[1-9]', text)
native = (root/'tests/dual_stop_d3/tb_d3_raw_edge_native.sv').read_text()
assert '.RAW_EDGE_ONLY(1)' in native and 'for(integer nf=0;nf<11;nf++)frame(0,nf<5 ? 0:2);' in native
assert 'if(meta[697:689]!=4 || meta[706:698]!=2 || meta[715:707]!=2' in native
assert 'if(meta[953:945]!=4 || meta[962:954]!=2 || meta[971:963]!=2)' in native
assert 'if(event_count[0]!=4 || event_count[1]!=4)' in native
assert "binary_pixels<1000000" in native and 'native edge contains color' in native
result = {'status': 'PASS_RAW_EDGE_DISPLAY_SOURCE_AND_TARGETED_CHECKS',
          'baseline': str(a.baseline.resolve()), 'baseline_manifest_sha256': sha(a.baseline/'frozen_inputs.json'),
          'source_manifest_sha256': sha(a.work/'frozen_inputs.json'), 'changed_inputs': sorted(changed),
          'unchanged_inputs': 700, 'restored_normalized_sha256': inverse,
          'rewrite_helper_sha256': sha(root/'scripts/d3_raw_edge_rewrite.py'),
          'oracle_sha256': sha(oracle), 'targeted_checks': sorted(required),
          'verification_directory': str(a.checks.resolve()), 'verification_sha256': sha(a.checks/'verification.json'),
          'native_fixture_sha256': sha(root/'tests/dual_stop_d3/tb_d3_raw_edge_native.sv'),
          'empty_native_fixture_sha256': sha(root/'tests/dual_stop_d3/tb_d3_raw_edge_empty_native.sv'),
          'authorized_visual_change': 'RAW original pixels / white Sobel edges on black. SW2 selects mode0/2; SW1 ignored. Gray and colored-overlay display modes removed from production configuration.',
          'preserved_behavior': 'All gradient/feature values, fault guards, timing, row replay/credit and original R27B dual counting/parking bodies; 1-second hold, five-empty alarms and motor/keys unchanged. Legacy parameter0 still supports original four modes.',
          'complete_software_or_physical_or_board_acceptance': False, 'production_modified': False}
(a.work/'RAW_EDGE_DISPLAY_PROOF.json').write_text(json.dumps(result, indent=2)+'\n')
print('PASS RAW_EDGE display source +3 targeted tests;700 other frozen inputs unchanged')
