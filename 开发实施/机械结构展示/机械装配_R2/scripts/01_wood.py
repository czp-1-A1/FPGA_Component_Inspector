def run(_context):
    assert D.rootComponent.occurrences.count==0
    c,o=component('W01_底板_650x400x12')
    box(c,'Base', '-base_l/2',-140,'-wood_t','base_l','base_w','wood_t')
    c,o=component('W02_后立板_300x360x12')
    box(c,'Wall','-wall_w/2','wall_y',0,'wall_w','wood_t','wall_h')
    centers=[(x,'145 mm + camera_pitch * '+str(i)) for x in [-83,-47,47,83] for i in range(9)]
    holes(c,'Camera_height_hole_array','y','wall_y-1 mm','wood_t+2 mm',centers)
    holes(c,'Lamp_rail_fixings','y','wall_y-1 mm','wood_t+2 mm',[(x,z) for x in [-120,120] for z in [80,240]])
    c,o=component('W03_后加强板_120x200x12',136)
    triangle(c,'Rear_gusset','x',0,'wood_t','wall_y+wood_t',0,120,200)
    instance(c,-148)
    c,o=component('W04_端部托料板_100x100x12')
    box(c,'Tray','belt_l/2+tray_gap',-50,'belt_z-wood_t',100,100,'wood_t')
    instance(c,rotation=math.pi)
    c,o=component('W05_托料木脚_高度暂定')
    box(c,'Foot',238,-40,0,40,80,'belt_z-wood_t')
    instance(c,rotation=math.pi)
    report('wood')
