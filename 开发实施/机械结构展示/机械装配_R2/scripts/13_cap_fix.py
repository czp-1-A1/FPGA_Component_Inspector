def run(_context):
 for o in D.rootComponent.occurrences:
  c=o.component
  if not c.name.startswith('P03'):continue
  sk=next(s for s in c.sketches if s.name=='Upper_acrylic_X_stop')
  for q in sk.sketchDimensions:
   ex=q.parameter.expression
   if ex=='6 mm':q.parameter.expression='4.75 mm'
   elif '-board_w/2-1 mm' in ex.replace(' ',''):
    q.parameter.expression=ex.replace('-board_w/2-1 mm','-board_w/2+0.25 mm')
   elif ex.startswith('abs(') and 'board_w' in ex and '1 mm' in ex:
    q.parameter.expression=ex.replace('-1 mm','+0.25 mm')
 print('P03 X stop shortened to clear Y stop; inspect geometry required')
