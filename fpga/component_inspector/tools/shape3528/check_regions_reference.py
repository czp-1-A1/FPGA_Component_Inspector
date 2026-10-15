from pathlib import Path
import json,re,sys
import numpy as np

round_path=Path(sys.argv[1])
chain_path=Path(sys.argv[2]) if len(sys.argv)>2 else round_path
def components(gray):
    # Independent two-pass label/equivalence algorithm, not the RTL queue,
    # packed-word addresses, neighbor phases or forwarding implementation.
    fg=gray>=100;labels=np.zeros(fg.shape,dtype=np.int32);parent=[0]
    def find(a):
        while parent[a]!=a:
            parent[a]=parent[parent[a]];a=parent[a]
        return a
    h,w=fg.shape
    for y,x in zip(*np.nonzero(fg)):
        a=labels[y,x-1] if x else 0;b=labels[y-1,x] if y else 0
        if not a and not b:
            a=len(parent);parent.append(a)
        elif not a:a=b
        elif b:
            ra,rb=find(a),find(b)
            if ra!=rb:parent[max(ra,rb)]=min(ra,rb)
        labels[y,x]=a
    roots=np.array([find(i) for i in range(len(parent))],dtype=np.int32)
    yy,xx=np.nonzero(fg);ids=roots[labels[yy,xx]]
    counts=np.bincount(ids,minlength=len(parent))
    xmin=np.full(len(parent),w);ymin=np.full(len(parent),h)
    xmax=np.full(len(parent),-1);ymax=np.full(len(parent),-1)
    np.minimum.at(xmin,ids,xx);np.maximum.at(xmax,ids,xx)
    np.minimum.at(ymin,ids,yy);np.maximum.at(ymax,ids,yy)
    out=[]
    for i in np.nonzero(counts)[0]:
        x0,x1,y0,y1=map(int,[xmin[i],xmax[i],ymin[i],ymax[i]])
        n=int(counts[i]);bw=x1-x0+1;bh=y1-y0+1
        if x0==0 or y0==0 or x1==w-1 or y1==h-1 or n<8 or min(bw,bh)<3:continue
        long,short=max(bw,bh),min(bw,bh);area=bw*bh
        size=26<=long<=39 and 20<=short<=36
        aspect=21*short<=20*long<=31*short;fill=20*n>=17*area
        strict=size and aspect and fill
        soft=26<=long<=43 and 20<=short<=38 and 21*short<=20*long and 5*long<=9*short and 4*n>=3*area
        circular=5*long<=7*short and 5*n>=3*area and 10*n<=9*area
        empty=circular and 5<=long<=13 and 4<=short<=12
        feed=circular and 14<=long<=23 and 10<=short<=21
        state=0 if feed else 2 if strict or soft else 3 if empty else 1
        cx=(x0+x1)//2;cy=(y0+y1)//2
        reason=(not size)|((not aspect)<<1)|((not fill)<<2)
        out.append(dict(x0=x0,x1=x1,y0=y0,y1=y1,fg=n,w=bw,h=bh,state=state,reason=reason,cx=cx,cy=cy,distance=abs(cx-320)+abs(cy-180)))
    return sorted(out,key=lambda a:(a['state']<2,a['distance'],-a['fg']))

def record(a,gray):
    cx,cy=a['cx'],a['cy'];dark=gray<=100
    def strip(x0):
        y0=cy-20;y1=cy+20;x1=x0+8
        return int(dark[max(0,y0):min(360,y1),max(0,x0):min(640,x1)].sum()) if x1>0 and x0<640 and y1>0 and y0<360 else 0
    refs=strip(cx-28)>=240 and strip(cx+20)>=240
    state=a['state'];reason=(a['reason']|((not refs)<<3)) if state==2 else 0
    if state!=2 and not refs:state=1
    fields=[(1,1),(state,2),(reason,4),(min(a['fg']*4,8191),13),(min(a['w']*2,127),7),(min(a['h']*2,127),7),
            (max(0,a['x0']*2-2),11),(min(1280,a['x1']*2+4),11),(max(0,a['y0']*2-2),10),(min(720,a['y1']*2+4),10)]
    packed=0
    for v,bits in fields:packed=(packed<<bits)|v
    return packed,dict(**a,published_state=state,published_reason=reason,side_reference_ok=refs)

# Zone membership and ranking are evaluated from geometric component data,
# independently of the RTL packed mask, queue, scan windows and register banks.
def region_records(gray):
    blobs=components(gray);out=[];packed=0
    for zone,(x0,x1,y0,y1) in enumerate([(400,880,240,400),(400,880,432,600)]):
        candidates=[]
        for a in blobs:
            cx=a['x0']+a['x1'];cy=a['y0']+a['y1']
            if x0<=cx<x1 and y0<=cy<y1 and a['state']!=0:
                candidates.append(dict(a,distance=abs(cx-(x0+x1)//2)+abs(cy-(y0+y1)//2)))
        chosen=sorted(candidates,key=lambda a:(a['state']<2,a['distance'],-a['fg']))[:2]
        chosen.sort(key=lambda a:a['x0'])
        for slot,a in enumerate(chosen):
            word,detail=record(a,gray);packed|=word<<(76*(zone*2+slot))
            out.append(dict(region=zone+1,slot=slot+1,record=word,features=detail))
    return packed,out

def read_image(path):
    tok=path.read_text(encoding='ascii').split(maxsplit=4)
    assert tok[0]=='P2' and int(tok[3])==255,path
    w,h=int(tok[1]),int(tok[2]);g=np.fromstring(tok[4],sep=' ',dtype=np.int32).reshape(h,w)
    if w==1280:g=(g[::2,::2]+g[::2,1::2]+g[1::2,::2]+g[1::2,1::2])//4
    assert g.shape==(360,640),g.shape
    return g
results=[]
for test,prefix,pattern in [('regions','region_case','REF regions case='),('regions_chain','region_cadence','REF region cadence frame=')]:
    case_root=chain_path if test=='regions_chain' else round_path
    log=case_root/'sim/modelsim_work'/test/'console.log'
    raw_log=log.read_bytes()
    lines=raw_log.decode('utf-16' if raw_log.startswith((b'\xff\xfe',b'\xfe\xff')) else 'utf-8-sig')
    matches=list(re.finditer(re.escape(pattern)+r'(\d+) (?:records|objects)=([0-9a-f]+)',lines))
    assert len(matches)==(8 if test=='regions' else 5),(test,len(matches))
    for match in matches:
        path=case_root/'sim'/f'{prefix}_{match[1]}.pgm'
        packed,details=region_records(read_image(path))
        assert packed==int(match[2],16),(path.name,hex(packed),match[2],details)
        results.append(dict(round=str(case_root),image=path.name,status='PASS',records_hex=f'{packed:076x}',objects=details))
(round_path/'independent_regions_reference.json').write_text(json.dumps(results,indent=2)+'\n',encoding='utf-8')
print('PASS independent region reference:',len(results),'actual reduced/full RGB masks, four records/region membership/boxes/classes/reasons/order')
