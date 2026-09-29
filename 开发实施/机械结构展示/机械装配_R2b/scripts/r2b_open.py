import adsk.core,adsk.fusion,json
OUT='E:/2026FPGA/FPGA_Component_Inspector/开发实施/机械结构展示/机械装配_R2b/'
def run(_context):
    app=adsk.core.Application.get()
    src='E:/2026FPGA/FPGA_Component_Inspector/开发实施/机械结构展示/机械装配_R2/打印准备_阶段2/P01修订_R2a/FPGA_Inspector_R2a_Parametric.f3d'
    doc=app.importManager.importToNewDocument(app.importManager.createFusionArchiveImportOptions(src));doc.name='FPGA_Inspector_R2b_Rear_M3_Trial'
    d=adsk.fusion.Design.cast(app.activeProduct);d.activateRootComponent()
    out={'document':doc.name,'timeline':d.timeline.count,'parameters':[{ 'name':p.name,'expression':p.expression} for p in d.userParameters], 'occurrences':[{'name':o.name,'component':o.component.name,'bodies':o.component.bRepBodies.count,'matrix':o.transform2.asArray()} for o in d.rootComponent.occurrences]}
    open(OUT+'evidence/baseline.json','w',encoding='utf8').write(json.dumps(out,ensure_ascii=False,indent=2))
    app.activeViewport.fit();adsk.doEvents();app.activeViewport.saveAsImageFile(OUT+'evidence/baseline.png',1400,1000)
    print(json.dumps({'document':doc.name,'timeline':d.timeline.count,'occurrences':len(out['occurrences'])}))
