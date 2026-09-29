def run(_context):
    c=next(o.component for o in D.rootComponent.occurrences if o.component.name.startswith('P02'))
    box(c,'Hard_standoff','-pad_w/2','board_w/2+lateral_gap/2+2 mm','support_z-soft_t','pad_w','pad_depth-support_depth-lateral_gap/2-2 mm','stack_h+retainer_gap+soft_t',OP.JoinFeatureOperation)
    box(c,'Lower_acrylic_Y_stop','-pad_w/2','board_w/2+lateral_gap/2','support_z-soft_t','pad_w',2,'acrylic_lower_t+soft_t',OP.JoinFeatureOperation)
    box(c,'Upper_acrylic_Y_stop','-pad_w/2','board_w/2+lateral_gap/2','support_z+stack_h-acrylic_upper_t','pad_w',2,'acrylic_upper_t+retainer_gap',OP.JoinFeatureOperation)
    holes(c,'Standoff_through_bolts','z','support_z-soft_t-1 mm','stack_h+retainer_gap+soft_t+2 mm',[(0,'board_w/2+9 mm'),(0,'board_w/2+21 mm')])
    for sx in [-1,1]:
      for sy in [-1,1]:
        c,o=component('P03_'+('L' if sx<0 else 'R')+('F' if sy<0 else 'B')+'_上防脱及X止挡')
        xx=str(sx*65)+' mm-pad_w/2'
        yy='board_w/2-5 mm' if sy>0 else '-board_w/2-25 mm'
        box(c,'Top_retainer',xx,yy,'support_z+stack_h+retainer_gap','pad_w',30,6)
        stopx='-lens_dx+board_l/2+lateral_gap/2' if sx>0 else '-lens_dx-board_l/2-lateral_gap/2-4 mm'
        stopy='board_w/2-5 mm' if sy>0 else '-board_w/2-1 mm'
        box(c,'Upper_acrylic_X_stop',stopx,stopy,'support_z+stack_h-acrylic_upper_t',4,6,'acrylic_upper_t+retainer_gap',OP.JoinFeatureOperation)
        holes(c,'Retainer_bolts','z','support_z+stack_h+retainer_gap-1 mm',8,[(sx*65,('' if sy>0 else '-')+'(board_w/2+9 mm)'),(sx*65,('' if sy>0 else '-')+'(board_w/2+21 mm)')])
    report('four_corner_positive_stops')
