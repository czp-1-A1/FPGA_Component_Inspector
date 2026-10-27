from pathlib import Path
from collections import deque
import hashlib,json,re
import numpy as np
import argparse
ap=argparse.ArgumentParser();ap.add_argument('--project',type=Path,required=True);args=ap.parse_args()
P=args.project.resolve();O=P/'sim';R=P
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
rawlog=(O/'modelsim_work/present_trace_detector/console.log').read_bytes();log=rawlog.decode('utf-16' if rawlog.startswith((b'\xff\xfe',b'\xfe\xff')) else 'utf-8-sig')
lines=re.findall(r'PTRACE_DETECTOR scene=(\d+) diag=([0-9a-f]+) objects=([0-9a-f]+) candidates=([0-9a-f]+) wait=(\d+)',log)
assert len(lines)==14
yy,xx=np.mgrid[:720,:1280]
GX=np.array([[-1,0,1],[-2,0,2],[-1,0,1]],np.int64);GY=GX.T
reports=[];kernel_count=0;nonzero_signed=0
captures={int(p.stem.split('_',1)[1].strip()):p for p in (O/'present_motion/detector_out').glob('scene_*.pgm')}
def cc(a,threshold):
 points=set(zip(*np.where(a>=threshold)[::-1]));out=[]
 while points:
  seed=points.pop();todo=deque([seed]);component=[seed]
  while todo:
   x,y=todo.popleft()
   for p in [(x-1,y),(x+1,y),(x,y-1),(x,y+1)]:
    if p in points:points.remove(p);todo.append(p);component.append(p)
  out.append((min(x for x,y in component),max(x for x,y in component),min(y for x,y in component),max(y for x,y in component),len(component)))
 return out
def literal_scene(n):
 left_hot=n==16
 if n in (15,16):n=1
 shift=n%4;by=320;lx=602;rx=690;level=180;level2=180;second=True;empty=False;roi1=False;only1=False;thin=False;hot=False;nobody=False
 if n==1:lx,rx=540,640
 if n==2:only1=True;second=False
 if n==3:nobody=True;empty=True
 if n==4:level=88;second=False
 if n==5:hot=True;second=False
 if n==6:thin=True;second=False
 if n==7:lx=560;second=False;empty=True
 if n==8:roi1=True;level2=210
 if n==9:lx=399;second=False
 if n==10:lx=872;second=False
 if n==11:shift=1;by=321
 image=np.full(xx.shape,30,np.uint8)
 def part(left,center_y,value):
  ax=xx-left;ay=yy-(center_y-22);width=14 if thin else 36
  on=(ax>=0)&(ax<width)&(ay>=0)&(ay<44)&~(((ax<4)|(ax>=width-4))&((ay<8)|(ay>=36)))
  z=np.where(on,value,30)
  if hot or (left_hot and left==lx+shift):z=np.where((ax>=2)&(ax<10)&(ay>=8)&(ay<36),230,z)
  return z.astype(np.uint8)
 if not nobody and not only1:
  image=np.maximum(image,part(lx+shift,by,level))
  if second:image=np.maximum(image,part(rx+shift,by,level2))
 if roi1 or only1:image=np.maximum(image,part(650+shift,500,level2))
 if empty:image=np.where((xx-640)**2+(yy-320)**2<=36,170,image).astype(np.uint8)
 return image

for case,diag,objects,candidates,wait in lines:
 n=int(case);p=captures[n];parts=p.read_bytes().split(b'\n',3)
 assert parts[:3]==[b'P5',b'1280 720',b'255']
 raw=np.frombuffer(parts[3],np.uint8).reshape(720,1280);assert np.array_equal(raw,literal_scene(n)),(n,'captured literal pixels')
 avg=raw.astype(np.int64).reshape(360,2,640,2).sum((1,3))//4;q=avg>>3
 value=int(diag,16);packet=int(objects,16)
 if value==0:
  assert all(not((packet>>(76*k+75))&1) or ((packet>>(76*k+73))&3)!=2 for k in range(4))
  reports.append({'scene':n,'pixels_xor':0,'selected_P':False,'capture_sha256':sha(p)});continue
 region=(value>>122)&1;slot=(value>>120)&3;weak=bool((value>>119)&1);ob=(packet>>(76*(2*region+slot)))&((1<<76)-1)
 assert slot<2 and (ob>>75)&1 and (ob>>73)&3==2
 x0=((ob>>31)&2047)+2;x0//=2;y0=((ob>>10)&1023)+2;y0//=2
 w=((ob>>49)&127)//2;h=((ob>>42)&127)//2;x1=x0+w-1;y1=y0+h-1;cx=x0+w//2;cy=y0+h//2
 count=(ob>>56)&8191
 assert (x0,x1,y0,y1,count//4) in cc(avg,80 if weak else 100),(n,'selected bbox/CCL population')
 assert ((value>>14)&15)==((ob>>69)&15),(n,'public reason')
 if n==16:assert slot==0 and ((value>>14)&15)==8 and ((value>>110)&255)==4,(n,'fixed review-priority negative')
 assert ((value>>12)&3)==((y0&1)*2+(x0&1)),(n,'grid phase')
 expected=0
 eligible=(x0>=193 and x1+1<448 and y0>=113 and y1+1<308 and w>=16 and h>=16 and cx>=200 and cx+8<=448 and cy>=120 and cy+8<=308)
 if weak:
  assert not ((value>>118)&1) and ((value>>110)&255)==128 and ((value>>18)&((1<<92)-1))==0
  sums=[0]*5;gradients=[0]*4
 elif eligible:
  blocks=[q[cy-4:cy+4,cx-4:cx+4],q[cy-4:cy+4,cx-8:cx-4],q[cy-4:cy+4,cx+4:cx+8],q[cy-8:cy-4,cx-4:cx+4],q[cy+4:cy+8,cx-4:cx+4]]
  sums=[int(z.sum()) for z in blocks];gradients=[]
  for side,(x,y) in enumerate([(x0,cy),(x1,cy),(cx,y0),(cx,y1)]):
   patch=q[y-1:y+2,x-1:x+2];dx=int((patch*GX).sum());dy=int((patch*GY).sum());gradients.append([dx,-dx,dy,-dy][side])
  good=sum(g>=8 for g in gradients);cm=sums[0]//64;edge_min=min(t//32 for t in sums[1:])
  fail=int(cm<13)|(int(edge_min*5<cm*4)<<1)|(int(2*max(sums[1:])>sums[0]+16)<<2)|(int(good<3)<<3)
  normal=not fail;legacy=(fail&7)==0
  for t,bits in [(sums[0],11),*((v,10) for v in sums[1:]),*((g&511,9) for g in gradients),(good,3),(int(legacy),1),(int(normal),1),(1,1),(fail,8)]:expected=(expected<<bits)|t
  got=((value>>99)&2047)<<90|((value>>59)&((1<<40)-1))<<50|((value>>23)&((1<<36)-1))<<14|((value>>20)&7)<<11|((value>>19)&1)<<10|((value>>18)&1)<<9|((value>>118)&1)<<8|((value>>110)&255)
  assert got==expected,(n,f'actual={got:026x}',f'expected={expected:026x}')
  kernel_count+=4;nonzero_signed+=sum(g!=0 for g in gradients)
 else:
  in_cache=x0>=193 and x1+1<448 and y0>=113 and y1+1<308
  body=w>=16 and h>=16 and cx>=200 and cx+8<=448 and cy>=120 and cy+8<=308
  expected_fail=(not in_cache)*16+(not body)*64
  assert not ((value>>118)&1) and ((value>>110)&255)==expected_fail
  assert (value>>18)&((1<<92)-1)==0
  sums=[0]*5;gradients=[0]*4
 reports.append({'scene':n,'pixels_xor':0,'selected_P':True,'region':region,'slot':slot,'weak':weak,'sums':sums,'signed_gradients':gradients,'capture_sha256':sha(p)})
assert kernel_count>=28 and nonzero_signed>20
out={'status':'PASS_INDEPENDENT_NATIVE_PIXELS_CCL_SAMPLES_SIGNED_GRADIENTS_AND_PUBLIC_MAPPING','manifest_sha256':sha(P/'R17_FROZEN_INPUTS.json'),'frames':len(lines),'pixels':len(lines)*1280*720,'signed_kernels':kernel_count,'scenes':reports,'not_field_accuracy':True}
(O/'present_motion/detector_independent_reference.json').write_text(json.dumps(out,indent=2)+'\n',encoding='utf-8')
print(json.dumps({k:v for k,v in out.items() if k!='scenes'}))
