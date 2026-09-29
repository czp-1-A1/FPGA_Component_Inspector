def run(_context):
 for o in D.rootComponent.occurrences:
  if o.component.name.startswith(('A01','A02')):
   print(o.name,o.transform2.asArray())
   if o.name.endswith(':1'):
    for p in o.component.occurrences:print('CHILD',p.name,p.transform2.asArray())
 for o in D.rootComponent.occurrences:
  if o.component.name.startswith('P03_LF'):
   for s in o.component.sketches:
    if 'X_stop' in s.name:print('DIMS',s.name,[(q.parameter.expression,q.parameter.name) for q in s.sketchDimensions])
