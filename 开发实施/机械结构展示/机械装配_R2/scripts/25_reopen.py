import adsk.core,adsk.fusion,json

def run(_context):
 app=adsk.core.Application.get();original=app.activeDocument
 doc=app.importManager.importToNewDocument(app.importManager.createFusionArchiveImportOptions('E:/2026FPGA/FPGA_Component_Inspector/开发实施/机械结构展示/机械装配_R2/FPGA_Inspector_R2_Prototype.f3d'))
 d=adsk.fusion.Design.cast(app.activeProduct)
 result={'reopened':bool(doc),'parameters':d.userParameters.count,'timeline':d.timeline.count,'all_occurrences':d.rootComponent.allOccurrences.count,'design_type':str(d.designType),'active_document':doc.name}
 assert result['parameters']==55 and result['timeline']==1244 and result['all_occurrences']==342
 open('E:/2026FPGA/FPGA_Component_Inspector/开发实施/机械结构展示/机械装配_R2/evidence/native_reopen.json','w',encoding='utf8').write(json.dumps(result,ensure_ascii=True,indent=2))
 doc.close(False);original.activate();print(json.dumps(result))
