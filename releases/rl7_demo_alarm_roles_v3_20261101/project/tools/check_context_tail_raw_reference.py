"""Independent components and named-field event/metadata oracle for R11."""
from pathlib import Path
import argparse,re,json,hashlib,sys
import numpy as np
def verify(source,sim,output):
 sys.path.insert(0,str(source/'tools'))
 from check_motion_recovery_raw_reference import components,record
 b=(sim/'modelsim_work/context_tail_raw/console.log').read_bytes();s=b.decode('utf-16' if b.startswith((b'\xff\xfe',b'\xfe\xff')) else 'utf-8-sig')
 assert 'PASS context_tail_raw:' in s and '** Fatal:' not in s
 packets={int(f):int(v,16) for f,v in re.findall(r'LOCAL_CANDIDATES source=(\d+) data=([0-9a-fA-F]+)',s)}
 assert set(packets)==set(range(1,21))
 fields=['x0','x1','y0','y1','w','h','fg'];checked=[]
 for frame,value in packets.items():
  path=sim/f'region_cadence_{frame}.pgm'
  with path.open(encoding='ascii') as f:
   assert [f.readline().strip() for _ in range(3)]==['P2','1280 720','255']
   image=np.fromstring(f.read(),dtype=np.int32,sep=' ').reshape(720,1280)
  refs={2:components(image,100),3:components(image,80)};assert value>>304==0
  typed=[record(value>>(i*76)&((1<<76)-1)) for i in range(4)];seen=set();rows=[]
  for r in typed:
   if not r['valid'] or r['kind']<2:continue
   cx=(r['x0']+r['x1'])/2;cy=(r['y0']+r['y1'])/2;index=round((cx-(558+(frame-1)*20))/44)
   assert index in (0,-1,-2,-3) and index not in seen;seen.add(index)
   assert abs(cx-(558+(frame-1)*20+index*44))<=6 and 310<=cy<=330
   assert r['kind']==(3 if index in (-1,-2) else 2)
   assert not(index==-2 and 7<=frame<=16),'No classification or event from absent pixels'
   matches=[q for q in refs[r['kind']] if all(q[k]==r[k] for k in fields)]
   assert len(matches)==1,(frame,r,matches)
   rows.append(dict(actual=r,reference=matches[0],physical_index=index))
  if frame==17:assert -2 in seen,'Late actual E return must be supplied'
  checked.append(dict(frame=frame,pgm_sha256=hashlib.sha256(path.read_bytes()).hexdigest(),objects=rows))
 events=[tuple(map(int,r)) for r in re.findall(r'LOCAL_EVENT id=(\d+) source=(\d+) kind=(\d+)',s)]
 assert events==[(1,6,2),(2,8,3),(3,12,2),(4,17,3)],events
 schema=[('source',32),('generation',16),('state',3),('reason',4),('dv',1),('dr',1),('region',1),('total',9),('present',9),('empty',9),('review',9),('object_ids',36),('empty_ids',72),('last_id',9),('last_kind',2),('last_reason',4),('page',6),('valid',1),('visible_run',16),('first_fault',16)]
 assert sum(w for _,w in schema)==256
 tuples=re.findall(r'LOCAL_NATIVE_RESULT source=(\d+) record=([0-9a-fA-F]+)',s);assert len(tuples)==20
 decoded=[]
 for fs,v in tuples:
  frame=int(fs);v=int(v,16);d={};offset=0
  for name,width in schema:d[name]=v>>offset&((1<<width)-1);offset+=width
  count=sum(frame>=p for p in [6,8,15,17]);empty=sum(frame>=p for p in [8,17])
  assert d['source']==frame and d['valid']==1 and d['visible_run']==1 and d['region']==0
  assert d['total']==count and d['empty']==empty and d['present']==count-empty
  assert d['object_ids']>>18==0,'Inactive ROI ID lane stays zero; local recovery/event truth unchanged'
  assert d['state']==(1 if frame<4 else 5 if 11<=frame<=14 else 2),(frame,d)
  assert d['reason']==(1 if frame<4 else 4 if 11<=frame<=14 else 0)
  assert (d['first_fault']==0)==(frame<=10)
  assert d['last_id']==count and d['last_kind']==([0,2,3,2,3][count])
  assert [d['empty_ids']>>(i*9)&511 for i in range(8)]==([2] if frame>=8 else [])+([4] if frame>=17 else [])+[0]*(8-empty)
  numbered={0:(1,6),-1:(2,8),-3:(3,15),-2:(4,17)}
  for lane in range(2):
   r=record(packets[frame]>>(lane*76)&((1<<76)-1));id=d['object_ids']>>(lane*9)&511
   if not r['valid'] or r['kind']<2:assert id==0;continue
   cx=(r['x0']+r['x1'])/2;idx=round((cx-(558+(frame-1)*20))/44);nr,publish=numbered[idx]
   assert id==(nr if frame>=publish else 0),(frame,lane,idx,id,nr)
  decoded.append(dict(frame=frame,fields=d))
 assert re.search(r'LOCAL_NATIVE_COUNT source=20 total=4 present=2 empty=2 R10total=2 R10empty=1 R10state=6 R10C=4',s)
 result=dict(status='PASS_R15_INDEPENDENT_NATIVE_COMPONENTS_ACTUAL_EVENTS_NO_WARNING_AND_PIXEL_ID_BINDING',source_frames=20,events=events,source_schema=schema,frames=checked,metadata=decoded,physical_board_accuracy='NOT_ASSERTED')
 output.write_text(json.dumps(result,indent=2),encoding='utf-8');return result
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--source',type=Path,required=True);p.add_argument('--sim',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args();print(verify(a.source,a.sim,a.output)['status'])
