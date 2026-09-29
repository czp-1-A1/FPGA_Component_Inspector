def run(_context):
    c,o=component('DEBUG_OWN_TEMP')
    sk,p,ce,sign=sketch(c,'y',109,'test')
    q=sk.sketchCurves.sketchCircles.addByCenterRadius(p(-83,145),.225)
    pt=q.centerSketchPoint
    info={'coord':[pt.geometry.x,pt.geometry.y,pt.geometry.z],'expr':[ce(-83,145,0),ce(-83,145,1)],'constraints':[g.objectType for g in sk.geometricConstraints],'fixed':pt.isFixed,'ref':pt.isReference,'origin':[sk.originPoint.geometry.x,sk.originPoint.geometry.y,sk.originPoint.geometry.z]}
    print(json.dumps(info))
