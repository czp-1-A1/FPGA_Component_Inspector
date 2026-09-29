import adsk.core, adsk.fusion, json

def run(_context):
    app=adsk.core.Application.get()
    doc=app.activeDocument
    if doc is None or doc.name!='FPGA_Carrier_Inspector_R2_Layout_Review':
        doc=app.documents.add(adsk.core.DocumentTypes.FusionDesignDocumentType)
    doc.name='FPGA_Carrier_Inspector_R2_Layout_Review'
    d=adsk.fusion.Design.cast(app.activeProduct)
    d.designType=adsk.fusion.DesignTypes.ParametricDesignType
    d.unitsManager.distanceDisplayUnits=adsk.fusion.DistanceUnits.MillimeterDistanceUnits
    print(json.dumps({'preflight_components':d.rootComponent.occurrences.count,'preflight_parameters':d.userParameters.count}))
    assert d.rootComponent.occurrences.count==0 and d.userParameters.count==0
    specs=[
      ('wood_t','12 mm','胶合板厚度'),('base_l','650 mm','底板长'),('base_w','400 mm','底板深'),
      ('wall_y','110 mm','后立板前面'),('wall_h','360 mm','立板高'),('wall_w','300 mm','立板宽'),
      ('belt_l','420 mm','现有设备包络'),('belt_w','80 mm','带面宽'),('machine_w','110 mm','设备包络宽'),('machine_h','80 mm','设备总高已知'),
      ('belt_z','80 mm','暂定带面高_待测'),('sample_h','5 mm','暂定样品高_待测'),('detect_z','belt_z+sample_h','检测平面'),
      ('board_l','130 mm','板及亚克力长'),('board_w','90 mm','板及亚克力宽'),
      ('lens_dx','20 mm','暂定沿长边偏心'),('lens_dy','0 mm','暂定沿短边偏心'),
      ('acrylic_lower_t','1 mm','暂定下亚克力厚'),('acrylic_upper_t','1 mm','暂定上亚克力厚'),
      ('stack_h','30 mm','暂定下板底至上板顶'),('lens_drop','20 mm','暂定镜头端面低于下板底'),
      ('lens_d','14 mm','镜头外径'),('lens_body_h','18.3 mm','镜头本体总高'),
      ('camera_wd','100 mm','镜头端面至检测面_目标40到200不代表可用'),
      ('lens_z','detect_z+camera_wd','镜头端面'),('support_z','lens_z+lens_drop','下亚克力底面'),
      ('pad_w','74 mm','P02横向宽'),('pad_depth','44 mm','P02前后总深'),('pad_t','10 mm','承托块厚'),
      ('support_depth','19 mm','名义接触深度'),('soft_t','0.5 mm','承托软垫厚'),
      ('retainer_gap','0.5 mm','上板防脱间隙'),('lateral_gap','1 mm','每轴总定位间隙'),
      ('slot_d','4.5 mm','M4孔槽校核直径'),('slot_end_margin','1 mm','每端必要余量'),
      ('camera_pitch','20 mm','相机高度分档距'),('camera_slot_l','28 mm','相机微调槽总长'),
      ('lamp_od','90 mm','灯外径'),('lamp_id','40 mm','灯通光孔'),('lamp_h','22 mm','灯高'),
      ('lamp_clearance','60 mm','暂定发光面到检测面的距离'),('lamp_bottom','detect_z+lamp_clearance','灯发光面标高'),
      ('lamp_y','0 mm','灯前后对中_偏离0不是检测工况'),('ring_id','91 mm','夹圈内径'),('ring_od','110 mm','夹圈主体外径'),
      ('ring_h','16 mm','夹圈高'),('ring_gap','2 mm','初始分缝总宽'),('ring_close_limit','1 mm','最小闭合缝_不证明夹力安全'),
      ('ring_z','lamp_bottom+3 mm','夹圈下缘'),('lamp_rail_slot','140 mm','灯竖槽总长'),
      ('lamp_arm_slot','72 mm','灯前后槽总长'),('lamp_z_bolt_pitch','16 mm','灯根部双螺杆距'),
      ('lamp_y_bolt_pitch','36 mm','连接板双螺杆距'),('tray_gap','2 mm','暂定机端过渡间隙'),
    ]
    for n,e,c in specs:d.userParameters.add(n,adsk.core.ValueInput.createByString(e),'mm',c)
    print(json.dumps({'document':doc.name,'parameters':d.userParameters.count,'previous_documents_preserved':True},ensure_ascii=False))
