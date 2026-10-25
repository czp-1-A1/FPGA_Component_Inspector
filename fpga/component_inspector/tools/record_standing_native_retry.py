"""Retain unsuccessful synthetic stimulus before correcting its RAW contrast."""
from pathlib import Path
import hashlib
import json
import shutil

P=Path(__file__).resolve().parents[1]
out=P/'sim/standing/failures/native_stimulus_contrast_r0'
out.mkdir()
for source in [P/'sim/modelsim_work/standing_raw_chain',P/'sim/standing/tb_standing_raw_chain.v',P/'standing_native_runner.log']:
 target=out/source.name
 if source.is_dir(): shutil.copytree(source,target)
 else: shutil.copy2(source,target)
for source in (P/'sim').glob('calibration*'):
 if source.is_file():shutil.copy2(source,out/source.name)
tb=P/'sim/standing/tb_standing_raw_chain.v'
body=tb.read_text(encoding='utf-8')
old='if(pattern==5 && px>=1113 && px<1137 && ((yy>=447 && yy<513) || (yy>=747 && yy<813)))source=760;'
assert body.count(old)==1
tb.write_text(body.replace(old,old.replace('source=760','source=840')),encoding='utf-8')
generator=P/'tools/create_standing_integration.py'
body=generator.read_text(encoding='utf-8');assert body.count(old)==1
generator.write_text(body.replace(old,old.replace('source=760','source=840')),encoding='utf-8')
record=dict(result='FAILED synthetic fixture isolation; not an RTL failure',
 evidence='native first frame Csum1612 maxEdge812; old and new both pass since1624<=1628',
 correction='Only synthetic bright-left RAW intensity760->840; predicate/oracles/old7 frames unchanged',
 frozen_design_unchanged=True, next='rerun all8 RAW frames including original WB cancellation',
 files={f.relative_to(out).as_posix():hashlib.sha256(f.read_bytes()).hexdigest() for f in out.rglob('*') if f.is_file()})
(out/'FAILURE.json').write_text(json.dumps(record,indent=2),encoding='utf-8')
print('Retained failure; only new synthetic RAW bright edge changed. No RTL/oracle change.')
