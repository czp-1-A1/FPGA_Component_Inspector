import adsk.core,adsk.fusion,json
def run(_context):
 app=adsk.core.Application.get();original=app.activeDocument
 root='E:/2026FPGA/FPGA_Component_Inspector/开发实施/机械结构展示/机械装配_R2/打印准备_阶段2/P01修订_R2a/'
 doc=app.importManager.importToNewDocument(app.importManager.createFusionArchiveImportOptions(root+'FPGA_Inspector_R2a_Parametric.f3d'));d=adsk.fusion.Design.cast(doc.products.itemByProductType('DesignProductType'));d.computeAll()
 occurrences=[o for o in d.rootComponent.occurrences if o.component.name.startswith('P01_')];c=occurrences[0].component;errors=[]
 for i in range(d.timeline.count):
  x=d.timeline.item(i).entity
  if hasattr(x,'healthState') and x.healthState!=adsk.fusion.FeatureHealthStates.HealthyFeatureHealthState:errors.append(x.name)
 result={'archive_reopened':True,'timeline':d.timeline.count,'parameters':d.userParameters.count,'pad_mount_slot_l_mm':d.userParameters.itemByName('pad_mount_slot_l').value*10,'camera_slot_l_mm':d.userParameters.itemByName('camera_slot_l').value*10,'two_shared_arms':len(occurrences)==2 and occurrences[1].component==c,'arm_positions_mm':[[v*10 for v in o.transform2.translation.asArray()] for o in occurrences],'P01_sketches_constrained':all(s.isFullyConstrained for s in c.sketches),'feature_errors':errors}
 result['component_ids']=[o.component.id for o in occurrences];result['two_shared_arms']=len(occurrences)==2 and occurrences[1].component.id==c.id
 open(root+'evidence/native_archive_check.json','w').write(json.dumps(result,indent=2));print(json.dumps(result));doc.close(False);original.activate()
