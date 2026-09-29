def mat(origin,ax,ay,az):
    m=adsk.core.Matrix3D.create()
    m.setWithCoordinateSystem(P.create(*(v/10 for v in origin)),adsk.core.Vector3D.create(*ax),adsk.core.Vector3D.create(*ay),adsk.core.Vector3D.create(*az))
    return m

def run(_context):
    placements=[mat((x,110,0),(1,0,0),(0,1,0),(0,0,1)) for x in [-110,110]]
    for yy in [170,205]:
      placements.extend([mat((136,yy,0),(0,-1,0),(1,0,0),(0,0,1)),mat((-136,yy,0),(0,1,0),(-1,0,0),(0,0,1))])
    for zz in [60,140]:
      placements.extend([mat((136,122,zz),(0,0,-1),(0,-1,0),(-1,0,0)),mat((-136,122,zz),(0,0,1),(0,-1,0),(1,0,0))])
    footplaces=[(248,-25,math.pi/2),(276,25,-math.pi/2),(-248,25,-math.pi/2),(-276,-25,math.pi/2)]
    for xx,yy,rot in footplaces:
      placements.append(mat((xx,yy,0),(math.cos(rot),math.sin(rot),0),(-math.sin(rot),math.cos(rot),0),(0,0,1)))
    for prefix,targets in [('A01',placements),('A02',placements[-4:])]:
      occs=sorted([o for o in D.rootComponent.occurrences if o.component.name.startswith(prefix)],key=lambda o:int(o.name.rsplit(':',1)[1]))
      for o,m in zip(occs,targets):o.transform2=m
    if D.snapshots.hasPendingSnapshot:D.snapshots.add()
    for o in D.rootComponent.occurrences:
      c=o.component
      if not c.name.startswith('P03'):continue
      sk=next(s for s in c.sketches if s.name=='Upper_acrylic_X_stop_sketch')
      sk.isComputeDeferred=True
      for q in sk.sketchDimensions:
        ex=q.parameter.expression
        if ex=='6 mm':q.parameter.expression='4.75 mm'
        elif 'abs(-board_w / 2 - 1 mm)'==ex:q.parameter.expression='abs(-board_w / 2 + 0.25 mm)'
      sk.isComputeDeferred=False
    D.computeAll()
    print('Captured 18 angle placements and cleared four stop corners')
