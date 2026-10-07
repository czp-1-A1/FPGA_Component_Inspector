"""Numerical analysis of a ruler in a photographed monitor; no image editing.

Requires Pillow and NumPy. Run from any directory. Outputs a provisional local
horizontal scale; assumes adjacent visible ruler ticks represent 1 mm.
"""
from pathlib import Path
import json
import numpy as np
from PIL import Image

root = Path(__file__).resolve().parent
array = np.asarray(Image.open(root / 'photo_01_ruler_raw.jpg').convert('L'))
profile = np.median(array[545:561, :], axis=0)
smooth = np.convolve(profile, np.ones(5) / 5, mode='same')
background = np.convolve(smooth, np.ones(41) / 41, mode='same')
darkness = background - smooth
candidates = [x for x in range(450, 1130)
              if darkness[x] > 1.0 and darkness[x] >= max(darkness[x-3:x+4])]
ticks = []
for x in sorted(candidates, key=lambda x: -darkness[x]):
    if all(abs(x-other) >= 15 for other in ticks):
        ticks.append(x)
ticks.sort()
assert len(ticks) == 29
assert all(20 <= gap <= 28 for gap in np.diff(ticks))

# Manually read green border centers in the original 1706x1279 photo.
# Border coordinates come from the existing RTL, not the ruler observations.
photo_anchors = [(387, 398), (1183, 404), (1164, 791), (399, 764)]
fpga_anchors = [(256, 172), (767, 172), (767, 427), (256, 427)]
matrix, target = [], []
for (x, y), (u, v) in zip(photo_anchors, fpga_anchors):
    matrix.extend([[x,y,1,0,0,0,-u*x,-u*y],
                   [0,0,0,x,y,1,-v*x,-v*y]])
    target.extend([u,v])
h = np.append(np.linalg.solve(matrix, target), 1.0).reshape(3,3)

def map_point(x, y):
    p = h @ np.array([x, y, 1.0])
    return (p[:2] / p[2]).tolist()

mapped = [map_point(x, 553.0) for x in ticks]
source_x = [p[0] for p in mapped]
pixels_per_mm = (source_x[-1] - source_x[0]) / (len(source_x)-1)
result = dict(
    source='photo_01_ruler_raw.jpg', photo_size=[array.shape[1],array.shape[0]],
    scan_rows=[545,560], tick_centers_photo_px=ticks,
    tick_interval_photo_px=np.diff(ticks).tolist(),
    photo_anchors_px=photo_anchors, fpga_anchors_px=fpga_anchors,
    photo_to_fpga_homography=h.tolist(), mapped_tick_centers=mapped,
    assumed_tick_mm=1.0, horizontal_source_pixels_per_mm=pixels_per_mm,
    approximate_80px_width_mm=80/pixels_per_mm,
    approximate_512px_width_mm=512/pixels_per_mm,
    extrapolated_1024px_width_mm=1024/pixels_per_mm,
    vertical_field='not_measured',
    limitations=['Manual border anchors, blurred ruler and photographed screen',
                 'Homography corrects screen perspective only',
                 'Ruler/object coplanarity and camera distance origin unconfirmed',
                 'Local horizontal scale; full width is an extrapolation, not edge-to-edge measurement',
                 'Second photo uses a different UI/crop and is not combined'])
print(json.dumps(result, ensure_ascii=False, indent=2))
