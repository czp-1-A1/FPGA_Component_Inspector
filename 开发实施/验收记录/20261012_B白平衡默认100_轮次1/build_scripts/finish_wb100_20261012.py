from pathlib import Path
from collections import Counter
import hashlib, json, re, shutil, subprocess

root = Path(__file__).resolve().parent.parent
project = root / 'fpga/component_inspector'
build = root / 'tmp/wb100_d3_r1_td_20261012'
prior = root / 'tmp/tracking_publish_diag_r2_td_20261011'
record = root / '开发实施/验收记录/20261012_B白平衡默认100_轮次1'
release = project / 'release/wb_defaults100_d3_20261012'
read = lambda p: p.read_text(encoding='utf-8-sig', errors='replace')
load = lambda p: json.loads(read(p))
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
dump = lambda p, data: p.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
inputs = load(build / 'inputs.json')
assert len(inputs) == 210
for e in inputs:
    assert sha(build / e['path']) == e['sha256'] == sha(project / e['path']), e['path']
for name in ['stage_inputs.json', 'simulation_inputs.json']:
    for e in load(build / name):
        assert sha(build / e['path']) == e['sha256'], e['path']
old = {e['path']: e['sha256'] for e in load(prior / 'inputs.json')}
changed = [e['path'] for e in inputs if old[e['path']] != e['sha256']]
assert set(changed) == {'user_source/hdl_source/uiisp_beta/ae_set.v', 'user_source/hdl_source/awb.v', 'user_source/hdl_source/isp/isp_top.v'}, changed
for e in load(record / 'changes.json'):
    assert sha(project / e['path']) == e['after_sha256']
    assert sha(record / 'before' / e['path']) == e['before_sha256']
for rel in changed:
    a = (project / rel).read_bytes()
    b = (record / 'before' / rel).read_bytes()
    # Only the requested reset literals may differ in production.
    assert a.replace(b"32'h00006464", b"32'h00004040") == b, rel

runs = build / 'td_project/camera_to_dsi_display_Runs'
phy = runs / 'phy_1'
oldruns = prior / 'td_project/camera_to_dsi_display_Runs'
warnings = {}
for stage, last in [('syn_1', 'opt_gate'), ('phy_1', 'bitgen')]:
    p = runs / stage
    assert read(p / 'build_exit_code.txt').strip() == '0'
    assert (p / ('.' + last + '.end.f')).exists() and not list(p.glob('.*.error.f'))
    assert not re.search(r'(?m)^\w+-\d+\s+(?:CRITICAL-)?ERROR:', read(p / 'build_console.log'))
    def warning_set(path):
        return Counter(re.sub(r'(\.v)\(\d+\)', r'\1(LINE)', s) for s in read(path).splitlines() if re.match(r'^\w+-\d+ (?:CRITICAL-)?WARNING:', s))
    new = warning_set(p / 'build_console.log')
    oldwarn = warning_set(oldruns / stage / 'build_console.log')
    assert new == oldwarn, (stage, list((new - oldwarn).elements()), list((oldwarn - new).elements()))
    warnings[stage] = sum(new.values())
timing = read(phy / 'camera_to_dsi_display_pr.timing')
assert 'Confidence          : Routed' in timing and 'Check Corner        : Both (Slow and Fast)' in timing
metrics = {k: float(re.search(label + r'\s*:\s*([-\d.]+)ns', timing)[1]) for k, label in [('setup_wns_ns', 'SWNS'), ('setup_tns_ns', 'STNS'), ('hold_wns_ns', 'HWNS'), ('hold_tns_ns', 'HTNS')]}
assert all(float(v) >= 0 for v in re.findall(r'(?:SWNS|HWNS)\s*:\s*([-\d.]+)ns', timing))
assert metrics['setup_tns_ns'] == metrics['hold_tns_ns'] == 0
assert all(int(v) == 0 for v in re.findall(r'(\d+) Viol Endpoints', timing))
metrics['sta_coverage_percent'] = float(re.search(r'STA coverage\s*:\s*([\d.]+)%', timing)[1])
area = read(phy / 'camera_to_dsi_display_phy.area')
resources = {}
for name in ['slice', 'eram', 'dsp']:
    m = re.search(r'^#' + name + r'\*?\s+(\d+)\s+out of\s+(\d+)\s+([\d.]+)%', area, re.M)
    resources[name] = dict(used=int(m[1]), total=int(m[2]), percent=float(m[3]))
def delays(path):
    return [(int(m[1]), int(m[2]), m[3]) for m in re.finditer(r'^\s*(\d+)\s+\d+\s+\d+\s+(\d+)\s+(set_max_delay .+)$', read(path).split('MCP/SMD Details')[0], re.M)]
newdelays = delays(phy / 'camera_to_dsi_display_exception.timing')
olddelays = delays(oldruns / 'phy_1/camera_to_dsi_display_exception.timing')
assert len(newdelays) == 37 and all(total > 0 and ignored == 0 for total, ignored, _ in newdelays)
assert Counter(e[2] for e in newdelays) == Counter(e[2] for e in olddelays)

tests = ['wb_controls', 'manual_wb', 'fixed_wb', 'controls', 'isp_metadata_stop']
assert read(build / 'sim/regression_exit_code.txt').strip() == '0'
for name in tests:
    p = build / 'sim/modelsim_work' / name
    assert 'PASS ' in read(p / 'console.log') and not re.search(r'(?m)^#?\s*\*\* (Fatal|Error):', read(p / 'console.log') + read(p / 'compile.log')), name
bit = phy / 'camera_to_dsi_display.bit'
audit = dict(status='PASS_source_simulation_and_routed_build', onsite='PENDING', changed_production_inputs=changed, tests=tests, timing=metrics, resources=resources, warnings=warnings, max_delays_matched=37, max_delays_ignored=0, bit=dict(bytes=bit.stat().st_size, sha256=sha(bit)))
dump(build / 'audit.json', audit)

assert not release.exists() and not (record / 'manifest.json').exists()
assert subprocess.check_output(['git', 'branch', '--show-current'], cwd=root, text=True).strip() == 'lj4747-contest-work'
head = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=root, text=True).strip()
assert head == '3be3967f2457622566fb20b7cef3aa5038e7d885'
assert not subprocess.check_output(['git', 'diff', '--cached', '--name-only'], cwd=root, text=True).strip()
release.mkdir()
shutil.copy2(bit, release / bit.name)
shutil.copy2(build / 'inputs.json', release / 'build_inputs.json')
(release / 'SHA256.txt').write_text(sha(bit) + '  ' + bit.name + '\n', encoding='ascii')
identity = f"{bit.stat().st_size}字节，SHA-256 `{sha(bit)}`"
stats = f"Routed慢/快角setup+{metrics['setup_wns_ns']:.3f}ns、hold+{metrics['hold_wns_ns']:.3f}ns，TNS0；Slice{resources['slice']['used']}/{resources['slice']['total']}={resources['slice']['percent']:.2f}%，ERAM{resources['eram']['used']}、DSP{resources['dsp']['used']}；STA覆盖{metrics['sta_coverage_percent']:.2f}%"
(release / 'README.md').write_text(f"# 默认白平衡R100/B100\n\n{identity}。基于D3，仅三处复位默认值改为100/100，保持/64、G通道及按键调参。孔追踪参数/门控未改；NO HOLE仍会等待。\n\n五项相关仿真PASS，{stats}。37条max_delay匹配/ignored0，约束与D3相同。未上板、未提交、未推送；旧D3镜像保留。\n", encoding='utf-8')
guide = root / '开发实施/43_B白平衡默认100_上板说明.md'
assert not guide.exists()
guide.write_text(f"# 默认白平衡R100/B100\n\n2026-10-12。镜像：[camera_to_dsi_display.bit](../{(release / bit.name).relative_to(root).as_posix()})。{identity}。\n\n下载后复位，HDMI应显示 `WB LOCK R100 B100 /64`；上电/复位均恢复100/100，按键仍可调红蓝。曝光/增益仍使用原默认值。基于D3，仅改三处默认值，没有实施42文档的孔边界修订。NO HOLE的定位条件及分类门控保持原样。\n\n五项相关仿真PASS；{stats}。现场图像、孔定位和分类验收仍待人工确认；没有执行JTAG/Flash、提交或推送。\n", encoding='utf-8')
p = record.with_suffix('.md')
s = read(p).replace('四路算术与截断帧场景', '四路算术与饱和裁剪场景')
s = s.replace('验证/构建进行中，尚未发布新镜像。软件验证不替代现场调色、孔定位与分类验收。', f"五项相关仿真PASS：{', '.join(tests)}；本轮只声明这五项新测，没有把其他受影响测试当作旧结果复用。综合/布局布线PASS；{stats}。37条max_delay全部匹配且ignored0，SDC与D3逐字节一致，{warnings['syn_1']}/{warnings['phy_1']}条综合/物理告警与D3内容相同。\n\n正式镜像`{(release / bit.name).relative_to(root).as_posix()}`，{identity}。冻结210生产输入相对D3只变三处默认值；冻结、测试及构建前后逐项散列一致。软件验证不替代现场调色、孔定位与分类验收。")
p.write_text(s, encoding='utf-8')
shutil.copy2(project / 'td_project/current_codex_build.json', record / 'current_build_before.json')
metadata = dict(purpose='D3_wb_defaults_100_only_hole_tracking_unchanged', td_version='6.2.168116', base_head=head, source_commit=None, source_snapshot=(record.relative_to(root) / 'source_snapshot').as_posix(), simulation_root=build.relative_to(root).as_posix(), release=dict(path=(release / bit.name).relative_to(root).as_posix(), **audit['bit']), validation_record=record.with_suffix('.md').relative_to(root).as_posix(), fresh_tests=tests, onsite='PENDING')
dump(project / 'td_project/current_codex_build.json', metadata)
def copy(src, rel):
    dst = record / rel
    assert not dst.exists(), rel
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)
for e in inputs:
    copy(build / e['path'], Path('source_snapshot') / e['path'])
for name in ['inputs.json', 'simulation_inputs.json', 'stage_inputs.json', 'audit.json']:
    copy(build / name, name)
for stage in ['syn_1', 'phy_1']:
    for f in (runs / stage).iterdir():
        if f.is_file() and f.suffix.lower() in {'.log', '.logw', '.rpt', '.txt', '.status', '.qor', '.area', '.tcl', '.prj', '.cfg', '.timing', '.bit', '.f'}:
            copy(f, Path('td_reports') / stage / f.name)
for e in load(build / 'simulation_inputs.json'):
    copy(build / e['path'], Path('simulation/source') / Path(e['path']).relative_to('sim'))
for name in tests:
    for filename in ['console.log', 'compile.log', 'transcript.log']:
        copy(build / 'sim/modelsim_work' / name / filename, Path('simulation/results') / name / filename)
for name in ['regression_console.log', 'regression_exit_code.txt']:
    copy(build / 'sim' / name, Path('simulation') / name)
for name in ['prepare_wb100_20261012.py', 'run_wb100_build_20261012.ps1', 'finish_wb100_20261012.py']:
    copy(root / 'tmp' / name, Path('build_scripts') / name)
manifest = [dict(path=p.relative_to(record).as_posix(), bytes=p.stat().st_size, sha256=sha(p)) for p in record.rglob('*') if p.is_file()]
dump(record / 'manifest.json', manifest)
for e in manifest:
    assert sha(record / e['path']) == e['sha256']
assert sha(release / bit.name) == sha(bit)
print(json.dumps(dict(release=str(release / bit.name), **audit), ensure_ascii=False))
