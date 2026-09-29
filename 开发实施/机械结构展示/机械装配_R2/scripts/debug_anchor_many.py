def run(_context):
 c=D.rootComponent.occurrences.item(0).component;sk=c.sketches.item(0)
 for k in range(1,9):
  q=sk.sketchCurves.sketchCircles.item(k)
  x=[-83,-47,47,83][k//9];z='145 mm + camera_pitch * '+str(k%9)
  anchor(sk,q.centerSketchPoint,E(x),neg(z))
  sk.sketchDimensions.addDiameterDimension(q,P.create()).parameter.expression='slot_d'
 print(json.dumps({'fully':sk.isFullyConstrained,'dims':sk.sketchDimensions.count}))
