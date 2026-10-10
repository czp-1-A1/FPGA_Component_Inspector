"""Package E only after frozen independent full-raster/switch and final TD checks pass."""
from pathlib import Path
import argparse, hashlib, json, re, shutil, zipfile
engine = Path(__file__).resolve().parents[1]
ap = argparse.ArgumentParser()
ap.add_argument('freeze', type=Path)
ap.add_argument('--desktop', type=Path, required=True)
ap.add_argument('--early', type=Path, nargs='*', default=[])
args = ap.parse_args()
root = args.freeze.resolve()
desktop = args.desktop.resolve()
out = engine / 'release/native_1080p30/dual_mode_diagnostic_20261010'
if out.exists() or desktop.exists():
    raise SystemExit('Refusing existing release or desktop folder')
def sha(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()
def validate_inputs(tree):
    meta = json.loads((tree / 'freeze.json').read_text(encoding='utf-8-sig'))
    for e in meta['inputs']:
        assert sha(tree / e['path']) == e['sha256'], e['path']
    for e in meta['vendor_models']:
        assert sha(Path(e['path'])) == e['sha256'], e['path']
    return meta
meta = validate_inputs(root)
assert meta['project'] == 'dual_mode' and len(meta['inputs']) == 14 and len(meta['vendor_models']) == 9
log = (root / 'sim/dual_pins.console.log').read_text(errors='replace')
assert 'PASS E dual-mode pins:720p60 to1080p30 to720p60' in log and '** Fatal:' not in log and '** Error:' not in log
frames = re.findall(r'OBS E full frame mode([01]) words(\d+) pixels(\d+) lines(\d+), HD(\d+) FHD(\d+) transitions(\d+)', log)
assert frames and frames[-1][-1] == '2' and frames[-1][0] == '0'
for mode, words, pixels, lines, hd, fhd, switches in frames:
    assert (int(words), int(pixels), int(lines)) == ((1237500,921600,720) if mode == '0' else (2475000,2073600,1080))
name = meta['project']
runs = root / 'td_project' / (name + '_Runs')
phy = runs / 'phy_1'
console = (phy / 'console.log').read_text(errors='replace')
timing = {}
for key in ('Setup', 'Hold'):
    matches = re.findall(key + r'\s*:\s*WNS\s+(-?\d+)ps\s+TNS\s+(-?\d+)ps\s+NUM_FEPS\s+(\d+)', console)
    assert matches, key + ' timing missing'
    wns, tns, endpoints = map(int, matches[-1])
    assert wns >= 0 and tns == 0 and endpoints == 0, key + ' final timing not passing'
    timing[key.lower() + '_wns_ns'] = wns / 1000
assert 'ERROR' not in console and 'Error' not in console
area = (phy / (name + '_phy.area')).read_text()
resources = {}
for key in ('slice', 'eram', 'dsp', 'pll', 'gclk'):
    m = re.search(r'(?m)^#' + key + r'\s+(\d+)\s+out of\s+(\d+)', area)
    assert m and int(m[1]) <= int(m[2]), key
    resources[key] = dict(used=int(m[1]), capacity=int(m[2]))
final = (phy / 'final_timing.rpt').read_text()
assert float(re.search(r'SWNS:\s*([\d.-]+)ns', final)[1]) == timing['setup_wns_ns']
assert float(re.search(r'HWNS:\s*([\d.-]+)ns', final)[1]) == timing['hold_wns_ns']
coverage = float(re.search(r'STA coverage\s*:\s*([\d.]+)%', final)[1])
assert 'clkc[0] ->' in final and 'clkc[1]' in final
assert re.search(r'0 Viol Endpoints,\s+59 Total Endpoints,\s+59 Paths Analyzed', final)
coverage_log = (phy / 'constraint_coverage.txt').read_text()
assert 'checking dummy node(0)' in coverage_log
assert 'checking invalid constraint(0)' in coverage_log
assert 'checking shadowed/ignored timing exception constraints(0)' in coverage_log
assert re.search(r'2\s+2\s+0\s+0\s+set_max_delay -datapath_only 2.0', coverage_log)
assert len(re.findall('PHY-5016 WARNING', console)) == 3
assert 'I_mode_select' in area and 'A4' in area
bit = phy / (name + '.bit')
assert bit.stat().st_size > 100000
al = (root / 'td_project' / (name + '.al')).read_text()
refs = re.findall(r'<File Path="([^"]+)"', al)
assert len(refs) == 8 and 'hdmi_ideal_pll' not in al and 'native_hdmi_pll.v' in al and name + '_top' in al
assert all((root / 'td_project' / r).resolve().exists() for r in refs)
out.mkdir(parents=True)
desktop.mkdir(parents=True)
def snapshot(tree, metadata, destination):
    destination.mkdir(parents=True, exist_ok=True)
    shutil.copy2(tree / 'freeze.json', destination / 'input_snapshot.json')
    with zipfile.ZipFile(destination / 'input_snapshot.zip', 'w', zipfile.ZIP_DEFLATED) as z:
        for e in metadata['inputs']:
            z.write(tree / e['path'], e['path'])
    for p in (tree / 'sim').glob('*.log'):
        q = destination / 'simulation' / p.name
        q.parent.mkdir(exist_ok=True)
        shutil.copy2(p, q)
snapshot(root, meta, out)
for early in args.early:
    early = early.resolve()
    snapshot(early, validate_inputs(early), out / 'early_rounds' / early.name)
build_inputs = []
for run in ('syn_1', 'phy_1'):
    for p in (runs / run).iterdir():
        if p.is_file() and (p.suffix in ('.log', '.logw', '.rpt', '.txt', '.area', '.stat', '.cfg', '.tcl', '.prj', '.ts', '.timing') or 'report' in p.name):
            q = out / 'reports' / run / p.name
            q.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(p, q)
        if p.name in ('settings.cfg', 'build.tcl', name + '.prj'):
            build_inputs.append(dict(path=p.relative_to(root).as_posix(), sha256=sha(p)))
(out / 'generated_build_inputs.json').write_text(json.dumps(build_inputs, indent=2) + '\n')
label = 'E_720p60_1080p30.bit'
shutil.copy2(bit, out / label)
shutil.copy2(bit, desktop / label)
for e in meta['inputs']:
    q = desktop / e['path']
    q.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(root / e['path'], q)
shutil.copytree(runs, desktop / 'td_project' / (name + '_Runs'))
for p in [desktop / 'td_project' / (name + '.al'), *list((desktop / 'td_project' / (name + '_Runs')).glob('*/*.prj'))]:
    p.write_text(re.sub(r'(<Project[^>]* Path=")[^"]+', lambda m: m[1] + (desktop / 'td_project').as_posix(), p.read_text(), count=1))
for r in re.findall(r'<File Path="([^"]+)"', (desktop / 'td_project' / (name + '.al')).read_text()):
    p = (desktop / 'td_project' / r).resolve()
    assert p.is_relative_to(desktop) and p.exists(), r
assert sha(bit) == sha(desktop / label) == sha(desktop / 'td_project' / (name + '_Runs') / 'phy_1' / (name + '.bit'))
rollback = engine / 'release/native_1080p30/stage2_base_20261008/rollback.bit'
assert sha(rollback) == 'bb6a71443b74790c64ceec562236799dc5b9418c07f4634c141b4df2a8bb9d65'
shutil.copy2(rollback, desktop / 'rollback.bit')
shutil.copy2(engine / 'tools/native_toolchain.json', out / 'toolchain.json')
audit = dict(
    status='INTERNAL_TIMING_PASS_EXTERNAL_BUDGETS_OPEN',
    setup_hold_both_corners=dict(setup_tns_ns=0, hold_tns_ns=0, violating_endpoints=0),
    related_pixel_to_serial_paths=dict(max_paths=59, min_paths=59, endpoints=59),
    mode_synchronizer=dict(first_stage_async_input_false_path_only=True,
        interstage_datapath_max_ns=2.0, actual_data_path_ns=0.307, max_slack_ns=1.629,
        packed_location='x030y048z2', checked_report='reports/phy_1/dual_mode_exception.timing'),
    invalid_dummy_no_clock_or_ignored_constraints=0,
    pll_frequency_mismatch_checks=0,
    target_clocks_mhz=dict(reference=50.0, intermediate=33.75, pixel=74.25, serial=371.25),
    displayed_sta_serial_mhz=371.333,
    displayed_sta_serial_explanation='2.693ns displayed precision inverse, not measured hardware frequency',
    pll_locations=dict(reference='x043y079z0', output='x000y039z0'),
    gclk_locations=dict(reference='x023y039z16', pixel='x023y039z0', serial='x023y039z1'),
    warnings=[dict(code='PHY-5016', text=line.strip(), status='OPEN_PHYSICAL_CLOCK_IO_AUDIT')
        for line in console.splitlines() if 'PHY-5016 WARNING' in line],
    no_input_delay=dict(ports=['I_rst_n','I_mode_select'], status='ASYNCHRONOUS_RESET_SWITCH_NO_EXTERNAL_SYNCHRONOUS_BUDGET'),
    no_output_delay=dict(ports=['O_tmds_ch0_p','O_tmds_ch1_p','O_tmds_ch2_p','O_tmds_clk_p'], status='OPEN_EXTERNAL_TMDS_BOARD_BUDGET'),
    full_real_pll_switch_simulation='NOT_RUN', analog_frequency_jitter_and_signal_integrity='NOT_RUN', physical_acceptance='NOT_RUN')
exception_log = (phy / 'dual_mode_exception.timing').read_text()
assert 'Data Path Delay     : 0.307ns' in exception_log and 'Slack               : 1.629ns' in exception_log
assert 'x030y048z2' in exception_log
(out / 'constraint_audit.json').write_text(json.dumps(audit, indent=2) + '\n')
summary = dict(bit=label, sha256=sha(bit), bytes=bit.stat().st_size,
    desktop_bit=(desktop / label).as_posix(), desktop_al=(desktop / 'td_project' / (name + '.al')).as_posix(),
    source_freeze=root.name, physical_acceptance='NOT_RUN', setup_tns_ns=0, hold_tns_ns=0,
    violating_endpoints=0, sta_coverage_percent=coverage, all_paths_timing_accepted=False,
    resources=resources, simulated_complete_hd_frames=int(frames[-1][4]), simulated_complete_fhd_frames=int(frames[-1][5]), simulated_transitions=2, **timing)
(out / 'diagnostic.json').write_text(json.dumps(summary, indent=2) + '\n')
readme = """# E同一镜像720p60/1080p30对照（诊断，待上板）

TD易失下载根目录E_720p60_1080p30.bit；工程td_project/dual_mode.al。
用户手动操作唯一板卡，保留旧Flash。下载一次，SW1下拨=720p60，
上拨=1080p30。每次等2–3秒，先下、再上、再下，记录色条/输入不支持
及显示器信息；SW2无作用。只在消抖20ms后的完整帧边界应用请求。
即使上拨1080不支持，也保持此bit，直接下拨检查720能否恢复。

同一份bit、同一组PLL、同一PHY/编码器/串行器、同一时钟及布线；
切换只改变栅格尺寸、色条分界及同步信号，PLL与串行器不随模式复位。
两种模式分别复现旧B720p60和旧C1080p30对齐VS格式，不发送AVI/音频。
720:1280×720、1650×750、HS1390..1430、VS725..730x0。
1080:1920×1080、2200×1125、HS2008..2052、
VS1083x2008至1088x2008，44拍/5行正同步。
共同目标像素74.25MHz、串行371.25MHz，5:1；两级PLL原源码保持。
TD串行371.333MHz为2.693ns时钟周期显示精度倒数，不能当成硬件实测。
没有相机或DDR；此色条结果不替代采集30fps/阶段2人工门槛。

预先冻结独立引脚参考与RTL：实际串行引脚反解，检查全部RGB像素、
行/帧计数、同步相位、顺序、直流平衡、SW接点抖动/20ms资格及
720→1080→720完整帧切换，并检查时钟连续、PLL不失锁/显示不复位。
PASS为严格5:1理想PLL+厂商ODDR模型；真实PLL完整E往返未运行。
先前D真实PLL16行PASS仍仅是D短行证据。未证明板上频率/抖动或根因。
14项冻结输入、9厂商模型SHA、6项生成构建输入、原始日志归档。
r1脚本文件名错误编译FAIL与冻结保留，r2仅修运行脚本，不改变参考/RTL。

TD6.2.178840最终setup/hold WNS见diagnostic.json，TNS0/违例端点0，
Slice163/21216、ERAM0/108、DSP0/40、PLL2/6、GCLK3/32，覆盖99.78%。
相关像素至串行路径有效分析；SW仅第一同步级异步输入设false path，
级间datapath max2ns有效约束，第二级仍受正常时钟约束。
3条PHY-5016、异步reset/SW无输入延迟、4个TMDS外部预算告警保留；
没有dummy/invalid/ignored例外，内部STA通过不等于全部板级路径闭合。

现场事实：旧B正常且信息1280×720p60；A/C/D和原相机/厂商TPG失败。
用户确认其他设备1080p30使用同一显示器、同一HDMI口及线正常。
E物理结果尚未获得，不宣称修复；也不能预设同一镜像E720必定成功。
原25相机测试本轮未重跑；FHD独立ISP数值、物理DDR、输入尺寸/FPS、
RAW/GRAY及最终实物项目未测。阶段2门槛未过，不进入EDGE/组合集成。

rollback.bit SHA bb6a71443b74790c64ceec562236799dc5b9418c07f4634c141b4df2a8bb9d65
为仓库旧候选，不声称就是用户可用Flash。若需回退由用户易失下载或
板卡断电重新加载已有Flash；不要覆盖已确认可用的旧固化镜像。
"""
(out / 'README.md').write_text(readme, encoding='utf-8')
(desktop / 'README.md').write_text(readme, encoding='utf-8')
(out / 'SHA256SUMS.txt').write_text(''.join(sha(p) + '  ' + p.relative_to(out).as_posix() + '\n'
    for p in sorted(out.rglob('*')) if p.is_file()), encoding='utf-8')
print(json.dumps(summary, indent=2))
