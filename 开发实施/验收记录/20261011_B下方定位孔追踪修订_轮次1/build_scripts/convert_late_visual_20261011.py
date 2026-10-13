from pathlib import Path
from PIL import Image
import hashlib,json
root=Path(__file__).resolve().parent.parent
build=root/'tmp/tracking_late_visual_td_20261011'
notes=json.loads((build/'visual_notes.json').read_text(encoding='utf-8'))
notes['source_sha256']=hashlib.sha256((root/'fpga/component_inspector/sim/tb_tracking_osd.v').read_bytes()).hexdigest()
notes['rasters']=[]
for p in sorted((build/'sim').glob('tracking_*.ppm')):
    png=p.with_suffix('.png')
    with Image.open(p) as im:
        assert im.size==(1024,600)
        im.save(png)
    notes['rasters'].append(dict(path=png.relative_to(build).as_posix(),bytes=png.stat().st_size,sha256=hashlib.sha256(png.read_bytes()).hexdigest()))
assert len(notes['rasters'])==3
(build/'visual_notes.json').write_text(json.dumps(notes,indent=2)+'\n',encoding='utf-8')
print(json.dumps(notes,indent=2))
