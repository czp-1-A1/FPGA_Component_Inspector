"""Independent components of the actual PPC4 stimulus dumps and real events."""
from pathlib import Path
from collections import deque
import argparse,json,re,hashlib
import numpy as np
from check_motion_recovery_raw_reference import record
def components(im,t):
 half=im.reshape(120,2,128,2).sum((1,3))//4;mask=half>=t;seen=np.zeros_like(mask);out=[]
 for y,x in zip(*np.where(mask)):
  if seen[y,x]:continue
  q=deque([(int(y),int(x))]);seen[y,x]=1;xs=[];ys=[]
  while q:
   yy,xx=q.popleft();xs.append(xx);ys.append(yy)
   for dy,dx in [(-1,0),(1,0),(0,-1),(0,1)]:
    ny,nx=yy+dy,xx+dx
    if 0<=ny<120 and 0<=nx<128 and mask[ny,nx] and not seen[ny,nx]:seen[ny,nx]=1;q.append((ny,nx))
  a,b,c,d=min(xs),max(xs),min(ys),max(ys)
  out.append(dict(x0=max(0,2*a-2),x1=min(256,2*b+4),y0=max(0,2*c-2),y1=min(240,2*d+4),w=2*(b-a+1),h=2*(d-c+1),fg=4*len(xs)))
 return out
def verify(sim,output):
 data=(sim/'modelsim_work/dual_motion/console.log').read_bytes();s=data.decode('utf-16' if data.startswith((b'\xff\xfe',b'\xfe\xff')) else 'utf-8-sig')
 assert 'PASS dual motion:' in s and '** Fatal' not in s
 rows=re.findall(r'DUAL_RGB_RESULT dir(\d+) source(\d+) data([0-9a-fA-F]+) old([0-9a-fA-F]+) T(\d+) P(\d+) E(\d+) oldT(\d+) oldE(\d+)',s)
 assert [(int(d),int(f)) for d,f,*_ in rows]==[(d,f) for d in range(2) for f in range(1,44)]
 fields=['x0','x1','y0','y1','w','h','fg'];checked=[];up={};cross={}
 for ds,fs,v,old,nt,np_,ne,ot,oe in rows:
  direction=int(ds);frame=int(fs);path=sim/f'dual_rgb_{direction}_{frame}.pgm'
  with path.open(encoding='ascii') as f:
   assert [f.readline().strip() for _ in range(3)]==['P2','256 240','255']
   im=np.fromstring(f.read(),dtype=np.int32,sep=' ').reshape(240,256)
  refs={2:components(im,100),3:components(im,80)};objs=[]
  assert int(v,16)>>304==0 and int(old,16)>>304==0
  centers=[100+4*(frame-1),50+4*(frame-1),-2+4*(frame-1)]
  if direction:centers=[256-x for x in centers]
  for slot in range(4):
   r=record(int(v,16)>>(slot*76)&((1<<76)-1))
   if not r['valid'] or r['kind']<2:continue
   m=[q for q in refs[r['kind']] if all(q[k]==r[k] for k in fields)];assert len(m)==1,(direction,frame,r)
   cx=(r['x0']+r['x1'])//2;idx=min(range(3),key=lambda i:abs(centers[i]-cx));assert centers[idx]==cx
   assert r['kind']==(3 if idx==1 else 2)
   if r['kind']==3:
    assert r['w']==8 and r['h']==8 and r['fg']==64
    high=[q for q in refs[2] if all(q[k]==r[k] for k in ['x0','x1','y0','y1','w','h'])]
    assert len(high)==1 and high[0]['fg']==48,'Actual T80 full4x4 plus same-box T100 circle12 required'
   if (cx<124 if direction==0 else cx>132):up[direction,idx]=True
   if up.get((direction,idx)) and (cx>132 if direction==0 else cx<124):cross.setdefault((direction,idx),frame)
   objs.append(r)
  assert all(not (record(int(old,16)>>(slot*76)&((1<<76)-1))['valid'] and record(int(old,16)>>(slot*76)&((1<<76)-1))['kind']==3) for slot in range(4))
  checked.append(dict(direction=direction,frame=frame,pgm_sha256=hashlib.sha256(path.read_bytes()).hexdigest(),objects=objs))
 events=[tuple(map(int,r)) for r in re.findall(r'DUAL_RGB_EVENT dir(\d+) id(\d+) source(\d+) kind(\d+)',s)]
 expected=[(d,i+1,cross[d,i],3 if i==1 else 2) for d in range(2) for i in range(3)]
 assert events==expected,(events,expected)
 result=dict(status='PASS_INDEPENDENT_ACTUAL_RGB_COMPONENTS_DUAL_THRESHOLD_AND_SOURCE_CROSSINGS',source_frames=86,events=events,frames=checked,physical_board_accuracy='NOT_ASSERTED')
 output.write_text(json.dumps(result,indent=2),encoding='utf-8');return result
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('sim',type=Path);p.add_argument('--output',type=Path,required=True);a=p.parse_args();print(verify(a.sim,a.output)['status'])
