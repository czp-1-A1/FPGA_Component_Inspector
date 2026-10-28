"""Independent scalar/NumPy reference for two 720p calibration probes."""
import argparse,json
from pathlib import Path
import numpy as np

def expected(rgb,mode,valid=True):
    a=rgb.astype(np.uint16)
    gray=((a[:,:,0]+2*a[:,:,1]+a[:,:,2])//4).astype(np.uint8)
    # Trace/fixtures retain64px context; measure only the centered32px.
    gray=gray[16:48,16:48]
    core=gray[8:24,8:24]
    mask=(gray.astype(np.uint16).reshape(16,2,16,2).sum((1,3))//4)>=[100,80,120,140][mode]
    yy,xx=np.nonzero(mask)
    width=2*(int(xx.max())-int(xx.min())+1) if len(xx) else 0
    height=2*(int(yy.max())-int(yy.min())+1) if len(yy) else 0
    area=4*int(mask.sum())
    clip=bool(mask[0].any() or mask[-1].any() or mask[:,0].any() or mask[:,-1].any())
    fields=[(int(valid),1),(int(clip),1),(mode,2),(int(core.sum())//256,8),(int(core.min()),8),(int(core.max()),8),(int((core==255).sum()),9),(area,13),(width,7),(height,7)]
    bits=0
    for value,size in fields:bits=(bits<<size)|value
    return bits

def image(pattern,zone):
    a=np.zeros((64,64,3),dtype=np.uint8)
    for y in range(64):
        for x in range(64):
            gx=x+608;gy=y+[288,484][zone]
            v=20+(gx+gy)%5
            r=g=b=v
            if pattern==0:
                if zone==0 and 16<=x<48 and 18<=y<46:r,g,b=150+gx%13,110+gy%11,70+(gx+gy)%7
                if zone==1 and (x-32)**2+(y-32)**2<=144:r=g=b=90+(gx+gy)%21
            elif pattern==1:r=g=b=120
            elif pattern==2:r=g=b=255 if (x+y)%2 else 0
            elif pattern==3:r=g=b=0
            elif pattern==4:r=g=b=255 if x>=62 and y>=62 else 0
            elif pattern==5:
                r=g=b=180 if (x-32)**2+(y-32)**2<=36 or y<8 else 20
            a[y,x]=(r,g,b)
    return a

CASES=[(0,0),(0,1),(0,2),(0,3),(1,1),(2,2),(2,3),(3,0),(4,0),(5,0)]
def main():
    p=argparse.ArgumentParser();p.add_argument('--generate',type=Path);p.add_argument('--trace',type=Path);p.add_argument('--records',type=Path);p.add_argument('--output',type=Path);args=p.parse_args()
    if args.generate:
        words=[expected(image(pattern,0),mode)|(expected(image(pattern,1),mode)<<64) for pattern,mode in CASES]
        args.generate.write_text(''.join(f'{x:032x}\n' for x in words),encoding='ascii')
        print('PASS generated 10 independent RGB/2x2-mask reference records')
    if args.trace:
        images={};modes={}
        for line in args.trace.read_text().splitlines():
            f,x,y,mode,word=line.split();f,x,y,mode=map(int,(f,x,y,mode))
            images.setdefault(f,[np.zeros((64,64,3),np.uint8),np.zeros((64,64,3),np.uint8)])
            modes[f]=mode;word=int(word,16)
            for z,y0 in enumerate([288,484]):
                if 608<=x<672 and y0<=y<y0+64:
                    for lane in range(4):
                        px=(word>>(24*(3-lane)))&0xffffff
                        images[f][z][y-y0,x-608+lane]=(px>>16,(px>>8)&255,px&255)
        compared=[]
        for line in args.records.read_text().splitlines():
            f,word=line.split();f=int(f);actual=int(word,16)
            assert f in images,f
            want=expected(images[f][0],modes[f])|(expected(images[f][1],modes[f])<<64)
            assert actual==want,(f,f'{actual:032x}',f'{want:032x}')
            compared.append(f)
        assert len(compared)>=4,compared
        result=dict(status='PASS',frames=compared,reference='RGB before display modes; scalar luma and independent NumPy 2x2 average/threshold/bbox/core statistics')
        if args.output:args.output.write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
        print('PASS independent calibration chain reference:',compared)
if __name__=='__main__':main()
