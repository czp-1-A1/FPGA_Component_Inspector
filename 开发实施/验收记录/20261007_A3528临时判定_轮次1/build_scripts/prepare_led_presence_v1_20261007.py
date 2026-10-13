from pathlib import Path
import hashlib, json, shutil, re

root = Path(__file__).resolve().parent.parent
project = root / 'fpga/component_inspector'
build = root / 'tmp/led_presence_demo_v1_td_20261007'
before = root / 'tmp/led_presence_demo_v1_before_20261007'
assert not (build / 'inputs.json').exists(), 'Preserve completed preparation'
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
read_json = lambda p: json.loads(p.read_text(encoding='utf-8-sig'))
baseline = read_json(project / 'release/edge_tail_fix_20261007/build_inputs.json')
assert len(baseline) == 207
for entry in baseline:
    source = project / entry['path']
    if before.exists() and entry['path'] == 'user_source/hdl_source/design_top_wrapper.v':
        source = before / entry['path']
    assert sha(source) == entry['sha256'], entry['path']
assert sha(project / 'release/edge_tail_fix_20261007/camera_to_dsi_display.bit') == 'bb6a71443b74790c64ceec562236799dc5b9418c07f4634c141b4df2a8bb9d65'
if not before.exists():
    before.mkdir()
    for rel in ['user_source/hdl_source/design_top_wrapper.v', 'sim/tb_classifier.v', 'td_project/current_codex_build.json']:
        dst = before / rel
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(project / rel, dst)
    shutil.copy2(root / 'AGENTS.md', before / 'AGENTS.md')

top = project / 'user_source/hdl_source/design_top_wrapper.v'
data = (before / 'user_source/hdl_source/design_top_wrapper.v').read_bytes()
old = b'// Placeholders only: enable after single-hole ROI and optical calibration.\r\nlocalparam CLASS_CALIBRATED=0;\r\nlocalparam [7:0] CLASS_THRESHOLD=0;'
new = b'// Temporary black-tape/white-part demo from historical 130 mm samples.\r\n// MEAN >= 58: present; below 58: empty. Recalibrate after fixture alignment.\r\nlocalparam CLASS_CALIBRATED=1;\r\nlocalparam [7:0] CLASS_THRESHOLD=58;'
assert data.count(old) == 1
top.write_bytes(data.replace(old, new))
tb = project / 'sim/tb_classifier.v'
data = (before / 'sim/tb_classifier.v').read_bytes()
anchor = b' probe(59,60,1,3);probe(60,60,1,2);probe(61,60,1,2);'
probes = b' // Temporary LED profile: historical readings and the 57/58/59 boundary.\n probe(36,58,1,3);probe(37,58,1,3);\n probe(78,58,1,2);probe(82,58,1,2);probe(85,58,1,2);probe(88,58,1,2);\n probe(57,58,1,3);probe(58,58,1,2);probe(59,58,1,2);\n'
assert data.count(anchor) == 1
tb.write_bytes(data.replace(anchor, probes + anchor).replace(b'independent 128-pixel sums,', b'T58 historical readings/boundary, independent 128-pixel sums,'))

build.mkdir(exist_ok=True)
inputs = []
for entry in baseline:
    src, dst = project / entry['path'], build / entry['path']
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)
    assert sha(src) == sha(dst)
    inputs.append({'path': entry['path'], 'bytes': dst.stat().st_size, 'sha256': sha(dst)})
changed = [x['path'] for x, old in zip(inputs, baseline) if x['sha256'] != old['sha256']]
assert changed == ['user_source/hdl_source/design_top_wrapper.v'], changed
template = root / 'tmp/edge_diagnostic_td_20261007/td_project/camera_to_dsi_display_Runs'
stage_inputs = []
file_paths = lambda p: re.findall(r'<File Path="([^"]+)"', p.read_text(encoding='utf-8-sig'))
al_sources = {(project / 'td_project' / x).resolve().relative_to(project.resolve()).as_posix() for x in file_paths(project / 'td_project/camera_to_dsi_display.al')}
for stage in ['syn_1', 'phy_1']:
    dest = build / 'td_project/camera_to_dsi_display_Runs' / stage
    dest.mkdir(parents=True, exist_ok=True)
    for name in ['settings.cfg', 'build.tcl', 'camera_to_dsi_display.prj']:
        shutil.copy2(template / stage / name, dest / name)
        stage_inputs.append({'path': (dest / name).relative_to(build).as_posix(), 'sha256': sha(dest / name)})
    prj_sources = {(dest / x).resolve().relative_to(build.resolve()).as_posix() for x in file_paths(dest / 'camera_to_dsi_display.prj')}
    assert prj_sources == al_sources, {'stage': stage, 'missing': list(al_sources-prj_sources), 'extra': list(prj_sources-al_sources)}
    assert all((build / rel).exists() for rel in prj_sources)
sim = build / 'sim'
sim.mkdir()
for src in (project / 'sim').iterdir():
    if src.is_file() and src.suffix.lower() in {'.v', '.ps1', '.py', '.do', '.md', '.hex'}:
        shutil.copy2(src, sim / src.name)
shutil.copytree(project / 'sim/osd_assets', sim / 'osd_assets')
(build / 'inputs.json').write_text(json.dumps(inputs, indent=2)+'\n', encoding='utf-8')
(build / 'stage_inputs.json').write_text(json.dumps(stage_inputs, indent=2)+'\n', encoding='utf-8')
(build / 'preparation.json').write_text(json.dumps({'input_count': len(inputs), 'baseline_changed': changed, 'project_sources': len(al_sources), 'old_bit_unchanged': True}, indent=2)+'\n', encoding='utf-8')
print(json.dumps({'build': str(build), 'input_count': len(inputs), 'baseline_changed': changed, 'project_sources': len(al_sources)}))
