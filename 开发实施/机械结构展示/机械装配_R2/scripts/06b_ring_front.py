def run(_context):
    for sy in [-1]:
        c,o=component('P06'+('A' if sy>0 else 'B')+'_分体灯夹圈')
        cylinder(c,'Annular_clamp','z','ring_z','ring_h',0,'lamp_y','ring_od',inner='ring_id')
        yy='lamp_y-80 mm' if sy>0 else 'lamp_y-ring_gap/2'
        box(c,'Split_gap',-80,yy,'ring_z-1 mm',160,'80 mm+ring_gap/2','ring_h+2 mm',OP.CutFeatureOperation)
        yy='lamp_y+ring_gap/2' if sy>0 else 'lamp_y-13 mm'
        for xx in [-68,48]:box(c,'Clamp_ear_'+str(xx),xx,yy,'ring_z',20,'13 mm-ring_gap/2','ring_h',OP.JoinFeatureOperation)
        by='lamp_y+18 mm' if sy>0 else 'lamp_y-18 mm'
        for xx in [-48,48]:cylinder(c,'Reinforced_mount_'+str(xx),'z','ring_z','ring_h',xx,by,14,OP.JoinFeatureOperation)
        cylinder(c,'Preserve_housing_clearance','z','ring_z-1 mm','ring_h+2 mm',0,'lamp_y','ring_id',OP.CutFeatureOperation)
        holes(c,'Bridge_mounts','z','ring_z-1 mm','ring_h+2 mm',[(x,by) for x in [-48,48]])
        holes(c,'Clamp_screws','y','lamp_y-14 mm',28,[(x,'ring_z+ring_h/2') for x in [-61,61]])
        stop_y='lamp_y+ring_gap/2-0.5 mm' if sy>0 else 'lamp_y-ring_gap/2'
        for xx in [-54,50]:box(c,'Closure_limit_'+str(xx),xx,stop_y,'ring_z',4,0.5,4,OP.JoinFeatureOperation)
        win_y='lamp_y+42 mm' if sy>0 else 'lamp_y-60 mm'
        box(c,'Straight_cable_vent_window',-8,win_y,'ring_z+4 mm',16,18,8,OP.CutFeatureOperation)
    report("ring_front")
