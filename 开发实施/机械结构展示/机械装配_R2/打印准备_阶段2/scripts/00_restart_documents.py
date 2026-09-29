import adsk.core,adsk.fusion,json

def run(_context):
 app=adsk.core.Application.get()
 original=app.importManager.importToNewDocument(app.importManager.createFusionArchiveImportOptions('E:/2026FPGA/FPGA_Component_Inspector/开发实施/机械结构展示/机械装配_R2/FPGA_Inspector_R2_Prototype.f3d'))
 original.name='FPGA_Carrier_Inspector_R2_Layout_Review'
 doc=app.documents.add(adsk.core.DocumentTypes.FusionDesignDocumentType);doc.name='R2_Fit_Coupons_Prototype'
 d=adsk.fusion.Design.cast(app.activeProduct);d.designType=adsk.fusion.DesignTypes.ParametricDesignType
 for n,e in [('pad_w','74 mm'),('coupon_w','43 mm'),('board_w','90 mm'),('pad_t','10 mm'),('soft_t','0.5 mm'),('stack_h','30 mm'),('retainer_gap','0.5 mm'),('lateral_gap','1 mm'),('acrylic_t','1 mm'),('slot_d','4.5 mm'),('support_depth','19 mm')]:d.userParameters.add(n,adsk.core.ValueInput.createByString(e),'mm','TEST_COUPON_ASSUMED_VERIFY_WITH_REAL_PARTS')
 print(json.dumps({'active':doc.name,'params':d.userParameters.count,'approved_source':original.name}))
