import adsk.core,adsk.fusion,json
def run(_context):
 app=adsk.core.Application.get();original=app.activeDocument
 path='E:/2026FPGA/FPGA_Component_Inspector/开发实施/机械结构展示/机械装配_R2/打印准备_阶段2/'
 doc=app.importManager.importToNewDocument(app.importManager.createFusionArchiveImportOptions(path+'R2_关键配合小样.f3d'));d=adsk.fusion.Design.cast(app.activeProduct)
 d.computeAll();errors=[];sketches=[];parts=[]
 for o in d.rootComponent.occurrences:
  c=o.component
  parts.append({'name':c.name,'bodies':c.bRepBodies.count,'solid':all(b.isSolid for b in c.bRepBodies)})
  for s in c.sketches:sketches.append({'part':c.name,'name':s.name,'fully_constrained':s.isFullyConstrained})
 for i in range(d.timeline.count):
  e=d.timeline.item(i).entity
  if hasattr(e,'healthState') and e.healthState!=adsk.fusion.FeatureHealthStates.HealthyFeatureHealthState:errors.append({'index':i,'name':e.name,'message':e.errorOrWarningMessage})
 result={'archive_reopened':True,'parameters':d.userParameters.count,'timeline':d.timeline.count,'parts':parts,'sketches':sketches,'feature_errors':errors}
 open(path+'evidence/native_coupon_verify.json','w',encoding='utf8').write(json.dumps(result,ensure_ascii=True,indent=2))
 doc.close(False);original.activate()
 d=adsk.fusion.Design.cast(app.activeProduct);d.activateRootComponent()
 cam=app.activeViewport.camera;cam.cameraType=adsk.core.CameraTypes.OrthographicCameraType;cam.isSmoothTransition=False;cam.eye=adsk.core.Point3D.create(65,-75,60);cam.target=adsk.core.Point3D.create(0,5,14);cam.upVector=adsk.core.Vector3D.create(0,0,1);app.activeViewport.camera=cam;adsk.doEvents();app.activeViewport.fit();app.activeViewport.refresh()
 print(json.dumps({'parts':len(parts),'errors':errors,'sketches':len(sketches),'constrained':sum(s['fully_constrained'] for s in sketches)}))
