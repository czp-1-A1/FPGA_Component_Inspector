import adsk.core,adsk.fusion,json

def run(_context):
 d=adsk.fusion.Design.cast(adsk.core.Application.get().activeProduct)
 tm=adsk.fusion.TemporaryBRepManager.get(); arr=[]
 def walk(c,m,path):
  for b in c.bRepBodies:
   t=tm.copy(b);tm.transform(t,m);bb=t.boundingBox
   arr.append((path,b,t,[bb.minPoint.x,bb.minPoint.y,bb.minPoint.z,bb.maxPoint.x,bb.maxPoint.y,bb.maxPoint.z]))
  for o in c.occurrences:
   # Explicit matrix composition: parent * local.
   a=m.asArray();z=o.transform2.asArray();w=adsk.core.Matrix3D.create()
   w.setWithArray([sum(a[r*4+k]*z[k*4+s] for k in range(4)) for r in range(4) for s in range(4)])
   walk(o.component,w,path+'/'+o.name)
 walk(d.rootComponent,adsk.core.Matrix3D.create(),'R2')
 clashes=[];failed=[];tested=0
 for i,(na,ba,a,aa) in enumerate(arr):
  for nb,bb,b,ab in arr[i+1:]:
   if not all(min(aa[k+3],ab[k+3])-max(aa[k],ab[k])>0.00001 for k in range(3)):continue
   t=tm.copy(a);tested+=1
   ok=tm.booleanOperation(t,b,adsk.fusion.BooleanTypes.IntersectionBooleanType)
   if not ok:failed.append([na,nb]);continue
   if t and t.volume>0.00001:clashes.append([na,nb,round(t.volume*1000,5)])
 health=[]
 for i in range(d.timeline.count):
  x=d.timeline.item(i).entity
  if hasattr(x,"healthState") and x.healthState!=adsk.fusion.FeatureHealthStates.HealthyFeatureHealthState:health.append([i,x.name,x.errorOrWarningMessage])
 result={'bodies':len(arr),'tested_pairs':tested,'clashes_mm3':clashes,'boolean_failures':failed,'health':health,'parameters':[{ 'name':p.name,'expression':p.expression,'value_cm':p.value} for p in d.userParameters], 'bounds':[{'name':n,'volume_mm3':b.volume*1000,'bounds_mm':[v*10 for v in bb],'solid':b.isSolid} for n,_,b,bb in arr]}
 open('E:/2026FPGA/FPGA_Component_Inspector/开发实施/机械结构展示/机械装配_R2c_合并布局/evidence/geometry_check.json','w',encoding='utf-8').write(json.dumps(result,ensure_ascii=True,indent=2))
 print(json.dumps({'bodies':len(arr),'clashes':clashes,'health':health,'boolean_failures':len(failed)}))

