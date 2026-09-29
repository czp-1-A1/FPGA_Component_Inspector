def run(_context):
    done=[];seen=set()
    for o in D.rootComponent.occurrences:
      c=o.component
      if c.id in seen or not c.name.startswith(('P06','P07','E08')):continue
      seen.add(c.id)
      for sk in c.sketches:
        dims=[];constraints=[];pt=None;ex=None;ey=None
        for q in sk.sketchDimensions:
          if not isinstance(q,adsk.fusion.SketchLinearDimension):continue
          if q.entityOne!=sk.originPoint:continue
          if not q.parameter.expression.startswith('abs('):continue
          pt=q.entityTwo
          expr=q.parameter.expression[4:-1]
          if q.orientation==HOR:ex=expr
          else:ey=expr
          dims.append(q)
        for g in sk.geometricConstraints:
          if isinstance(g,adsk.fusion.CoincidentConstraint):
            one=g.point;two=g.entity
          elif isinstance(g,(adsk.fusion.HorizontalPointsConstraint,adsk.fusion.VerticalPointsConstraint)):
            one=g.pointOne;two=g.pointTwo
          else:continue
          if one==sk.originPoint:pt=two;constraints.append(g)
          elif two==sk.originPoint:pt=one;constraints.append(g)
        if pt is None:continue
        if ex is None:ex=E(round(pt.geometry.x*10,8))
        if ey is None:ey='lamp_y' if abs(pt.geometry.x)<1e-7 and abs(pt.geometry.y)<1e-7 and sk.sketchCurves.sketchCircles.count else E(round(pt.geometry.y*10,8))
        for q in dims:q.deleteMe()
        for g in constraints:g.deleteMe()
        anchor(sk,pt,ex,ey)
        done.append(c.name+'/'+sk.name)
    D.computeAll()
    print(json.dumps({'signed_coordinate_sketches':len(done),'names':done},ensure_ascii=True))
