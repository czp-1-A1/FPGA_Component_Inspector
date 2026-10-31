"""Bind the reversible FSS rewrite and independent tests to exact frozen inputs."""
from pathlib import Path
import argparse
import hashlib
import json
import re
from d3_fss_ref_prepare_rewrite import restore

parser = argparse.ArgumentParser()
parser.add_argument('--baseline', type=Path, required=True)
parser.add_argument('--work', type=Path, required=True)
parser.add_argument('--checks', type=Path, nargs='+', required=True)
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
sha = lambda path: hashlib.sha256(path.read_bytes()).hexdigest()
load = lambda path: json.loads(path.read_text())
before, after = load(args.baseline / 'frozen_inputs.json'), load(args.work / 'frozen_inputs.json')
changed = [name for name in before if before[name] != after[name]]
target = 'user_source/hdl_source/frame_shape_search.v'
assert len(before) == len(after) == 704 and changed == [target]
for name, digest in after.items():
    assert sha(args.work / 'project' / name) == digest
assert before[target] == 'e031d235d78b1bfbd271f33718d064d15c0eeb80f55b3cd6f938dacd358813a4'
original = (args.baseline / 'project' / target).read_text()
candidate = (args.work / 'project' / target).read_text()
assert restore(candidate) == original
oracle = root / 'tests/dual_stop_d3/r50_reference_frame_shape_search.sv'
recovered = oracle.read_text().replace('module r50_reference_frame_shape_search #', 'module frame_shape_search #', 1).replace('r50_reference_empty_gate_trace', 'empty_gate_trace')
assert recovered == original
assert 'REF_WAIT:phase<=REF_CHECK;' in candidate
assert 'if(REVIEW_PROBE)dark_bank[ref_index]<={left_dark[8]' in candidate
assert '(right_dark+dark_word)>=256' in candidate
tests = []
evidence = {}
for folder in args.checks:
    proof = load(folder / 'verification.json')
    assert proof['status'] == 'PASS'
    for name, digest in proof['inputs'].items():
        assert after[name] == digest == sha(folder / 'inputs' / Path(name).name), name
    for name, digest in proof['extra_inputs'].items():
        assert sha(root / 'tests/dual_stop_d3' / Path(name).name) == digest == sha(folder / 'inputs' / Path(name).name), name
    for item in proof['tests']:
        log = folder / (item['name'] + '.log')
        text = log.read_text(encoding='utf-8-sig')
        assert sha(log) == item['sha256'] and 'PASS ' in text
        assert not re.search(r'\*\* (?:Fatal|Error):|Errors:\s*[1-9]', text)
        tests.append(item['name'])
    evidence[str(folder / 'verification.json')] = sha(folder / 'verification.json')
assert len(tests) == 5 and set(tests) == {'tb_d3_fss_ref_math', 'tb_d3_fss_ref_prepare', 'tb_d3_fss_ref_pixels', 'tb_d3_pixels', 'tb_d3_rank_pixels'}
result = {'status': 'PASS_FSS_REFERENCE_PREPARATION_SOURCE_AND_TARGETED_EQUIVALENCE',
          'baseline': str(args.baseline.resolve()), 'changed_files': changed, 'unchanged_inputs': 703,
          'before_sha256': before[target], 'after_sha256': after[target],
          'source_manifest_sha256': sha(args.work / 'frozen_inputs.json'),
          'restored_original_normalized_sha256': hashlib.sha256(restore(candidate).encode()).hexdigest(),
          'original_normalized_sha256': hashlib.sha256(original.encode()).hexdigest(),
          'reference_oracle_sha256': sha(oracle), 'rewrite_helper_sha256': sha(root / 'scripts/d3_fss_ref_prepare_rewrite.py'),
          'selected_tests': tests, 'evidence': evidence,
          'stability_scope': 'Original REF_WAIT case only changes phase. left_dark/right_dark/ref_index/state_bank and constant inspection recipes remain stable until consuming REF_CHECK. Reset/frame_start/invalidate/pixel_sof discard that check; capture priority either stalls with stable operands or leaves the phase. Legal known mask bits give dark_word 0..4.',
          'original_9bit_predicates_and_32bit_diagnostics_preserved': True,
          'added_FSM_cycles': 0, 'production_modified': False,
          'complete_software_or_physical_or_hardware_acceptance': False}
(args.work / 'FSS_REFERENCE_PREPARATION_PROOF.json').write_text(json.dumps(result, indent=2) + '\n')
print(result['status'], len(tests), 'targeted tests; 703 other inputs unchanged')
