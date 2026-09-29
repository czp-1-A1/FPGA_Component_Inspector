import adsk.core,adsk.fusion,json,time,os

def run(_context):
 app=adsk.core.Application.get();vp=app.activeViewport;adsk.fusion.Design.cast(app.activeProduct).activateRootComponent()
 root='E:/2026FPGA/FPGA_Component_Inspector/开发实施/机械结构展示/机械装配_R2/'
 os.makedirs(root+'整体视图',exist_ok=True)
 views=[('Front',(0,-100,17),(0,0,1)),('Top',(0,6,120),(0,1,0)),('Right',(120,6,17),(0,0,1)),('Isometric',(75,-90,65),(0,0,1))]
 for name,eye,up in views:
  c=vp.camera;c.cameraType=adsk.core.CameraTypes.OrthographicCameraType;c.isSmoothTransition=False
  c.eye=adsk.core.Point3D.create(*eye);c.target=adsk.core.Point3D.create(0,6,17);c.upVector=adsk.core.Vector3D.create(*up)
  vp.camera=c;adsk.doEvents();vp.fit();adsk.doEvents();vp.refresh();time.sleep(.3);adsk.doEvents()
  print(name,vp.saveAsImageFile(root+'整体视图/R2_'+name+'.png',2000,1500))

