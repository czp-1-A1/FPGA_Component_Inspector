import adsk.core,adsk.fusion,json
from pathlib import Path
Q=Path('E:/2026FPGA/FPGA_Component_Inspector/开发实施/机械结构展示/机械装配_R2c_合并布局')
def run(_context):
 d=adsk.fusion.Design.cast(adsk.core.Application.get().activeProduct);tm=adsk.fusion.TemporaryBRepManager.get();result=[]
 def value(n):return d.userParameters.itemByName(n).value*10
 def snapshot():
  dims={}
  for o in d.rootComponent.occurrences:
   if not o.component.name.startswith(('P09','P10','E03','E05','E06','E07')):continue
   for b in o.component.bRepBodies:
    t=tm.copy(b);tm.transform(t,o.transform2);bb=t.boundingBox;dims[o.component.name]=[getattr(p,k)*10 for p in [bb.minPoint,bb.maxPoint] for k in 'xyz']
  w=value('board_l');cx=value('board_cx');pw=value('pad_w');widths=[min(cx+w/2,s*65+pw/2)-max(cx-w/2,s*65-pw/2)-5 for s in [-1,1]]
  return {'bounds':dims,'worst_support_width_mm':widths,'support_pass':min(widths)>=12-1e-6,'health':[d.timeline.item(i).name for i in range(d.timeline.count) if getattr(d.timeline.item(i).entity,'healthState',0)!=0]}
 for n,e in [('stack_h','34 mm'),('lens_dx','22 mm'),('lens_dy','5 mm'),('lens_drop','23 mm'),('belt_z','85 mm'),('board_l','128 mm'),('upper_offset_x','1 mm'),('upper_offset_y','1 mm')]:
  p=d.userParameters.itemByName(n);old=p.expression;p.expression=e;d.computeAll();result.append({'parameter':n,'test':e,**snapshot()});p.expression=old;d.computeAll()
  (Q/'evidence/regression.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf8')
 print(json.dumps([{'parameter':r['parameter'],'health':r['health'],'support_pass':r['support_pass']} for r in result]))
