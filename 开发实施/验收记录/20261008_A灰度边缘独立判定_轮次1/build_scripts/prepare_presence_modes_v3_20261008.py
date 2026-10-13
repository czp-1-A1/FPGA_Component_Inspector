from pathlib import Path
import hashlib, json, shutil, subprocess
root = Path(__file__).resolve().parent.parent
project = root / 'fpga/component_inspector'
prior = root / 'tmp/led_presence_demo_v2_r2_td_20261008'
before = root / 'tmp/presence_modes_v3_before_20261008'
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
inputs = json.loads((prior / 'inputs.json').read_text(encoding='utf-8-sig'))
assert not before.exists()
assert subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=root, text=True).strip() == '3be3967f2457622566fb20b7cef3aa5038e7d885'
for entry in inputs:
    assert sha(project / entry['path']) == entry['sha256'], entry['path']
    destination = before / entry['path']
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(project / entry['path'], destination)
for relative in ['sim', 'td_project/current_codex_build.json']:
    source = project / relative
    if source.is_dir():
        destination = before / relative
        destination.mkdir(exist_ok=True)
        for item in source.iterdir():
            if item.is_file() and item.suffix in {'.v', '.py', '.ps1', '.md'}:
                shutil.copy2(item, destination / item.name)
        shutil.copytree(source / 'osd_assets', destination / 'osd_assets')
    else:
        shutil.copy2(source, before / relative)
shutil.copy2(root / 'AGENTS.md', before / 'AGENTS.md')
(before / 'inputs.json').write_text(json.dumps(inputs, indent=2) + '\n', encoding='utf-8')
print('PASS pre-change snapshot:', len(inputs), 'R2 production inputs verified; prior tests/assets/checkpoint preserved')
