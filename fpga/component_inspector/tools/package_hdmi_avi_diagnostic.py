"""Package D only after independent serial-frame and final TD checks pass."""
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
out = engine / 'release/native_1080p30/hdmi_avi_diagnostic_20261009'
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
log = (root / 'sim/avi_pins.console.log').read_text(errors='replace')
assert 'PASS HDMI AVI serial: frames2' in log and '** Fatal:' not in log and '** Error:' not in log
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
bit = phy / (name + '.bit')
assert bit.stat().st_size > 100000
al = (root / 'td_project' / (name + '.al')).read_text()
refs = re.findall(r'<File Path="([^"]+)"', al)
assert len(refs) == 9 and 'hdmi_ideal_pll' not in al and 'native_hdmi_pll.v' in al and name + '_top' in al
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
label = 'D_1080p30_HDMI.bit'
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
summary = dict(bit=label, sha256=sha(bit), bytes=bit.stat().st_size,
    desktop_bit=(desktop / label).as_posix(), desktop_al=(desktop / 'td_project' / (name + '.al')).as_posix(),
    source_freeze=root.name, physical_acceptance='NOT_RUN', setup_tns_ns=0, hold_tns_ns=0,
    violating_endpoints=0, sta_coverage_percent=coverage, all_paths_timing_accepted=False,
    resources=resources, **timing)
(out / 'diagnostic.json').write_text(json.dumps(summary, indent=2) + '\n')
readme = '''# D 1080p30 HDMI格式色条（诊断，待上板）

TD易失下载根目录D_1080p30_HDMI.bit，AL为td_project/avi_fhd30.al。
人工操作唯一板卡；保留旧Flash。旧相机/TPG/A/B/C及失败证据均保留。

相对实物失败C，D保留色条、1920×1080、2200×1125、正HS44/VS5，
VS首尾与HS前沿对齐、74.25/371.25MHz目标、同一PLL源码与PHY和TMDS引脚。
增加HDMI视频前导/保护带、数据岛前后保护带和每帧一包AVI（RGB16:9、
默认量化、VIC34、不重复像素，HB82 02 0D、PB2D 00 20 00 22 00…）。
这是格式识别的受控对照，独立布局仍可能改变物理时钟质量，未证明故障根因。
没有相机、DDR或音频，不构成完整HDMI认证或采集30fps验收。

规范参考：https://fpga.mit.edu/6205/_static/F23/common_files/week04/CEC_HDMI_Specification.pdf
作者交叉核对：https://github.com/hdl-util/hdmi/blob/master/src/packet_assembler.sv
量化默认依据：https://github.com/torvalds/linux/blob/master/drivers/gpu/drm/drm_edid.c
控制间隔至少12拍（普通控制＋8拍前导），视频2拍保护带，数据岛2+32+2拍。
视频前导只在下一行有活动图像时发送，包括帧尾接第一行。

运行前冻结接收参考及源码：反解三个实际串行引脚，连续两个完整帧，
每帧2475000符号/2073600 RGB像素/1080行；检查全部边界、正同步相位，
控制间隔/前导/保护带、每帧一次AVI、所有4子包BCH、头BCH及AVI校验和。
PASS为严格5:1理想PLL＋厂商ODDR模型；真实PLL全链及板上频率未测。
TD6.2.178840完整综合/P&R/bitgen，最终WNS/资源见diagnostic.json，
setup/hold TNS0、违例端点0；相关像素至串行路径分析，原PHY-5016告警保留。
复位及4个TMDS外部板级预算仍开放，不能称所有物理路径闭合。
15项预冻结输入、9厂商模型SHA、6项生成构建输入和原始日志均归档。
原25相机测试本轮未重跑，ISP数值参考/物理DDR/实际采集尺寸FPS仍未测。

用户确认C仍输入不支持、B色条可显示但信息菜单看不到读数；其他设备
实际1080p30能显示的用户陈述保留。D仅待人工验证色条/输入不支持。
阶段2人工门槛未通过；不启用EDGE，不改30fps目标或分类UNCAL。
rollback.bit SHA bb6a71443b74790c64ceec562236799dc5b9418c07f4634c141b4df2a8bb9d65
为仓库旧候选，不声称就是用户可用Flash。人工易失下载回退，不固化覆盖旧Flash。
'''
(out / 'README.md').write_text(readme, encoding='utf-8')
(desktop / 'README.md').write_text(readme, encoding='utf-8')
(out / 'SHA256SUMS.txt').write_text(''.join(sha(p) + '  ' + p.relative_to(out).as_posix() + '\n'
    for p in sorted(out.rglob('*')) if p.is_file()), encoding='utf-8')
print(json.dumps(summary, indent=2))
