import adsk.core,adsk.fusion,json

def run(_context):
 d=adsk.fusion.Design.cast(next(doc for doc in adsk.core.Application.get().documents if doc.name=='FPGA_Inspector_R2a_P01_Slot56_Trial').products.itemByProductType('DesignProductType'))
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
  center=P.create(*[(a[k]+b[k])/20 for k in range(3)])
  return tm.createBox(adsk.core.OrientedBoundingBox3D.create(center,V.create(1,0,0),V.create(0,1,0),*( (b[k]-a[k])/10 for k in range(3))))
 def cyl(a,b,r):return tm.createCylinderOrCone(P.create(*(v/10 for v in a)),r/10,P.create(*(v/10 for v in b)),r/10)
 tests=[]
 for name,a,b in [('front_connector',(-20,-100,210),(20,-45,230)),('rear_connector',(-20,45,210),(20,95,230)),('left_connector',(-120,-15,210),(-85,15,230)),('right_connector',(45,-15,210),(100,15,230)),('sample_pickup',(-40,-100,85),(40,-60,125))]:tests.append((name,box(a,b),('E03','E04','E05')))
 tests.append(('focus_fingers_D34',cyl((0,0,185),(0,0,203),17),('E06','E07')))
 for x in [-83,-47,47,83]:tests.append(('camera_root_socket_D10_'+str(x),cyl((x,70,185),(x,100,185),5),('H_CAM_ROOT',)))
 for x in [-120,120]:
  for z in [170,186]:
   tests.append(('lamp_front_socket_D10_'+str((x,z)),cyl((x,44,z),(x,74,z),5),('H_LAMP_ROOT',)))
   tests.append(('lamp_rear_spanner_'+str((x,z)),box((x-9,98.8,z-7),(x+9,104,z+7)),('H_LAMP_ROOT',)))
 for x in [-61,61]:tests.append(('ring_clamp_tool_D10_'+str(x),cyl((x,-60,156),(x,-13,156),5),('H_RING_CLAMP',)))
 for x in [-65,65]:
  for y in [-66,-54,54,66]:
   tests.append(('pad_shank_insertion_D4_'+str((x,y)),cyl((x,y,174.5),(x,y,310),2),('H_CAM_PAD',)))
   tests.append(('pad_top_tool_D10_'+str((x,y)),cyl((x,y,241.5),(x,y,271.5),5),('H_CAM_PAD',)))
   tests.append(('pad_bottom_socket_D12_'+str((x,y)),cyl((x,y,149.5),(x,y,184.5),6),('H_CAM_PAD',)))
 out=[]
 for name,tool,skip in tests:
  bad=[];tb=tool.boundingBox;ta=[tb.minPoint.x,tb.minPoint.y,tb.minPoint.z,tb.maxPoint.x,tb.maxPoint.y,tb.maxPoint.z]
  for n,_,b,ba in arr:
   if n.split('/')[1].startswith(skip):continue
   if not all(min(ta[k+3],ba[k+3])-max(ta[k],ba[k])>1e-5 for k in range(3)):continue
   t=tm.copy(tool);ok=tm.booleanOperation(t,b,adsk.fusion.BooleanTypes.IntersectionBooleanType)
   if not ok:bad.append([n,'BOOLEAN_FAILED'])
   elif t and t.volume>1e-5:bad.append([n,round(t.volume*1000,4)])
  out.append({'envelope':name,'excluded_mating_parts':skip,'clashes':bad})
 path='E:/2026FPGA/FPGA_Component_Inspector/开发实施/机械结构展示/机械装配_R2/打印准备_阶段2/P01修订_R2a/evidence/access_checks.json'
 open(path,'w',encoding='utf8').write(json.dumps(out,ensure_ascii=True,indent=2))
 print(json.dumps(out))
