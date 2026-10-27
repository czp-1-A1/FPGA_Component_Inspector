from pathlib import Path
import argparse,json,re,hashlib
import numpy as np
ap=argparse.ArgumentParser();ap.add_argument('--project',type=Path,required=True);a=ap.parse_args();P=a.project.resolve();S=P/'sim';U=S/'present_motion/unit'
raw=(S/'modelsim_work/present_trace_unit/console.log').read_bytes();log=raw.decode('utf-16' if raw.startswith((b'\xff\xfe',b'\xfe\xff')) else 'utf-8-sig')
rows=re.findall(r'PTRACE_UNIT case=(\d+) metrics=([0-9a-f]+) wait=(\d+)',log);assert len(rows)==34
from importlib.util import spec_from_file_location,module_from_spec
truth=json.loads((U/'independent_reference.json').read_text())['cases']
packed=np.array([int(x,16) for x in (U/'fixtures.hex').read_text().split()],np.uint32).reshape(34,196,64);q=np.zeros((34,196,256),np.int64)
for lane in range(4):q[:,:,lane::4]=(packed>>(lane*5))&31
GX=np.array([[-1,0,1],[-2,0,2],[-1,0,1]],np.int64);GY=GX.T
checked=0
for ci,data,wait in rows:
 i=int(ci);c=truth[i];x0,x1,y0,y1=c['bounds'];cx=x0+(x1-x0+1)//2;cy=y0+(y1-y0+1)//2;z=q[i]
 if i<26:assert int(data,16)==0 and int(wait)==108;continue
 sums=[int(b.sum()) for b in [z[cy-116:cy-108,cx-196:cx-188],z[cy-116:cy-108,cx-200:cx-196],z[cy-116:cy-108,cx-188:cx-184],z[cy-120:cy-116,cx-196:cx-188],z[cy-108:cy-104,cx-196:cx-188]]]
 gradients=[]
 for side,(x,y) in enumerate([(x0,cy),(x1,cy),(cx,y0),(cx,y1)]):
  patch=z[y-113:y-110,x-193:x-190];dx=int((patch*GX).sum());dy=int((patch*GY).sum());gradients.append([dx,-dx,dy,-dy][side])
 good=sum(g>=8 for g in gradients);center=sums[0]//64;minimum=min(x//32 for x in sums[1:]);fail=int(center<13)|(int(minimum*5<center*4)<<1)|(int(2*max(sums[1:])>sums[0]+16)<<2)|(int(good<3)<<3)
 value=0
 for n,bits in [(sums[0],11),*((v,10) for v in sums[1:]),*((g&511,9) for g in gradients),(good,3),(int((fail&7)==0),1),(int(fail==0),1),(1,1),(fail,8)]:value=(value<<bits)|n
 assert int(data,16)==value and int(wait)==684,(i,data,value)
 assert sums==c['sums'] and gradients==c['signed_gradients'];checked+=1
assert checked==8 and 'PASS PRESENT_TRACE_UNIT:' in log
out={'status':'PASS_INDEPENDENT_34_INPUTS_8_P_METRICS_PLUS_FROZEN_CONTROL_ASSERTIONS','cases':34,'P_metrics':checked,'manifest_sha256':hashlib.sha256((P/'R17_FROZEN_INPUTS.json').read_bytes()).hexdigest(),'console_sha256':hashlib.sha256(raw).hexdigest()}
(S/'present_motion/unit_independent_result.json').write_text(json.dumps(out,indent=2),encoding='utf-8');print(json.dumps(out))
