from pathlib import Path
import hashlib
import numpy as np
root=Path(__file__).resolve().parent
w,h=1024,600
x=np.arange(w,dtype=np.int32)[None,:]
y=np.arange(h,dtype=np.int32)[:,None]
for mode in range(4):
    pixel_lines=[]
    word_lines=[]
    for fid in (1,2):
        r=(x*3+y*5+fid*17)&255
        g=(x*7+y*11+fid*31)&255
        b=(x*13+y*17+fid*47)&255
        gray=(r+2*g+b)//4
        output=np.stack([r,g,b],axis=2).astype(np.uint8)
        if mode&1:
            output[172:428,256:768,:]=gray[172:428,256:768,None]
        if mode&2:
            gx=gray[:-2,2:]+2*gray[1:-1,2:]+gray[2:,2:]-gray[:-2,:-2]-2*gray[1:-1,:-2]-gray[2:,:-2]
            gy=gray[2:,:-2]+2*gray[2:,1:-1]+gray[2:,2:]-gray[:-2,:-2]-2*gray[:-2,1:-1]-gray[:-2,2:]
            magnitude=np.abs(gx)+np.abs(gy)
            hits=magnitude[172:426,256:766]>=80
            output[173:427,257:767,:][hits]=[255,174,100]
        pixel_lines.extend(f'{int(p[0]):02x}{int(p[1]):02x}{int(p[2]):02x}'+chr(10) for p in output.reshape(-1,3))
        raw=output.tobytes()
        word_lines.extend(raw[k:k+16].hex()+chr(10) for k in range(0,len(raw),16))
    for kind,lines in [('pixels',pixel_lines),('words',word_lines)]:
        path=root/f'mode_{mode}_{kind}.hex'
        path.write_text(''.join(lines),encoding='ascii')
        print(path.name,path.stat().st_size,hashlib.sha256(path.read_bytes()).hexdigest())
