"""Bind a reversible private-buffer encoding and independent tests to inputs."""
from pathlib import Path
import argparse
import hashlib
import json
import re
from d3_slot_valid_storage_rewrite import restore

p = argparse.ArgumentParser()
p.add_argument('--baseline', type=Path, required=True)
p.add_argument('--work', type=Path, required=True)
p.add_argument('--checks', type=Path, nargs='+', required=True)
a = p.parse_args()
root = Path(__file__).resolve().parents[1]
sha = lambda path: hashlib.sha256(path.read_bytes()).hexdigest()
load = lambda path: json.loads(path.read_text())
before, after = load(a.baseline / 'frozen_inputs.json'), load(a.work / 'frozen_inputs.json')
target = 'user_source/hdl_source/frame_shape_search.v'
assert len(before) == len(after) == 704
assert {name for name in before if before[name] != after[name]} == {target}
for name, digest in after.items():
    assert sha(a.work / 'project' / name) == digest, name
old_text = (a.baseline / 'project' / target).read_text()
new_text = (a.work / 'project' / target).read_text()
assert before[target] == 'e031d235d78b1bfbd271f33718d064d15c0eeb80f55b3cd6f938dacd358813a4'
assert restore(new_text) == old_text
oracle = root / 'tests/dual_stop_d3/r50_reference_frame_shape_search.sv'
assert oracle.read_text().replace('module r50_reference_frame_shape_search #', 'module frame_shape_search #', 1).replace('r50_reference_empty_gate_trace', 'empty_gate_trace') == old_text
selected, evidence = [], {}
for folder in a.checks:
    receipt = load(folder / 'verification.json')
    assert receipt['status'] == 'PASS'
    for name, digest in receipt['inputs'].items():
        assert after[name] == digest == sha(folder / 'inputs' / Path(name).name), name
    for name, digest in receipt['extra_inputs'].items():
        assert sha(root / 'tests/dual_stop_d3' / Path(name).name) == digest == sha(folder / 'inputs' / Path(name).name), name
    for item in receipt['tests']:
        log = folder / (item['name'] + '.log')
        text = log.read_text(encoding='utf-8-sig')
        assert sha(log) == item['sha256'] and 'PASS ' in text
        assert not re.search(r'\*\* (?:Fatal|Error):|Errors:\s*[1-9]', text)
        selected.append(item['name'])
    evidence[str(folder / 'verification.json')] = sha(folder / 'verification.json')
assert len(selected) == 4 and set(selected) == {'tb_d3_slot_valid_storage', 'tb_d3_slot_valid_pixels', 'tb_d3_pixels', 'tb_d3_rank_pixels'}
result = {'status': 'PASS_SLOT_VALID_PRIVATE_BUFFER_SOURCE_AND_TARGETED_EQUIVALENCE',
          'baseline': str(a.baseline.resolve()), 'before_sha256': before[target], 'after_sha256': after[target],
          'source_manifest_sha256': sha(a.work / 'frozen_inputs.json'), 'unchanged_inputs': 703,
          'restored_normalized_sha256': hashlib.sha256(restore(new_text).encode()).hexdigest(),
          'original_normalized_sha256': hashlib.sha256(old_text.encode()).hexdigest(),
          'oracle_sha256': sha(oracle), 'rewrite_helper_sha256': sha(root / 'scripts/d3_slot_valid_storage_rewrite.py'),
          'selected_tests': selected, 'evidence': evidence,
          'encoding_invariant': 'Each private visible word equals written ? raw_word : 0. Reset/frame clears only written; same prioritized PACK_SCAN writes set the selected word-valid bit and data; duplicate-zero writes preserve visible zero even if unwritten. All other edges hold. This preserves partial/error packets, not just full valid frames.',
          'FSM_cycles_added': 0, 'original_counter_or_IO_or_clocks_or_SDC_or_display_modes_changed': False,
          'production_modified': False, 'complete_software_or_physical_or_hardware_acceptance': False}
(a.work / 'SLOT_VALID_STORAGE_PROOF.json').write_text(json.dumps(result, indent=2) + '\n')
print(result['status'], len(selected), 'targeted tests; 703 other inputs unchanged')
