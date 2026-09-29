def mat(origin,ax,ay,az):
    m=adsk.core.Matrix3D.create()
    m.setWithCoordinateSystem(P.create(*(v/10 for v in origin)),adsk.core.Vector3D.create(*ax),adsk.core.Vector3D.create(*ay),adsk.core.Vector3D.create(*az))
    return m

def run(_context):
    global PARENT
    old=[o for o in D.rootComponent.occurrences if o.component.name.startswith('W05')]
    for o in reversed(old):o.deleteMe()
    c,o=component('W05_托料脚_12厚胶合板_高度暂定',236)
    box(c,'Plywood_foot',0,-40,0,'wood_t',80,'belt_z-wood_t')
    holes(c,'Angle_fixings','x',-1,'wood_t+2 mm',[(-25,12.5),(-25,'belt_z-wood_t-12.5 mm')])
    instance(c,288,rotation=math.pi);instance(c,-236,rotation=math.pi);instance(c,-288)
    a,first=component('A01_普通角码及两套M4_25x25x25')
    PARENT=a
    c,o=component('C01_普通角码_现货孔位待核')
    box(c,'Angle_base',-12.5,-25,0,25,25,2)
    box(c,'Angle_upright',-12.5,-2,0,25,2,25,OP.JoinFeatureOperation)
    holes(c,'Base_hole','z',-1,4,[(0,-12.5)])
    holes(c,'Upright_hole','y',-3,4,[(0,12.5)])
    fastener_group('WOOD_BASE','z',0,-12.5,'-wood_t',2,25,[(0,0,0,0)],head='low')
    fastener_group('WOOD_UPRIGHT','y',0,12.5,-2,'wood_t',25,[(0,0,0,0)],head='low')
    PARENT=D.rootComponent
    placements=[mat((x,110,0),(1,0,0),(0,1,0),(0,0,1)) for x in [-110,110]]
    for yy in [170,205]:
      placements.extend([mat((136,yy,0),(0,-1,0),(1,0,0),(0,0,1)),mat((-136,yy,0),(0,1,0),(-1,0,0),(0,0,1))])
    for zz in [60,140]:
      placements.extend([mat((136,122,zz),(0,0,-1),(0,-1,0),(-1,0,0)),mat((-136,122,zz),(0,0,1),(0,-1,0),(1,0,0))])
    footplaces=[(248,-25,math.pi/2),(276,25,-math.pi/2),(-248,25,-math.pi/2),(-276,-25,math.pi/2)]
    for xx,yy,rot in footplaces:
      placements.append(mat((xx,yy,0),(math.cos(rot),math.sin(rot),0),(-math.sin(rot),math.cos(rot),0),(0,0,1)))
    first.transform2=placements[0]
    for m in placements[1:]:D.rootComponent.occurrences.addExistingComponent(a,m)
    a,first=component('A02_托料板上角码及两套M4')
    PARENT=a
    c,o=component('C02_上角码_同规格倒装')
    box(c,'Angle_base',-12.5,-25,'belt_z-wood_t-2 mm',25,25,2)
    box(c,'Angle_upright',-12.5,-2,'belt_z-wood_t-25 mm',25,2,25,OP.JoinFeatureOperation)
    holes(c,'Base_hole','z','belt_z-wood_t-3 mm',4,[(0,-12.5)])
    holes(c,'Upright_hole','y',-3,4,[(0,'belt_z-wood_t-12.5 mm')])
    fastener_group('TRAY_TOP','z',0,-12.5,'belt_z-wood_t-2 mm','belt_z',25,[(0,0,0,0)])
    fastener_group('TRAY_SIDE','y',0,'belt_z-wood_t-12.5 mm',-2,'wood_t',25,[(0,0,0,0)],head='low')
    PARENT=D.rootComponent
    first.transform2=placements[-4]
    for m in placements[-3:]:D.rootComponent.occurrences.addExistingComponent(a,m)
    base=next(o.component for o in D.rootComponent.occurrences if o.component.name.startswith('W01'))
    wall=next(o.component for o in D.rootComponent.occurrences if o.component.name.startswith('W02'))
    brace=next(o.component for o in D.rootComponent.occurrences if o.component.name.startswith('W03'))
    tray=next(o.component for o in D.rootComponent.occurrences if o.component.name.startswith('W04'))
    baseholes=[(x,97.5) for x in [-110,110]]+[(x,y) for x in [-123.5,123.5] for y in [170,205]]+[(260.5,-25),(263.5,25),(-260.5,25),(-263.5,-25)]
    holes(base,'Structural_fixings_only','z','-wood_t-1 mm','wood_t+2 mm',baseholes)
    holes(wall,'Angle_fixings','y','wall_y-1 mm','wood_t+2 mm',[(x,12.5) for x in [-110,110]]+[(x,z) for x in [-123.5,123.5] for z in [60,140]])
    holes(brace,'Angle_fixings','x',-1,'wood_t+2 mm',[(y,12.5) for y in [170,205]]+[(134.5,z) for z in [60,140]])
    holes(tray,'Foot_angle_fixings','z','belt_z-wood_t-1 mm','wood_t+2 mm',[(260.5,-25),(263.5,25)])
    c,o=component('S02_底部防滑垫_20x20x8',300,-115)
    box(c,'Rubber_foot',-10,-10,'-wood_t-8 mm',20,20,8)
    for x,y in [(-300,-115),(300,235),(-300,235)]:instance(c,x,y)
    print(json.dumps({'wood_angle_groups':18,'wood_fasteners':36,'foot_panels_12mm':4,'base_rubber_feet':4}))
