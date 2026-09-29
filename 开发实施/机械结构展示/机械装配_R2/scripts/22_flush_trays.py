def cone(c,name,z1,d1,z2,d2,u,v,op):
 sections=[]
 for z,di in [(z1,d1),(z2,d2)]:
  sk,p,ce,sign=sketch(c,'z',z,name+'_section_'+str(len(sections)))
  circle(sk,p,ce,u,v,di);sections.append(sk)
 li=c.features.loftFeatures.createInput(op)
 for sk in sections:li.loftSections.add(sk.profiles.item(0))
 if op==OP.CutFeatureOperation:li.participantBodies=[b for b in c.bRepBodies]
 ft=c.features.loftFeatures.add(li);ft.name=name
 for sk in sections:sk.isLightBulbOn=False

def run(_context):
 global PARENT
 a=next(o.component for o in D.rootComponent.occurrences if o.component.name.startswith('A02'))
 for o in list(a.occurrences):
  if o.component.name.startswith('H_TRAY_TOP') and ('Bolt' in o.component.name or 'Washer_head' in o.component.name):o.deleteMe()
 PARENT=a;c,o=component('H_TRAY_TOP_Countersunk_M4x20_顶面低0p2')
 cylinder(c,'Shank','z','belt_z-20.2 mm',18,0,-12.5,4)
 cone(c,'Countersunk_head_90deg','belt_z-2.2 mm',4,'belt_z-0.2 mm',8,0,-12.5,OP.JoinFeatureOperation)
 c.attributes.add('R2','geometry_note','Purchased M4x20 countersunk screw; 20mm overall length includes head; no top washer; top recessed 0.2mm; verify actual head and countersink')
 PARENT=D.rootComponent
 tray=next(o.component for o in D.rootComponent.occurrences if o.component.name.startswith('W04'))
 for i,(x,y) in enumerate([(260.5,-25),(263.5,25)]):cone(tray,'Flush_head_recess_'+str(i),'belt_z-2 mm',4.4,'belt_z',8.4,x,y,OP.CutFeatureOperation)
 # Make the closure-limit parameter actually drive the four stop faces.
 for o in D.rootComponent.occurrences:
  if not o.component.name.startswith('P06'):continue
  for sk in o.component.sketches:
   if not sk.name.startswith('Closure_limit'):continue
   sk.isComputeDeferred=True
   for q in sk.sketchDimensions:
    ex=q.parameter.expression
    if ex=='0.5 mm':q.parameter.expression='(ring_gap-ring_close_limit)/2'
    elif 'ring_gap / 2 - 0.5 mm' in ex:q.parameter.expression=ex.replace('ring_gap / 2 - 0.5 mm','ring_close_limit / 2')
   sk.isComputeDeferred=False
 D.computeAll();print('Four countersunk tray screws, two shared recesses; closure-limit parameter connected')
