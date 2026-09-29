import adsk.core,adsk.fusion,json
def run(_context):
 d=adsk.fusion.Design.cast(adsk.core.Application.get().activeProduct)
 out=[]
 for o in d.rootComponent.occurrences:
  c=o.component
  out.append({'name':c.name,'bodies':c.bRepBodies.count,'sketches':[{'name':s.name,'curves':s.sketchCurves.count,'fully':s.isFullyConstrained,'constraints':[g.objectType for g in s.geometricConstraints],'dimensions':[(q.parameter.name,q.parameter.expression) for q in s.sketchDimensions]} for s in c.sketches]})
 print(json.dumps(out,ensure_ascii=False))
