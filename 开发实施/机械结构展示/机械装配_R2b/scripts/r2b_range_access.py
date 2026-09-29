import adsk.core,adsk.fusion,json

def run(_context):
 d=adsk.fusion.Design.cast(adsk.core.Application.get().activeProduct)
 tm=adsk.fusion.TemporaryBRepManager.get(); arr=[]
 def walk(c,m,path):
  for b in c.bRepBodies:
   t=tm.copy(b);tm.transform(t,m);bb=t.boundingBox
   arr.append((path,b,t,[bb.minPoint.x,bb.minPoint.y,bb.minPoint.z,bb.maxPoint.x,bb.maxPoint.y,bb.maxPoint.z]))
  for o in c.occurrences:
   # Explicit matrix composition: parent * local.
   a=m.asArray();z=o.transform2.asArray();w=adsk.core.Matrix3D.create()
   w.setWithArray([sum(a[r*4+k]*z[k*4+s] for k in range(4)) for r in range(4) for s in range(4)])
   walk(o.component,w,path+'/'+o.name)
 walk(d.rootComponent,adsk.core.Matrix3D.create(),'R2')

 P=adsk.core.Point3D;V=adsk.core.Vector3D
 def box(a,b):
  return tm.createBox(adsk.core.OrientedBoundingBox3D.create(P.create(*[(a[k]+b[k])/20 for k in range(3)]),V.create(1,0,0),V.create(0,1,0),*((b[k]-a[k])/10 for k in range(3))))
 def cyl(a,b,r):return tm.createCylinderOrCone(P.create(*(x/10 for x in a)),r/10,P.create(*(x/10 for x in b)),r/10)
 def clashes(tool,skip=(),only=None):
  bb=tool.boundingBox;ta=[getattr(p,k) for p in [bb.minPoint,bb.maxPoint] for k in ['x','y','z']];bad=[]
  for n,_,b,ba in arr:
   top=n.split('/')[1]
   if top.startswith(skip) or (only and not top.startswith(only)):continue
   if not all(min(ta[k+3],ba[k+3])-max(ta[k],ba[k])>1e-5 for k in range(3)):continue
   t=tm.copy(tool);ok=tm.booleanOperation(t,b,adsk.fusion.BooleanTypes.IntersectionBooleanType)
   if not ok:bad.append([n,'BOOLEAN_FAILED'])
   elif t and t.volume>1e-5:bad.append([n,round(t.volume*1000,4)])
  return bad
 tests=[]
 for x in [-120,120]:
  for y in [-18,18]:
   tests.append(('M4_head_tool_'+str((x,y)),cyl((x,y,180.8),(x,y,215),5),('H_P08',),None))
   tests.append(('M4_under_nut_tool_'+str((x,y)),box((x-5,y-8,145),(x+5,y+8,157.2)),('H_P08',),None))
  for z in [176,192]:
   tests.append(('P05_root_front_tool_'+str((x,z)),cyl((x,44,z),(x,74,z),5),('H_LAMP_ROOT',),None))
   tests.append(('P05_root_rear_tool_'+str((x,z)),box((x-9,98.8,z-7),(x+9,104,z+7)),('H_LAMP_ROOT',),None))
 for x,y in [(39,0),(0,39),(-39,0),(0,-39)]:tests.append(('M3_bench_tool_'+str((x,y)),cyl((x,y,179.5),(x,y,210),4),(),('A08','E08')))
 tests.append(('focus_D34',cyl((0,0,185),(0,0,203),17),('E06','E07'),None))
 tests.append(('optical_D40_below_emitter',cyl((0,0,85.01),(0,0,144.99),20),('E02',),None))
 for name,a,b in [('front_connector',(-20,-100,210),(20,-45,230)),('rear_connector',(-20,45,210),(20,95,230)),('left_connector',(-120,-15,210),(-85,15,230)),('right_connector',(45,-15,210),(100,15,230)),('sample_pickup',(-40,-100,85),(40,-60,125))]:tests.append((name,box(a,b),('E03','E04','E05'),None))

 base=arr;rows=[]
 def offset(n,D,H,Y):
  n=n.split('/')[1]
  if n.startswith(('P01','P02','P03','S01','E03','E04','E05','E06','E07','H_CAM_PAD')):return (0,0,(D-100)/10)
  if n.startswith('H_CAM_ROOT'):
   row=max(125,min(305,125+20*round((D+84.5-125)/20)))
   return (0,0,(row-185)/10)
  if n.startswith(('A08','E08','H_P08')):return (0,Y/10,(H-60)/10)
  if n.startswith(('P05','H_LAMP_ROOT')):return (0,0,(H-60)/10)
  return (0,0,0)
 for wd,h,y in [(50,10,-14.75),(50,10,14.75),(132,92,-14.75),(132,92,14.75),(200,92,-14.75),(200,92,14.75),(50,10,-13),(56,16,-14.75)]:
  arr=[]
  for n,b,t,bb in base:
   off=offset(n,wd,h,y);m=adsk.core.Matrix3D.create();m.translation=V.create(*off);tt=tm.copy(t);tm.transform(tt,m);arr.append((n,b,tt,[v+off[k%3] for k,v in enumerate(bb)]))
  results=[]
  for name,t,skip,only in tests:
   off=(0,0,0)
   if name.startswith(('focus','front_connector','rear_connector','left_connector','right_connector')):off=(0,0,(wd-100)/10)
   elif name.startswith(('M4_','M3_')):off=(0,y/10,(h-60)/10)
   elif name.startswith('P05_root'):off=(0,0,(h-60)/10)
   tt=tm.copy(t);m=adsk.core.Matrix3D.create();m.translation=V.create(*off);tm.transform(tt,m)
   if name.startswith('optical'):tt=cyl((0,y,85.01),(0,y,85+h-.01),20)
   results.append({'envelope':name,'clashes':clashes(tt,skip,only)})
  rows.append({'D':wd,'H':h,'Y':y,'checks':results})
 path='E:/2026FPGA/FPGA_Component_Inspector/开发实施/机械结构展示/机械装配_R2b/evidence/range_access_checks.json'
 open(path,'w',encoding='utf8').write(json.dumps(rows,ensure_ascii=False,indent=2))
 print(json.dumps({'poses':len(rows),'checks':len(rows)*len(tests),'failures':[{'D':r['D'],'H':r['H'],'Y':r['Y'],'bad':[t for t in r['checks'] if t['clashes']]} for r in rows if any(t['clashes'] for t in r['checks'])]}))
