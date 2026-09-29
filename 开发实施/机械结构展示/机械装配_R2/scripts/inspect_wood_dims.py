def run(_context):
 for o in D.rootComponent.occurrences:
  if not o.component.name.startswith(('W02','W03')):continue
  for s in o.component.sketches:
   if s.name.startswith('Angle_fixings'):print(o.component.name,s.name,[q.parameter.expression for q in s.sketchDimensions])
