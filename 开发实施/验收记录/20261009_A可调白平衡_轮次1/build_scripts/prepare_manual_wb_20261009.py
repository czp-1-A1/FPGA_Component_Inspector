from pathlib import Path
import hashlib, json, shutil, subprocess

root = Path(__file__).resolve().parent.parent
project = root / 'fpga/component_inspector'
before = root / 'tmp/manual_wb_v1_before_20261009'
prior = root / 'tmp/fixed_wb_tuning_r2_td_20261009'
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
assert not before.exists()
inputs = json.loads((prior / 'inputs.json').read_text(encoding='utf-8-sig'))
for e in inputs:
    src = project / e['path']
    assert sha(src) == e['sha256'], e['path']
    dst = before / e['path']
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)
sim = before / 'sim'
sim.mkdir()
for src in (project / 'sim').iterdir():
    if src.is_file() and src.suffix in {'.v', '.py', '.ps1', '.md', '.do'}:
        shutil.copy2(src, sim / src.name)
shutil.copytree(project / 'sim/osd_assets', sim / 'osd_assets')
for rel in ['AGENTS.md', 'fpga/component_inspector/td_project/current_codex_build.json']:
    dst = before / 'documents' / rel
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(root / rel, dst)
(before / 'inputs.json').write_text(json.dumps(inputs, indent=2) + '\n', encoding='utf-8')
(before / 'git_status.txt').write_bytes(subprocess.check_output(['git', 'status', '--short', '--branch'], cwd=root))
print(f'PASS manual WB baseline frozen: {len(inputs)} production inputs; no RTL changes yet')
