"""Independent actual-PGM component oracle for ordered finiteP,E,E,P RAW."""
from pathlib import Path
import json,re,hashlib,argparse
import numpy as np
from check_motion_recovery_raw_reference import components,record
def verify(sim,output):
 b=(sim/'modelsim_work/recovery_raw_motion/console.log').read_bytes()
 log=b.decode('utf-16' if b.startswith((b'\xff\xfe',b'\xfe\xff')) else 'utf-8-sig')
 assert 'PASS recovery raw motion:' in log and '** Fatal:' not in log
 rows=re.findall(r'HOLD_CANDIDATES source=(\d+) data=([0-9a-fA-F]+)',log)
 assert [int(a) for a,_ in rows]==list(range(1,19)),rows
 fields=['x0','x1','y0','y1','w','h','fg'];checked=[];objects=0
 for fs,packet in rows:
  frame=int(fs);path=sim/f'region_cadence_{frame}.pgm'
  with path.open(encoding='ascii') as f:
   assert [f.readline().strip() for _ in range(3)]==['P2','1280 720','255']
   image=np.fromstring(f.read(),dtype=np.int32,sep=' ').reshape(720,1280)
  refs={2:components(image,100),3:components(image,80)};value=int(packet,16);assert value>>304==0
  typed=[record((value>>(76*i))&((1<<76)-1)) for i in range(4)]
  typed=[r for r in typed if r['valid'] and r['kind']>=2];physical=[];observations=[]
  for r in typed:
   cx=(r['x0']+r['x1'])/2;cy=(r['y0']+r['y1'])/2
   index=round((cx-(558+(frame-1)*20))/44)
   assert index in (0,-1,-2,-3) and 310<=cy<=330,(frame,r,index)
   assert abs(cx-(558+(frame-1)*20+index*44))<=6
   assert r['kind']==(3 if index in (-1,-2) else 2)
   assert not(index==-2 and 7<=frame<=14),'No event/position from truly absentRAW empty'
   matches=[q for q in refs[r['kind']] if all(q[k]==r[k] for k in fields)]
   assert len(matches)==1,(frame,r,matches)
   assert index not in physical,'No duplicate main/nearest observation'
   physical.append(index);observations.append({'actual':r,'reference':matches[0],'physical_index':index})
  assert len(typed)>=1
  if frame==15:assert -2 in physical,'Actual returned mainEMPTY must reach recorder'
  objects+=len(typed);checked.append({'frame':frame,'pgm_sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'objects':observations})
 events=[tuple(map(int,row)) for row in re.findall(r'HOLD_EVENT id=(\d+) source=(\d+) kind=(\d+)',log)]
 assert events==[(1,6,2),(2,8,3),(3,15,3),(4,12,2)],events
 assert re.search(r'HOLD_NATIVE_COUNT source=18 total=4 present=2 empty=2 R8total=\d+ R8empty=\d+ R8state=3 R8C=4',log)
 result={'status':'PASS_INDEPENDENT_RECOVERY_NATIVE_RAW_COMPONENTS_EVENTS_AND_R8_C4_SENSITIVITY','source_frames':18,'classified_objects':objects,'events':events,'physical_board_accuracy':'NOT_ASSERTED','frames':checked}
 output.write_text(json.dumps(result,indent=2),encoding='utf-8');return result
if __name__=='__main__':
 ap=argparse.ArgumentParser();ap.add_argument('sim',type=Path);ap.add_argument('--output',type=Path,required=True);a=ap.parse_args();print(verify(a.sim,a.output)['status'])
