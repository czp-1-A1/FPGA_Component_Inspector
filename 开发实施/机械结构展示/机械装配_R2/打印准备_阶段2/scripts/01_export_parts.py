import adsk.core,adsk.fusion,json,os

def run(_context):
 app=adsk.core.Application.get();d=adsk.fusion.Design.cast(app.activeProduct)
 root='E:/2026FPGA/FPGA_Component_Inspector/开发实施/机械结构展示/机械装配_R2/打印准备_阶段2/'
 for folder in ['零件STEP','evidence/切片输入网格']:os.makedirs(root+folder,exist_ok=True)
 seen=set();out=[]
 for o in d.rootComponent.occurrences:
  c=o.component;n=c.name
  if c.id in seen or not n.startswith(('P','W','S01','S03')):continue
  seen.add(c.id);code=n.split('_')[0]
  if n.startswith('P03'):code='_'.join(n.split('_')[:2])
  if n.startswith('P07'):code='_'.join(n.split('_')[:2])
  e=d.exportManager;ok=e.execute(e.createSTEPExportOptions(root+'零件STEP/'+code+'.step',c))
  if n.startswith('P'):
   opt=e.createSTLExportOptions(c,root+'evidence/切片输入网格/'+code+'.stl');opt.unitType=adsk.fusion.DistanceUnits.MillimeterDistanceUnits;opt.isBinaryFormat=True;opt.surfaceDeviation=.001;opt.normalDeviation=.08;opt.maximumEdgeLength=.3;opt.sendToPrintUtility=False
   assert e.execute(opt)
  rows=[]
  for b in c.bRepBodies:
   bb=b.preciseBoundingBox;rows.append({'volume_mm3':b.volume*1000,'bounds_mm':[v*10 for v in [bb.minPoint.x,bb.minPoint.y,bb.minPoint.z,bb.maxPoint.x,bb.maxPoint.y,bb.maxPoint.z]],'solid':b.isSolid})
  out.append({'code':code,'name':n,'qty':sum(x.component==c for x in d.rootComponent.occurrences),'bodies':rows,'exported':ok})
 open(root+'evidence/part_exports.json','w',encoding='utf8').write(json.dumps(out,ensure_ascii=True,indent=2))
 print(json.dumps({'unique_parts':len(out),'document_unchanged':not app.activeDocument.isModified,'parts':out}))
