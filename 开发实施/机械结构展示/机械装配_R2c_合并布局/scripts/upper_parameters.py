import adsk.core,adsk.fusion,json,re
from pathlib import Path
Q=Path('E:/2026FPGA/FPGA_Component_Inspector/开发实施/机械结构展示/机械装配_R2c_合并布局')
def run(_context):
 d=adsk.fusion.Design.cast(adsk.core.Application.get().activeProduct);vi=adsk.core.ValueInput
 specs=[('upper_board_l','board_l'),('upper_board_w','board_w'),('upper_offset_x','0 mm'),('upper_offset_y','0 mm'),('upper_cx','board_cx+upper_offset_x'),('upper_cy','board_cy+upper_offset_y')]
 for n,e in specs:d.userParameters.add(n,vi.createByString(e),'mm','UNMEASURED upper acrylic dimensions / offsets; must confirm before manufacturing')
 changes=[]
 for o in d.rootComponent.occurrences:
  c=o.component
  if c.name.startswith('E05'):
   for p in c.modelParameters:
    old=p.expression;new=re.sub(r'\bboard_l\b','upper_board_l',old);new=re.sub(r'\bboard_w\b','upper_board_w',new);new=re.sub(r'-\s*lens_dx\b','upper_cx',new);new=re.sub(r'-\s*lens_dy\b','upper_cy',new)
    if new!=old:p.expression=new;changes.append([c.name,old,new])
  if c.name.startswith('P10'):
   for s in c.sketches:
    if not s.name.startswith('X_positive_stop'):continue
    for dim in s.sketchDimensions:
     p=dim.parameter;old=p.expression;new=re.sub(r'\bboard_l\b','upper_board_l',old);new=re.sub(r'\bboard_w\b','upper_board_w',new);new=re.sub(r'\bboard_cx\b','upper_cx',new);new=re.sub(r'\bboard_cy\b','upper_cy',new)
     if new!=old:p.expression=new;changes.append([c.name,old,new])
  if c.name.startswith('A08'):
   for sub in c.occurrences:
    if sub.component.name.startswith('REF_M3'):
     sub.component.name=sub.component.name.replace('长度待定','暂选M3x12_内嵌段未绘')
     sub.component.attributes.add('R2c','M3_Q1','M3x12 provisional; nominal engagement2.5; modeled shank omits embedded segment; drawing depth4 not confirmed usable')
 d.computeAll()
 out={'changes':changes,'new_parameters':specs,'health':[(d.timeline.item(i).name,getattr(d.timeline.item(i).entity,'errorOrWarningMessage','')) for i in range(d.timeline.count) if getattr(d.timeline.item(i).entity,'healthState',0)!=0]}
 (Q/'evidence/upper_parameters.json').write_text(json.dumps(out,ensure_ascii=False,indent=2),encoding='utf8');print(json.dumps(out,ensure_ascii=False))
