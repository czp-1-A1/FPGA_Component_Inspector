def run(_context):
    for sx in [-1,1]:
        c,o=component('P07_'+('L' if sx<0 else 'R')+'_灯圈连接板')
        x0=40 if sx>0 else -128
        box(c,'Bridge_plate',x0,'lamp_y-26 mm','ring_z+ring_h',88,52,8)
        box(c,'Central_opening',40 if sx>0 else -108,'lamp_y-10 mm','ring_z+ring_h-1 mm',68,20,10,OP.CutFeatureOperation)
        cylinder(c,'Housing_keepout','z','ring_z+ring_h-1 mm',10,0,'lamp_y',92,OP.CutFeatureOperation)
        slots(c,'Clamp_compliance_slots','z','ring_z+ring_h-1 mm',10,[(sx*48,'lamp_y-18 mm'),(sx*48,'lamp_y+18 mm')],8.5)
        holes(c,'Arm_fasteners','z','ring_z+ring_h-1 mm',10,[(sx*120,'lamp_y-18 mm'),(sx*120,'lamp_y+18 mm')])
    report('lamp_clamp_and_bridges')
