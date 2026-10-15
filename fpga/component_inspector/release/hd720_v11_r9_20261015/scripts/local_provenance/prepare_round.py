from pathlib import Path
import hashlib
import json
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parent
PACKAGE = Path('C:/Users/Li47/Desktop/aa/V11/v11_handoff_20261015/v11_handoff_20261015')
PYTHON = sys.executable

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def main():
    manifest = json.loads((PACKAGE / 'MANIFEST.json').read_text(encoding='utf-8'))
    mismatches = [name for name, digest in manifest.items()
                  if not (PACKAGE / name).is_file() or sha(PACKAGE / name) != digest]
    audit = {'package_files': len(manifest), 'mismatches': mismatches,
             'manifest_sha256': sha(PACKAGE / 'MANIFEST.json')}
    (ROOT / 'handoff_verification.json').write_text(json.dumps(audit, indent=2), encoding='utf-8')
    if mismatches:
        raise RuntimeError(mismatches)
    print('PASS package manifest:', len(manifest), 'files')
    dev = ROOT / 'development/fpga/component_inspector'
    guard = dev / 'user_source/hdl_source/roi_frame_guard.v'
    old = b'parameter Y_BITS=$clog2(HEIGHT+1),COUNT_BITS=$clog2(WIDTH*HEIGHT+1))('
    new = (b'// Preserve the legacy 10-bit coordinate port for small-frame callers.\r\n'
           b' // FHD still expands to 11 bits so rows 1024..1079 remain representable.\r\n'
           b' parameter Y_BITS=(HEIGHT<1024 ? 10 : $clog2(HEIGHT+1)),\r\n'
           b' COUNT_BITS=$clog2(WIDTH*HEIGHT+1))(')
    value = guard.read_bytes()
    if value.count(old) != 1:
        raise RuntimeError('Unexpected development guard state')
    guard.write_bytes(value.replace(old, new))
    inputs = json.loads((PACKAGE / 'source_snapshot/inputs.json').read_text())
    inputs.update(json.loads((PACKAGE / 'source_snapshot/extra_inputs.json').read_text()))
    snapshot = ROOT / 'r9/source_snapshot'
    snapshot.mkdir(parents=True, exist_ok=False)
    changed = []
    for name, original_sha in inputs.items():
        src, dst = dev / name, snapshot / name
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src, dst)
        actual = sha(src)
        if actual != original_sha:
            changed.append({'file': name, 'old_sha256': original_sha, 'new_sha256': actual})
    new_inputs = {name: sha(snapshot / name) for name in inputs}
    (snapshot / 'inputs.json').write_text(json.dumps(new_inputs, indent=2), encoding='utf-8')
    (ROOT / 'r9/changes.json').write_text(json.dumps(changed, indent=2), encoding='utf-8')
    print('Frozen r9:', len(new_inputs), 'files;', len(changed), 'changes including relocated TD metadata')
    subprocess.run([PYTHON, str(PACKAGE / 'scripts/replay.py'), '--action', 'prepare',
                    '--snapshot', str(snapshot), '--work', str(ROOT / 'r9/fpga/component_inspector'),
                    '--td-root', 'D:/td6.2.1'], check=True)

if __name__ == '__main__':
    main()
