import adsk.core,adsk.fusion,json
OUT='E:/2026FPGA/FPGA_Component_Inspector/开发实施/机械结构展示/机械装配_R2b/'
def run(_context):
 a=adsk.core.Application.get();d=adsk.fusion.Design.cast(a.activeProduct);out=[]
 for name,expr in [('lamp_y','10 mm'),('lamp_clearance','65 mm'),('p08_t','7 mm')]:
  p=d.userParameters.itemByName(name);old=p.expression;p.expression=expr;d.computeAll()
  carrier=next(o for o in d.rootComponent.occurrences if o.component.name.startswith('A08'))
  lamp=next(o for o in d.rootComponent.occurrences if o.component.name.startswith('E08'));bb=lamp.boundingBox
  row={'parameter':name,'test':expr,'carrier_matrix':carrier.transform2.asArray(),'lamp_bbox_mm':[getattr(pt,k)*10 for pt in [bb.minPoint,bb.maxPoint] for k in ['x','y','z']],'health':[]}
  for i in range(d.timeline.count):
   e=d.timeline.item(i).entity
   if hasattr(e,'healthState') and e.healthState!=adsk.fusion.FeatureHealthStates.HealthyFeatureHealthState:row['health'].append([e.name,e.errorOrWarningMessage])
  out.append(row);p.expression=old;d.computeAll()
  open(OUT+'evidence/regression.json','w',encoding='utf8').write(json.dumps(out,ensure_ascii=False,indent=2))
 print(json.dumps(out))
