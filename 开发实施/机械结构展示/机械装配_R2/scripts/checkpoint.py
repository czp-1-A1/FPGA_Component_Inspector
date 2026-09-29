import adsk.core,adsk.fusion,json

def run(_context):
 d=adsk.fusion.Design.cast(adsk.core.Application.get().activeProduct)
 print(json.dumps({'components':[o.component.name for o in d.rootComponent.occurrences],'timeline':d.timeline.count}))
 e=d.exportManager
 print('CHECKPOINT',e.execute(e.createFusionArchiveExportOptions('E:/2026FPGA/FPGA_Component_Inspector/开发实施/机械结构展示/机械装配_R2/R2_working_checkpoint.f3d')))

