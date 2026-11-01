"""Rebuild preparation from a sealed source tree, without editing that tree."""
from pathlib import Path
import argparse, hashlib, importlib.util, json, re, shutil

def prepare(source, manifest, work, td):
    if work.exists():
        raise RuntimeError('Refuse to overwrite existing work directory: ' + str(work))
    if not str(work).isascii() or ' ' in str(work):
        raise RuntimeError('Use an ASCII project parent without spaces, e.g. D:/CodexWork/ClassifiedCount_replay')
    inputs = json.loads(manifest.read_text(encoding='utf-8'))
    for rel, digest in inputs.items():
        p = source / rel
        assert hashlib.sha256(p.read_bytes()).hexdigest() == digest, ('Source changed', rel)
    work.mkdir(parents=True)
    for rel in inputs:
        destination = work / rel
        destination.resolve().relative_to(work)
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source / rel, destination)
    # GUI .al Path is location metadata. Normalize it only in the fresh work
    # copy; all relative source paths, device parameters, RTL and SDC stay fixed.
    entry = work / 'td_project/camera_to_dsi_display.al'
    original = entry.read_text(encoding='utf-8')
    relocated = re.sub(r'(<Project\b[^>]*\bPath=")[^"]*', lambda m: m[1] + entry.parent.as_posix(), original, count=1)
    entry.write_text(relocated, encoding='utf-8')
    spec = importlib.util.spec_from_file_location('classified_prepare', work / 'tools/prepare_classified_project.py')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    receipt = module.prepare(work, td)
    for rel, digest in inputs.items():
        if rel.startswith('user_source/') or rel.endswith('.sdc'):
            assert hashlib.sha256((work / rel).read_bytes()).hexdigest() == digest, rel
    receipt['frozen_source_manifest_sha256'] = hashlib.sha256(manifest.read_bytes()).hexdigest()
    receipt['project_metadata_only_relocation'] = True
    (work / 'portable_preparation.json').write_text(json.dumps(receipt, indent=2), encoding='utf-8')
    return receipt

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--source', type=Path, required=True)
    parser.add_argument('--manifest', type=Path, required=True)
    parser.add_argument('--work', type=Path, required=True)
    parser.add_argument('--td', type=Path, default=Path('D:/td6.2.1'))
    args = parser.parse_args()
    result = prepare(args.source.resolve(), args.manifest.resolve(), args.work.resolve(), args.td.resolve())
    print('PASS portable fresh work copy:', len(result['inputs']), 'project/IP dependencies; frozen RTL/SDC unchanged')
