"""Independent actual post-ISP PGM components, physical sequence and source events."""
from pathlib import Path
import json,re,hashlib,argparse
import numpy as np
from check_motion_recovery_raw_reference import components,record

def verify(sim,output,name):
    leading=name=='start_entry_raw';frames=22 if leading else 11
    b=(sim/'modelsim_work'/name/'console.log').read_bytes()
    log=b.decode('utf-16' if b.startswith((b'\xff\xfe',b'\xfe\xff')) else 'utf-8-sig')
    assert 'PASS '+name.replace('_',' ')+':' in log and '** Fatal:' not in log
    rows=re.findall(r'SPEED_CANDIDATES source=(\d+) data=([0-9a-fA-F]+)',log)
    assert [int(a) for a,_ in rows]==list(range(1,frames+1)),rows
    fields=['x0','x1','y0','y1','w','h','fg'];checked=[];objects=0;seen_upstream={};pixel_crossings={}
    for fs,packet in rows:
        frame=int(fs);path=sim/f'region_cadence_{frame}.pgm'
        with path.open(encoding='ascii') as f:
            assert [f.readline().strip() for _ in range(3)]==['P2','1280 720','255']
            image=np.fromstring(f.read(),dtype=np.int32,sep=' ').reshape(720,1280)
        refs={2:components(image,100),3:components(image,80)}
        value=int(packet,16);assert value>>304==0
        typed=[record((value>>(76*i))&((1<<76)-1)) for i in range(4)]
        typed=[r for r in typed if r['valid'] and r['kind']>=2]
        shift=(frame-1)*20 if leading else ((frame-1)*20 if frame<=3 else 64 if frame==4 else 92 if frame==5 else 124+(frame-6)*32)
        first=(402 if leading else 558)+shift;physical=[];observations=[]
        for r in typed:
            cx=(r['x0']+r['x1'])/2;cy=(r['y0']+r['y1'])/2
            index=round((cx-first)/44)
            assert index in (0,-1,-2,-3) and 310<=cy<=330,(frame,r,index)
            assert abs(cx-(first+index*44))<=6
            expected_kind=(3 if index==0 else 2) if leading else (3 if index in (-1,-2) else 2)
            assert r['kind']==expected_kind,(frame,index,r)
            matches=[q for q in refs[r['kind']] if all(q[k]==r[k] for k in fields)]
            assert len(matches)==1,(frame,r,matches)
            pixel_cx=(matches[0]['x0']+matches[0]['x1'])//2
            if pixel_cx<636:seen_upstream[index]=True
            if seen_upstream.get(index) and pixel_cx>644 and index not in pixel_crossings:pixel_crossings[index]=frame
            assert index not in physical,'No duplicate actual retained/nearest observation'
            physical.append(index);observations.append({'actual':r,'reference':matches[0],'physical_index':index})
        if frame==1 and leading:assert 0 in physical,'Leading E must really classify at the entry before any body anchor'
        objects+=len(typed);checked.append({'frame':frame,'pgm_sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'objects':observations})
    events=[tuple(map(int,row)) for row in re.findall(r'SPEED_EVENT id=(\d+) source=(\d+) kind=(\d+)',log)]
    if leading:
        assert set(pixel_crossings)=={0,-1,-2,-3},pixel_crossings
        expected=[(1,pixel_crossings[0],3),(2,pixel_crossings[-1],2),(3,pixel_crossings[-2],2),(4,pixel_crossings[-3],2)]
    else:expected=[(1,5,2),(2,7,3),(3,8,3),(4,9,2)]
    assert events==expected,events
    result={'status':'PASS_INDEPENDENT_START_SPEED_NATIVE_COMPONENTS_AND_ACTUAL_SOURCE_EVENTS','test':name,'source_frames':frames,'classified_objects':objects,'events':events,'physical_board_accuracy':'NOT_ASSERTED','frames':checked}
    output.write_text(json.dumps(result,indent=2),encoding='utf-8');return result

if __name__=='__main__':
    ap=argparse.ArgumentParser();ap.add_argument('sim',type=Path);ap.add_argument('--test',choices=['start_entry_raw','speed_raw','dual_raw_motion'],required=True);ap.add_argument('--output',type=Path,required=True)
    a=ap.parse_args();print(verify(a.sim,a.output,a.test)['status'])
