"""Explain actual FF/LUT sharing changes between two exported placements."""
from pathlib import Path
import argparse
import collections
import csv
import hashlib
import json

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def load(folder):
    audit = json.loads((folder / 'SLICE_PACKING_AUDIT.json').read_text())
    assert audit['status'] == 'PASS_ACTUAL_SAVED_SLICE_AND_REGISTER_COUNT_RECONCILIATION'
    for name, digest in audit['files_sha256'].items():
        assert sha(folder / name) == digest
    with (folder / 'all_slice_registers.csv').open(encoding='utf-8-sig') as handle:
        rows = list(csv.DictReader(handle))
    by_q = {row['q']: row for row in rows}
    assert len(by_q) == len(rows) == audit['totals']['registers']
    return audit, by_q

parser = argparse.ArgumentParser()
parser.add_argument('--reference', type=Path, required=True)
parser.add_argument('--candidate', type=Path, required=True)
parser.add_argument('--out', type=Path, required=True)
args = parser.parse_args()
before, old = load(args.reference)
after, new = load(args.candidate)
shared = set(old) & set(new)
into = [q for q in shared if old[q]['category'] != 'register_only' and new[q]['category'] == 'register_only']
away = [q for q in shared if old[q]['category'] == 'register_only' and new[q]['category'] != 'register_only']
old_only = set(old) - shared
new_only = set(new) - shared
assert len(into) - len(away) + sum(new[q]['category'] == 'register_only' for q in new_only) - sum(old[q]['category'] == 'register_only' for q in old_only) == after['classes']['register_only']['ff'] - before['classes']['register_only']['ff']
families = collections.defaultdict(collections.Counter)
for q, row in old.items():
    families[row['family']]['before_total_ff'] += 1
    families[row['family']]['before_register_only_ff'] += row['category'] == 'register_only'
for q, row in new.items():
    families[row['family']]['after_total_ff'] += 1
    families[row['family']]['after_register_only_ff'] += row['category'] == 'register_only'
changes = []
for name, counts in families.items():
    change = counts['after_register_only_ff'] - counts['before_register_only_ff']
    if change:
        changes.append({'family': name, **dict(counts), 'register_only_ff_delta': change,
                        'total_ff_delta': counts['after_total_ff'] - counts['before_total_ff']})
changes.sort(key=lambda row: -row['register_only_ff_delta'])
cache = [row for row in new.values() if 'reference_bad_choices[' in row['q']]
assert len(cache) == 5 and all(row['category'] == 'logic_or_carry' and row['ce_mode'] == '1' for row in cache)
result = {'status': 'PASS_RECONCILED_PHYSICAL_REGISTER_SHARING_COMPARISON',
          'reference': str(args.reference.resolve()), 'candidate': str(args.candidate.resolve()),
          'reference_audit_sha256': sha(args.reference / 'SLICE_PACKING_AUDIT.json'),
          'candidate_audit_sha256': sha(args.candidate / 'SLICE_PACKING_AUDIT.json'),
          'before_totals': before['totals'], 'after_totals': after['totals'],
          'same_named_Q_bits': len(shared), 'reference_only_Q_names': len(old_only), 'candidate_only_Q_names': len(new_only),
          'same_named_FF_into_register_only': len(into), 'same_named_FF_out_of_register_only': len(away),
          'reference_only_register_only_ff': sum(old[q]['category'] == 'register_only' for q in old_only),
          'candidate_only_register_only_ff': sum(new[q]['category'] == 'register_only' for q in new_only),
          'new_preparation_FF_all_LUT_shared_and_CE1': cache,
          'largest_register_only_ff_increases': changes[:25],
          'largest_register_only_ff_decreases': sorted(changes, key=lambda row: row['register_only_ff_delta'])[:25],
          'reference_pairing_only_capacity_upper_bound_slices': before['register_only_pairing_capacity_upper_bound_slices'],
          'scope': 'Actual packed Slice/Q contents, string-corresponding Q nets and exact aggregate reconciliation. Not a sequential netlist equivalence proof or a legal repacking/timing guarantee.',
          'RTL_or_SDC_or_implementation_changed': False}
args.out.write_text(json.dumps(result, indent=2) + '\n')
print(json.dumps({key: result[key] for key in ['status', 'same_named_Q_bits', 'same_named_FF_into_register_only', 'same_named_FF_out_of_register_only', 'reference_pairing_only_capacity_upper_bound_slices']}))
