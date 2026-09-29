def run(_context):
    for z in [80,240]:fastener_group('RAIL_'+str(z),'y',0,z,86,'wall_y+wood_t',45,[(120,0,0,0),(-120,0,0,0)],washerod=9)
    for z in [6,22]:fastener_group('LAMP_ROOT_'+str(z),'y',0,'ring_z+ring_h+'+str(z)+' mm',74,98,35,[(120,0,0,0),(-120,0,0,0)])
    for y in [-18,18]:
        fastener_group('BRIDGE_ARM_'+str(y),'z',0,'lamp_y+'+str(y)+' mm','ring_z+ring_h-12 mm','ring_z+ring_h+8 mm',30,[(120,0,0,0),(-120,0,0,0)])
        fastener_group('BRIDGE_RING_'+str(y),'z',0,'lamp_y+'+str(y)+' mm','ring_z','ring_z+ring_h+8 mm',35,[(48,0,0,0),(-48,0,0,0)])
    fastener_group('RING_CLAMP','y',0,'ring_z+ring_h/2','lamp_y-13 mm','lamp_y+13 mm',35,[(61,0,0,0),(-61,0,0,0)],head='low')
    print(json.dumps({'lamp_fasteners':'4x45 + 4x35 root + 4x30 arms + 4x35 ring + 2x35 clamp'}))
