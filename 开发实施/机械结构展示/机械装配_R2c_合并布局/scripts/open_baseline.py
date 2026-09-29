import adsk.core,adsk.fusion,json
from pathlib import Path
ROOT=Path('E:/2026FPGA/FPGA_Component_Inspector/开发实施/机械结构展示')
OUT=ROOT/'机械装配_R2c_合并布局'
def run(_context):
 app=adsk.core.Application.get(); im=app.importManager
 doc=im.importToNewDocument(im.createFusionArchiveImportOptions(str(ROOT/'机械装配_R2b/FPGA_Inspector_R2b_Parametric.f3d')))
 doc.name='FPGA_Inspector_R2c_Conditional_Quote'
 d=adsk.fusion.Design.cast(app.activeProduct);r=d.rootComponent
 rows=[];seen=set()
 for o in r.allOccurrences:
  c=o.component;bb=o.boundingBox
  rows.append({'name':o.fullPathName,'component':c.name,'transform':o.transform2.asArray(),'bodies':[{'name':b.name,'volume':b.volume*1000,'bounds':[v*10 for v in [b.boundingBox.minPoint.x,b.boundingBox.minPoint.y,b.boundingBox.minPoint.z,b.boundingBox.maxPoint.x,b.boundingBox.maxPoint.y,b.boundingBox.maxPoint.z]]} for b in c.bRepBodies]})
  if c.name.startswith(('P01','P02','P03','P04','P05','P08')) and c.name not in seen:
   seen.add(c.name);d.exportManager.execute(d.exportManager.createSTEPExportOptions(str(OUT/'evidence'/('baseline_'+c.name.split('_')[0]+('_'+c.name.split('_')[1] if c.name.startswith('P03') else '')+'.step')),c))
 pars=[{'name':p.name,'expression':p.expression,'value_mm':p.value*10} for p in d.userParameters]
 (OUT/'evidence/baseline.json').write_text(json.dumps({'occurrences':rows,'parameters':pars},ensure_ascii=False,indent=2),encoding='utf8')
 app.activeViewport.fit();app.activeViewport.saveAsImageFile(str(OUT/'evidence/baseline.png'),1200,900)
 print(json.dumps({'doc':doc.name,'components':len(rows),'exported':list(seen)}))
