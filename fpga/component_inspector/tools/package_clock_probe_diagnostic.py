"""Freeze verified F outputs; refuse failed/incomplete tests or stale inputs."""
from pathlib import Path
import argparse, hashlib, json, re, shutil, zipfile

engine = Path(__file__).resolve().parents[1]
ap = argparse.ArgumentParser()
ap.add_argument('freeze', type=Path)
ap.add_argument('--simulation-freeze', type=Path, required=True)
ap.add_argument('--desktop', type=Path, required=True)
ap.add_argument('--early', type=Path, nargs='*', default=[])
args = ap.parse_args()
root, simroot, desktop = (p.resolve() for p in (args.freeze, args.simulation_freeze, args.desktop))
out = engine / 'release/native_1080p30/clock_probe_diagnostic_20261011'
if out.exists() or desktop.exists():
    raise SystemExit('Refusing existing release/Desktop directory')

def sha(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()

def read(p):
    b = p.read_bytes()
    return b.decode("utf-16" if b[:2] in (b"\xff\xfe", b"\xfe\xff") else "utf-8-sig", errors="replace")

def load_inputs(tree):
    m = json.loads((tree / 'freeze.json').read_text(encoding='utf-8-sig'))
    assert m['project'] == 'clock_probe'
    for e in m['inputs']:
        assert sha(tree / e['path']) == e['sha256'] and (tree / e['path']).stat().st_size == e['bytes'], e['path']
    for e in m['vendor_models']:
        assert sha(Path(e['path'])) == e['sha256'], e['path']
    return m

meta, simmeta = load_inputs(root), load_inputs(simroot)
# SDC/AL/build generator may differ; all production HDL and simulation inputs
# must be byte-identical to the independent simulation's frozen inputs.
sm = {e['path']: e for e in simmeta['inputs']}
bindings = []
for e in meta['inputs']:
    if e['path'].startswith(('diagnostics/', 'user_source/', 'sim/')):
        assert e == sm[e['path']], e['path']
        bindings.append(e)
assert len(bindings) == 17 and meta['vendor_models'] == simmeta['vendor_models']
logs = {}
for f, marker in [('clock_probe_units.console.log', 'PASS F units complete'),
    ('clock_probe.console.log', 'PASS F dual-mode pins:720p60 to1080p30 to720p60')]:
    s = read(simroot / 'sim' / f)
    assert marker in s and '** Fatal:' not in s and '** Error:' not in s
    assert re.search(r'Errors: 0, Warnings: 0', s), f
    logs[f] = s
assert 'PASS F OSD:720+FHD complete raster3712500 samples' in logs['clock_probe_units.console.log']
frames = re.findall(r'OBS F full frame mode([01]) words(\d+) pixels(\d+) lines(\d+), HD(\d+) FHD(\d+) transitions(\d+)', logs['clock_probe.console.log'])
assert frames and frames[-1][0] == '0' and frames[-1][-1] == '2'
for mode, words, pixels, lines, *_ in frames:
    assert tuple(map(int, (words, pixels, lines))) == ((1237500, 921600, 720) if mode == '0' else (2475000, 2073600, 1080))
name = meta['project']
runs = root / 'td_project' / (name + '_Runs')
phy = runs / 'phy_1'
console = read(phy / 'td_console.log')
timing = {}
for key in ('Setup', 'Hold'):
    m = re.findall(key + r'\s*:\s*WNS\s+(-?\d+)ps\s+TNS\s+(-?\d+)ps\s+NUM_FEPS\s+(\d+)', console)
    assert m
    wns, tns, ep = map(int, m[-1])
    assert wns >= 0 and tns == 0 and ep == 0, key
    timing[key.lower() + '_wns_ns'] = wns / 1000
assert not re.search(r'\b(ERROR|Error|CRITICAL)\b', console)
final = (phy / 'final_timing.rpt').read_text()
for k, v in [('SWNS', timing['setup_wns_ns']), ('HWNS', timing['hold_wns_ns'])]:
    assert float(re.search(k + r':\s*([\d.-]+)ns', final)[1]) == v
assert re.search(r'0 Viol Endpoints,\s+59 Total Endpoints,\s+59 Paths Analyzed', final)
coverage = float(re.search(r'STA coverage\s*:\s*([\d.]+)%', final)[1])
cov = (phy / 'constraint_coverage.txt').read_text()
for key in ('no clock', 'dummy node', 'invalid constraint', 'no path constraints', 'shadowed/ignored timing exception constraints'):
    assert 'checking ' + key + '(0)' in cov, key
sdc = (root / 'td_project' / (name + '.sdc')).read_text()
assert 'set_false_path -hold' not in sdc and 'set_clock_groups' not in sdc
expected_budgets = [2.0, 12.0, 2.0, 8.0, 8.0, 2.0]
ex = (phy / (name + '_exception.timing')).read_text()
matches = re.findall(r'(?m)^\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(set_max_delay -datapath_only ([\d.]+)[^\n]*)$', ex)
assert len(matches) == 6 and [float(x[5]) for x in matches] == expected_budgets
for count, dominated, shadowed, ignored, *_ in matches:
    assert int(count) > 0 and count == dominated and shadowed == ignored == '0'
assert all(float(x) >= 0 for x in re.findall(r'Slack\s*:\s*([\d.-]+)ns', ex))
area = (phy / (name + '_phy.area')).read_text()
resources = {}
for key in ('slice', 'eram', 'dsp', 'pll', 'gclk'):
    m = re.search(r'(?m)^#' + key + r'\s+(\d+)\s+out of\s+(\d+)', area)
    assert m and int(m[1]) <= int(m[2])
    resources[key] = dict(used=int(m[1]), capacity=int(m[2]))
assert 'I_mode_select' in area and 'A4' in area
assert len(re.findall('PHY-5016 WARNING', console)) == 3
bit = phy / (name + '.bit')
assert bit.stat().st_size > 100000
al = (root / 'td_project' / (name + '.al')).read_text()
refs = re.findall(r'<File Path="([^"]+)"', al)
assert len(refs) == 11 and 'hdmi_ideal_pll' not in al and 'native_hdmi_pll.v' in al
assert all((root / 'td_project' / r).resolve().exists() for r in refs)
out.mkdir(parents=True)
desktop.mkdir(parents=True)

def archive(tree, m, target, reports=True):
    target.mkdir(parents=True, exist_ok=True)
    shutil.copy2(tree / 'freeze.json', target / 'input_snapshot.json')
    with zipfile.ZipFile(target / 'input_snapshot.zip', 'w', zipfile.ZIP_DEFLATED) as z:
        for e in m['inputs']:
            z.write(tree / e['path'], e['path'])
    for p in (tree / 'sim').glob('*.log'):
        q = target / 'simulation' / p.name
        q.parent.mkdir(exist_ok=True)
        shutil.copy2(p, q)
    if reports:
        for run in ('syn_1', 'phy_1'):
            for p in (tree / 'td_project' / (name + '_Runs') / run).iterdir():
                if p.is_file() and (p.suffix in ('.log', '.logw', '.rpt', '.txt', '.area', '.stat', '.cfg', '.tcl', '.prj', '.ts', '.timing') or 'report' in p.name):
                    q = target / 'reports' / run / p.name
                    q.parent.mkdir(parents=True, exist_ok=True)
                    shutil.copy2(p, q)

archive(root, meta, out)
archive(simroot, simmeta, out / 'simulation_freeze', reports=False)
for early in args.early:
    early = early.resolve()
    archive(early, load_inputs(early), out / 'early_rounds' / early.name)
build_inputs = [dict(path=p.relative_to(root).as_posix(), sha256=sha(p))
    for run in ('syn_1', 'phy_1') for p in (runs / run).iterdir()
    if p.name in ('settings.cfg', 'build.tcl', name + '.prj')]
(out / 'generated_build_inputs.json').write_text(json.dumps(build_inputs, indent=2) + '\n')
(out / 'simulation_binding.json').write_text(json.dumps(dict(build_freeze=root.name,
    simulation_freeze=simroot.name, byte_identical_production_and_test_inputs=bindings,
    differences='Only build-generator/SDC/AL; r4 removes crossing hold exemptions and limits lock cut to hard-lock source pins. No RTL/test/reference changes after r2 freeze.'), indent=2) + '\n')
label = 'F_720p60_1080p30_probe.bit'
shutil.copy2(bit, out / label)
shutil.copy2(bit, desktop / label)
for e in meta['inputs']:
    q = desktop / e['path']
    q.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(root / e['path'], q)
shutil.copytree(runs, desktop / 'td_project' / (name + '_Runs'))
for p in [desktop / 'td_project' / (name + '.al'), *list((desktop / 'td_project' / (name + '_Runs')).glob('*/*.prj'))]:
    p.write_text(re.sub(r'(<Project[^>]* Path=")[^"]+', lambda m: m[1] + (desktop / 'td_project').as_posix(), p.read_text(), count=1))
for r in refs:
    p = (desktop / 'td_project' / r).resolve()
    assert p.is_relative_to(desktop) and p.exists()
assert sha(bit) == sha(desktop / label) == sha(desktop / 'td_project' / (name + '_Runs') / 'phy_1' / (name + '.bit'))
old = engine / 'release/edge_diagnostic_20261007/camera_to_dsi_display.bit'
assert sha(old) == 'c3a1cce7d4a19d6750c0e6f3e36395a3c2f3d31901834a1b13a76f497a9230f8'
shutil.copy2(old, desktop / 'OLD_user_identified_working.bit')
shutil.copy2(engine / 'tools/native_toolchain.json', out / 'toolchain.json')
shutil.copy2(engine / 'diagnostics/hdmi_positive/CLOCK_PROBE.md', out / 'RTL_INTERFACES.md')
audit = dict(status='INTERNAL_STA_PASS_EXTERNAL_BUDGETS_OPEN',
    setup_tns_ns=0, hold_tns_ns=0, violating_endpoints=0,
    normal_crossing_hold_checks=True, blanket_clock_group_cut=False,
    valid_max_delay_constraints=[dict(paths=int(n), dominated=int(d), shadowed=int(s), ignored=int(i), command=c)
        for n, d, s, i, c, _ in matches],
    packed_cell_aliases='Constraints also match some intra-domain packed flops. All max budgets are below clock periods and tighten setup; all hold checks retained in r4.',
    related_pixel_to_serial_paths=dict(max=59, min=59),
    target_clocks_mhz=dict(reference=50, intermediate=33.75, pixel=74.25, serial=371.25),
    displayed_sta_serial_mhz=371.333, displayed_precision_note='Rounded2.693ns inverse, not hardware frequency measurement',
    warnings=[dict(code='PHY-5016', text=line.strip(), status='OPEN_BOARD_PLL_PHY_AUDIT') for line in console.splitlines() if 'PHY-5016 WARNING' in line],
    async_inputs_without_delays=['I_rst_n', 'I_mode_select'],
    output_budgets_open=['O_tmds_ch0_p','O_tmds_ch1_p','O_tmds_ch2_p','O_tmds_clk_p'],
    invalid_dummy_no_clock_ignored_or_no_path=0,
    physical_frequency_jitter_tmds='NOT_RUN')
(out / 'constraint_audit.json').write_text(json.dumps(audit, indent=2) + '\n')
summary = dict(bit=label, sha256=sha(bit), bytes=bit.stat().st_size,
    desktop_bit=(desktop / label).as_posix(), desktop_al=(desktop / 'td_project' / (name + '.al')).as_posix(),
    build_freeze=root.name, simulation_freeze=simroot.name,
    physical_acceptance='NOT_RUN', all_paths_timing_accepted=False,
    setup_tns_ns=0, hold_tns_ns=0, violating_endpoints=0,
    sta_coverage_percent=coverage, resources=resources,
    frozen_inputs=len(meta['inputs']), vendor_models=len(meta['vendor_models']),
    byte_identical_simulation_inputs=len(bindings), portable_al_references=len(refs),
    simulated_complete_hd_frames=int(frames[-1][4]), simulated_complete_fhd_frames=int(frames[-1][5]),
    simulated_transitions=2, **timing)
(out / 'diagnostic.json').write_text(json.dumps(summary, indent=2) + '\n')
tests = dict(
    counter_gray_windows_wrap_clock_stop_lock_reset='PASS_FROZEN_R2_1000_CYCLE_UNIT_WINDOW',
    mailbox_atomic_dest_stop_resume='PASS_FROZEN_R2',
    osd_complete_720_and_fhd_rasters='PASS_3712500_SAMPLES_NONZERO_HEX_FIELDS_AND_EQUAL_DELAY',
    serialized_pins='PASS_ALL_RGB_INITIAL_ZERO_OSD_SYNC_COUNTS_AND_TWO_SWITCHES_IDEAL_PLL_VENDOR_ODDR',
    serialized_dynamic_one_second_fields='NOT_RUN_ENDS_BEFORE_HARDWARE_WINDOW',
    full_real_pll_frame_switch_simulation='NOT_RUN',
    actual_board_clock_serial_frequency_jitter='NOT_RUN',
    physical_hdmi_acceptance='NOT_RUN', physical_camera_ddr='NOT_RUN',
    prior_camera_test_suite='NOT_RERUN_UNCHANGED_PRODUCTION',
    early_rounds=dict(r1='FAIL_TEST_REFERENCE_HEX_CASE_RETAINED',
        r2='SIM_PASS_TD_INTERNAL_PASS_CONSTRAINT_AUDIT_REJECTED_HOLD_SCOPE',
        r3='TD_INTERNAL_PASS_LOCK_CUT_SCOPE_REFINED_IN_R4',
        r4='FINAL_INTERNAL_STA_AND_CONSTRAINT_AUDIT_PASS_EXTERNAL_BUDGETS_OPEN'))
(out / 'tests.json').write_text(json.dumps(tests, indent=2) + '\n')
readme = f"""# F：旧版参考的内部时钟诊断（待上板）

直接易失下载根目录 `{label}`，TD工程 `td_project/clock_probe.al`。
不需要重新编译。用户手动操作唯一板卡，保留原可用Flash。
操作：SW1下拨等5秒 → 上拨等5秒 → 再下拨等3秒，拍顶端全部文字。
下拨720p60、上拨1080p30；SW2无作用。即使上拨输入不支持，仍等5秒
再下拨。不要换bit；同一镜像会保存最近完整1080统计，返回720读取。
若下拨也不能显示，记录现象，可断电恢复原Flash，不覆盖旧固化镜像。

画面P/H/V为每50,000,000个板端参考周期实际累计的像素时钟/行/帧事件，
均以十六进制显示，VALID第一位720、第二位FHD，1才表示完整稳定窗口。
目标参考值（不是预设读数）：P约046CF710；720 H约0000AFC8/V约0000003C；
FHD H约000083D6/V约0000001E。边界量化可差1，绝对精度依赖板端50MHz。
无相机/DDR，P/H/V不代表采集FPS，也不是外部串行时钟或抖动测量。

旧可显示镜像SHA c3a1cce7d4a19d6750c0e6f3e36395a3c2f3d31901834a1b13a76f497a9230f8
已核对207项输入；旧OSD FPS测相机，旧HDMI标称1024×600/60.9299Hz。
F参考其独立50MHz秒窗口方式与同一底层PHY，并保留E已能往返的
同一PLL/编码器/串行器和720/1080栅格。没有修改PLL频率、同步极性或VS相位。
共同像素74.25MHz/串行371.25MHz，5:1；7201650×750、10802200×1125。
旧版可显示事实保留；此次仍不预判根因，不宣称1080问题已修复。

仿真：冻结参考先于测试。r1 %X测试参考小写字母与大写UI不一致FAIL保留；
r2只修参考大小写，RTL/通过准则不改。计数/Gray/回绕/初始混合窗口/
停钟/失锁抖动/恢复/复位、194位邮箱停钟原子快照、完整720/FHD OSD
3712500拍及3级RGB/DE/HS/VS一致延迟PASS。完整串行引脚反解全部RGB
（初始零计数OSD）、同步、行帧数、直流平衡及两次SW往返PASS。
完整引脚测试为理想共用5:1 PLL+厂商ODDR；真实PLL完整F帧/往返未运行，
动态1秒读数的串行完整帧未运行。系统计数单元使用显式1000周期短窗口。
构建r4与仿真r2的{len(bindings)}项HDL/测试/参考输入逐字节绑定一致。

TD6.2.178840最终setup {timing['setup_wns_ns']:+.3f}ns/hold {timing['hold_wns_ns']:+.3f}ns，TNS0/违例端点0，
Slice{resources['slice']['used']}/21216、ERAM{resources['eram']['used']}/108、DSP{resources['dsp']['used']}/40、PLL{resources['pll']['used']}/6、GCLK{resources['gclk']['used']}/32，覆盖{coverage}%。
6项最大物理延迟预算有效匹配，dummy/invalid/ignored/no-path0。
r2跨域hold豁免受打包别名影响，审计拒绝；r4全部恢复正常hold检查，
锁定信号豁免限制到两个硬PLL lock源引脚，不能切其他同步来源。
59条pixel→serial建立/保持路径有效，预算没有替代PLL或硬件频率测量。
3条PHY-5016、2异步输入无延迟及4TMDS外部预算告警仍开放；内部STA
通过不等于所有板级路径或显示器接受通过。报告及原始失败日志保留。

旧production/release/Example不改，原采集与HDMI30fps目标保持。
相机FHD独立ISP数值、物理DDR压力、尺寸/采集FPS/RAW/GRAY人工门槛及
最终EDGE/组合/稳定性未测；ENABLE_EDGE=0、CLASS_CALIBRATED=0。
F只供诊断，阶段2未通过，不能进入完整功能或称为已验收版本。

`OLD_user_identified_working.bit`为用户指定旧镜像副本，仅放桌面便于回退，
SHA与上述旧release相同。需要时由用户易失下载或断电加载已有Flash。
新F SHA-256：{sha(bit)}，{bit.stat().st_size}字节。
"""
for folder in (out, desktop):
    (folder / 'README.md').write_text(readme, encoding='utf-8')
(desktop / 'SHA256SUMS.txt').write_text(sha(desktop / label) + '  ' + label + '\n' + sha(desktop / 'OLD_user_identified_working.bit') + '  OLD_user_identified_working.bit\n')
(out / 'SHA256SUMS.txt').write_text(''.join(sha(p) + '  ' + p.relative_to(out).as_posix() + '\n'
    for p in sorted(out.rglob('*')) if p.is_file()), encoding='utf-8')
print(json.dumps(summary, indent=2))
