import adsk.core,adsk.fusion,json
def run(_context):
 app=adsk.core.Application.get();d=adsk.fusion.Design.cast(app.activeProduct);out={'document':app.activeDocument.name,'timeline':d.timeline.count,'docs':[x.name for x in app.documents]}
 print(json.dumps(out));c=next((o.component for o in d.rootComponent.occurrences if o.component.name.startswith('P01_')),None)
 if not c:return
 out['sketches']=[{'name':s.name,'dimensions':[{'name':v.parameter.name,'expression':v.parameter.expression} for v in s.sketchDimensions]} for s in c.sketches if s.name.startswith('Pad_position')]
 p='E:/2026FPGA/FPGA_Component_Inspector/开发实施/机械结构展示/机械装配_R2/打印准备_阶段2/evidence/'
 app.activeViewport.saveAsImageFile(p+'P01_revision_before.png',1400,1000)
 open(p+'P01_preflight.json','w',encoding='utf8').write(json.dumps(out,ensure_ascii=True,indent=2));print(json.dumps(out))

