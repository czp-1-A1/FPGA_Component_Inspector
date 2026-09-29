def run(_context):
 seen=set();changes=[]
 for o in D.rootComponent.occurrences:
  c=o.component
  if c.id not in seen and c.name.startswith(('W02','W03','P05')):
   seen.add(c.id)
   for s in c.sketches:
    if c.name.startswith(('W02','W03')) and s.name.startswith('Angle_fixings'):
     for q in s.sketchDimensions:
      if '140 mm' in q.parameter.expression:q.parameter.expression=q.parameter.expression.replace('140 mm','110 mm');changes.append(q.parameter.name)
    if c.name.startswith('P05') and s.name.startswith('Top_rib'):
     for q in s.sketchDimensions:
      if q.parameter.expression=='abs(-46 mm)':q.parameter.expression='abs(-29 mm)';changes.append(q.parameter.name)
  if c.name.startswith('A01') and int(o.name.rsplit(':',1)[1]) in [9,10]:
   m=o.transform2;t=m.translation;t.z=11;m.translation=t;o.transform2=m
 if D.snapshots.hasPendingSnapshot:D.snapshots.add()
 D.computeAll();print(json.dumps({'changed_dimensions':changes,'upper_brace_connection_z_mm':110,'lamp_rib_front_y_mm':45}))

