def run(_context):
    bad=[];bs=[]
    for i in range(D.timeline.count):
      e=D.timeline.item(i).entity
      if getattr(e,'healthState',0)!=0:
        bad.append({'index':i,'name':getattr(e,'name',''),'type':e.objectType,'parent':getattr(getattr(e,'parentComponent',None),'name',''),'message':getattr(e,'errorOrWarningMessage','')})
    for o in D.rootComponent.occurrences:
      if o.component.name.startswith(('E08','P06','P07')):
        bs.append({'name':o.name,'volumes':[b.volume*1000 for b in o.component.bRepBodies]})
    print(json.dumps({'unhealthy':bad,'lamp_bodies':bs},ensure_ascii=True))
