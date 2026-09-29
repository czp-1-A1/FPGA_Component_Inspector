def run(_context):
    o=D.rootComponent.occurrences.item(0);assert o.component.name=='DEBUG_OWN_TEMP';o.deleteMe()
    c,o=component('DEBUG_OWN_TEMP')
    sk,p,ce,sign=sketch(c,'y',109,'test')
    out=[]
    for x in [-83,-47,47,83]:
      for i in range(9):
        z='145 mm + camera_pitch * '+str(i)
        q=sk.sketchCurves.sketchCircles.addByCenterRadius(p(x,z),.225)
        pt=q.centerSketchPoint
        out.append({'coords':[pt.geometry.x,pt.geometry.y],'expr':[ce(x,z,0),ce(x,z,1)],'point_idx':pt.entityToken[-24:],'constraints':sk.geometricConstraints.count})
    print(json.dumps(out))
