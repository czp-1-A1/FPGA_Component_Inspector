"""Frozen fixed-field/reference cross-check, independent of the EDID decoder."""
from pathlib import Path
import hashlib
import json
import sys

first, second, decoded_file, capture_file, output = map(Path, sys.argv[1:])
assert not output.exists()
raw = first.read_bytes()
assert raw == second.read_bytes()
expected_sha = '9ab76e3d63361f947c654318459ed6418c73be47cd7ebe39d7ecb20cd4f55a57'
assert hashlib.sha256(raw).hexdigest() == expected_sha
assert len(raw) == 256 and raw[:8].hex() == '00ffffffffffff00'
assert raw[126] == 1 and sum(raw[:128]) % 256 == sum(raw[128:]) % 256 == 0
# Inspect only these public timing fields; never export the serial descriptor.
assert raw[108:126].hex() == '000000fd0030901ee63c000a202020202020'
assert raw[132:145].hex() == '4c101f0514041303120211013f'
expected_vics = [16, 31, 5, 20, 4, 19, 3, 18, 2, 17, 1, 63]
decoded = json.loads(decoded_file.read_text(encoding='utf-8'))
capture = json.loads(capture_file.read_text(encoding='utf-8'))
assert decoded['sha256'] == capture['edid_sha256'] == expected_sha
assert decoded['model'] == capture['model'] == 'Q24G51F'
assert capture['active'] and capture['video_output_technology'] == 5
assert decoded['range_limits'] == [dict(min_v_hz=48, max_v_hz=144,
    min_h_khz=30, max_h_khz=230, max_pixel_mhz=600, formula_flag=0)]
assert decoded['cta_extensions'][0]['video_vics'] == expected_vics
assert decoded['advertised_1080p60_vic16'] is True
assert decoded['advertised_720p60_vic4'] is True
assert decoded['advertised_1080p30_vic34'] is False
assert decoded['detailed_1080p30'] == []
modes = capture['source_modes']
assert len(modes) == capture['source_mode_count'] == 23
fhd = [m for m in modes if m['HorizontalActivePixels'] == 1920
       and m['VerticalActivePixels'] == 1080]
assert len(fhd) == 1 and fhd[0]['VerticalRefreshRateNumerator'] == 60
assert fhd[0]['VerticalRefreshRateDenominator'] == 1
result = dict(status='PASS_FIXED_FIELDS_AND_ASSOCIATION', repeated_capture_identical=True,
    raw_edid_sha256=expected_sha, checksums=[0, 0], active_hdmi_technology=5,
    range_descriptor_offset=108, range_descriptor_hex=raw[108:126].hex(),
    cta_vdb_offset=132, cta_vdb_hex=raw[132:145].hex(), video_vics=expected_vics,
    wmi_source_modes=23, wmi_fhd_source_refresh_hz=60,
    limit='WMI source-mode enumeration is partial and may synthesize timings. Neither WMI nor EDID is a measurement of FPGA output or proof of all custom-mode acceptance.',
    reference_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest())
output.write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
print(json.dumps(result, indent=2))
