"""Create an immutable, independently hashed source/build-input copy."""
from pathlib import Path
import argparse, hashlib, json, shutil, subprocess

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('destination', type=Path)
    ap.add_argument('--baseline', action='store_true')
    args = ap.parse_args()
    engine = Path(__file__).resolve().parents[1]
    repo = engine.parents[1]
    dest = args.destination.resolve()
    if dest.exists():
        raise SystemExit('Refusing to replace an existing frozen directory')
    original = json.loads((engine/'release/edge_tail_fix_20261007/build_inputs.json').read_text(encoding='utf-8-sig'))
    paths = {e['path'] for e in original}
    if args.baseline:
        for e in original:
            assert digest(engine/e['path']) == e['sha256'], e['path']
    else:
        for directory in ('sim', 'tools'):
            paths.update(p.relative_to(engine).as_posix() for p in (engine/directory).rglob('*')
                         if p.is_file() and p.suffix in ('.v','.sv','.py','.ps1','.hex','.tcl','.json','.md'))
        paths.add('user_source/hdl_source/native_hdmi_pll.v')
        paths.update(p.relative_to(engine).as_posix() for p in (engine/'vendor_reference').rglob('*') if p.is_file())
    manifest = []
    for rel in sorted(paths):
        src, out = engine/rel, dest/rel
        out.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src, out)
        manifest.append(dict(path=rel,sha256=digest(out),bytes=out.stat().st_size))
    bit = engine/'release/edge_tail_fix_20261007/camera_to_dsi_display.bit'
    if args.baseline:
        shutil.copy2(bit, dest/'rollback.bit')
    metadata = dict(branch=subprocess.check_output(['git','branch','--show-current'],cwd=repo,text=True).strip(),
                    head=subprocess.check_output(['git','rev-parse','HEAD'],cwd=repo,text=True).strip(),
                    rollback_sha256=digest(bit),inputs=manifest)
    (dest/'freeze.json').write_text(json.dumps(metadata,indent=2)+'\n',encoding='utf-8')
    print(f'Frozen {len(manifest)} files at {dest}; HEAD={metadata["head"]}')

if __name__ == '__main__':
    main()
