import adsk.core, adsk.fusion, json
def run(_context):
 app=adsk.core.Application.get(); out={}; hardware={}
 for doc in [next(x for x in app.documents if x.name=='FPGA_Inspector_R2a_P01_Slot56_Trial')]:
  d=adsk.fusion.Design.cast(doc.products.itemByProductType('DesignProductType'))
  if not d:continue
  seen=set()
  for o in d.rootComponent.allOccurrences:
   c=o.component;name=c.name
   hardware[name]=hardware.get(name,0)+1
   if c.id in seen or not name.startswith(('P0','W0','S0','CT','HT')):continue
   seen.add(c.id);code='_'.join(name.split('_')[:2]) if name.startswith(('P03_','P07_')) else name.split('_')[0];sketches=[]
   for sk in c.sketches:
    curves=[]
    for line in sk.sketchCurves.sketchLines:
     if line.isConstruction:continue
     curves.append({'type':'line','points':[[v*10 for v in sk.sketchToModelSpace(p.geometry).asArray()] for p in [line.startSketchPoint,line.endSketchPoint]]})
    for circle in sk.sketchCurves.sketchCircles:
     curves.append({'type':'circle','center':[v*10 for v in sk.sketchToModelSpace(circle.centerSketchPoint.geometry).asArray()],'radius':circle.radius*10})
    sketches.append({'name':sk.name,'curves':curves,'constrained':sk.isFullyConstrained})
   out[code]={'name':name,'sketches':sketches}
 root='E:/2026FPGA/FPGA_Component_Inspector/开发实施/机械结构展示/机械装配_R2/打印准备_阶段2/P01修订_R2a/evidence/'
 open(root+'drawing_geometry.json','w',encoding='utf8').write(json.dumps(out,ensure_ascii=True,indent=2))
 open(root+'hardware_inventory.json','w',encoding='utf8').write(json.dumps(hardware,ensure_ascii=True,indent=2))
 print(json.dumps({'components':len(out),'hardware_types':len(hardware)}))
 print(json.dumps([{'document':doc.name,'timeline':adsk.fusion.Design.cast(doc.products.itemByProductType('DesignProductType')).timeline.count,'root_components':[o.component.name for o in adsk.fusion.Design.cast(doc.products.itemByProductType('DesignProductType')).rootComponent.occurrences if o.component.name.startswith(('CT','HT'))]} for doc in app.documents]))

