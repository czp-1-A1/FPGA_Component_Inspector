from pathlib import Path
from collections import deque
import re,json,hashlib
import numpy as np
import argparse
ap=argparse.ArgumentParser();ap.add_argument('--project',type=Path,required=True);ap.add_argument('--test',choices=['edge_detector','edge_adversary'],default='edge_detector');args=ap.parse_args()
P=args.project.resolve();O=P/'sim';MANIFEST=P/'R17_FROZEN_INPUTS.json'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
raw=(O/'modelsim_work'/args.test/'console.log').read_bytes()
log=raw.decode('utf-16' if raw.startswith((b'\xff\xfe',b'\xfe\xff')) else 'utf-8-sig')
def fields(line):return dict(re.findall(r'(\w+)=([^ ]+)',line))
pgms={int(p.stem.split('_',1)[1].strip()):p for p in O.glob('rgb_*.pgm')}
results=[fields(s) for s in log.splitlines() if s.startswith('# RESULT ')]
comparisons=[fields(s) for s in log.splitlines() if s.startswith('# COMP ')]
proofs=[fields(s) for s in log.splitlines() if s.startswith('# PROOF ')]
expected_frames=24 if args.test=='edge_adversary' else 21
assert len(results)==expected_frames
yy,xx=np.mgrid[224:416,384:896]
def ellipse(cx,cy,w,h):
    return ((xx-(cx-w//2)+.5)/(w/2)-1)**2+((yy-(cy-h//2)+.5)/(h/2)-1)**2<=1
def components(a,threshold):
    remaining=set(zip(*np.where(a>=threshold)[::-1]));out=[]
    while remaining:
        start=remaining.pop();todo=deque([start]);points=[start]
        while todo:
            x,y=todo.popleft()
            for pt in [(x-1,y),(x+1,y),(x,y-1),(x,y+1)]:
                if pt in remaining:remaining.remove(pt);todo.append(pt);points.append(pt)
        out.append(points)
    return out
GX=np.array([[-1,0,1],[-2,0,2],[-1,0,1]],dtype=np.int64);GY=GX.T
reports=[];field_checks=0;edge_checks=0
for raw in results:
    r={k:int(v) for k,v in raw.items() if k!='record'};i=r['case']
    p=pgms[i];data=p.read_bytes().split(b'\n',3)
    assert data[:3]==[b'P5',b'512 192',b'255']
    actual=np.frombuffer(data[3],np.uint8).reshape(192,512)
    def aperture(xoffset):
        x=xx+xoffset;cx=640+r['px'];cy=r['empty_y']+r['py'];w,h=r['w'],r['h']
        on=((x-(cx-w//2)+.5)/(w/2)-1)**2+((yy-(cy-h//2)+.5)/(h/2)-1)**2<=1
        if r['filled']:on=(x>=cx-w//2)&(x<cx-w//2+w)&(yy>=cy-h//2)&(yy<cy-h//2+h)
        return np.where(on,r['level'],30)
    image=np.full(actual.shape,30,dtype=np.int64)
    if i!=15:
        blurred=sum(aperture(k) for k in range(-r['blur'],r['blur']+1))//(2*r['blur']+1)
        image=np.where((xx>=620)&(xx<660)&(yy>=r['empty_y']-16)&(yy<r['empty_y']+16),blurred,image)
    if r['body']:
        for left in [572,684]:
            bx=xx-left;by=yy-298
            image=np.where((bx>=0)&(bx<36)&(by>=0)&(by<44)&~(((bx<4)|(bx>=32))&((by<8)|(by>=36))),180,image)
    if r['feed']:
        for cx in [584,640,696]:image=np.where(ellipse(cx,360,16,14),180,image)
    assert np.array_equal(actual,image),(i,'literal captured input differs')
    avg=actual.astype(np.uint16).reshape(96,2,256,2).sum(axis=(1,3))//4
    measured=[]
    for g in components(avg,80):
        x0=min(x for x,y in g)+192;x1=max(x for x,y in g)+192
        y0=min(y for x,y in g)+112;y1=max(y for x,y in g)+112
        if 620<=x0+x1<=660:
            measured.append((x0+x1,y0+y1,x1-x0+1,y1-y0+1,len(g)))
    logged=[a for a in comparisons if int(a['case'])==i]
    assert len(logged)==len(measured),(i,logged,measured)
    for a,m in zip(logged,sorted(measured,key=lambda z:z[1])):
        assert tuple(map(int,a['xy'].split(',')))+tuple(map(int,a['wh'].split(',')))+(int(a['fg']),)==m,(i,a,m)
        field_checks+=5
    q=avg.astype(np.int64)>>3
    for a in [a for a in proofs if int(a['case'])==i]:
        x0,x1,y0,y1=map(int,a['bbox'].split(','));cx=x0+(x1-x0+1)//2;cy=y0+(y1-y0+1)//2
        strengths=[]
        for side,(x,y) in enumerate([(x0,cy),(x1,cy),(cx,y0),(cx,y1)]):
            patch=q[y-112-1:y-112+2,x-192-1:x-192+2]
            dx=int((patch*GX).sum());dy=int((patch*GY).sum());strengths.append(max([dx,-dx,dy,-dy][side],0))
        packed=sum(v<<(8*k) for k,v in enumerate(strengths))
        assert packed==int(a['edge'],16),(i,strengths,a)
        assert (sum(v>=8 for v in strengths)>=3)==bool(int(a['edge_ok'])),(i,a)
        edge_checks+=4
    expected_e=int(i<21 and i not in [15,16,17,18,19]);expected_p=0 if i in [12,17] else 2
    assert r['E']==expected_e and r['P']==expected_p,(i,r)
    reports.append({'case':i,'capture_sha256':sha(p),'literal_pixels_xor':0,'expected_empty':expected_e,'actual_empty':r['E'],'actual_present':r['P'],'old_empty':r['OLD_E'],'new_cycles':r['new_cycles'],'old_cycles':r['old_cycles']})
assert field_checks>150 and edge_checks>=64
out={'status':'PASS_INDEPENDENT_LITERAL_RGB_CCL_AND_SIGNED_SOBEL_PROOFS','manifest_sha256':sha(MANIFEST),'frames':expected_frames,'pixels':expected_frames*512*192,'CCL_fields':field_checks,'signed_sobel_kernels':edge_checks,'rescued_R21_misses':sum(r['actual_empty']>r['old_empty'] for r in reports),'designed_scenes_not_field_accuracy':True,'scenes':reports}
(O/'edge_detector_independent_reference.json').write_text(json.dumps(out,indent=2),encoding='utf-8')
print(json.dumps({k:v for k,v in out.items() if k!='scenes'}))
