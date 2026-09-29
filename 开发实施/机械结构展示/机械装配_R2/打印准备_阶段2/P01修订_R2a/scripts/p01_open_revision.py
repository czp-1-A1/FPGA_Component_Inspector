import adsk.core,adsk.fusion,json
def run(_context):
 app=adsk.core.Application.get();app.activeViewport.saveAsImageFile('E:/2026FPGA/FPGA_Component_Inspector/开发实施/机械结构展示/机械装配_R2/打印准备_阶段2/evidence/active_before_R2a.png',1200,900)
 doc=app.importManager.importToNewDocument(app.importManager.createFusionArchiveImportOptions('E:/2026FPGA/FPGA_Component_Inspector/开发实施/机械结构展示/机械装配_R2/FPGA_Inspector_R2_Prototype.f3d'));doc.name='FPGA_Inspector_R2a_P01_Slot56_Trial'
 print(json.dumps({'new_copy':doc.name}))
