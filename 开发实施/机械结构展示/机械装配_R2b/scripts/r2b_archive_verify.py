import adsk.core,adsk.fusion,json
OUT='E:/2026FPGA/FPGA_Component_Inspector/开发实施/机械结构展示/机械装配_R2b/'
def run(_context):
 a=adsk.core.Application.get();doc=a.importManager.importToNewDocument(a.importManager.createFusionArchiveImportOptions(OUT+'FPGA_Inspector_R2b_Parametric.f3d'));doc.name='FPGA_Inspector_R2b_Layout_Review'
 d=adsk.fusion.Design.cast(a.activeProduct);d.activateRootComponent();out={'document':doc.name,'timeline':d.timeline.count,'parameters':d.userParameters.count,'body_count':sum(o.component.bRepBodies.count for o in d.rootComponent.allOccurrences),'old_active':[o.name for o in d.rootComponent.occurrences if o.component.name.startswith(('P06','P07','S03','H_RING','H_BRIDGE'))],'P08':[],'health':[]}
 for o in d.rootComponent.allOccurrences:
  if not o.component.name.startswith('P08'):continue
  c=o.component;b=c.bRepBodies.item(0);bb=b.preciseBoundingBox;out['P08'].append({'id':c.id,'occurrence':o.fullPathName,'matrix':o.transform2.asArray(),'volume_mm3':b.volume*1000,'bbox_mm':[getattr(p,k)*10 for p in [bb.minPoint,bb.maxPoint] for k in ['x','y','z']],'sketches_fully_constrained':all(s.isFullyConstrained for s in c.sketches)})
 for i in range(d.timeline.count):
  e=d.timeline.item(i).entity
  if hasattr(e,'healthState') and e.healthState!=adsk.fusion.FeatureHealthStates.HealthyFeatureHealthState:out['health'].append([e.name,e.errorOrWarningMessage])
 vp=a.activeViewport;c=vp.camera;c.cameraType=adsk.core.CameraTypes.OrthographicCameraType;c.isSmoothTransition=False;c.eye=adsk.core.Point3D.create(75,-90,65);c.target=adsk.core.Point3D.create(0,6,17);c.upVector=adsk.core.Vector3D.create(0,0,1);vp.camera=c;adsk.doEvents();vp.fit();adsk.doEvents();vp.refresh()
 open(OUT+'evidence/archive_readback.json','w',encoding='utf8').write(json.dumps(out,ensure_ascii=False,indent=2));print(json.dumps(out))
