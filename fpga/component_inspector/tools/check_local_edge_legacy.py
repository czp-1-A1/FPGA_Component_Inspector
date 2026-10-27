from pathlib import Path
import argparse,json,re,hashlib
from collections import deque
import numpy as np
ap=argparse.ArgumentParser();ap.add_argument('--project',type=Path,required=True);args=ap.parse_args()
P=args.project.resolve();O=P/'sim';sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
raw=(O/'modelsim_work/edge_legacy_negatives/console.log').read_bytes()
text=raw.decode('utf-16' if raw.startswith((b'\xff\xfe',b'\xfe\xff')) else 'utf-8-sig')
assert 'PASS CONTEXT_GUARD32:' in text and '** Fatal:' not in text
yy,xx=np.indices((128,288));xx=xx+512;yy=yy+256
def point(x,y,left,top,size,px,py):
    ax=x-left-px;ay=y-top-py
    return np.where((ax>=0)&(ax<size)&(ay>=0)&(ay<size)&~(((ax<2)|(ax>=size-2))&((ay<2)|(ay>=size-2))),110,30)
def fixture(test,case):
    if test=='context_edge36':
        phase=case%2;margin=[8,12,16,18,19,20,21,24,32][(case%18)//2];mirrored=case>=18
        image=np.where((xx>=(360+phase if mirrored else 640+phase-margin))&(xx<(640+phase+margin if mirrored else 920+phase))&(yy>=260)&(yy<352),30,150)
        a=point(xx,yy,636,316,10,phase,0);image=np.where(a>30,a,image)
        for left in ([560+phase,496+phase] if mirrored else [684+phase,748+phase]):
            bx=xx-left;by=yy-298
            on=(bx>=0)&(bx<36)&(by>=0)&(by<44)&~(((bx<4)|(bx>=32))&((by<8)|(by>=36)))
            image=np.where(on,180,image)
        target=(640+phase,320)
    else:
        phase=case%2 if case<16 else (case-24)%2 if case>=24 else 0;yp=(case%4)//2 if case<16 else 0
        blur=0 if test=='context_no_body4' else [0,2,4,6][case//4] if case<16 else 6 if case==23 else 0
        left=586 if case==20 else 636;top=356 if case==17 else 274 if case==18 else 316
        size=12 if case==18 else 4 if case==19 else 14 if case==22 else 10
        image=np.full(xx.shape,30,dtype=np.int64)
        if case!=16:
            a=sum(point(xx+k,yy,left,top,size,phase,yp) for k in range(-blur,blur+1))//(2*blur+1)
            area=(xx>=left-14)&(xx<left+size+14)&(yy>=top-4)&(yy<top+size+4)
            image=np.where(area,a,image)
        if test!='context_no_body4' and case!=23:
            for body_left in [572,684]:
                bx=xx-body_left;by=yy-298
                on=(bx>=0)&(bx<36)&(by>=0)&(by<44)&~(((bx<4)|(bx>=32))&((by<8)|(by>=36)))
                image=np.where(on,180,image)
        if case==20:image=np.where(point(xx,yy,left,top,size,phase,yp)>30,220,image)
        if case==21:image=np.where((xx>=616)&(xx<632)&(yy>=312)&(yy<328),150,image)
        if case>=24:
            phase=(case-24)%2;left_patch=616 if (case-24)//4==0 else 648
            bottom=(case-24)%4>=2
            image=np.where((xx>=left_patch+phase)&(xx<left_patch+16+phase)&(yy>=(312 if bottom else 296))&(yy<(344 if bottom else 324)),150,image)
        target=(left+phase+size//2,top+yp+size//2)
    return image.astype(np.uint8),target
def component_box(avg,tx,ty):
    cx=tx//2-256;cy=ty//2-128
    assert avg[cy,cx]>=80,(tx,ty)
    seen={(cx,cy)};q=deque(seen)
    while q:
        x,y=q.popleft()
        for nx,ny in [(x-1,y),(x+1,y),(x,y-1),(x,y+1)]:
            if 0<=nx<144 and 0<=ny<64 and (nx,ny) not in seen and avg[ny,nx]>=80:
                seen.add((nx,ny));q.append((nx,ny))
    return min(x for x,y in seen)+256,max(x for x,y in seen)+256,min(y for x,y in seen)+128,max(y for x,y in seen)+128
pgms={int(p.stem.split('_',1)[1].strip()):p for p in O.glob('input_*.pgm')}
assert set(pgms)==set(range(32));reports=[]
results=[dict(re.findall(r'(\w+)=([^ ]+)',line)) for line in text.splitlines() if line.startswith('# RESULT ')]
assert len(results)==32
for i,row in enumerate(results):
 assert int(row['case'])==i
 data=pgms[i].read_bytes().split(b'\n',3);assert data[:3]==[b'P5',b'288 128',b'255']
 actual=np.frombuffer(data[3],np.uint8).reshape(128,288);expected,target=fixture('context_guard32',i)
 assert np.array_equal(actual,expected),(i,'literal fixture pixels differ')
 avg=actual.astype(np.uint16).reshape(64,2,144,2).sum(axis=(1,3))//4
 packet=int(row['records'],16);empties=[]
 for k in range(8):
  rec=(packet>>(76*k))&((1<<76)-1)
  if not rec>>75 or (rec>>73)&3!=3:continue
  x0=(rec>>31)&2047;y0=(rec>>10)&1023;x1=(rec>>20)&2047;y1=rec&1023
  # Record uses source-pixel bounds; CCL operates in half-resolution cells.
  cx=(x0+x1)//2;cy=(y0+y1)//2
  assert abs(cx-target[0])<=4 and abs(cy-target[1])<=4,(i,cx,cy,target)
  box=component_box(avg,*target)
  assert ((x0+2)//2,(x1-4)//2,(y0+2)//2,(y1-4)//2)==box,(i,box,(x0,x1,y0,y1))
  empties.append((x0,x1,y0,y1))
 want=1 if i<12 else 0
 assert int(row['empty'])==len(empties)==want,(i,row,empties)
 reports.append({'case':i,'input_sha256':sha(pgms[i]),'empty':want,'actual_empty_bounds':empties})
result={'status':'PASS_32_ORIGINAL_LITERAL_NEGATIVES_WITH_LOCAL_EDGE_ENABLED','frames':32,'pixels':32*288*128,'positive':12,'negative':20,'xor0':True,'cases':reports,'not_board_accuracy':True,'checker_sha256':sha(Path(__file__))}
(O/'edge_legacy_independent_reference.json').write_text(json.dumps(result,indent=2),encoding='utf8')
print(result['status'])
