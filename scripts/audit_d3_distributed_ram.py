"""Read existing placed netlist only; account for actual distributed-RAM Slices."""
from pathlib import Path
import argparse
import collections
import json
import re

from audit_d3_slice_packing import parse_cells, sha

p = argparse.ArgumentParser()
p.add_argument('--export', type=Path, required=True)
p.add_argument('--out', type=Path, required=True)
a = p.parse_args()
folder = a.export.resolve()
receipt = json.loads((folder / 'EXPORT_RECEIPT.json').read_text())
assert receipt['status'] == 'READ_ONLY_SAVED_PLACEMENT_EXPORTED_NOT_NEW_IMPLEMENTATION'
assert receipt['placement_database_before_sha256'] == receipt['placement_database_after_sha256']
for name, digest in receipt['files_sha256'].items():
    assert sha(folder / name) == digest, name
cells = [c for c in parse_cells(folder / 'placed_netlist.v') if c['kind'] == 'PH1P_PHY_MSLICE']
area = (folder / 'imported.area').read_text()
assert len(cells) == int(re.search(r'(?m)^\s*#used ram\s+(\d+)', area)[1])
groups = collections.defaultdict(list)
for c in cells:
    assert c['parameters']['RAMMODE'] == '"DPRAM"'
    hierarchy = c['name'].lstrip('\\').rsplit('/', 1)[0]
    address = tuple(c['ports'].get(n, '') for n in ['ia', 'ib', 'ic', 'id', 'ie', 'imf'])
    groups[(hierarchy, address)].append(c)
rows = []
for (hierarchy, address), members in sorted(groups.items()):
    rows.append({'hierarchy': hierarchy, 'slice_count': len(members),
                 'vendor_ddr': hierarchy.startswith('u_ph1p35_324_ddr_wrapper/'),
                 'read_address_pins': dict(zip(['ia', 'ib', 'ic', 'id', 'ie', 'imf'], address)),
                 'sample_cells': [c['name'] for c in members[:2]],
                 'sample_outputs': [{k: v for k, v in c['ports'].items() if k in ['ofa', 'ofb', 'oqa', 'oqb']} for c in members[:2]]})
vendor = sum(row['slice_count'] for row in rows if row['vendor_ddr'])
result = {'status': 'READ_ONLY_BASELINE_DISTRIBUTED_RAM_ACCOUNTING_NOT_OPTIMIZATION',
          'placement_database_sha256': receipt['placement_database_before_sha256'],
          'placed_netlist_sha256': sha(folder / 'placed_netlist.v'),
          'export_receipt_sha256': sha(folder / 'EXPORT_RECEIPT.json'),
          'script_sha256': sha(Path(__file__)), 'total_slices': len(cells),
          'vendor_ddr_slices': vendor, 'application_slices': len(cells) - vendor,
          'groups': rows,
          'scope': 'Actual primitive count and read-pin grouping. Output/register pins can be shared with other logic. No exclusive reclaimable-Slice estimate, ERAM-port equivalence, full schematic reconstruction, new physical experiment, or hardware acceptance.'}
a.out.write_text(json.dumps(result, indent=2) + '\n')
print(json.dumps({k: result[k] for k in ['status', 'total_slices', 'vendor_ddr_slices', 'application_slices']}))
