from pathlib import Path
import sys,json,re
import numpy as np
# Independent two-pass connected-component labeling with union/find.
# It does not reuse the FPGA flood-fill, queue, address packing or model outputs.
def connected_stats(binary):
 height,width=binary.shape;labels=np.zeros((height,width),np.int32);parent=[0]
 def find(a):
  while parent[a]!=a:
   parent[a]=parent[parent[a]];a=parent[a]
  return a
 for y in range(height):
  for x in range(width):
   if not binary[y,x]:continue
   left=int(labels[y,x-1]) if x else 0;up=int(labels[y-1,x]) if y else 0
   if not left and not up:
    label=len(parent);parent.append(label)
   else:
    label=left or up
    if left and up:
     a,b=find(left),find(up)
     if a!=b:parent[max(a,b)]=min(a,b)
   labels[y,x]=label
 boxes={}
 for y in range(height):
  for x in range(width):
   if not labels[y,x]:continue
   root=find(int(labels[y,x]));labels[y,x]=root
   if root not in boxes:boxes[root]=[x,y,x,y,0]
   q=boxes[root];q[0]=min(q[0],x);q[1]=min(q[1],y);q[2]=max(q[2],x);q[3]=max(q[3],y);q[4]+=1
 stats=[[0,0,width,height,int(np.count_nonzero(binary==0))]]
 for root in sorted(boxes):
  x0,y0,x1,y1,count=boxes[root];stats.append([x0,y0,x1-x0+1,y1-y0+1,count])
 return np.asarray(stats,dtype=np.int64)
root=Path(sys.argv[1]);console=(root/'sim/modelsim_work/local_isp/console.log').read_text(encoding='utf-8-sig',errors='replace')
records=[]
for line in console.splitlines():
 m=re.search(r'REF local frame=(\d+) state=(\d+) located=(\d+) FG=(\d+) W=(\d+) H=(\d+) X0=(\d+) X1=(\d+) Y0=(\d+) Y1=(\d+) REVIEW=(\d+)',line)
 if not m:continue
 frame,state,located,fg,w,h,x0,x1,y0,y1,review=map(int,m.groups())
 parts=(root/'sim'/f'native_case_{frame}.pgm').read_text().split();assert parts[:4]==['P2','192','144','255'];image=np.array(list(map(int,parts[4:])),np.uint8).reshape(144,192)
 binary=(image>=100).astype(np.uint8);dark=image<=100
 stats=connected_stats(binary)
 candidates=[]
 for i,(x,y,cw,ch,count) in enumerate(stats[1:],1):
  if x==0 or y==0 or x+cw==192 or y+ch==144 or count<8 or cw<6 or ch<6:continue
  cx=(2*x+cw-1)//2;cy=(2*y+ch-1)//2;dx=abs(cx-96);dy=abs(cy-72)
  if dx<=32 and dy<=24:candidates.append((dx+dy,-int(count),i))
 if not candidates:
  expected_state=0 if binary.any() else 1;expected=dict(state=expected_state,located=0,FG=0,W=0,H=0,CHECK=0)
 else:
  _,_,i=min(candidates);x,y,cw,ch,count=map(int,stats[i]);cx=(2*x+cw-1)//2;cy=(2*y+ch-1)//2
  long=max(cw,ch);short=min(cw,ch);area=cw*ch
  present=52<=long<=78 and 40<=short<=72 and long*20>=short*21 and long*20<=short*31 and count*20>=area*17
  envelope=52<=long<=86 and 40<=short<=76 and long*20>=short*21 and long*5<=short*9 and count*4>=area*3
  circular=long*5<=short*7 and count*5>=area*3 and count*10<=area*9
  empty=circular and 10<=long<=26 and 8<=short<=24
  sprocket=circular and 28<=long<=46 and 20<=short<=42
  context=np.count_nonzero(dark[cy-40:cy+40,cx-56:cx-40])>=960 and np.count_nonzero(dark[cy-40:cy+40,cx+40:cx+56])>=960
  expected_state=2 if present or envelope else 0 if not context or sprocket else 3 if empty else 1
  expected_review=int(expected_state==2 and (not present or not context))
  expected=dict(state=expected_state,located=1,CHECK=expected_review,FG=min(count,8191),W=min(cw,127),H=min(ch,127),X0=x+416-2,X1=x+cw+416+2,Y0=y+228-2,Y1=y+ch+228+2)
 actual=dict(state=state,located=located,CHECK=review,FG=fg,W=w,H=h,X0=x0,X1=x1,Y0=y0,Y1=y1)
 assert all(actual[k]==v for k,v in expected.items()),(frame,actual,expected)
 records.append(dict(frame=frame,actual=actual,reference=expected,status='PASS'))
assert len(records)==12,'Expected 12 complete native reference frames'
assert [r['actual']['CHECK'] for r in records[-4:]]==[1,1,1,0]
(root/'native_reference_results.json').write_text(json.dumps(records,indent=2),encoding='utf-8');print('PASS independent two-pass component reference:',len(records),'native pre-overlay mask frames, including shape/context CHECK and recovery')
