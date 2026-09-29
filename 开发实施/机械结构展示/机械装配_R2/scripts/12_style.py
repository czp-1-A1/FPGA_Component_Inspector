import adsk.core,adsk.fusion,json

def run(_context):
 app=adsk.core.Application.get();d=adsk.fusion.Design.cast(app.activeProduct)
 colors={'wood':(197,157,103,255),'camera':(36,102,155,255),'light':(219,140,42,255),'metal':(145,153,161,255),'belt':(42,104,91,255),'board':(38,57,92,255),'acrylic':(174,217,235,100),'black':(49,52,56,255)}
 aps={}
 for k,v in colors.items():
  a=d.appearances.add('R2_'+k);a.color=adsk.core.Color.create(*v);a.roughness=.6;aps[k]=a
 seen=set()
 def walk(c):
  if c.id in seen:return
  seen.add(c.id);n=c.name
  key='wood' if n.startswith('W') else 'camera' if n.startswith(('P01','P02','P03')) else 'light' if n.startswith('P') else 'acrylic' if n.startswith(('E03','E05')) else 'board' if n.startswith('E04') else 'belt' if n.startswith('E02') else 'black' if n.startswith(('E06','E07','S')) else 'metal'
  for b in c.bRepBodies:b.appearance=aps[key]
  for o in c.occurrences:walk(o.component)
 walk(d.rootComponent)
 cam=app.activeViewport.camera;cam.cameraType=adsk.core.CameraTypes.OrthographicCameraType;cam.isSmoothTransition=False
 cam.eye=adsk.core.Point3D.create(75,-90,65);cam.target=adsk.core.Point3D.create(0,5,14);cam.upVector=adsk.core.Vector3D.create(0,0,1)
 app.activeViewport.camera=cam;adsk.doEvents();app.activeViewport.fit();app.activeViewport.refresh()
 print('Appearance and Z-up view ready')
