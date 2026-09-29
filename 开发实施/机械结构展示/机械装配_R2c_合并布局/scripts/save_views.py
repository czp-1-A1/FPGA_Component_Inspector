import adsk.core,adsk.fusion,json,time
from pathlib import Path
Q=Path('E:/2026FPGA/FPGA_Component_Inspector/开发实施/机械结构展示/机械装配_R2c_合并布局')
def run(_context):
 app=adsk.core.Application.get();d=adsk.fusion.Design.cast(app.activeProduct);d.activateRootComponent();rows=[]
 for o in d.rootComponent.allOccurrences:
  c=o.component
  if not c.name.startswith(('P09','P10')):continue
  b=c.bRepBodies.item(0);bb=b.boundingBox
  rows.append({'name':c.name,'bodies':c.bRepBodies.count,'volume_mm3':b.volume*1000,'bounds_mm':[getattr(p,k)*10 for p in [bb.minPoint,bb.maxPoint] for k in ['x','y','z']],'sketches':[{'name':s.name,'fully_constrained':s.isFullyConstrained} for s in c.sketches]})
  assert c.bRepBodies.count==1 and b.isSolid
  d.exportManager.execute(d.exportManager.createSTEPExportOptions(str(Q/'evidence'/('new_'+c.name.split('_')[0]+'.step')),c))
 errors=[{'index':i,'name':d.timeline.item(i).name,'message':getattr(d.timeline.item(i).entity,'errorOrWarningMessage','')} for i in range(d.timeline.count) if getattr(d.timeline.item(i).entity,'healthState',0)!=0]
 (Q/'evidence/new_native.json').write_text(json.dumps({'parts':rows,'health':errors},ensure_ascii=False,indent=2),encoding='utf8')
 assert d.exportManager.execute(d.exportManager.createFusionArchiveExportOptions(str(Q/'FPGA_Inspector_R2c_Conditional.f3d')))
 vp=app.activeViewport
 def view(name,eye,target,up):
  c=vp.camera;c.cameraType=adsk.core.CameraTypes.OrthographicCameraType;c.isSmoothTransition=False;c.eye=adsk.core.Point3D.create(*eye);c.target=adsk.core.Point3D.create(*target);c.upVector=adsk.core.Vector3D.create(*up);vp.camera=c;adsk.doEvents();vp.fit();adsk.doEvents();vp.refresh();time.sleep(.25);adsk.doEvents();vp.saveAsImageFile(str(Q/'视图'/name)+'.png',1600,1200)
 for name,eye,up in [('整体正视',(0,-100,17),(0,0,1)),('整体俯视',(0,6,120),(0,1,0)),('整体右视',(120,6,17),(0,0,1)),('整体轴测',(75,-90,65),(0,0,1))]:view(name,eye,(0,6,17),up)
 states=[(o,o.isLightBulbOn) for o in d.rootComponent.occurrences]
 for o,_ in states:o.isLightBulbOn=o.component.name.startswith(('P09','P10','S01','E03','E04','E05','E06','E07','H_P10'))
 view('承托局部',(40,-50,52),(0,0,21),(0,0,1))
 for o,_ in states:o.isLightBulbOn=o.component.name.startswith(('P09R','P10R','S01R','H_P10_R'))
 view('右侧正式件',(35,-48,40),(6.5,0,21),(0,0,1))
 for o,v in states:o.isLightBulbOn=v
 view('整体轴测',(75,-90,65),(0,6,17),(0,0,1))
 print(json.dumps({'parts':rows,'health':errors},ensure_ascii=False))
