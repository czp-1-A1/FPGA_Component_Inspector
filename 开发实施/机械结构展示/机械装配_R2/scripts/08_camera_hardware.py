def run(_context):
    if D.userParameters.itemByName('camera_row_z') is None:D.userParameters.add('camera_row_z',V.createByString('185 mm'),'mm','当前选用分档孔高度_125到305每20一档')
    for y in [9,21]:
        copies=[(65,0,0,0),(-65,0,0,0),(65,0,0,math.pi),(-65,0,0,math.pi)]
        fastener_group('CAM_PAD_'+str(y),'z',0,'board_w/2+'+str(y)+' mm','support_z-soft_t-pad_t-10 mm','support_z+stack_h+retainer_gap+6 mm',65,copies)
    for x in [-18,18]:
        fastener_group('CAM_ROOT_'+str(x),'y',x,'camera_row_z',100,'wall_y+wood_t',30,[(65,0,0,0),(-65,0,0,0)])
    print(json.dumps({'camera_fasteners':'8x M4x65 + 4x M4x30; nuts and washers separate components'}))
