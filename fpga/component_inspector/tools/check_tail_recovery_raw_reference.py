"""Independent actual-pixel finite-tail oracle; no forced DUT records."""
from pathlib import Path
import json,re,hashlib,argparse
import numpy as np
from check_motion_recovery_raw_reference import components,record
def verify(sim,output):
 b=(sim/'modelsim_work/tail_recovery_raw/console.log').read_bytes()
 log=b.decode('utf-16' if b.startswith((b'\xff\xfe',b'\xfe\xff')) else 'utf-8-sig')
 assert 'PASS tail recovery raw:' in log and '** Fatal:' not in log
 rows=re.findall(r'REF region cadence frame=(\d+) objects=([0-9a-fA-F]+)',log)
 assert [int(a) for a,_ in rows]==list(range(1,13))
 checked=[];count=0;fields=['x0','x1','y0','y1','w','h','fg']
 for fs,packet in rows:
  frame=int(fs);path=sim/f'region_cadence_{frame}.pgm'
  with path.open(encoding='ascii') as f:
   assert [f.readline().strip() for _ in range(3)]==['P2','1280 720','255']
   image=np.fromstring(f.read(),dtype=np.int32,sep=' ').reshape(720,1280)
  refs=components(image,100);value=int(packet,16);assert value>>152==0
  expected=[-1,0] if frame<=7 else [] if frame==9 else [-1]
  actual=[record((value>>(76*i))&((1<<76)-1)) for i in range(2)]
  unknown=[r for r in actual if r['valid'] and r['kind']==1]
  actual=[r for r in actual if r['valid'] and r['kind']>=2]
  assert len(actual)==len(expected),(frame,actual,expected)
  observations=[]
  for r,index in zip(actual,expected):
   assert r['kind']==2 and 310<=(r['y0']+r['y1'])/2<=330
   assert abs((r['x0']+r['x1'])/2-(538+(frame-1)*20+index*44))<=6
   matches=[ref for ref in refs if all(ref[k]==r[k] for k in fields)]
   assert len(matches)==1,(frame,r,matches)
   observations.append({'actual':r,'reference':matches[0],'physical_index':index})
  count+=len(actual);checked.append({'frame':frame,'pgm_sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'objects':observations,'unknown_reports_not_counted':unknown})
 result={'status':'PASS_INDEPENDENT_FINITE_TAIL_NATIVE_RAW_PIXELS_AND_SEQUENCE','source_frames':12,'classified_objects':count,'physical_board_accuracy':'NOT_ASSERTED','frames':checked}
 output.write_text(json.dumps(result,indent=2),encoding='utf-8');return result
if __name__=='__main__':
 ap=argparse.ArgumentParser();ap.add_argument('sim',type=Path);ap.add_argument('--output',type=Path,required=True);a=ap.parse_args();print(verify(a.sim,a.output)['status'])
