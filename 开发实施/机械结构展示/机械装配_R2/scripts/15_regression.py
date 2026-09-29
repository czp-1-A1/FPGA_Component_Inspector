import adsk.core,adsk.fusion,json

def run(_context):
 app=adsk.core.Application.get();d=adsk.fusion.Design.cast(app.activeProduct);out=[]
 for name,value in [('stack_h','35 mm'),('lens_dx','18 mm'),('lens_drop','22 mm'),('belt_z','75 mm'),('lamp_y','-14.75 mm'),('lamp_y','14.75 mm')]:
  p=d.userParameters.itemByName(name);old=p.expression;p.expression=value;ok=d.computeAll()
  errors=[]
  for i in range(d.timeline.count):
   e=d.timeline.item(i).entity
   if hasattr(e,'healthState') and e.healthState!=adsk.fusion.FeatureHealthStates.HealthyFeatureHealthState:errors.append([i,e.name,e.errorOrWarningMessage])
  bs={}
  for o in d.rootComponent.occurrences:
   if o.component.name.startswith(('E03','E06','E08','P06','P07','P02')):
    for b in o.component.bRepBodies:
     bb=b.preciseBoundingBox;bs[o.name]=[bb.minPoint.x*10,bb.minPoint.y*10,bb.minPoint.z*10,bb.maxPoint.x*10,bb.maxPoint.y*10,bb.maxPoint.z*10]
  out.append({'parameter':name,'test':value,'compute':ok,'health':errors,'bounds_local_mm':bs})
  p.expression=old;d.computeAll()
  open('E:/2026FPGA/FPGA_Component_Inspector/开发实施/机械结构展示/机械装配_R2/evidence/parameter_regression.json','w',encoding='utf8').write(json.dumps(out,ensure_ascii=True,indent=2))
 print(json.dumps(out))
