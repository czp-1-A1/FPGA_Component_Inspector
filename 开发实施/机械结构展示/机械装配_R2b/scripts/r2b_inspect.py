import adsk.core,adsk.fusion,json,math
OUT='E:/2026FPGA/FPGA_Component_Inspector/开发实施/机械结构展示/机械装配_R2b/'
def run(_context):
 app=adsk.core.Application.get();d=adsk.fusion.Design.cast(app.activeProduct);tm=adsk.fusion.TemporaryBRepManager.get();p=adsk.core.Point3D
 occurrences=[o for o in d.rootComponent.allOccurrences if o.component.name.startswith('P08')]
 assert len(occurrences)==2 and occurrences[0].component==occurrences[1].component
 c=occurrences[0].component;body=c.bRepBodies.item(0);bb=body.preciseBoundingBox
 # Temporary geometry is not accepted by MeasureManager; bracket radial clearance by exact BRep intersections.
 lo,hi=20.,50.
 for _ in range(22):
  radius=(lo+hi)/2
  tube=tm.createCylinderOrCone(p.create(0,0,10),radius/10,p.create(0,0,25),radius/10)
  assert tm.booleanOperation(tube,body,adsk.fusion.BooleanTypes.IntersectionBooleanType)
  if tube and tube.volume>1e-9:hi=radius
  else:lo=radius
 gap=(lo+hi)/2-20
 def ring(x,y,z,od,id,th=.01):
  a=tm.createCylinderOrCone(p.create(x/10,y/10,z/10),od/20,p.create(x/10,y/10,(z+th)/10),od/20)
  b=tm.createCylinderOrCone(p.create(x/10,y/10,z/10),id/20,p.create(x/10,y/10,(z+th)/10),id/20)
  assert tm.booleanOperation(a,b,adsk.fusion.BooleanTypes.DifferenceBooleanType)
  return a
 def supported_area(b,x,y,z,od,id):
  a=ring(x,y,z,od,id);assert tm.booleanOperation(a,b,adsk.fusion.BooleanTypes.IntersectionBooleanType)
  return a.volume*1000/.01 if a else 0
 z=lambda n:d.userParameters.itemByName(n).value*10
 support=[]
 for x,y in [(39,0),(0,39)]:
  support.append({'point':[x,y],'M3_washer_bearing_mm2':supported_area(body,x,y,z('p08_top')-.01,7,3.6),'foot_annular_contact_mm2':supported_area(body,x,y,z('lamp_back'),10,3.6)})
 for y in [-18,18]:support.append({'point':[120,y],'M4_washer_bearing_mm2':supported_area(body,120,y,z('p08_top')-.01,9,4.5)})
 mats=[o.transform2.asArray() for o in occurrences]
 out={'component_id':c.id,'shared_definition':True,'occurrences':[o.fullPathName for o in occurrences],'matrices':mats,'body_count':c.bRepBodies.count,'solid':body.isSolid,'volume_mm3':body.volume*1000,'bbox_mm':[v*10 for v in [bb.minPoint.x,bb.minPoint.y,bb.minPoint.z,bb.maxPoint.x,bb.maxPoint.y,bb.maxPoint.z]],'envelope_mm':[(getattr(bb.maxPoint,k)-getattr(bb.minPoint,k))*10 for k in ['x','y','z']],'central_D40_clearance_mm':gap,'bearing_areas':support,'sketches':[{'name':s.name,'fully_constrained':s.isFullyConstrained} for s in c.sketches], 'parameters':{n:z(n) for n in ['lamp_bottom','lamp_back','p08_bottom','p08_top','p08_t','p08_w','lamp_y']},'health':[]}
 for i in range(d.timeline.count):
  e=d.timeline.item(i).entity
  if hasattr(e,'healthState') and e.healthState!=adsk.fusion.FeatureHealthStates.HealthyFeatureHealthState:out['health'].append([i,e.name,e.errorOrWarningMessage])
 # Compare a true 180-degree body rotation to the second placed occurrence.
 a=tm.copy(body);m=adsk.core.Matrix3D.create();m.setToRotation(math.pi,adsk.core.Vector3D.create(0,0,1),p.create());tm.transform(a,m)
 b=tm.copy(body);tm.transform(b,occurrences[1].transform2)
 volume=b.volume;assert tm.booleanOperation(a,b,adsk.fusion.BooleanTypes.IntersectionBooleanType)
 out['rotated_intersection_volume_mm3']=a.volume*1000;out['swap_volume_error_mm3']=abs(a.volume-volume)*1000
 open(OUT+'evidence/P08_native_checks.json','w',encoding='utf8').write(json.dumps(out,ensure_ascii=False,indent=2));print(json.dumps(out,ensure_ascii=True))
