import adsk.core,adsk.fusion,json,os

def run(_context):
 app=adsk.core.Application.get();d=adsk.fusion.Design.cast(app.activeProduct)
 path='E:/2026FPGA/FPGA_Component_Inspector/开发实施/机械结构展示/机械装配_R2/'
 e=d.exportManager
 native=e.execute(e.createFusionArchiveExportOptions(path+'FPGA_Inspector_R2_Prototype.f3d'))
 step=e.execute(e.createSTEPExportOptions(path+'FPGA_Inspector_R2_Assembly.step'))
 counts={'user_parameters':d.userParameters.count,'timeline':d.timeline.count,'all_occurrences':d.rootComponent.allOccurrences.count,'native_export':native,'step_export':step}
 open(path+'evidence/export_counts.json','w').write(json.dumps(counts,indent=2))
 print(json.dumps(counts))
