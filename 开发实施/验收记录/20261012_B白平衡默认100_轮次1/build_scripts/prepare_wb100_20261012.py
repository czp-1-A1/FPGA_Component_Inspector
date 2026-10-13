from pathlib import Path
import hashlib, json, shutil

root = Path(__file__).resolve().parent.parent
project = root / 'fpga/component_inspector'
prior = root / 'tmp/tracking_publish_diag_r2_td_20261011'
build = root / 'tmp/wb100_d3_r1_td_20261012'
record = root / '开发实施/验收记录/20261012_B白平衡默认100_轮次1'
assert not build.exists() and not record.exists()
record.mkdir(parents=True)
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()

# Exact byte replacements preserve the legacy RTL encodings and line endings.
changes = {
    'user_source/hdl_source/uiisp_beta/ae_set.v': [
        (b"O_wb_tune<=0;O_wb_request<=32'h00004040;", b"O_wb_tune<=0;O_wb_request<=32'h00006464;")],
    'user_source/hdl_source/awb.v': [
        (b"pending<=32'h00004040;active<=32'h00004040;", b"pending<=32'h00006464;active<=32'h00006464;")],
    'user_source/hdl_source/isp/isp_top.v': [
        (b"wb_frame_request<=32'h00004040;", b"wb_frame_request<=32'h00006464;")],
    'sim/tb_wb_controls.v': [
        (b"16'h4040", b"16'h6464"), (b"32'h00004040", b"32'h00006464"),
        (b"32'h00013f40", b"32'h00016364"), (b"32'h00024040", b"32'h00026464"),
        (b"32'h0003403f", b"32'h00036463"), (b"32'h00044040", b"32'h00046464"),
        (b'ticks(1000)', b'ticks(1800)')],
    'sim/tb_manual_wb.v': [
        (b"request=32'h00004040;", b"request=32'h00006464;"),
        (b"expected_tag=32'h00004040;", b"expected_tag=32'h00006464;"),
        (b"frame(32'h00004040,1);frame(32'h00016020,1);", b"frame(32'h00006464,1);frame(32'h00004040,1);frame(32'h00016020,1);"),
        (b"active!==32'h00004040", b"active!==32'h00006464"),
        (b"frame(32'h00004040,0);", b"frame(32'h00006464,0);")],
}
before = []
for rel, replacements in changes.items():
    src = project / rel
    dst = record / 'before' / rel
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)
    original = src.read_bytes()
    changed = original
    for old, new in replacements:
        assert old in changed, (rel, old)
        changed = changed.replace(old, new)
    src.write_bytes(changed)
    before.append(dict(path=rel, before_sha256=sha(dst), after_sha256=sha(src)))
(record / 'changes.json').write_text(json.dumps(before, indent=2) + '\n', encoding='utf-8')

inputs = json.loads((prior / 'inputs.json').read_text(encoding='utf-8'))
for e in inputs:
    src = project / e['path']
    dst = build / e['path']
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)
    e.update(sha256=sha(dst), bytes=dst.stat().st_size)
for stage in ['syn_1', 'phy_1']:
    rel = Path('td_project/camera_to_dsi_display_Runs') / stage
    dst = build / rel
    dst.mkdir(parents=True)
    for name in ['settings.cfg', 'build.tcl', 'camera_to_dsi_display.prj']:
        shutil.copy2(prior / rel / name, dst / name)
sim = build / 'sim'
sim.mkdir()
for p in (project / 'sim').iterdir():
    if p.is_file() and p.suffix in {'.v', '.py', '.ps1', '.md', '.do'}:
        shutil.copy2(p, sim / p.name)
shutil.copytree(project / 'sim/osd_assets', sim / 'osd_assets')
for name, data in [
    ('inputs.json', inputs),
    ('simulation_inputs.json', [dict(path=p.relative_to(build).as_posix(), sha256=sha(p)) for p in sim.rglob('*') if p.is_file()]),
    ('stage_inputs.json', [dict(path=p.relative_to(build).as_posix(), sha256=sha(p)) for stage in ['syn_1', 'phy_1'] for p in (build / 'td_project/camera_to_dsi_display_Runs' / stage).iterdir() if p.is_file()]),
]:
    (build / name).write_text(json.dumps(data, indent=2) + '\n', encoding='utf-8')
script = (root / 'tmp/run_tracking_diag_build_20261011.ps1').read_bytes()
assert b'tracking_publish_diag_r2_td_20261011' in script
(root / 'tmp/run_wb100_build_20261012.ps1').write_bytes(script.replace(b'tracking_publish_diag_r2_td_20261011', b'wb100_d3_r1_td_20261012'))
print(f'Frozen {len(inputs)} production inputs: {build}')
