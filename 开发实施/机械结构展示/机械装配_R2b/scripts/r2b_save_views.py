import adsk.core,adsk.fusion,json,time
OUT='E:/2026FPGA/FPGA_Component_Inspector/开发实施/机械结构展示/机械装配_R2b/'
def run(_context):
 app=adsk.core.Application.get();d=adsk.fusion.Design.cast(app.activeProduct);d.activateRootComponent();vp=app.activeViewport
 d.rootComponent.isOriginFolderLightBulbOn=False
 def view(name,eye,target,up,fit=True):
  c=vp.camera;c.cameraType=adsk.core.CameraTypes.OrthographicCameraType;c.isSmoothTransition=False;c.eye=adsk.core.Point3D.create(*eye);c.target=adsk.core.Point3D.create(*target);c.upVector=adsk.core.Vector3D.create(*up);vp.camera=c;adsk.doEvents()
  if fit:vp.fit()
  adsk.doEvents();vp.refresh();time.sleep(.25);adsk.doEvents();assert vp.saveAsImageFile(OUT+'视图/'+name+'.png',1800,1350)
 for name,eye,up in [('整体正视',(0,-100,17),(0,0,1)),('整体俯视',(0,6,120),(0,1,0)),('整体右视',(120,6,17),(0,0,1)),('整体轴测',(75,-90,65),(0,0,1))]:view(name,eye,(0,6,17),up)
 assert d.exportManager.execute(d.exportManager.createFusionArchiveExportOptions(OUT+'FPGA_Inspector_R2b_Parametric.f3d'))
 # Visibility-only detail view; return every occurrence to original state afterwards.
 state=[(o,o.isLightBulbOn) for o in d.rootComponent.occurrences]
 for o,_ in state:o.isLightBulbOn=o.component.name.startswith(('A08','P05','P04','E08','H_P08','H_LAMP_ROOT'))
 view('灯架局部装配',(42,-52,58),(0,1,18),(0,0,1))
 for o,v in state:o.isLightBulbOn=v
 view('整体轴测',(75,-90,65),(0,6,17),(0,0,1))
 print(json.dumps({'native_saved':True,'views':5,'timeline':d.timeline.count,'parameters':d.userParameters.count}))
