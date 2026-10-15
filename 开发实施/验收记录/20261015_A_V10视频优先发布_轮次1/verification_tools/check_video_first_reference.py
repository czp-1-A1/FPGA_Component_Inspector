from pathlib import Path
import json,re,sys
import numpy as np

root=Path.cwd();round_path=root/'tmp'/sys.argv[1]
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
        out.append(dict(x0=x0,x1=x1,y0=y0,y1=y1,fg=n,w=bw,h=bh,state=state,reason=reason,cx=cx,cy=cy,distance=abs(cx-256)+abs(cy-150)))
    return sorted(out,key=lambda a:(a['state']<2,a['distance'],-a['fg']))

def record(a,gray):
    cx,cy=a['cx'],a['cy'];dark=gray<=100
    def strip(x0):
        y0=cy-20;y1=cy+20;x1=x0+8
        return int(dark[max(0,y0):min(300,y1),max(0,x0):min(512,x1)].sum()) if x1>0 and x0<512 and y1>0 and y0<300 else 0
    refs=strip(cx-28)>=240 and strip(cx+20)>=240
    state=a['state'];reason=(a['reason']|((not refs)<<3)) if state==2 else 0
    if state!=2 and not refs:state=0
    fields=[(1,1),(state,2),(reason,4),(min(a['fg']*4,8191),13),(min(a['w']*2,127),7),(min(a['h']*2,127),7),
            (max(0,a['x0']*2-2),11),(min(1024,a['x1']*2+4),11),(max(0,a['y0']*2-2),10),(min(600,a['y1']*2+4),10)]
    packed=0
    for v,bits in fields:packed=(packed<<bits)|v
    return packed,dict(**a,published_state=state,published_reason=reason,side_reference_ok=refs)

results=[]
for name,pattern,test in [('frame_case','REF frame case=', 'frame_search'),('native_full','REF native frame=','frame_video'),('native_full','REF native frame=','frame_tailproof'),('native_full','REF native frame=','frame_stop'),('native_full','REF native frame=','frame_process'),('cadence','REF cadence frame=','frame_cadence')]:
    log=round_path/'sim/modelsim_work'/test/'console.log'
    if not log.exists():continue
    lines=log.read_text(encoding='utf-8',errors='replace')
    for m in re.finditer(re.escape(pattern)+r'(\d+) objects=([0-9a-f]+) state=(\d+) FG=(\d+) W=(\d+) H=(\d+) X0=(\d+) X1=(\d+) Y0=(\d+) Y1=(\d+)',lines):
        frame=int(m[1]);path=round_path/'sim'/f'{name}_{frame}.pgm'
        tokens=path.read_text(encoding='ascii').split(maxsplit=4);assert tokens[0]=='P2'
        width,height=int(tokens[1]),int(tokens[2]);gray=np.fromstring(tokens[4],sep=' ',dtype=np.int32).reshape(height,width)
        if width==1024:gray=(gray[::2,::2]+gray[::2,1::2]+gray[1::2,::2]+gray[1::2,1::2])//4
        blobs=components(gray);selected=blobs[:2]
        if len(selected)==2 and (selected[0]['state']==0 or selected[1]['state']==0):selected=selected[:1]
        records=[record(a,gray) for a in selected]
        if len(records)==2 and selected[0]['x0']>=selected[1]['x0']:records.reverse()
        packed=sum(a[0]<<(76*i) for i,a in enumerate(records))
        assert packed==int(m[2],16),(path.name,hex(packed),m[2],records)
        if selected:
            p,detail=record(selected[0],gray)
            expected=[detail['published_state'],min(detail['fg']*4,8191),min(detail['w']*2,127),min(detail['h']*2,127),
                      max(0,detail['x0']*2-2),min(1024,detail['x1']*2+4),max(0,detail['y0']*2-2),min(600,detail['y1']*2+4)]
            assert expected==list(map(int,m.groups()[2:])),(path.name,expected,m.groups()[2:])
        results.append(dict(image=path.name,status='PASS',objects_hex=f'{packed:038x}',objects=[a[1] for a in records]))
assert results,'No actual images/log records verified'
(round_path/'independent_reference_results.json').write_text(json.dumps(results,indent=2),encoding='utf-8')
print('PASS independent full-frame reference:',len(results),'actual masks/images, both component counts/boxes/classes/reasons/order and primary fields')
