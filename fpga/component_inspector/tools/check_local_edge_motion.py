from pathlib import Path
import hashlib,json,re,sys
import numpy as np
import argparse
ap=argparse.ArgumentParser();ap.add_argument('--project',type=Path,required=True);ap.add_argument('--test',choices=['edge_motion_fast','edge_motion_left'],required=True);a=ap.parse_args();P=a.project.resolve();O=P/'sim'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
M=json.loads((P/'R17_FROZEN_INPUTS.json').read_text());
profiles=[{'name':a.test,'total':15,'empty_ids':[1,2,8,13,15] if a.test=='edge_motion_fast' else [1,3,8,14,15],'right':int(a.test=='edge_motion_fast'),'margin':12,'blur':2,'speed':25,'scene':0}]
yy,xx=np.indices((160,480));xx+=400;yy+=240
def rgb_reference(row,offset):
    total=row['total'];empty=set(row['empty_ids']);right=row['right'];first=(350+offset) if right else (930-offset)
    centers=[first-i*64 if right else first+i*64 for i in range(total)]
    leading=row['margin'] if 1 in empty else 28;trailing=row['margin'] if total in empty else 28
    lo=(centers[-1]-trailing) if right else (centers[0]-leading);hi=(centers[0]+leading) if right else (centers[-1]+trailing)
    carrier=(xx>=lo)&(xx<hi)&(yy>=250)&(yy<350);image=np.where(carrier,30,150)
    for i,cx in enumerate(centers,1):
        dx=xx-cx;dy=yy-320
        if i not in empty:
            on=(dx>=-18)&(dx<18)&(dy>=-22)&(dy<22)&~(((dx< -14)|(dx>=14))&((dy< -14)|(dy>=14)))
            image=np.where(carrier&on,180,image)
        else:
            values=[]
            for q in range(-row['blur'],row['blur']+1):
                x=dx+q
                on=((2*x+1)**2*144+(2*dy+1)**2*196)<=196*144
                values.append(np.where(on,160,30))
            a=sum(values)//(2*row['blur']+1)
            image=np.where(carrier&(dx>=-20)&(dx<=20)&(dy>=-6)&(dy<6),a,image)
        fy=yy-280;a=(dx+7)//2;b=(fy+7)//2
        on=(dx>=-7)&(fy>=-7)&(a>=0)&(b>=0)&(a<7)&(b<7)&~((((a==0)|(a==6))&((b<2)|(b>=5)))|(((a==1)|(a==5))&((b==0)|(b==6))))
        image=np.where(carrier&on,np.where((a>=2)&(a<5)&(b>=2)&(b<5),110,90),image)
    return image.astype(np.uint8),centers
def typed_records(packet):
    out=[]
    for i in range(4):
        word=(packet>>(76*i))&((1<<76)-1)
        if word>>75 and ((word>>73)&3)>=2:
            x0=(word>>31)&2047;x1=(word>>20)&2047;y0=(word>>10)&1023;y1=word&1023
            out.append({'slot':i,'word':word,'class':(word>>73)&3,'cx':(x0+x1)//2,'cy':(y0+y1)//2})
    return out
reports=[]
for row in profiles:
    W=O;log=W/'modelsim_work'/a.test/'console.log';raw=log.read_bytes();text=raw.decode('utf-16' if raw.startswith((b'\xff\xfe',b'\xfe\xff')) else 'utf-8-sig')
    assert 'PASS LOCAL_EDGE_FINITE_MOTION:' in text and '** Fatal:' not in text,(row['name'],'runtime not PASS')
    frames={};captures={};body_comparisons=0
    for line in text.splitlines():
        match=re.search(r'FRAME source=(\d+) offset=(\d+) scene=(\d+) right=(\d+) objects=([0-9a-f]+) oldobjects=([0-9a-f]+) total=(\d+) E=(\d+)',line)
        if not match:continue
        source,offset,scene,right=map(int,match.groups()[:4]);assert offset==(source-1)*row['speed'] and scene==row['scene'] and right==row['right']
        p=W/f'input_{source}.pgm';head=p.read_bytes().split(b'\n',3)
        assert head[:3]==[b'P5',b'480 160',b'255'] and len(head[3])==480*160
        actual=np.frombuffer(head[3],dtype=np.uint8).reshape(160,480);expected,centers=rgb_reference(row,offset)
        assert np.array_equal(actual,expected),(row['name'],source,'RGBfixture XOR not0',int(np.count_nonzero(actual!=expected)))
        captures[source]=sha(p);objects=typed_records(int(match[5],16));old=typed_records(int(match[6],16));mapped={}
        for item in objects:
            j=min(range(row['total']),key=lambda i:abs(centers[i]-item['cx']));physical=j+1
            assert abs(centers[j]-item['cx'])<=4 and abs(item['cy']-320)<=4,(row['name'],source,'unproved object',item,centers[j])
            assert item['class']==(3 if physical in row['empty_ids'] else 2),(row['name'],source,'physicalclass',physical,item)
            assert physical not in mapped,(row['name'],source,'duplicatephysicaltarget',physical)
            mapped[physical]=item
        for item in old:
            j=min(range(row['total']),key=lambda i:abs(centers[i]-item['cx']));physical=j+1
            if item['class']==2 and physical in mapped and mapped[physical]['class']==2:
                assert item['word']==mapped[physical]['word'],(row['name'],source,'existingPrecordchanged',physical)
                body_comparisons+=1
        frames[source]={'offset':offset,'centers':centers,'objects':mapped}
    expected_frames=1350//row['speed']+1
    assert set(frames)==set(range(1,expected_frames+1)),(row['name'],len(frames),expected_frames)
    events=[]
    for source,pocket,kind,reason in re.findall(r'EVENT new source=(\d+) id=(\d+) class=(\d+) reason=([0-9a-f]+)',text):
        source,pocket,kind=int(source),int(pocket),int(kind)
        assert pocket==len(events)+1 and kind==(3 if pocket in row['empty_ids'] else 2)
        assert source in frames and pocket in frames[source]['objects'],(row['name'],'eventwithoutactualsameframeobservation',source,pocket)
        observed=frames[source]['objects'][pocket];assert observed['class']==kind
        d=(observed['cx']-640) if row['right'] else (640-observed['cx']);assert d>4,(row['name'],'eventdidnotactuallycross',source,pocket,observed)
        upstream=[s for s,f in frames.items() if s<source and pocket in f['objects'] and ((f['objects'][pocket]['cx']<636) if row['right'] else (f['objects'][pocket]['cx']>644))]
        assert upstream,(row['name'],'noactualupstreamobservation',source,pocket)
        events.append({'id':pocket,'class':kind,'source':source,'actual_upstream_sources':upstream,'cross_cx':observed['cx']})
    assert len(events)==row['total'] and [e['id'] for e in events if e['class']==3]==row['empty_ids']
    reports.append({'profile':row,'source_frames':len(frames),'actual_RGB_pixels_checked':len(frames)*480*160,'RGB_XOR0':True,'captured_inputs':captures,'unchanged_common_body_record_comparisons':body_comparisons,'events':events,'log_sha256':sha(log)})
out={'status':'PASS_INDEPENDENT_FINITE_RGB_PHYSICAL_IDS_AND_ACTUAL_CROSSINGS','manifest_sha256':sha(P/'R17_FROZEN_INPUTS.json'),'profiles':reports,'frames':sum(r['source_frames'] for r in reports),'pixels':sum(r['actual_RGB_pixels_checked'] for r in reports),'not_field_speed_or_RAW':True,'checker_sha256':sha(Path(__file__))}
(O/'edge_motion_independent_reference.json').write_text(json.dumps(out,indent=2),encoding='utf8')
print(json.dumps({'status':out['status'],'profiles':len(reports),'frames':out['frames'],'pixels':out['pixels']}))
