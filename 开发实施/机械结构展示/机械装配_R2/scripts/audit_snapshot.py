def run(_context):
    out=[]
    for o in D.rootComponent.occurrences:
      bs=[]
      for body in o.component.bRepBodies:
        b=body.preciseBoundingBox
        bs.append({'name':body.name,'solid':body.isSolid,'volume':body.volume*1000,'bounds':[round(v*10,4) for v in [b.minPoint.x,b.minPoint.y,b.minPoint.z,b.maxPoint.x,b.maxPoint.y,b.maxPoint.z]]})
      out.append({'name':o.name,'bodies':bs})
    print(json.dumps(out,ensure_ascii=True))
