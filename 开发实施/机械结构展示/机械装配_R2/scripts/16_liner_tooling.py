def run(_context):
 seen=set()
 for o in D.rootComponent.occurrences:
  c=o.component
  if c.id in seen or not c.name.startswith('H_LAMP_ROOT') or 'Bolt' not in c.name:continue
  seen.add(c.id)
  for s in c.sketches:
   if s.name=='Socket_head_sketch':
    for q in s.sketchDimensions:
     if q.parameter.expression=='7 mm':q.parameter.expression='8.1 mm'
  c.name=c.name.replace('Bolt','HexHead_Bolt')
  c.attributes.add('R2','geometry_note','M4 AF7 external hex head, conservative OD8.1 envelope; use side-entry 7mm spanner in open rear channel; verify actual purchased head dimensions')
 for rear in [False,True]:
  c,o=component('S03'+('A' if rear else 'B')+'_灯圈软衬_0p5厚_待实配')
  cylinder(c,'Soft_liner','z','ring_z+2 mm',12,0,'lamp_y',91,inner=90)
  box(c,'Split_liner',-60,'lamp_y-60 mm' if rear else 'lamp_y-1 mm','ring_z+1 mm',120,61,14,OP.CutFeatureOperation)
  box(c,'Cable_window',-8,'lamp_y+42 mm' if rear else 'lamp_y-60 mm','ring_z+4 mm',16,18,8,OP.CutFeatureOperation)
  c.attributes.add('R2','material','SOFT_LINER_0.5_ASSUMED_TEST_REQUIRED')
 print('Added split soft liner and specified side-access external hex lamp-root bolts')
