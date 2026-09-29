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

 def kind(n):
  n=n.split('/')[1]
  if n.startswith('H_CAM_ROOT'):return 'root'
  if n.startswith(('P09','P10','S01','E03','E04','E05','E06','E07','H_P10')):return 'camera'
  if n.startswith(('A08','E08','H_P08')):return 'lampxy'
  if n.startswith(('P05','H_LAMP_ROOT')):return 'lampz'
  return 'fixed'
 classes=[kind(n) for n,_,_,_ in arr]
 def pose(wd,light,y=0):
  row=max(125,min(305,125+20*round((wd+84.5-125)/20)))
  ds={'fixed':(0,0,0),'camera':(0,0,(wd-100)/10),'root':(0,0,(row-185)/10),'lampz':(0,0,(light-60)/10),'lampxy':(0,y/10,(light-60)/10)}
  boxes=[[v+ds[k][i%3] for i,v in enumerate(a[3])] for a,k in zip(arr,classes)]
  cache={};bad=[]
  def body(i):
   if i not in cache:
    cache[i]=tm.copy(arr[i][2]);m=adsk.core.Matrix3D.create();m.translation=adsk.core.Vector3D.create(*ds[classes[i]]);tm.transform(cache[i],m)
   return cache[i]
  for i in range(len(arr)):
   for j in range(i+1,len(arr)):
    if ds[classes[i]]==ds[classes[j]]:continue
    a=boxes[i];b=boxes[j]
    if not all(min(a[k+3],b[k+3])-max(a[k],b[k])>1e-5 for k in range(3)):continue
    t=tm.copy(body(i));ok=tm.booleanOperation(t,body(j),adsk.fusion.BooleanTypes.IntersectionBooleanType)
    if not ok:bad.append(['BOOLEAN_FAILED',arr[i][0],arr[j][0]])
    elif t and t.volume>1e-5:bad.append([arr[i][0],arr[j][0],round(t.volume*1000,3)])
  return {'wd':wd,'lamp_clearance':light,'lamp_y':y,'row':row,'clashes':bad}
 results=[]
 for light in [10,16,30,60,80,92]:
  for wd in [50,56,70,100,120,132,160,200]:
   if wd<light+40:continue
   for y in ([-13,0,14.75] if light<16 else [-14.75,0,14.75]):results.append(pose(wd,light,y))
 # Include both sides of indexed-hole transitions and the retained window boundaries.
 for row in range(125,306,20):
  for wd in [row-84.5-10,row-84.5+10]:
   if 50<=wd<=200:results.append(pose(wd,10,0))
 for wd,light,y in [(100,60,0),(120,60,0),(50,10,-14.75),(100,68,0),(200,94,0),(40,10,0)]:results.append(pose(wd,light,y))
 path='E:/2026FPGA/FPGA_Component_Inspector/开发实施/机械结构展示/机械装配_R2c_合并布局/evidence/pose_sweep.json'
 open(path,'w',encoding='utf8').write(json.dumps(results,ensure_ascii=True,indent=2))
 print(json.dumps({'poses':len(results),'collision_free':sum(not r['clashes'] for r in results),'results_file':path}))
