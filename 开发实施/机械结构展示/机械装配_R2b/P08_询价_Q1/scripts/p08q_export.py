import adsk.core,adsk.fusion,json
OUT='E:/2026FPGA/FPGA_Component_Inspector/开发实施/机械结构展示/机械装配_R2b/P08_询价_Q1/'
def run(_context):
 a=adsk.core.Application.get();a.activeViewport.saveAsImageFile(OUT+'evidence/active_before.png',1200,900)
 doc=a.importManager.importToNewDocument(a.importManager.createFusionArchiveImportOptions(OUT+'../FPGA_Inspector_R2b_Parametric.f3d'));doc.name='P08_Q1_Quote_Export_Review'
 d=adsk.fusion.Design.cast(a.activeProduct);occ=[o for o in d.rootComponent.allOccurrences if o.component.name.startswith('P08')];assert len(occ)==2 and occ[0].component==occ[1].component
 c=occ[0].component;b=c.bRepBodies.item(0);bb=b.preciseBoundingBox
 out={'source':'R2b preserved archive','quantity':2,'material':'PETG','infill_percent':100,'native_volume_mm3':b.volume*1000,'bbox_mm':[getattr(p,k)*10 for p in [bb.minPoint,bb.maxPoint] for k in ['x','y','z']],'sketches':[{'name':s.name,'fully_constrained':s.isFullyConstrained} for s in c.sketches],'parameters':{p.name:{'expression':p.expression,'mm':p.value*10} for p in d.userParameters if p.name.startswith('p08') or p.name in ['lamp_back','lamp_h','lamp_y']},'health':[]}
 for i in range(d.timeline.count):
  e=d.timeline.item(i).entity
  if hasattr(e,'healthState') and e.healthState!=adsk.fusion.FeatureHealthStates.HealthyFeatureHealthState:out['health'].append([e.name,e.errorOrWarningMessage])
 assert not out['health'] and all(x['fully_constrained'] for x in out['sketches'])
 assert d.exportManager.execute(d.exportManager.createSTEPExportOptions(OUT+'evidence/P08_native_assembly_coords.step',c))
 open(OUT+'evidence/native_export.json','w',encoding='utf8').write(json.dumps(out,ensure_ascii=False,indent=2));print(json.dumps(out))
 doc.close(False)
