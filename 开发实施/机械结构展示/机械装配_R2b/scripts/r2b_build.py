OUT='E:/2026FPGA/FPGA_Component_Inspector/开发实施/机械结构展示/机械装配_R2b/'
def run(_context):
    assert APP.activeDocument.name=='FPGA_Inspector_R2b_Rear_M3_Trial'
    specs=[('p08_t','6 mm'),('p08_w','14 mm'),('p08_foot_h','3 mm'),('p08_foot_d','10 mm'),('p08_m3_d','3.6 mm'),('p08_pcd_r','39 mm'),('p08_ear_x','120 mm'),('p08_ear_w','20 mm'),('p08_ear_l','52 mm'),('p08_m4_pitch','36 mm'),('p08_washer_d','7 mm'),('p08_washer_t','0.5 mm'),('lamp_back','lamp_bottom+lamp_h'),('p08_bottom','lamp_back+p08_foot_h'),('p08_top','p08_bottom+p08_t')]
    for n,e in specs:D.userParameters.add(n,V.createByString(e),'mm','R2b trial; interface/load/temperature not physically verified')
    targets=[o for o in D.rootComponent.occurrences if o.component.name.startswith(('P06','P07','S03','H_RING_CLAMP','H_BRIDGE_RING','H_BRIDGE_ARM'))]
    removed=[o.name for o in targets]
    for o in reversed(targets):D.rootComponent.features.removeFeatures.add(o)
    changed=[];seen=set()
    import re
    for o in D.rootComponent.occurrences:
        c=o.component
        if c.id in seen or not c.name.startswith(('P05','H_LAMP_ROOT')):continue
        seen.add(c.id)
        for p in c.modelParameters:
            before=p.expression;after=re.sub(r'ring_z\s*\+\s*ring_h','p08_bottom',before)
            if after!=before:p.expression=after;changed.append([c.name,p.name,before,after])
    # One carrier joint drives both 180-degree-related P08 occurrences with lamp_y.
    carrier,co=component('A08_灯背板组件_前后参数驱动')
    rs=D.rootComponent.sketches.add(D.rootComponent.xZConstructionPlane);rs.name='R2b_lamp_fixed_datum';rs.isLightBulbOn=False
    cs=carrier.sketches.add(carrier.xZConstructionPlane);cs.name='R2b_carrier_datum';cs.isLightBulbOn=False
    g1=adsk.fusion.JointGeometry.createByPoint(cs.originPoint.createForAssemblyContext(co))
    g2=adsk.fusion.JointGeometry.createByPoint(rs.originPoint)
    ji=D.rootComponent.joints.createInput(g1,g2);ji.setAsRigidJointMotion();ji.offset=V.createByString('lamp_y')
    j=D.rootComponent.joints.add(ji);j.name='R2b_Lamp_Y_parameter';j.isLightBulbOn=False
    globals()['PARENT']=carrier
    c,o=component('P08_背孔连接板_同款候选_待实物互换')
    box(c,'Upper_bar','-p08_w/2','p08_pcd_r-p08_w/2','p08_bottom','p08_pcd_r+p08_w','p08_w','p08_t')
    box(c,'Vertical_bar','p08_pcd_r-p08_w/2','-p08_w/2','p08_bottom','p08_w','p08_pcd_r+p08_w','p08_t',OP.JoinFeatureOperation)
    box(c,'Outer_bar','p08_pcd_r-p08_w/2','-p08_w/2','p08_bottom','p08_ear_x-p08_pcd_r+p08_w/2','p08_w','p08_t',OP.JoinFeatureOperation)
    box(c,'Twin_hole_ear','p08_ear_x-p08_ear_w/2','-p08_ear_l/2','p08_bottom','p08_ear_w','p08_ear_l','p08_t',OP.JoinFeatureOperation)
    for n,x,y in [('X','p08_pcd_r',0),('Y',0,'p08_pcd_r')]:cylinder(c,'Foot_'+n,'z','lamp_back','p08_foot_h',x,y,'p08_foot_d',OP.JoinFeatureOperation)
    holes(c,'M3_trial_through','z','lamp_back','p08_foot_h+p08_t',[('p08_pcd_r',0),(0,'p08_pcd_r')],'p08_m3_d')
    holes(c,'M4_mount','z','p08_bottom','p08_t',[('p08_ear_x','-p08_m4_pitch/2'),('p08_ear_x','p08_m4_pitch/2')])
    c.attributes.add('R2b','M3_status','3.6mm unvalidated; HT01 is M4 only; no HT02; printing held for rear interface and insertion depth')
    a=D.appearances.itemByName('R2_light')
    if a:
        for b in c.bRepBodies:b.appearance=a
    instance(c,rotation=math.pi)
    if D.snapshots.hasPendingSnapshot:D.snapshots.add()
    # Four washers plus deliberately incomplete screw envelopes: no assumed threaded engagement.
    for x,y in [(39,0),(0,39),(-39,0),(0,-39)]:
        c,o=component('H_M3_Washer_'+str((x,y))+'_OD7_ID3p6_t0p5')
        cylinder(c,'Flat_washer_trial','z','p08_top','p08_washer_t',x,y,'p08_washer_d',inner='p08_m3_d')
        c,o=component('REF_M3_'+str((x,y))+'_头及板内杆包络_长度待定')
        cylinder(c,'External_shank_only','z','lamp_back','p08_foot_h+p08_t+p08_washer_t',x,y,3)
        cylinder(c,'Head_envelope','z','p08_top+p08_washer_t',3,x,y,5.5,OP.JoinFeatureOperation)
        c.attributes.add('R2b','not_a_selected_screw','No shank below lamp_back; head OD5.5 height3 only an assumed socket screw envelope; final length TBD')
    globals()['PARENT']=D.rootComponent
    for y in [-18,18]:fastener_group('P08_ARM_'+str(y),'z',0,'lamp_y+'+str(y)+' mm','p08_bottom-12 mm','p08_top',30,[(120,0,0,0),(-120,0,0,0)])
    lamp=next(o.component for o in D.rootComponent.occurrences if o.component.name.startswith('E08'))
    holes(lamp,'Confirmed_M3_axes_depth4_drawing_only','z','lamp_back-4 mm',4,[(39,'lamp_y'),(-39,'lamp_y'),(0,'lamp_y+39 mm'),(0,'lamp_y-39 mm')],3)
    lamp.attributes.add('R2b','thread_interface','Diameter3 simplified thread envelope, drawing depth4; allowable engagement unknown; no modeled thread flank')
    D.computeAll();D.activateRootComponent()
    open(OUT+'evidence/changes.json','w',encoding='utf8').write(json.dumps({'removed':removed,'parameter_edits':changed,'new_parameters':specs},ensure_ascii=False,indent=2))
    print(json.dumps({'removed_occurrences':len(removed),'edited_model_parameters':len(changed),'timeline':D.timeline.count,'carrier_matrix':co.transform2.asArray()}))
    APP.activeViewport.fit();APP.activeViewport.saveAsImageFile(OUT+'evidence/after_build.png',1400,1000)
