"""Independent 2x2-mask/connected-component check of actual post-ISP PGM dumps.

The physical input sequence is the fixed synthetic native RAW motion fixture;
this does not substitute for camera/board ground truth. No DUT internals are
forced, and no output is used to generate an expected component.
"""
from pathlib import Path
from collections import deque
import argparse, hashlib, json, re
import numpy as np

def components(image, threshold):
    half = image.reshape(360, 2, 640, 2).sum(axis=(1, 3)) // 4
    mask = half >= threshold
    seen = np.zeros(mask.shape, dtype=bool)
    result = []
    for y in range(120, 200):
        for x in range(200, 440):
            if not mask[y, x] or seen[y, x]:
                continue
            queue = deque([(y, x)])
            seen[y, x] = True
            xmin = xmax = x
            ymin = ymax = y
            count = bright = 0
            while queue:
                yy, xx = queue.popleft()
                count += 1
                bright += int(half[yy, xx] >= 100)
                xmin, xmax = min(xmin, xx), max(xmax, xx)
                ymin, ymax = min(ymin, yy), max(ymax, yy)
                for dy, dx in [(-1, 0), (1, 0), (0, -1), (0, 1)]:
                    ny, nx = yy + dy, xx + dx
                    if 0 <= ny < 360 and 0 <= nx < 640 and mask[ny, nx] and not seen[ny, nx]:
                        seen[ny, nx] = True
                        queue.append((ny, nx))
            result.append({'x0': max(0, xmin * 2 - 2), 'x1': min(1280, xmax * 2 + 4),
                           'y0': max(0, ymin * 2 - 2), 'y1': min(720, ymax * 2 + 4),
                           'w': (xmax - xmin + 1) * 2, 'h': (ymax - ymin + 1) * 2,
                           'fg': min(8191, count * 4), 'bright_cells': bright})
    return result

def record(value):
    return {'valid': (value >> 75) & 1, 'kind': (value >> 73) & 3, 'reason': (value >> 69) & 15,
            'fg': (value >> 56) & 8191, 'w': (value >> 49) & 127, 'h': (value >> 42) & 127,
            'x0': (value >> 31) & 2047, 'x1': (value >> 20) & 2047,
            'y0': (value >> 10) & 1023, 'y1': value & 1023}

def verify(sim, output):
    b = (sim / 'modelsim_work/classified_raw_motion/console.log').read_bytes()
    log = b.decode('utf-16' if b.startswith((b'\xff\xfe', b'\xfe\xff')) else 'utf-8-sig')
    assert 'PASS classified raw motion:' in log and '** Fatal:' not in log, 'Native motion test not passed'
    rows = re.findall(r'REF region cadence frame=(\d+) objects=([0-9a-fA-F]+)', log)
    assert [int(a) for a, _ in rows] == list(range(1, 8)), 'Seven complete actual source dumps required'
    checked = []
    fields = ['x0', 'x1', 'y0', 'y1', 'w', 'h', 'fg']
    for frame_string, packet in rows:
        frame = int(frame_string)
        path = sim / f'region_cadence_{frame}.pgm'
        with path.open() as f:
            assert f.readline().strip() == 'P2'
            assert f.readline().strip() == '1280 720'
            assert f.readline().strip() == '255'
            image = np.fromstring(f.read(), dtype=np.int32, sep=' ')
        assert image.size == 1280 * 720
        image = image.reshape(720, 1280)
        refs = {2: components(image, 100), 3: components(image, 80)}
        value = int(packet, 16)
        assert value >> 152 == 0, 'Inactive fixed region supplied a target'
        objects = []
        for index in range(2):
            actual = record((value >> (76 * index)) & ((1 << 76) - 1))
            assert actual['valid'] and actual['kind'] in (2, 3)
            center_x = (actual['x0'] + actual['x1']) / 2
            center_y = (actual['y0'] + actual['y1']) / 2
            assert 310 <= center_y <= 330, 'Round feed row counted as a pocket'
            physical_index = round((center_x - (602 + (frame - 1) * 8)) / 80)
            assert abs(center_x - (602 + (frame - 1) * 8 + physical_index * 80)) <= 6
            kind = 3 if (physical_index + 300) % 3 == 0 else 2
            assert actual['kind'] == kind, ('Physical class mismatch', frame, actual, kind)
            matches = [ref for ref in refs[kind] if all(ref[k] == actual[k] for k in fields)]
            assert len(matches) == 1, ('Independent mask geometry/foreground mismatch', frame, actual, matches)
            if kind == 3:
                assert matches[0]['bright_cells'] <= 5, 'Empty fixture outside original T80 recipe'
            objects.append({'actual': actual, 'reference': matches[0], 'physical_index': physical_index})
        checked.append({'frame': frame, 'pgm_sha256': hashlib.sha256(path.read_bytes()).hexdigest(), 'objects': objects})
    result = {'status': 'PASS_INDEPENDENT_NATIVE_RAW_MASK_GEOMETRY_AND_PHYSICAL_SEQUENCE',
              'source_frames': 7, 'classified_objects': 14, 'method': 'independent NumPy2x2 average, deque4-neighbor components; native fixture class/position truth',
              'physical_board_accuracy': 'NOT_ASSERTED', 'frames': checked}
    output.write_text(json.dumps(result, indent=2), encoding='utf-8')
    return result

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('sim', type=Path)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    result = verify(args.sim, args.output)
    print(result['status'], result['source_frames'], 'native frames,', result['classified_objects'], 'classified objects')
