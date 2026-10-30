"""Check literal captured RAW pixels and the predeclared two-tape events."""
from pathlib import Path
import argparse
import hashlib
import json
import re

import numpy as np


def verify(project):
    sim = project / 'sim'
    path = sim / 'modelsim_work/two_region_raw/console.log'
    raw = path.read_bytes()
    log = raw.decode('utf-16' if raw.startswith(b'\xff\xfe') else 'utf-8-sig')
    assert 'PASS R24_TWO_REGION_RAW:' in log
    assert not re.search(r'^#\s*\*\* (Fatal|Error):', log, re.M)
    events = [(int(b), int(i), int(f), int(k)) for b, i, f, k in re.findall(
        r'DUAL_EVENT bank=(\d+) id=(\d+) source=(\d+) kind=(\d+)', log)]
    for bank in range(2):
        assert [e[1:] for e in events if e[0] == bank] == [
            (1, 5, 2), (2, 7, 3), (3, 8, 3), (4, 9, 2)]
    captures = {}
    for frame in range(1, 12):
        pgm = sim / f'region_cadence_{frame}.pgm'
        tokens = pgm.read_text().split()
        assert tokens[:4] == ['P2', '1280', '720', '255']
        pixels = np.array(tokens[4:], dtype=np.uint8).reshape(720, 1280)
        upper = pixels[240:400, 400:880]
        lower = pixels[400:560, 400:880]
        assert np.array_equal(upper, lower), ('actual tape translation', frame)
        assert np.count_nonzero(upper > 30) > 100, ('missing physical objects', frame)
        captures[pgm.name] = hashlib.sha256(pgm.read_bytes()).hexdigest()
    rows = re.findall(r'SPEED_CANDIDATES source=(\d+) data=([0-9a-f]+)', log)
    assert [int(f) for f, _ in rows] == list(range(1, 12))
    compared = 0
    for frame, packed in rows:
        value = int(packed, 16)
        for slot in range(4):
            a = (value >> (76 * slot)) & ((1 << 76) - 1)
            b = (value >> (304 + 76 * slot)) & ((1 << 76) - 1)
            assert a >> 75 == b >> 75, ('lane validity', frame, slot)
            if a >> 75:
                assert a >> 20 == b >> 20, ('class/reason/geometry', frame, slot)
                assert ((b >> 10) & 1023) - ((a >> 10) & 1023) == 160
                assert (b & 1023) - (a & 1023) == 160
                compared += 1
    cadence = re.findall(r'CADENCE frame=(\d+) .*?LP=([0-9a-f]+)', log)
    assert [int(f) for f, _ in cadence] == list(range(1, 13))
    assert all(3250 <= int(period, 16) <= 3380 for _, period in cadence)
    result = {
        'status': 'PASS_TWO_LANE_NATIVE_PIXELS_CLASSIFIED_OBJECTS_AND_PHYSICAL_EVENT_TRUTH',
        'accepted_native_frames': 12, 'classified_frames': 11, 'canceled_frames': 1,
        'events': events, 'compared_classified_objects': compared,
        'compared_actual_pixels': 11 * 160 * 480,
        'captures_sha256': captures, 'console_sha256': hashlib.sha256(raw).hexdigest(),
        'scope': 'Synthetic RAW and real ISP/DDR simulation; field accuracy not asserted',
    }
    destination = project / 'validation/r24'
    destination.mkdir(parents=True, exist_ok=True)
    (destination / 'native_reference.json').write_text(json.dumps(result, indent=2), encoding='utf8')
    return result


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('project', type=Path)
    result = verify(parser.parse_args().project.resolve())
    print(result['status'], result['compared_actual_pixels'], 'pixels')
