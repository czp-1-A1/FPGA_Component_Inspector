import adsk.core,adsk.fusion,json
from pathlib import Path
Q=Path('E:/2026FPGA/FPGA_Component_Inspector/开发实施/机械结构展示/机械装配_R2c_合并布局')
def run(_context):
 d=adsk.fusion.Design.cast(adsk.core.Application.get().activeProduct);tm=adsk.fusion.TemporaryBRepManager.get();P=adsk.core.Point3D;V=adsk.core.Vector3D
 def val(n):return d.userParameters.itemByName(n).value*10
 def collect():
  arr=[]
  for o in d.rootComponent.occurrences:
   if not o.component.name.startswith(('P09','P10','S01','E03','E04','E05','E06','E07','H_P10')):continue
   for b in o.component.bRepBodies:
    t=tm.copy(b);tm.transform(t,o.transform2);arr.append((o.component.name,t))
  return arr
 def shift(b,x=0,y=0,z=0):
  t=tm.copy(b);m=adsk.core.Matrix3D.create();m.translation=V.create(x/10,y/10,z/10);tm.transform(t,m);return t
 def intersect(a,b):
  aa=a.boundingBox;bb=b.boundingBox
  if any(min(getattr(aa.maxPoint,k),getattr(bb.maxPoint,k))-max(getattr(aa.minPoint,k),getattr(bb.minPoint,k))<1e-6 for k in 'xyz'):return 0
  t=tm.copy(a);ok=tm.booleanOperation(t,b,adsk.fusion.BooleanTypes.IntersectionBooleanType)
  assert ok,'Boolean failed'
  return t.volume*1000 if t else 0
 arr=collect();tests=[]
 # Board vertical insertion with both P10 and their bolts removed, final 60mm sampled every 1mm.
 for lift in range(61):
  bad=[]
  for n,b in arr:
   if not n.startswith(('E03','E04','E05','E06','E07')):continue
   moving=shift(b,z=lift)
   for nn,bb in arr:
    if nn.startswith(('P09','S01')):
     v=intersect(moving,bb)
     if v>.01:bad.append([n,nn,v])
  tests.append({'lift_mm':lift,'clashes':bad})
 cap=[]
 for side in ['L','R']:
  for lift in range(41):
   a=next(b for n,b in arr if n.startswith('P10'+side));a=shift(a,z=lift);bad=[]
   for n,b in arr:
    if n.startswith(('P09','E03','E04','E05','E06','E07')):
     v=intersect(a,b)
     if v>.01:bad.append([n,v])
   cap.append({'side':side,'lift_mm':lift,'clashes':bad})
 extremes=[]
 for x in [-.5,.5]:
  for y in [-.5,.5]:
   for z in [0,.5]:
    bad=[]
    for n,b in arr:
     if not n.startswith(('E03','E04','E05','E06','E07')):continue
     t=shift(b,x,y,z)
     for nn,bb in arr:
      if nn.startswith(('P09','P10')):
       v=intersect(t,bb)
       if v>.01:bad.append([n,nn,v])
    extremes.append({'xyz_offset_mm':[x,y,z],'clashes':bad,'lower_Y_stop_vertical_overlap_mm':max(0,val('acrylic_lower_t')-z),'upper_X_stop_vertical_overlap_mm':val('acrylic_upper_t')})
 # Rectangular contact intersection excludes all holes (outside bearing Y zone) and applies conservative 5mm budget.
 contacts=[]
 for sx in [-1,1]:
  for sy in [-1,1]:
   ax=val('board_cx')-val('board_l')/2;bx=ax+val('board_l');px=sx*65-val('pad_w')/2
   width=max(0,min(bx,px+val('pad_w'))-max(ax,px));depth=val('support_depth')
   contacts.append({'side':sx,'end':sy,'nominal_overlap_mm':[width,depth],'budget_deduction_mm':[5,5],'effective_rectangle_mm':[width-5,depth-5],'passes_12x14':width-5>=12-1e-6 and depth-5>=14-1e-6})
 # Opposing printed surfaces bound each XY direction. Locking force seats at hard posts, not acrylic.
 out={'board_insertion':tests,'cap_insertion':cap,'extremes':extremes,'contacts':contacts,'retainer_nominal_gap_mm':val('retainer_gap'),'total_XY_gap_mm':val('lateral_gap'),'hard_post_mm':[val('p09_post_w'),val('p09_post_d')],'washer_OD_mm':9,'washer_to_post_edge_mm':(min(val('p09_post_w'),val('p09_post_d'))-9)/2,'retainer_bolt_pitch_mm':2*val('p09_bolt_y'),'M4_grip_mm':val('pad_t')+10+val('soft_t')+val('stack_h')+val('retainer_gap')+val('p10_t'),'note':'nominal unmeasured rectangles and generic equipment envelopes; actual forbidden regions, upper/lower offsets, manufacturing tolerances still require measurement'}
 (Q/'evidence/board_checks.json').write_text(json.dumps(out,ensure_ascii=False,indent=2),encoding='utf8')
 print(json.dumps({'board_insertion_failed':sum(bool(t['clashes']) for t in tests),'cap_insertion_failed':sum(bool(t['clashes']) for t in cap),'extreme_failures':sum(bool(t['clashes']) for t in extremes),'contacts':contacts}))
