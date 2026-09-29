def run(_context):
    c=D.rootComponent.occurrences.item(0).component;sk=c.sketches.item(0)
    pt=sk.sketchCurves.sketchCircles.item(0).centerSketchPoint
    anchor(sk,pt,'-83 mm','-145 mm')
    print(json.dumps({'dims':[(q.parameter.name,q.parameter.expression) for q in sk.sketchDimensions],'constraints':[g.objectType for g in sk.geometricConstraints]}))
