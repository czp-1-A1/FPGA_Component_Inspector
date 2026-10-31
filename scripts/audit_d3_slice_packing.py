"""Reconcile physical Slice contents and rank register-only logical families."""
from pathlib import Path
import argparse
import collections
import csv
import hashlib
import json
import math
import re

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def clean_net(expr):
    return re.sub(r'\s+', '', expr.strip().lstrip('\\'))

def family(expr):
    return re.sub(r'(?:\[[^\]]+\])+$', '', clean_net(expr))

def owner(expr):
    name = clean_net(expr)
    if 'local_shape_detection$detector/' in name:
        tail = name.split('local_shape_detection$detector/', 1)[1]
        return 'FSS/' + (tail.split('/')[0] if '/' in tail else 'main')
    if 'observe_counter$counter/' in name:
        match = re.search(r'regions\[(\d+)\]', name)
        return 'count_observer/lane' + (match[1] if match else '?')
    if 'dual_parking$parking/' in name:
        tail = name.split('dual_parking$parking/', 1)[1]
        return 'parking/' + (tail.split('/')[0] if '/' in tail else 'main')
    return name.split('/')[0]

def parse_cells(path):
    text = re.sub(r'/\*.*?\*/|//[^\n]*', '', path.read_text(), flags=re.S)
    pattern = re.compile(r'^\s*(PH1P_\w+)\s*(?:#\((.*?)\)\s*)?(\\\S+|\w+)\s*\((.*?)\)\s*$', re.S)
    cells = []
    for statement in text.split(';'):
        match = pattern.search(statement)
        if match:
            params = dict(re.findall(r'\.(\w+)\(([^()]*)\)', match[2] or ''))
            ports = dict(re.findall(r'\.(\w+)\(([^()]*)\)', match[4]))
            cells.append({'kind': match[1], 'name': match[3], 'parameters': params, 'ports': ports})
        elif re.match(r'^\s*PH1P_\w+(?:\s|#)', statement) and 'module' not in statement:
            raise AssertionError('Unparsed physical primitive: ' + statement[:160])
    return cells

def audit(folder):
    receipt = json.loads((folder / 'EXPORT_RECEIPT.json').read_text())
    assert receipt['status'] == 'READ_ONLY_SAVED_PLACEMENT_EXPORTED_NOT_NEW_IMPLEMENTATION'
    assert receipt['placement_database_before_sha256'] == receipt['placement_database_after_sha256']
    for name, digest in receipt['files_sha256'].items():
        assert sha(folder / name) == digest, name
    cells = parse_cells(folder / 'placed_netlist.v')
    slices = [c for c in cells if c['kind'] in ['PH1P_PHY_LSLICE', 'PH1P_PHY_MSLICE']]
    area = (folder / 'imported.area').read_text()
    number = lambda key: int(re.search(r'(?m)^\s*#' + re.escape(key) + r'\s+(\d+)', area)[1])
    assert len(slices) == number('slice')
    assert sum('LUTMODE' in c['parameters'] for c in slices) == number('lut6')
    assert sum(c['kind'] == 'PH1P_PHY_MSLICE' for c in slices) == number('used ram')
    totals = collections.Counter()
    families = collections.defaultdict(collections.Counter)
    owners = collections.defaultdict(collections.Counter)
    classes = collections.defaultdict(collections.Counter)
    pure_slice_owners = collections.Counter()
    reg_rows, all_regs, control_groups = [], [], collections.defaultdict(collections.Counter)
    for cell in slices:
        ps, pts = cell['parameters'], cell['ports']
        category = 'distributed_ram' if cell['kind'] == 'PH1P_PHY_MSLICE' else 'logic_or_carry' if 'LUTMODE' in ps else 'register_only'
        totals[category + '_slices'] += 1
        registers = []
        for side in ['A', 'B']:
            q = pts.get('oq' + side.lower(), '').strip()
            # Some TD cells retain QA/QB configuration for unused outputs.
            # Require the actual connected Q pin; this reconciles exact FF count.
            if ps.get('OQ' + side + 'MUX') != '"Q' + side + '"' or not q or q.startswith('open_'):
                continue
            name = family(q)
            ce_mode = ps.get('CE' + side + 'MUX', '"0"').strip('"')
            ce = clean_net(pts.get('ce' + side.lower(), '')) if ce_mode == 'SIG' else ce_mode
            common_control = (ps.get('CLKMUX', '"0"'), clean_net(pts.get('clk', "1'b0")),
                              ps.get('ASRMUX', '"1"'), clean_net(pts.get('asr', "1'b1")),
                              ps.get('SSRMUX', '"1"'), clean_net(pts.get('ssr', "1'b1")),
                              ps.get('LATCHMODE', '"DFF"'))
            reg = {'slice': cell['name'], 'side': side, 'q_raw': q, 'q': clean_net(q),
                   'family': name, 'owner': owner(q), 'category': category,
                   'clock': clean_net(pts.get('clk', "1'b0")), 'clock_mux': ps.get('CLKMUX', '"0"'),
                   'ce_mode': ce_mode, 'ce': ce,
                   'asr_mux': ps.get('ASRMUX', '"1"'), 'asr': clean_net(pts.get('asr', "1'b1")),
                   'ssr_mux': ps.get('SSRMUX', '"1"'), 'ssr': clean_net(pts.get('ssr', "1'b1")),
                   'data_mux': ps.get('REG' + side + '_SD', '"OFA"' if side == 'A' else '"SUM"'),
                   'data': clean_net(pts.get('im' + side.lower(), ''))}
            registers.append(reg)
            all_regs.append(reg)
            totals['registers'] += 1
            families[name]['total_ff'] += 1
            families[name][category + '_ff'] += 1
            owners[reg['owner']]['total_ff'] += 1
            owners[reg['owner']][category + '_ff'] += 1
            classes[category]['ff'] += 1
            classes[category]['ce_' + ce_mode] += 1
            control_groups[common_control]['total_ff'] += 1
            control_groups[common_control][category + '_ff'] += 1
        totals[category + '_' + str(len(registers)) + 'ff_slices'] += 1
        if category == 'register_only':
            assert registers, cell['name']
            own = {r['owner'] for r in registers}
            pure_slice_owners[next(iter(own)) if len(own) == 1 else 'MIXED'] += 1
            row = {'slice': cell['name'], 'ff_count': len(registers)}
            for reg in registers:
                for key, value in reg.items():
                    if key not in ['slice', 'side']:
                        row[reg['side'] + '_' + key] = value
            reg_rows.append(row)
    assert totals['registers'] == number('slice reg')
    assert totals['register_only_slices'] == number('reg only')
    assert totals['logic_or_carry_slices'] == number('with luts') + number('with adder')
    # CE and data pins are independent A/B inputs; grouping here describes
    # physical sharing, not a complete legal-packing compatibility predicate.
    def write_csv(path, rows):
        keys = list(dict.fromkeys(key for row in rows for key in row))
        with path.open('w', newline='', encoding='utf-8-sig') as output:
            writer = csv.DictWriter(output, fieldnames=keys)
            writer.writeheader()
            writer.writerows(rows)
    ordered_families = sorted(({'family': name, **dict(counts)} for name, counts in families.items()), key=lambda row: (-row.get('register_only_ff', 0), -row['total_ff'], row['family']))
    ordered_owners = sorted(({'owner': name, **dict(counts)} for name, counts in owners.items()), key=lambda row: -row.get('register_only_ff', 0))
    controls = [{'clock_mux': key[0], 'clock': key[1], 'asr_mux': key[2], 'asr': key[3],
                 'ssr_mux': key[4], 'ssr': key[5], 'latchmode': key[6], **dict(counts)}
                for key, counts in control_groups.items()]
    controls.sort(key=lambda row: -row.get('register_only_ff', 0))
    write_csv(folder / 'register_only_slices.csv', reg_rows)
    write_csv(folder / 'register_families.csv', ordered_families)
    write_csv(folder / 'shared_control_groups.csv', controls)
    write_csv(folder / 'all_slice_registers.csv', all_regs)
    result = {'status': 'PASS_ACTUAL_SAVED_SLICE_AND_REGISTER_COUNT_RECONCILIATION',
              'export_directory': str(folder), 'input_receipt_sha256': sha(folder / 'EXPORT_RECEIPT.json'),
              'placed_netlist_sha256': sha(folder / 'placed_netlist.v'), 'area_sha256': sha(folder / 'imported.area'),
              'totals': dict(totals), 'classes': {name: dict(counts) for name, counts in classes.items()},
              'register_only_pure_owner_slice_counts': dict(pure_slice_owners),
              'top_register_only_families': ordered_families[:40], 'owners': ordered_owners,
              'top_shared_control_groups': controls[:20],
              'register_only_pairing_capacity_upper_bound_slices': totals['register_only_slices'] - math.ceil(classes['register_only']['ff'] / 2),
              'scope': 'Each physical LSLICE/MSLICE instance is one packed Slice. Actual connected QA/QB pins reconcile FF count; absent LUTMODE matches register-only area. Logical family/owner from Q net is representative, not RTL-exclusive ownership. No X/Y location or complete legal packing compatibility claimed.',
              'CE_interpretation': 'CEAMUX/CEBMUX 1 means always enabled; SIG means pin controlled. A/B CE and data muxes are independent. Shared clock/ASR/SSR tuple is descriptive; tool internal Control Set counts are a different definition.',
              'files_sha256': {name: sha(folder / name) for name in ['register_only_slices.csv', 'register_families.csv', 'shared_control_groups.csv', 'all_slice_registers.csv']},
              'optimization_or_hardware_action': False}
    (folder / 'SLICE_PACKING_AUDIT.json').write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps({'directory': str(folder), 'totals': result['totals'],
                      'pairing_upper_bound': result['register_only_pairing_capacity_upper_bound_slices'],
                      'top_families': ordered_families[:10]}, indent=2))
    return result

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--export', type=Path, required=True)
    args = parser.parse_args()
    audit(args.export.resolve())
