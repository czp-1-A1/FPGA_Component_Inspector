from pathlib import Path
import numpy as np

root=Path(__file__).resolve().parent
x=np.arange(1024,dtype=np.int32)[None,:]
y=np.arange(600,dtype=np.int32)[:,None]
lines=[]
for fid in (1,2):
    r=(x*3+y*5+fid*17)&255
    g=(x*7+y*11+fid*31)&255
    b=(x*13+y*17+fid*47)&255
    gray=(r+2*g+b)//4
    gx=gray[:-2,2:]+2*gray[1:-1,2:]+gray[2:,2:]-gray[:-2,:-2]-2*gray[1:-1,:-2]-gray[2:,:-2]
    gy=gray[2:,:-2]+2*gray[2:,1:-1]+gray[2:,2:]-gray[:-2,:-2]-2*gray[:-2,1:-1]-gray[:-2,2:]
    core=(np.abs(gx)+np.abs(gy))[259:339,471:551]
    pixels=core.size
    edges=int(np.sum(core>=80))
    strength=int(core.sum())
    lines.append(f'{strength:08x}{edges:04x}{pixels:04x}\n')
    print(f'fid={fid} independent core pixels={pixels} edges={edges} sum={strength}')
(root/'reference_core_stats.hex').write_text(''.join(lines),encoding='ascii')
