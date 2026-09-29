import adsk.core,adsk.fusion,json,math
OUT='E:/2026FPGA/FPGA_Component_Inspector/开发实施/机械结构展示/机械装配_R2b/'
def run(_context):
 a=adsk.core.Application.get();d=adsk.fusion.Design.cast(a.activeProduct);tm=adsk.fusion.TemporaryBRepManager.get();P=adsk.core.Point3D
 c=next(o.component for o in d.rootComponent.allOccurrences if o.component.name.startswith('P08'))
 faces=[]
 for f in c.bRepBodies.item(0).faces:
  cyl=adsk.core.Cylinder.cast(f.geometry)
  if cyl:faces.append({'origin_mm':[getattr(cyl.origin,k)*10 for k in ['x','y','z']],'radius_mm':cyl.radius*10,'axis':[getattr(cyl.axis,k) for k in ['x','y','z']]})
 p05=next(o.component for o in d.rootComponent.occurrences if o.component.name.startswith('P05')).bRepBodies.item(0)
 def ring(z,y):
  b=tm.createCylinderOrCone(P.create(0,y/10,z/10),.45,P.create(0,y/10,(z+.01)/10),.45)
  h=tm.createCylinderOrCone(P.create(0,y/10,z/10),.225,P.create(0,y/10,(z+.01)/10),.225)
  assert tm.booleanOperation(b,h,adsk.fusion.BooleanTypes.DifferenceBooleanType);return b
 rows=[]
 for off in [-14.75,0,14.75]:
  for y in [-18+off,18+off]:
   b=ring(158,y);assert tm.booleanOperation(b,p05,adsk.fusion.BooleanTypes.IntersectionBooleanType)
   rows.append({'y_offset_mm':off,'bolt_y_mm':y,'P05_underwasher_bearing_mm2':b.volume*1000/.01})
 out={'P08_cylindrical_faces':faces,'P05_washer_support':rows,'M4_grip_mm':18,'M4_length_mm':30,'M4_two_washers_mm':1.6,'M4_nut_mm':3.2,'M4_nominal_protrusion_beyond_nut_mm':7.2,'M4_note':'Retain 4 existing M4x30; geometric thread envelope only, purchased thread coverage/tolerance to verify','default_native_bodies':[]}
 for o in d.rootComponent.allOccurrences:
  if not o.component.name.startswith(('P08','P05','E08','P01')):continue
  for b in o.component.bRepBodies:
   bb=b.preciseBoundingBox;out['default_native_bodies'].append({'occurrence':o.fullPathName,'volume_mm3':b.volume*1000,'bbox_local_mm':[getattr(p,k)*10 for p in [bb.minPoint,bb.maxPoint] for k in ['x','y','z']]})
 open(OUT+'evidence/interface_checks.json','w',encoding='utf8').write(json.dumps(out,ensure_ascii=False,indent=2));print(json.dumps(out))
