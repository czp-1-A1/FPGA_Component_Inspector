"""Read-only base/CTA EDID timing audit; omit monitor serial identifiers.

Reference: Linux DRM drm_edid.c (svd_to_vic, CTA VIC table, monitor range).
An absent advertised mode is not proof that every custom mode is rejected.
"""
from pathlib import Path
import argparse
import hashlib
import json


def detailed_timing(data):
    clock = int.from_bytes(data[:2], 'little') * 10000
    if not clock:
        return None
    ha = data[2] + ((data[4] >> 4) << 8)
    hb = data[3] + ((data[4] & 15) << 8)
    va = data[5] + ((data[7] >> 4) << 8)
    vb = data[6] + ((data[7] & 15) << 8)
    hs = data[8] + ((data[11] >> 6) << 8)
    hw = data[9] + (((data[11] >> 4) & 3) << 8)
    vs = (data[10] >> 4) + (((data[11] >> 2) & 3) << 4)
    vw = (data[10] & 15) + ((data[11] & 3) << 4)
    assert ha and va and hb and vb and hs + hw <= hb and vs + vw <= vb
    return dict(pixel_hz=clock, width=ha, height=va, h_total=ha + hb,
                v_total=va + vb, h_front_porch=hs, h_sync_width=hw,
                v_front_porch=vs, v_sync_width=vw,
                interlaced=bool(data[17] & 128),
                raster_rate_hz=clock / ((ha + hb) * (va + vb)))


def inspect(raw):
    assert raw[:8] == bytes.fromhex('00ffffffffffff00'), 'EDID header'
    assert len(raw) >= 128 and len(raw) % 128 == 0, 'EDID length'
    assert len(raw) == 128 * (1 + raw[126]), 'Missing/trailing extension'
    sums = [sum(raw[i:i + 128]) % 256 for i in range(0, len(raw), 128)]
    assert all(value == 0 for value in sums), 'EDID checksum'
    assert raw[18] == 1 and raw[19] in (3, 4), 'EDID version unsupported'
    result = dict(bytes=len(raw), sha256=hashlib.sha256(raw).hexdigest(),
                  version=f'{raw[18]}.{raw[19]}', extension_count=raw[126],
                  block_checksums=sums, model=None, range_limits=[],
                  detailed_timings=[], cta_extensions=[], unparsed_extension_tags=[])
    for offset in range(54, 126, 18):
        data = raw[offset:offset + 18]
        timing = detailed_timing(data)
        if timing:
            result['detailed_timings'].append(dict(location=f'base:{offset}', **timing))
        elif data[:3] == b'\0\0\0' and data[3] == 0xfc:
            result['model'] = data[5:18].decode('ascii').strip()
        elif data[:3] == b'\0\0\0' and data[3] == 0xfd:
            # Version1.4 may use byte4 offset flags; preserve/reject unknown flags.
            flags = data[4]
            assert flags & ~15 == 0
            result['range_limits'].append(dict(
                min_v_hz=data[5] + (255 if flags & 1 else 0),
                max_v_hz=data[6] + (255 if flags & 2 else 0),
                min_h_khz=data[7] + (255 if flags & 4 else 0),
                max_h_khz=data[8] + (255 if flags & 8 else 0),
                max_pixel_mhz=data[9] * 10, formula_flag=data[10]))
    for index in range(1, 1 + raw[126]):
        block = raw[index * 128:(index + 1) * 128]
        if block[0] != 2:
            result['unparsed_extension_tags'].append(block[0])
            continue
        end = block[2]
        assert end == 0 or 4 <= end <= 127
        extension = dict(index=index, revision=block[1], video_vics=[],
                         data_blocks=[], extended_video_vics=[])
        pos = 4
        while end and pos < end:
            tag, size = block[pos] >> 5, block[pos] & 31
            assert pos + 1 + size <= end, 'CTA data block boundary'
            data = block[pos + 1:pos + 1 + size]
            extension['data_blocks'].append(dict(offset=pos, tag=tag, size=size))
            if tag == 2 or (tag == 7 and size and data[0] == 14):
                svds = data if tag == 2 else data[1:]
                vics = [svd & 127 if 1 <= svd <= 64 or 129 <= svd <= 192
                        else svd for svd in svds]
                key = 'video_vics' if tag == 2 else 'extended_video_vics'
                extension[key].extend(vics)
            pos += 1 + size
        if end:
            for offset in range(end, 110, 18):
                timing = detailed_timing(block[offset:offset + 18])
                if timing:
                    result['detailed_timings'].append(
                        dict(location=f'CTA{index}:{offset}', **timing))
        result['cta_extensions'].append(extension)
    vics = [vic for ext in result['cta_extensions']
            for vic in ext['video_vics'] + ext['extended_video_vics']]
    result['advertised_1080p30_vic34'] = 34 in vics
    result['advertised_1080p60_vic16'] = 16 in vics
    result['advertised_720p60_vic4'] = 4 in vics
    result['detailed_1080p30'] = [mode for mode in result['detailed_timings']
        if mode['width'] == 1920 and mode['height'] == 1080
        and not mode['interlaced'] and 29 <= mode['raster_rate_hz'] <= 31]
    result['limit'] = ('Declared base DTD/CTA VDB/Y420VDB only; EDID does not '
                       'prove all custom timings, transport waveform or hardware acceptance.')
    return result


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('edid', type=Path)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    if args.output.exists():
        raise SystemExit('Refusing existing output')
    result = inspect(args.edid.read_bytes())
    result['decoder_sha256'] = hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
    args.output.write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
    print(json.dumps(result, indent=2))
