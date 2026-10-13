from pathlib import Path
import hashlib, json, shutil, re

root = Path(__file__).resolve().parent.parent
project = root / 'fpga/component_inspector'
build = root / 'tmp/led_presence_demo_v2_td_20261008'
before = root / 'tmp/led_presence_demo_v2_before_20261008'
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
load = lambda p: json.loads(p.read_text(encoding='utf-8-sig'))
dump = lambda p, d: p.write_text(json.dumps(d, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
assert not build.exists() and not before.exists(), 'Preserve prior preparation/evidence'
baseline = load(project / 'release/led_presence_demo_v1_20261007/build_inputs.json')
assert len(baseline) == 207
for entry in baseline:
    assert sha(project / entry['path']) == entry['sha256'], entry['path']
for name, expected in [
    ('led_presence_demo_v1_20261007', '4c8aa1695e06f3218ba5ae01b67e78e188755a61beea9f1229cdd1ef7296e22e'),
    ('edge_tail_fix_20261007', 'bb6a71443b74790c64ceec562236799dc5b9418c07f4634c141b4df2a8bb9d65')]:
    assert sha(project / 'release' / name / 'camera_to_dsi_display.bit') == expected
before.mkdir()
for rel in ['user_source/hdl_source/design_top_wrapper.v', 'sim/tb_display_state.v', 'td_project/current_codex_build.json']:
    dst = before / rel
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(project / rel, dst)
shutil.copy2(root / 'AGENTS.md', before / 'AGENTS.md')

top = project / 'user_source/hdl_source/design_top_wrapper.v'
data = top.read_bytes()
changes = [
    (b'// MEAN >= 58: present; below 58: empty. Recalibrate after fixture alignment.\r\n',
     b'// MEAN >= 58: present; below 58: empty. Recalibrate after fixture alignment.\r\n// Exposure/gain tuning stays enabled; config/fresh-sample guards still apply.\r\n'),
    (b'localparam [15:0] CLASS_EXPOSURE=2244,CLASS_GAIN=48;\r\n', b''),
    (b'.calibration_ok(CLASS_CALIBRATED && camera_receive[48:33]==CLASS_EXPOSURE && camera_receive[32:17]==CLASS_GAIN)', b'.calibration_ok(CLASS_CALIBRATED)'),
    (b'.calibration_ok(CLASS_CALIBRATED && cam_display[48:33]==CLASS_EXPOSURE && cam_display[32:17]==CLASS_GAIN)', b'.calibration_ok(CLASS_CALIBRATED)')]
for old, new in changes:
    assert data.count(old) == 1
    data = data.replace(old, new)
assert data.count(b'.calibration_ok(CLASS_CALIBRATED)') == 2
assert b'CLASS_EXPOSURE' not in data and b'CLASS_GAIN' not in data
top.write_bytes(data)

tb = project / 'sim/tb_display_state.v'
data = tb.read_bytes()
assert b'\r' not in data
anchor = b'reg [27:0] held;reg token;'
task = b'''// Tuning is permitted with the provisional threshold. Parameter changes must
// still wait for a new token; the supplied means are logic stimuli, not an
// optical prediction for these exposure/gain settings.
task tuned_sample;input [15:0] new_ex,new_ga;input [7:0] v,mn,mx;input [1:0] expected;
begin
 ex=new_ex;ga=new_ga;wait_dest(2);
 if(valid || dest_state!==1) $fatal(1,"tuning retained old result");
 wait_dest(45);
 if(valid || dest_state!==1) $fatal(1,"stable tuning reused old token");
 sample(v,mn,mx,expected);
end endtask
'''
assert data.count(anchor) == 1
data = data.replace(anchor, task+anchor)
anchor = b' sample(37,25,110,3);'
scenario = b'''
 // Enabled classification resumes at non-default gain and exposure settings.
 tuned_sample(2244,47,85,27,255,2);
 cfg=0;wait_dest(2);
 if(valid || dest_state!==1) $fatal(1,"tuning busy did not wait");
 @(negedge sclk);bad=1;sv=0;@(negedge sclk);bad=0;
 ex=2228;cfg=1;wait_dest(45);
 if(valid || dest_state!==1) $fatal(1,"tuning completion revived invalid sample");
 sample(36,26,112,3);
 tuned_sample(2212,49,78,27,255,2);
 tuned_sample(3,16,37,25,110,3);
 tuned_sample(2244,89,88,30,252,2);
 tuned_sample(2244,48,36,26,112,3);
'''
assert data.count(anchor) == 1
data = data.replace(anchor, anchor+scenario)
data = data.replace(b'recipe mismatch/return, stopped CSI,', b'recipe mismatch/return, enabled exposure/gain tuning with fresh tokens, stopped CSI,')
tb.write_bytes(data)

build.mkdir()
inputs = []
for entry in baseline:
    src, dst = project / entry['path'], build / entry['path']
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)
    assert sha(src) == sha(dst)
    inputs.append({'path': entry['path'], 'bytes': dst.stat().st_size, 'sha256': sha(dst)})
changed = [x['path'] for x, old in zip(inputs, baseline) if x['sha256'] != old['sha256']]
assert changed == ['user_source/hdl_source/design_top_wrapper.v'], changed
template = root / 'tmp/led_presence_demo_v1_td_20261007/td_project/camera_to_dsi_display_Runs'
stage_inputs = []
file_paths = lambda p: re.findall(r'<File Path="([^"]+)"', p.read_text(encoding='utf-8-sig'))
al_sources = {(project / 'td_project' / x).resolve().relative_to(project.resolve()).as_posix() for x in file_paths(project / 'td_project/camera_to_dsi_display.al')}
for stage in ['syn_1', 'phy_1']:
    dest = build / 'td_project/camera_to_dsi_display_Runs' / stage
    dest.mkdir(parents=True)
    for name in ['settings.cfg', 'build.tcl', 'camera_to_dsi_display.prj']:
        shutil.copy2(template / stage / name, dest / name)
        stage_inputs.append({'path': (dest / name).relative_to(build).as_posix(), 'sha256': sha(dest / name)})
    prj_sources = {(dest / x).resolve().relative_to(build.resolve()).as_posix() for x in file_paths(dest / 'camera_to_dsi_display.prj')}
    assert prj_sources == al_sources
    assert all((build / rel).exists() for rel in prj_sources)
sim = build / 'sim'
sim.mkdir()
for src in (project / 'sim').iterdir():
    if src.is_file() and src.suffix.lower() in {'.v', '.ps1', '.py', '.do', '.md', '.hex'}:
        shutil.copy2(src, sim / src.name)
shutil.copytree(project / 'sim/osd_assets', sim / 'osd_assets')
dump(build / 'inputs.json', inputs)
dump(build / 'stage_inputs.json', stage_inputs)
dump(build / 'preparation.json', {'input_count': len(inputs), 'v1_changed': changed, 'project_sources': len(al_sources), 'v1_and_edge_bits_unchanged': True})
print(json.dumps({'build': str(build), 'input_count': len(inputs), 'v1_changed': changed, 'project_sources': len(al_sources)}))
