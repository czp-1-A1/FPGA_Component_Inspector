"""Independent NumPy reference over archived post-RGB rasters and published tuples."""
from pathlib import Path
import hashlib
import json
import re
import numpy as np

P=Path(__file__).resolve().parents[1]
text=(P/'sim/modelsim_work/surface_raw_chain/console.log').read_text(encoding='utf-8-sig')
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
packets={int(f):int(s,16) for f,s in re.findall(r'PROBE native frame(\d+) checks\d+ packet=([0-9a-f]+)',text)}
rows=[];probes=0
for frame,word in re.findall(r'REF region cadence frame=(\d+) objects=([0-9a-f]+)',text):
 frame=int(frame);path=P/'sim'/f'region_cadence_{frame}.pgm'
 data=path.read_text(encoding='ascii').split()
 assert data[:4]==['P2','1280','720','255']
 image=np.array(data[4:],dtype=np.int32).reshape(720,1280)
 cell=image.reshape(360,2,640,2).sum(axis=(1,3))//4
 q=cell>>3;packet=int(word,16)
 for slot in range(4):
  ob=(packet>>(76*slot))&((1<<76)-1)
  assert ob>>75==1 and (ob>>73)&3==2
  width=(ob>>49)&127;height=(ob>>42)&127;x0=(ob>>31)&2047;y0=(ob>>10)&1023
  cx=(x0+2)//2+width//4;cy=(y0+2)//2+height//4
  slices=[(slice(cy-4,cy+4),slice(cx-4,cx+4)),
          (slice(cy-4,cy+4),slice(cx-8,cx-4)),
          (slice(cy-4,cy+4),slice(cx+4,cx+8)),
          (slice(cy-8,cy-4),slice(cx-4,cx+4)),
          (slice(cy+4,cy+8),slice(cx-4,cx+4))]
  means=[int(q[s].sum()//q[s].size) for s in slices]
  expected=means[0]>=13 and 5*min(means[1:])>=4*means[0] and width>=32 and height>=32
  reason=(ob>>69)&15
  assert bool(reason&8)==(not expected),(frame,slot,means,reason)
  if slot%2==0:
   probe=(packets[frame]>>(64*(slot//2)))&((1<<64)-1)
   for f,s in enumerate(slices):
    m=int(cell[s].sum()//cell[s].size)
    assert ((probe>>(32-8*f))&255)==m,(frame,slot,f,m)
    probes+=1
  rows.append(dict(frame=frame,slot=slot,center_half=[cx,cy],means5=means,
                   reference_normal=bool(expected),reason=reason,raster_sha256=sha(path)))
assert len(rows)==24 and probes==60
result=dict(status='PASS_INDEPENDENT_ARCHIVED_NATIVE_RASTERS',
            surface_decisions=len(rows),feature_references=5*len(rows),probe_exact_mean_comparisons=probes,
            simulation_pixels_not_field_raw=True,rows=rows)
(P/'P02_NATIVE_RASTER_VERIFICATION.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
print('PASS archived native rasters:24 quality decisions from120 five-bit means;60 exact eight-bit probe means')
