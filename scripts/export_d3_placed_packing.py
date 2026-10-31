"""Read a saved placed DB and export packing evidence; never optimize or program."""
from pathlib import Path
import argparse
import csv
import hashlib
import io
import json
import os
import re
import subprocess
import time

parser = argparse.ArgumentParser()
parser.add_argument('--work', type=Path, required=True)
parser.add_argument('--out', type=Path, required=True)
args = parser.parse_args()
w, out = args.work.resolve(), args.out.resolve()
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
load = lambda p: json.loads(p.read_text())
assert not out.exists()
receipt = load(w / 'PLACEMENT_RESULT.json')
assert receipt['status'] == 'PLACED_ONLY_NOT_ROUTED_NOT_DELIVERABLE'
db = w / 'runs/phy_1/camera_to_dsi_display_place.db'
before = sha(db)
assert before == receipt['placement_database_sha256']
source = load(w / 'frozen_inputs.json')
assert len(source) == 704
for name, digest in source.items():
    assert sha(w / 'project' / name) == digest, name
tasks = subprocess.run(['tasklist', '/fi', 'IMAGENAME eq td_commands_prompt.exe', '/fo', 'csv'], capture_output=True, check=True).stdout.decode('utf8', errors='replace')
assert not any(row and row[0].lower() == 'td_commands_prompt.exe' for row in csv.reader(io.StringIO(tasks)))
out.mkdir(parents=True)
(out / 'temp').mkdir()
script = out / 'export.tcl'
script.write_text('''if {[catch {
import_device ph1_35p.db -package PH1P35MDG324 -speed 3
cd {RUN}
open_project camera_to_dsi_display.prj -noanalyze
import_db camera_to_dsi_display_place.db
set cells [get_cells *]
puts "AUDIT_ALL_CELL_COUNT [llength $cells]"
write_verilog {OUT/placed_netlist.v}
report_area -io_info -file {OUT/imported.area}
puts "PASS READ_ONLY_PLACED_PACKING_EXPORT"
} reason]} {puts stderr $reason; exit 1}
exit 0
'''.replace('RUN', (w / 'runs/phy_1').as_posix()).replace('OUT', out.as_posix()))
env = dict(os.environ)
env['TEMP'] = env['TMP'] = str(out / 'temp')
started = time.monotonic()
with (out / 'export.log').open('w') as log:
    process = subprocess.run(['E:/TD/bin/td_commands_prompt.exe'], input='source {' + script.as_posix() + '}\n', text=True, cwd=out, env=env, stdout=log, stderr=subprocess.STDOUT, timeout=180)
assert sha(db) == before, 'Input placement DB changed'
text = (out / 'export.log').read_text(errors='replace')
assert process.returncode == 0 and 'PASS READ_ONLY_PLACED_PACKING_EXPORT' in text
assert not re.search(r'(?mi)^\s*(?:ERROR|\w+-\d+\s*:\s*Error)', text)
assert (out / 'placed_netlist.v').is_file() and (out / 'imported.area').is_file()
result = {'status': 'READ_ONLY_SAVED_PLACEMENT_EXPORTED_NOT_NEW_IMPLEMENTATION',
          'work': str(w), 'seconds': round(time.monotonic() - started, 1),
          'placement_database_before_sha256': before, 'placement_database_after_sha256': sha(db),
          'source_manifest_sha256': sha(w / 'frozen_inputs.json'),
          'placement_receipt_sha256': sha(w / 'PLACEMENT_RESULT.json'),
          'files_sha256': {p.name: sha(p) for p in [script, out / 'export.log', out / 'placed_netlist.v', out / 'imported.area']},
          'SYN_place_route_or_hardware_action': False}
(out / 'EXPORT_RECEIPT.json').write_text(json.dumps(result, indent=2) + '\n')
print(json.dumps(result, indent=2))
