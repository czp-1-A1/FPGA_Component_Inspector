from pathlib import Path
import sys,json,re
import numpy as np
import cv2
root=Path(sys.argv[1]);console=(root/'sim/modelsim_work/local_isp/console.log').read_text(encoding='utf-8-sig',errors='replace')
records=[]
for line in console.splitlines():
 m=re.search(r'REF local frame=(\d+) state=(\d+) located=(\d+) FG=(\d+) W=(\d+) H=(\d+) X0=(\d+) X1=(\d+) Y0=(\d+) Y1=(\d+)',line)
 if not m:continue
 frame,state,located,fg,w,h,x0,x1,y0,y1=map(int,m.groups())
 parts=(root/'sim'/f'native_case_{frame}.pgm').read_text().split();assert parts[:4]==['P2','192','144','255'];image=np.array(list(map(int,parts[4:])),np.uint8).reshape(144,192)
 binary=(image>=100).astype(np.uint8);dark=image<=100
 labels,lab,stats,centroids=cv2.connectedComponentsWithStats(binary,connectivity=4)
 candidates=[]
 for i,(x,y,cw,ch,count) in enumerate(stats[1:],1):
  if x==0 or y==0 or x+cw==192 or y+ch==144 or count<8 or cw<6 or ch<6:continue
  cx=(2*x+cw-1)//2;cy=(2*y+ch-1)//2;dx=abs(cx-96);dy=abs(cy-72)
  if dx<=32 and dy<=24:candidates.append((dx+dy,-int(count),i))
 if not candidates:
  expected_state=0 if binary.any() else 1;expected=dict(state=expected_state,located=0,FG=0,W=0,H=0)
 else:
  _,_,i=min(candidates);x,y,cw,ch,count=map(int,stats[i]);cx=(2*x+cw-1)//2;cy=(2*y+ch-1)//2
  long=max(cw,ch);short=min(cw,ch);area=cw*ch
  present=52<=long<=78 and 40<=short<=72 and long*20>=short*21 and long*20<=short*31 and count*20>=area*17
  circular=long*5<=short*7 and count*5>=area*3 and count*10<=area*9
  empty=circular and 10<=long<=26 and 8<=short<=24
  sprocket=circular and 28<=long<=46 and 20<=short<=42
  context=np.count_nonzero(dark[cy-40:cy+40,cx-56:cx-40])>=960 and np.count_nonzero(dark[cy-40:cy+40,cx+40:cx+56])>=960
  expected_state=0 if not context or sprocket else 2 if present else 3 if empty else 1
  expected=dict(state=expected_state,located=1,FG=min(count,8191),W=min(cw,127),H=min(ch,127),X0=x+416-2,X1=x+cw+416+2,Y0=y+228-2,Y1=y+ch+228+2)
 actual=dict(state=state,located=located,FG=fg,W=w,H=h,X0=x0,X1=x1,Y0=y0,Y1=y1)
 assert all(actual[k]==v for k,v in expected.items()),(frame,actual,expected)
 records.append(dict(frame=frame,actual=actual,reference=expected,status='PASS'))
assert records,'No native dumps available'
(root/'native_reference_results.json').write_text(json.dumps(records,indent=2),encoding='utf-8');print('PASS independent OpenCV reference:',len(records),'native pre-overlay mask frames')
