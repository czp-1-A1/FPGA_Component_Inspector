import os

def run(_context):
 original=next(x for x in APP.documents if x.name=='FPGA_Carrier_Inspector_R2_Layout_Review')
 root='E:/2026FPGA/FPGA_Component_Inspector/开发实施/机械结构展示/机械装配_R2/打印准备_阶段2/'
 c,o=component('CT01_右后承托局部小样')
 box(c,'Support_base','-pad_w/2','board_w/2-support_depth',0,'coupon_w',44,'pad_t')
 box(c,'Hard_standoff','-pad_w/2','board_w/2+lateral_gap/2+2 mm','pad_t','coupon_w','25 mm-lateral_gap/2-2 mm','soft_t+stack_h+retainer_gap',OP.JoinFeatureOperation)
 box(c,'Lower_Y_stop','-pad_w/2','board_w/2+lateral_gap/2','pad_t','coupon_w',2,'soft_t+acrylic_t',OP.JoinFeatureOperation)
 box(c,'Upper_Y_stop','-pad_w/2','board_w/2+lateral_gap/2','pad_t+soft_t+stack_h-acrylic_t','coupon_w',2,'acrylic_t+retainer_gap',OP.JoinFeatureOperation)
 holes(c,'Two_through_bolts','z',-1,'pad_t+soft_t+stack_h+retainer_gap+2 mm',[(0,54),(0,66)])
 c,o=component('CT02_右后防脱及X止挡局部小样')
 box(c,'Retainer','-pad_w/2',40,'pad_t+soft_t+stack_h+retainer_gap','coupon_w',30,6)
 box(c,'Upper_X_stop','-20 mm+lateral_gap/2',40,'pad_t+soft_t+stack_h-acrylic_t',4,4.75,'acrylic_t+retainer_gap',OP.JoinFeatureOperation)
 holes(c,'Two_through_bolts','z','pad_t+soft_t+stack_h+retainer_gap-1 mm',8,[(0,54),(0,66)])
 c,o=component('CT03_托臂槽段试装垫座')
 box(c,'Arm_segment',-12,10,-10,24,84,10)
 slots(c,'Pad_mount_slot','z',-11,12,[(0,49)],60)
 c,o=component('HT01_孔槽及横孔试片',110)
 box(c,'Base',0,0,0,80,60,6)
 for i,di in enumerate([4,4.2,4.4,4.5,4.6,4.8]):holes(c,'Vertical_'+str(di),'z',-1,8,[(10+12*i,10)],di)
 for i,(x,y,w) in enumerate([(20,26,4.2),(60,26,4.5),(20,44,4.8)]):slots(c,'Slot_'+str(w),'z',-1,8,[(x,y)],28,w,direction='u')
 box(c,'Horizontal_hole_boss',50,40,6,20,16,10,OP.JoinFeatureOperation)
 holes(c,'Horizontal_M4','y',39,18,[(60,11)],4.5)
 box(c,'Origin_notch',0,0,-1,3,3,8,OP.CutFeatureOperation)
 D.computeAll();D.activateRootComponent();out=[]
 for o in D.rootComponent.occurrences:
  c=o.component;code=c.name.split('_')[0];e=D.exportManager
  assert e.execute(e.createSTEPExportOptions(root+'小样STEP/'+code+'.step',c))
  op=e.createSTLExportOptions(c,root+'小样原始网格/'+code+'.stl');op.unitType=adsk.fusion.DistanceUnits.MillimeterDistanceUnits;op.isBinaryFormat=True;op.surfaceDeviation=.001;op.maximumEdgeLength=.3;op.normalDeviation=.08;op.sendToPrintUtility=False;assert e.execute(op)
  b=c.bRepBodies.item(0);bb=b.preciseBoundingBox;out.append({'code':code,'name':c.name,'qty':1,'volume_mm3':b.volume*1000,'bounds_mm':[v*10 for v in [bb.minPoint.x,bb.minPoint.y,bb.minPoint.z,bb.maxPoint.x,bb.maxPoint.y,bb.maxPoint.z]],'solid':b.isSolid})
 assert D.exportManager.execute(D.exportManager.createFusionArchiveExportOptions(root+'R2_关键配合小样.f3d'))
 cam=APP.activeViewport.camera;cam.cameraType=adsk.core.CameraTypes.OrthographicCameraType;cam.isSmoothTransition=False;cam.eye=P.create(25,-25,22);cam.target=P.create(5,3,1);cam.upVector=adsk.core.Vector3D.create(0,0,1);APP.activeViewport.camera=cam;adsk.doEvents();APP.activeViewport.fit();APP.activeViewport.refresh();APP.activeViewport.saveAsImageFile(root+'小样视图/小样组合.png',1600,1000)
 open(root+'evidence/coupons.json','w',encoding='utf8').write(json.dumps(out,ensure_ascii=True,indent=2));print(json.dumps(out))
 original.activate()
