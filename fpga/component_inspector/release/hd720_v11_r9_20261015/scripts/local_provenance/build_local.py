"""Build a frozen replay with this TD installation's actual flow location."""
from pathlib import Path
import hashlib
import json
import os
import re
import subprocess
import time

ROOT = Path(__file__).resolve().parent
WORK = ROOT / 'r9/fpga/component_inspector'
TD = Path('D:/td6.2.1')

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

flow = next((TD / name for name in ['doc/scripts/DefaultFlow.tcl', 'scripts/DefaultFlow.tcl']
             if (TD / name).is_file()), None)
if flow is None:
    raise RuntimeError('TD DefaultFlow not found')
temp = ROOT / 'tool_temp'
temp.mkdir(exist_ok=True)
os.environ['TEMP'] = os.environ['TMP'] = str(temp)
source = ROOT / 'r9/source_snapshot'
manifest = json.loads((source / 'inputs.json').read_text())
for name, digest in manifest.items():
    if sha(source / name) != digest:
        raise RuntimeError('Frozen input changed: ' + name)
    if name.startswith(('user_source/', 'sim/')) and sha(WORK / name) != digest:
        raise RuntimeError('Replay input changed: ' + name)

for stage in ['syn_1', 'phy_1']:
    stage_dir = WORK / 'td_project/camera_to_dsi_display_Runs' / stage
    local_tcl = stage_dir / 'build_local.tcl'
    # Keep frozen build.tcl intact. Only locate the installed vendor flow.
    value = (stage_dir / 'build.tcl').read_text()
    value, count = re.subn(r'source \{[^}]*DefaultFlow\.tcl\}',
                          lambda m: 'source {' + flow.as_posix() + '}', value)
    if count != 1:
        raise RuntimeError('Unexpected build script')
    local_tcl.write_text(value, encoding='utf-8')
    command = [str(TD / 'bin/td_commands_prompt.exe'), local_tcl.name]
    print('RUN', stage, command, flush=True)
    started = time.time()
    log = stage_dir / 'build_local.log'
    with log.open('w', encoding='utf-8') as out:
        proc = subprocess.Popen(command, cwd=stage_dir, stdout=out, stderr=subprocess.STDOUT)
        code = proc.wait()
    (stage_dir / 'build_local.result.json').write_text(json.dumps({
        'command': command, 'exit_code': code, 'elapsed_seconds': time.time() - started,
        'vendor_flow': str(flow), 'vendor_flow_sha256': sha(flow),
        'source_manifest_sha256': sha(source / 'inputs.json')}, indent=2), encoding='utf-8')
    print('DONE', stage, 'exit', code, 'seconds', round(time.time() - started, 1), flush=True)
    if code:
        raise RuntimeError('Build failed: ' + str(log))
print('Build completed; routed timing and constraints require separate review.', flush=True)
