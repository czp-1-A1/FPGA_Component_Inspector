import adsk.core,adsk.fusion,json,os
def run(_context):
 app=adsk.core.Application.get()
 doc=app.importManager.importToNewDocument(app.importManager.createFusionArchiveImportOptions('E:/2026FPGA/FPGA_Component_Inspector/开发实施/机械结构展示/机械装配_R2/FPGA_Inspector_R2_Prototype.f3d'));doc.name='FPGA_Inspector_R2a_P01_Slot56_Trial';d=adsk.fusion.Design.cast(doc.products.itemByProductType('DesignProductType'))
 root='E:/2026FPGA/FPGA_Component_Inspector/开发实施/机械结构展示/机械装配_R2/打印准备_阶段2/P01修订_R2a/'
 for name in ['evidence','零件STEP','小样STEP','scripts']:os.makedirs(root+name,exist_ok=True)
 c=next(o.component for o in d.rootComponent.occurrences if o.component.name.startswith('P01_'));assert not d.userParameters.itemByName('pad_mount_slot_l')
 d.userParameters.add('pad_mount_slot_l',adsk.core.ValueInput.createByString('56 mm'),'mm','P01承托安装槽总长；不等同相机高度微调槽')
 edits=[]
 for sk in c.sketches:
  if not sk.name.startswith('Pad_position'):continue
  sk.isComputeDeferred=True
  for dim in sk.sketchDimensions:
   p=dim.parameter
   if '60 mm' in p.expression:before=p.expression;p.expression=before.replace('60 mm','pad_mount_slot_l');edits.append({'parameter':p.name,'before':before,'after':p.expression})
  sk.isComputeDeferred=False
 assert len(edits)==8;d.computeAll();c.name='P01_对称托臂_槽56_R2a_待实测'
 e=d.exportManager
 assert e.execute(e.createSTEPExportOptions(root+'零件STEP/P01.step',c))
 assert e.execute(e.createSTEPExportOptions(root+'FPGA_Inspector_R2a_Assembly.step'))
 assert e.execute(e.createFusionArchiveExportOptions(root+'FPGA_Inspector_R2a_Parametric.f3d'))
 bb=c.bRepBodies.item(0).preciseBoundingBox
 meta=[{'code':'P01','name':c.name,'qty':2,'bodies':[{'bounds_mm':[v*10 for v in [bb.minPoint.x,bb.minPoint.y,bb.minPoint.z,bb.maxPoint.x,bb.maxPoint.y,bb.maxPoint.z]],'volume_mm3':c.bRepBodies.item(0).volume*1000,'solid':True}]}]
 open(root+'evidence/part_exports.json','w',encoding='utf8').write(json.dumps(meta,ensure_ascii=True,indent=2));open(root+'evidence/coupons.json','w').write('[]')
 open(root+'evidence/parameter_changes.json','w').write(json.dumps(edits,indent=2))
 d.activateRootComponent();cam=app.activeViewport.camera;cam.isSmoothTransition=False;cam.cameraType=adsk.core.CameraTypes.OrthographicCameraType;cam.eye=adsk.core.Point3D.create(65,-75,60);cam.target=adsk.core.Point3D.create(0,5,14);cam.upVector=adsk.core.Vector3D.create(0,0,1);app.activeViewport.camera=cam;adsk.doEvents();app.activeViewport.fit();app.activeViewport.refresh();app.activeViewport.saveAsImageFile(root+'R2a_整体.png',1400,1000)
 print(json.dumps({'changed':len(edits),'shared_occurrences':sum(o.component==c for o in d.rootComponent.occurrences),'timeline':d.timeline.count}))
