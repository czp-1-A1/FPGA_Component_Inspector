from pathlib import Path
import argparse,json,hashlib,re
import numpy as np
p=argparse.ArgumentParser();p.add_argument('--project',type=Path,required=True);a=p.parse_args();P=a.project.resolve();S=P/'sim';U=S/'local_edge'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
truth=json.loads((U/'unit_independent_reference.json').read_text());N=len(truth['cases'])
packed=np.array([int(t,16) for t in (U/'fixtures.hex').read_text().split()],dtype=np.uint32).reshape(N,196,64)
q=np.zeros((N,196,256),np.int64)
for lane in range(4):q[:,:,lane::4]=(packed>>(lane*5))&31
GX=np.array([[-1,0,1],[-2,0,2],[-1,0,1]],np.int64);GY=GX.T
expected=[]
for i,c in enumerate(truth['cases']):
 x0,x1,y0,y1=c['bounds'];cx=x0+(x1-x0+1)//2;cy=y0+(y1-y0+1)//2;arr=q[i];edges=[]
 for k,(x,y) in enumerate([(x0,cy),(x1,cy),(cx,y0),(cx,y1)]):
  patch=arr[y-112-1:y-112+2,x-192-1:x-192+2];dx=int((patch*GX).sum());dy=int((patch*GY).sum());edges.append(max([dx,-dx,dy,-dy][k],0))
 assert edges==c['gradient_strengths'],(i,edges,c)
 values=[arr[cy-116:cy-108,cx-196:cx-188],arr[cy-116:cy-108,cx-200:cx-196],arr[cy-116:cy-108,cx-188:cx-184],arr[cy-120:cy-116,cx-196:cx-188],arr[cy-108:cy-104,cx-196:cx-188]]
 totals=[int(v.sum()) for v in values];assert totals==c['surface_sums'],(i,totals,c)
 means=[v//(64 if k==0 else 32) for k,v in enumerate(totals)];legacy=means[0]>=13 and min(means[1:])*5>=means[0]*4 and max(totals[1:])*2<=totals[0]+16
 good=sum(v>=8 for v in edges)>=3;flags=int(not c['empty'] and legacy and good)|(int(c['empty'] and good)<<1)
 assert flags==int(c['expected_normal'])|(int(c['expected_empty'])<<1)
 expected.append((flags,sum(v<<(8*k) for k,v in enumerate(edges))))
raw=(S/'modelsim_work/edge_unit/console.log').read_bytes();log=raw.decode('utf-16' if raw.startswith((b'\xff\xfe',b'\xfe\xff')) else 'utf-8-sig')
actual=[(int(i),int(f,16),int(e,16),int(w)) for i,f,e,w in re.findall(r'EDGE_UNIT case=(\d+) flags=([0-9a-f]+) edge=([0-9a-f]+) wait=(\d+)',log)]
assert len(actual)==42
for k,(i,flags,edges,wait) in enumerate(actual):
 valid=k<N or k>=N+7
 assert (flags,edges)==(expected[i] if valid else (0,0)),(k,i,flags,edges)
 assert wait==(108 if truth['cases'][i]['empty'] else 684) if valid else wait==0
out={'status':'PASS_INDEPENDENT_UNIT_SERIALIZED_GRAY_132_SIGNED_SOBEL_KERNELS_42_REQUESTS','cases':N,'requests':len(actual),'kernels':N*4,'runtime_fixture_sha256':sha(U/'fixtures.hex'),'source_manifest_sha256':sha(P/'R17_FROZEN_INPUTS.json'),'console_sha256':sha(S/'modelsim_work/edge_unit/console.log')}
(S/'edge_unit_independent_reference.json').write_text(json.dumps(out,indent=2),encoding='utf-8');print(json.dumps(out))
