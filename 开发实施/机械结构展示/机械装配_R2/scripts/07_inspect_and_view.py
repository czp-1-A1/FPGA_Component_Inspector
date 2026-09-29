def run(_context):
    out=[];seen=set()
    for o in D.rootComponent.occurrences:
      c=o.component
      if c.id not in seen:
        seen.add(c.id)
        if all(ord(ch)<256 for ch in c.name) and any(ord(ch)>127 for ch in c.name):c.name=c.name.encode('latin1').decode('utf-8')
      bs=[]
      for body in c.bRepBodies:
        bb=body.preciseBoundingBox
        bs.append({'solid':body.isSolid,'volume_mm3':body.volume*1000,'bounds_local_mm':[v*10 for v in [bb.minPoint.x,bb.minPoint.y,bb.minPoint.z,bb.maxPoint.x,bb.maxPoint.y,bb.maxPoint.z]]})
      out.append({'name':o.name,'bodies':bs,'transform':o.transform2.asArray()})
    camera=APP.activeViewport.camera
    camera.cameraType=adsk.core.CameraTypes.OrthographicCameraType
    camera.eye=P.create(75,-90,65);camera.target=P.create(0,5,14);camera.upVector=adsk.core.Vector3D.create(0,0,1)
    camera.isSmoothTransition=False;APP.activeViewport.camera=camera
    adsk.doEvents();APP.activeViewport.fit();APP.activeViewport.refresh()
    ap=D.rootComponent.occurrences.item(0).component.bRepBodies.item(0).appearance
    print(json.dumps({'geometry':out,'appearance':ap.name,'appearance_properties':[(q.id,q.objectType) for q in ap.appearanceProperties]},ensure_ascii=True))
