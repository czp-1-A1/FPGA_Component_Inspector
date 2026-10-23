"""Restore only frozen R13 inputs into a fresh project; never build/program."""
from pathlib import Path
import argparse, hashlib, importlib.util, json, re, shutil
from verify_r13 import verify, read_json, check, MANIFEST_SHA

def prepare(repo, work, td):
    verified = verify(repo)
    check(not work.exists(), 'Refuse to overwrite work directory: ' + str(work))
    check(str(work).isascii() and ' ' not in str(work), 'Use an ASCII work path without spaces')
    source = repo / 'fpga/component_inspector'
    manifest = read_json(repo / 'releases/r13_20261023/frozen_inputs.json')
    check((td / 'scripts/DefaultFlow.tcl').is_file(), 'Missing TD DefaultFlow.tcl')
    work.mkdir(parents=True)
    for rel in manifest:
        destination = work / rel
        destination.resolve().relative_to(work)
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source / rel, destination)
    entry = work / 'td_project/camera_to_dsi_display.al'
    original = entry.read_text(encoding='utf-8')
    relocated, count = re.subn(r'(<Project\b[^>]*\bPath=")[^"]*', lambda m:m[1] + entry.parent.as_posix(), original, count=1)
    check(count == 1, 'Expected one .al project location')
    entry.write_text(relocated, encoding='utf-8')
    spec = importlib.util.spec_from_file_location('r13_frozen_prepare', work / 'tools/prepare_classified_project.py')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    result = module.prepare(work, td)
    expected_keys = read_json(repo / 'releases/r13_20261023/evidence/project_dependency_delta.json')['expected_dependencies']
    expected = {rel: manifest[rel] for rel in expected_keys}
    check(result['inputs'] == expected, 'Project dependency keys or SHA differ from the final98 closure')
    cfg = work / 'td_project/camera_to_dsi_display_Runs/phy_1/settings.cfg'
    cfg_text, count = re.subn(r'place seed \d+', 'place seed 2', cfg.read_text(encoding='utf-8'))
    check(count == 1, 'Expected one physical seed setting')
    cfg.write_text(cfg_text, encoding='utf-8')
    for rel, digest in manifest.items():
        if rel.startswith('user_source/') or rel.endswith('.sdc'):
            check(hashlib.sha256((work / rel).read_bytes()).hexdigest() == digest, 'Frozen RTL/SDC changed: ' + rel)
    receipt = {'status':'PASS_FRESH_R13_471_SOURCE_98_DEPENDENCIES_SEED2_NO_BUILD', 'source_manifest_sha256':MANIFEST_SHA, 'project':str(work), 'td':str(td), 'physical_seed':2, 'inputs':result['inputs'], 'source_verification':verified, 'hardware_operation':False, 'build_executed':False}
    (work / 'r13_preparation.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8')
    return receipt

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--repo', type=Path, default=Path(__file__).resolve().parents[2])
    parser.add_argument('--work', type=Path, required=True)
    parser.add_argument('--td', type=Path, default=Path('D:/td6.2.1'))
    args = parser.parse_args()
    result = prepare(args.repo.resolve(), args.work.resolve(), args.td.resolve())
    print(result['status'])
