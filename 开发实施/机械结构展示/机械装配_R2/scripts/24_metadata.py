def run(_context):
 comments={'wood_t': '胶合板厚度', 'base_l': '底板长', 'base_w': '底板深', 'wall_y': '后立板前面', 'wall_h': '立板高', 'wall_w': '立板宽', 'belt_l': '现有设备包络', 'belt_w': '带面宽', 'machine_w': '设备包络宽', 'machine_h': '设备总高已知', 'belt_z': '暂定带面高_待测', 'sample_h': '暂定样品高_待测', 'detect_z': '检测平面', 'board_l': '板及亚克力长', 'board_w': '板及亚克力宽', 'lens_dx': '暂定沿长边偏心', 'lens_dy': '暂定沿短边偏心', 'acrylic_lower_t': '暂定下亚克力厚', 'acrylic_upper_t': '暂定上亚克力厚', 'stack_h': '暂定下板底至上板顶', 'lens_drop': '暂定镜头端面低于下板底', 'lens_d': '镜头外径', 'lens_body_h': '镜头本体总高', 'camera_wd': '镜头端面至检测面_目标40到200不代表可用', 'lens_z': '镜头端面', 'support_z': '下亚克力底面', 'pad_w': 'P02横向宽', 'pad_depth': 'P02前后总深', 'pad_t': '承托块厚', 'support_depth': '名义接触深度', 'soft_t': '承托软垫厚', 'retainer_gap': '上板防脱间隙', 'lateral_gap': '每轴总定位间隙', 'slot_d': 'M4孔槽校核直径', 'slot_end_margin': '每端必要余量', 'camera_pitch': '相机高度分档距', 'camera_slot_l': '相机微调槽总长', 'lamp_od': '灯外径', 'lamp_id': '灯通光孔', 'lamp_h': '灯高', 'lamp_clearance': '暂定发光面到检测面的距离', 'lamp_bottom': '灯发光面标高', 'lamp_y': '灯前后对中_偏离0不是检测工况', 'ring_id': '夹圈内径', 'ring_od': '夹圈主体外径', 'ring_h': '夹圈高', 'ring_gap': '初始分缝总宽', 'ring_close_limit': '最小闭合缝_不证明夹力安全', 'ring_z': '夹圈下缘', 'lamp_rail_slot': '灯竖槽总长', 'lamp_arm_slot': '灯前后槽总长', 'lamp_z_bolt_pitch': '灯根部双螺杆距', 'lamp_y_bolt_pitch': '连接板双螺杆距', 'tray_gap': '暂定机端过渡间隙', 'camera_row_z': '手动选择分档孔高125至305、步距20；修改拍摄距离后选择就近孔排'}
 for n,c in comments.items():D.userParameters.itemByName(n).comment=c
 out=[];seen=set()
 def walk(c):
  if c.id in seen:return
  seen.add(c.id)
  for sk in c.sketches:out.append({'component':c.name,'sketch':sk.name,'fully_constrained':sk.isFullyConstrained})
  for o in c.occurrences:walk(o.component)
 walk(D.rootComponent)
 D.rootComponent.attributes.add('R2','release_status','FIRST_STAGE_LAYOUT_REVIEW_PROTOTYPE_UNTESTED')
 open('E:/2026FPGA/FPGA_Component_Inspector/开发实施/机械结构展示/机械装配_R2/evidence/sketch_constraints.json','w',encoding='utf8').write(json.dumps(out,ensure_ascii=True,indent=2))
 print(json.dumps({'sketches':len(out),'fully_constrained':sum(q['fully_constrained'] for q in out)}))
