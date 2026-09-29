OUT='E:/2026FPGA/FPGA_Component_Inspector/开发实施/机械结构展示/机械装配_R2c_合并布局/'
def run(_context):
 assert APP.activeDocument.name=='FPGA_Inspector_R2c_Conditional_Quote'
 specs=[('arm_half_span','65 mm'),('board_cx','-lens_dx'),('board_cy','-lens_dy'),('p09_post_w','18 mm'),('p09_post_d','18 mm'),('p09_stop_t','2 mm'),('p09_front_tail','2.5 mm'),('p10_bridge_w','10 mm'),('p10_t','6 mm'),('p09_outreach','lateral_gap/2+p09_stop_t+p09_post_d'),('p09_bolt_y','board_w/2+lateral_gap/2+p09_stop_t+p09_post_d/2'),('p09_arm_front','board_cy-board_w/2-p09_outreach-p09_front_tail')]
 for n,e in specs:D.userParameters.add(n,V.createByString(e),'mm','R2c CONDITIONAL QUOTE: measure board before manufacture')
 targets=[o for o in D.rootComponent.occurrences if o.component.name.startswith(('P01','P02','P03','S01','H_CAM_PAD'))]
 removed=[o.name for o in targets]
 for o in reversed(targets):D.rootComponent.features.removeFeatures.add(o)
 for sx,side in [(-1,'L'),(1,'R')]:
  c,o=component('P09'+side+'_一体承托_实测前禁止制造',sx*65)
  box(c,'Arm_no_obsolete_pad_slots',-12,'p09_arm_front','support_z-soft_t-pad_t-10 mm',24,'110 mm-p09_arm_front',10)
  box(c,'Original_root',-26,100,'support_z-soft_t-pad_t-40 mm',52,10,50,OP.JoinFeatureOperation)
  for x in [-12,8]:triangle(c,'Root_rib_'+str(x),'x',x,4,100,'support_z-soft_t-pad_t-10 mm',-95,-30,OP.JoinFeatureOperation)
  slots(c,'Root_height_fine','y',99,12,[(-18,'support_z-soft_t-pad_t-10 mm'),(18,'support_z-soft_t-pad_t-10 mm')],'camera_slot_l')
  for sy in [-1,1]:
   ys='board_cy+board_w/2-support_depth' if sy>0 else 'board_cy-board_w/2-p09_outreach'
   py='board_cy+board_w/2+lateral_gap/2+p09_stop_t' if sy>0 else 'board_cy-board_w/2-p09_outreach'
   ly='board_cy+board_w/2+lateral_gap/2' if sy>0 else 'board_cy-board_w/2-lateral_gap/2-p09_stop_t'
   box(c,'Bearing_'+str(sy),'-pad_w/2',ys,'support_z-soft_t-pad_t','pad_w','support_depth+p09_outreach','pad_t',OP.JoinFeatureOperation)
   box(c,'Narrow_hard_post_'+str(sy),'-p09_post_w/2',py,'support_z-soft_t','p09_post_w','p09_post_d','stack_h+retainer_gap+soft_t',OP.JoinFeatureOperation)
   box(c,'Lower_Y_stop_'+str(sy),'-pad_w/2',ly,'support_z-soft_t','pad_w','p09_stop_t','acrylic_lower_t+soft_t',OP.JoinFeatureOperation)
   holes(c,'Retainer_only_bolt_'+str(sy),'z','support_z-soft_t-pad_t-11 mm','pad_t+stack_h+retainer_gap+soft_t+12 mm',[(0,'board_cy'+('+' if sy>0 else '-')+'p09_bolt_y')])
  c.attributes.add('R2c','removed_features','Pad installation slots; second bolt at each corner; full-width tall wall; excess front arm; no boolean union of old parts')
  a=D.appearances.itemByName('R2_camera')
  if a:
   for b in c.bRepBodies:b.appearance=a
  cap,co=component('P10'+side+'_板外连接可拆压架_实测前禁止制造',sx*65)
  for sy in [-1,1]:
   yy='board_cy+board_w/2-5 mm' if sy>0 else 'board_cy-board_w/2-p09_outreach'
   box(cap,'Retainer_'+str(sy),'-pad_w/2',yy,'support_z+stack_h+retainer_gap','pad_w','5 mm+p09_outreach','p10_t',OP.NewBodyFeatureOperation if sy==-1 else OP.JoinFeatureOperation) if sy==-1 else None
  # bridge joins the first end, then the other end joins the bridge.
  bx='pad_w/2-p10_bridge_w' if sx>0 else '-pad_w/2'
  box(cap,'Outside_straight_bridge',bx,'board_cy-board_w/2-p09_outreach','support_z+stack_h+retainer_gap','p10_bridge_w','board_w+2*p09_outreach','p10_t',OP.JoinFeatureOperation)
  box(cap,'Retainer_1','-pad_w/2','board_cy+board_w/2-5 mm','support_z+stack_h+retainer_gap','pad_w','5 mm+p09_outreach','p10_t',OP.JoinFeatureOperation)
  stopx='board_cx+board_l/2+lateral_gap/2-arm_half_span' if sx>0 else 'board_cx-board_l/2-lateral_gap/2-4 mm+arm_half_span'
  for sy in [-1,1]:
   yy='board_cy+board_w/2-5 mm' if sy>0 else 'board_cy-board_w/2+0.25 mm'
   box(cap,'X_positive_stop_'+str(sy),stopx,yy,'support_z+stack_h-acrylic_upper_t',4,4.75,'acrylic_upper_t+retainer_gap',OP.JoinFeatureOperation)
   holes(cap,'Retainer_through_'+str(sy),'z','support_z+stack_h+retainer_gap-1 mm','p10_t+2 mm',[(0,'board_cy'+('+' if sy>0 else '-')+'p09_bolt_y')])
   fastener_group('P10_'+side+str(sy),'z',0,'board_cy'+('+' if sy>0 else '-')+'p09_bolt_y','support_z-soft_t-pad_t-10 mm','support_z+stack_h+retainer_gap+p10_t',65,[(sx*65,0,0,0)])
   pad,po=component('S01'+side+str(sy)+'_现场软垫_待实测',sx*65)
   py='board_cy+board_w/2-support_depth' if sy>0 else 'board_cy-board_w/2'
   box(pad,'Soft_contact','-pad_w/2',py,'support_z-soft_t','pad_w','support_depth','soft_t')
  if a:
   for b in cap.bRepBodies:b.appearance=a
 if D.snapshots.hasPendingSnapshot:D.snapshots.add()
 D.computeAll();D.activateRootComponent()
 open(OUT+'evidence/changes.json','w',encoding='utf8').write(json.dumps({'removed':removed,'parameters':specs},ensure_ascii=False,indent=2))
 report('R2c_rebuilt')
 APP.activeViewport.saveAsImageFile(OUT+'evidence/rebuilt.png',1400,1000)
