def run(_context):
 sk=D.rootComponent.occurrences.item(0).component.sketches.item(0)
 pt=sk.sketchCurves.sketchCircles.item(1).centerSketchPoint
 a=[pt.geometry.x,pt.geometry.y]
 sk.sketchDimensions.addDistanceDimension(sk.originPoint,pt,HOR,P.create(-4,-17,0)).parameter.expression='83 mm'
 print(json.dumps({'before':a,'after':[pt.geometry.x,pt.geometry.y],'dims':[(q.parameter.expression,q.objectType) for q in sk.sketchDimensions],'constraints':[g.objectType for g in sk.geometricConstraints],'fixed':pt.isFixed}))
