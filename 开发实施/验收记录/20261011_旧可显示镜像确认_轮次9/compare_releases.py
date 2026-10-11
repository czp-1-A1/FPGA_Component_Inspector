"""Read-only audit of the user-identified old bit and frozen stage2 inputs."""
from pathlib import Path
from fractions import Fraction
import hashlib
import json
import re
import sys
import zipfile

repo, output = map(Path, sys.argv[1:])
assert not output.exists()
old_release = repo / 'fpga/component_inspector/release/edge_diagnostic_20261007'
old_snapshot = repo / '开发实施/验收记录/20261007_A_EDGE冻结诊断_轮次1/source_snapshot'
new_release = repo / 'fpga/component_inspector/release/native_1080p30/stage2_base_20261008'
old_manifest = json.loads((old_release / 'manifest.json').read_text(encoding='utf-8'))
new_manifest = json.loads((new_release / 'input_snapshot.json').read_text(encoding='utf-8'))
new_metadata = json.loads((new_release / 'release.json').read_text(encoding='utf-8'))

def sha(data):
    return hashlib.sha256(data).hexdigest()

old_bit = old_release / 'camera_to_dsi_display.bit'
assert sha(old_bit.read_bytes()) == old_manifest['bit']['sha256'] == (
    'c3a1cce7d4a19d6750c0e6f3e36395a3c2f3d31901834a1b13a76f497a9230f8')
assert old_bit.stat().st_size == old_manifest['bit']['bytes'] == 1789539
for item in old_manifest['build_inputs']:
    data = (old_snapshot / item['path']).read_bytes()
    assert len(data) == item['bytes'] and sha(data) == item['sha256'], item['path']
assert len(old_manifest['build_inputs']) == 207
assert sha((new_release / 'camera_to_dsi_display.bit').read_bytes()) == new_metadata['bit_sha256']

common = ['user_source/hdl_source/' + filename for filename in (
    'design_top_wrapper.v', 'experiment_osd.v', 'input_monitor.v', 'hdmi_tx.v',
    'hdmi_phy_warpper.v', 'hdmi_1_4b_transmitter_core_wrapper.enc.v', 'vtc/uivtc.v')]
common += ['user_source/ip_source/PLL/PLL.v']
old_data = {path: (old_snapshot / path).read_bytes() for path in common}
new_data = {}
source_differences = []
expected_new = {item['path']: item for item in new_manifest['inputs']}
with zipfile.ZipFile(new_release / 'input_snapshot.zip') as archive:
    for path in common + ['user_source/hdl_source/native_hdmi_pll.v']:
        data = archive.read(path)
        assert sha(data) == expected_new[path]['sha256']
        assert len(data) == expected_new[path]['bytes']
        new_data[path] = data
        source_differences.append(dict(path=path, old_sha256=sha(old_data[path])
            if path in old_data else None, new_sha256=sha(data),
            unchanged=path in old_data and old_data[path] == data))

top_path = 'user_source/hdl_source/design_top_wrapper.v'
old_top, new_top = (data[top_path].decode('utf-8') for data in (old_data, new_data))

def geometry(top):
    result = {}
    for name in ('H_ActiveSize', 'H_FrameSize', 'H_SyncStart', 'H_SyncEnd',
                 'V_ActiveSize', 'V_FrameSize', 'V_SyncStart', 'V_SyncEnd'):
        value = re.search(r'\.' + name + r'\s*\(\s*(\w+)\s*\)', top)[1]
        if not value.isdigit():
            value = re.search(r'\b' + value + r'\s*=\s*(\d+)', top)[1]
        result[name] = int(value)
    return result

old_geometry, new_geometry = map(geometry, (old_top, new_top))
assert old_geometry == dict(H_ActiveSize=1024, H_FrameSize=1344, H_SyncStart=1184,
    H_SyncEnd=1208, V_ActiveSize=600, V_FrameSize=635, V_SyncStart=612, V_SyncEnd=614)
assert new_geometry == dict(H_ActiveSize=1920, H_FrameSize=2200, H_SyncStart=2008,
    H_SyncEnd=2052, V_ActiveSize=1080, V_FrameSize=1125, V_SyncStart=1084, V_SyncEnd=1089)
pll = old_data['user_source/ip_source/PLL/PLL.v'].decode('utf-8')
dividers = {name: int(re.search(r'\.' + name + r'\s*\(\s*(\d+)\s*\)', pll)[1])
    for name in ('REFCLK_DIV', 'FBCLK_DIV', 'CLKC0_DIV', 'CLKC4_DIV', 'CLKC5_DIV')}
assert dividers == dict(REFCLK_DIV=1, FBCLK_DIV=2, CLKC0_DIV=13, CLKC4_DIV=25, CLKC5_DIV=5)
assert '.FBKCLK("CLKC0_EXT")' in pll and '.fbclk(clk0_out)' in pll
assert re.search(r'\.clk4_out\s*\(\s*S_hdmi_pixel_clk\s*\)', old_top)
assert re.search(r'\.clk5_out\s*\(\s*S_hdmi_serial_clk\s*\)', old_top)
monitor = old_data['user_source/hdl_source/input_monitor.v'].decode('utf-8')
assert 'REF_HZ=50000000' in monitor and 'if(frame_start)' in monitor
assert 'fps<=window_frames' in monitor
assert '.frame_start(S_raw10_frame_start)' in old_top
assert '.ref_clk(I_sys_clk)' in old_top
assert '.fps(mon_fps)' in old_top and '.fps(mon_display[127:112])' in old_top
old_pixel = Fraction(50000000 * 2 * 13, 25)
new_pixel = Fraction(50000000 * 108 * 33, 5 * 32 * 15)
result = dict(status='PASS_FROZEN_SOURCE_AND_BIT_BINDING', date='2026-10-11',
    user_identified_old_release='edge_diagnostic_20261007',
    user_reports_old_display_works=True, physical_readback='NOT_RUN',
    old_bit_sha256=old_manifest['bit']['sha256'],
    old_all_207_inputs_sha_verified=True, old_geometry=old_geometry,
    old_pll_dividers=dividers, old_nominal_pixel_hz=int(old_pixel),
    old_nominal_serial_hz=260000000,
    old_nominal_hdmi_refresh_hz=float(old_pixel / (1344 * 635)),
    old_osd_fps_source='RAW10 camera frame_start counted against independent50MHz reference; not display refresh',
    new_bit_sha256=new_metadata['bit_sha256'], new_geometry=new_geometry,
    new_nominal_pixel_hz=int(new_pixel), new_nominal_serial_hz=371250000,
    new_nominal_hdmi_refresh_hz=float(new_pixel / (2200 * 1125)),
    selected_new_inputs_sha_verified=9, source_differences=source_differences,
    source_reference_sha256=sha(Path(__file__).read_bytes()),
    limit='Calculated nominal clocks/raster rate from frozen source and50MHz assumption. No measured FPGA output, Flash readback, new simulation, TD or new bit. Old display success does not itself establish1080p30 acceptance; root cause remains open.')
output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print(json.dumps(result, ensure_ascii=False, indent=2))
