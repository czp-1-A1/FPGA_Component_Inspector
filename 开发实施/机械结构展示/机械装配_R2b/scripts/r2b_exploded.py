import adsk.core,adsk.fusion,json,time
OUT='E:/2026FPGA/FPGA_Component_Inspector/开发实施/机械结构展示/机械装配_R2b/'
def run(_context):
 app=adsk.core.Application.get();original=app.activeDocument;d=adsk.fusion.Design.cast(app.activeProduct);tm=adsk.fusion.TemporaryBRepManager.get();items=[]
 def walk(c,m,path):
  for b in c.bRepBodies:
   if not path.split('/')[1].startswith(('A08','P05','E08','H_P08')):continue
   t=tm.copy(b);tm.transform(t,m);name=c.name
   dz=-25 if name.startswith('E08') else 18 if name.startswith('P08') else 29 if name.startswith('H_M3') else 43 if name.startswith('REF_M3') else 35 if name.startswith('H_P08') and 'Bolt' in name else 26 if name.startswith('H_P08') and 'Washer_head' in name else -15 if name.startswith('H_P08') else 0
   move=adsk.core.Matrix3D.create();move.translation=adsk.core.Vector3D.create(0,0,dz/10);tm.transform(t,move);items.append((name,t,b.appearance,dz))
  for o in c.occurrences:
   aa=m.asArray();bb=o.transform2.asArray();w=adsk.core.Matrix3D.create();w.setWithArray([sum(aa[r*4+k]*bb[k*4+s] for k in range(4)) for r in range(4) for s in range(4)]);walk(o.component,w,path+'/'+o.name)
 walk(d.rootComponent,adsk.core.Matrix3D.create(),'root')
 doc=app.documents.add(adsk.core.DocumentTypes.FusionDesignDocumentType);doc.name='R2b_Exploded_View_Only';dd=adsk.fusion.Design.cast(app.activeProduct);dd.designType=adsk.fusion.DesignTypes.DirectDesignType
 for name,b,appearance,dz in items:
  occ=dd.rootComponent.occurrences.addNewComponent(adsk.core.Matrix3D.create());occ.component.name=name;made=occ.component.bRepBodies.add(b)
  # Appearance copied into the temporary view document; all shapes come from actual final BReps.
  ap=dd.appearances.itemByName(appearance.name)
  if not ap:ap=dd.appearances.addByCopy(appearance,appearance.name)
  made.appearance=ap
 vp=app.activeViewport;c=vp.camera;c.cameraType=adsk.core.CameraTypes.OrthographicCameraType;c.isSmoothTransition=False;c.eye=adsk.core.Point3D.create(42,-62,55);c.target=adsk.core.Point3D.create(0,0,17);c.upVector=adsk.core.Vector3D.create(0,0,1);vp.camera=c;adsk.doEvents();vp.fit();adsk.doEvents();vp.refresh();time.sleep(.3);adsk.doEvents();assert vp.saveAsImageFile(OUT+'视图/灯架局部爆炸.png',1800,1350)
 open(OUT+'evidence/explosion_offsets.json','w',encoding='utf8').write(json.dumps([{'name':n,'visual_Z_offset_mm':z} for n,_,_,z in items],ensure_ascii=False,indent=2))
 doc.close(False);original.activate();print(json.dumps({'exploded_bodies':len(items),'original_model_unchanged':True}))
