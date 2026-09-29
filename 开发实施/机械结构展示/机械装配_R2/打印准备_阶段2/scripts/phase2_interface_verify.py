import adsk.core,adsk.fusion,json
def run(_context):
 app=adsk.core.Application.get();ds={doc.name:adsk.fusion.Design.cast(doc.products.itemByProductType('DesignProductType')) for doc in app.documents};a=ds['FPGA_Carrier_Inspector_R2_Layout_Review'];b=ds['R2_Fit_Coupons_Prototype'];tm=adsk.fusion.TemporaryBRepManager.get();results=[]
 for small,big,offset in [('CT01','P02',(0,0,-194.5)),('CT02','P03_RB',(-65,0,-194.5))]:
  source=next(o.component.bRepBodies.item(0) for o in a.rootComponent.occurrences if o.component.name.startswith(big+'_'))
  test=next(o.component.bRepBodies.item(0) for o in b.rootComponent.occurrences if o.component.name.startswith(small+'_'))
  moved=tm.copy(source);m=adsk.core.Matrix3D.create();m.translation=adsk.core.Vector3D.create(*(v/10 for v in offset));assert tm.transform(moved,m)
  obb=adsk.core.OrientedBoundingBox3D.create(adsk.core.Point3D.create(-1.55,5,4),adsk.core.Vector3D.create(1,0,0),adsk.core.Vector3D.create(0,1,0),4.3,10,12)
  box=tm.createBox(obb);assert tm.booleanOperation(moved,box,adsk.fusion.BooleanTypes.IntersectionBooleanType)
  v1=moved.volume*1000;v2=test.volume*1000;common=tm.copy(moved);assert tm.booleanOperation(common,test,adsk.fusion.BooleanTypes.IntersectionBooleanType);vi=common.volume*1000 if common else 0
  results.append({'coupon':small,'source':big,'source_crop_volume_mm3':v1,'coupon_volume_mm3':v2,'intersection_mm3':vi,'symmetric_difference_mm3':v1+v2-2*vi,'matching':abs(v1+v2-2*vi)<.001})
 open('E:/2026FPGA/FPGA_Component_Inspector/开发实施/机械结构展示/机械装配_R2/打印准备_阶段2/evidence/native_interface_comparison.json','w',encoding='utf8').write(json.dumps(results,indent=2));print(json.dumps(results))
