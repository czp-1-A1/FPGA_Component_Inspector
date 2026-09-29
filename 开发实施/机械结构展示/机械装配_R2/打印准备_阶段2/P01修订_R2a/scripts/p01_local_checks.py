import adsk.core,adsk.fusion,json,math
def run(_context):
 app=adsk.core.Application.get();doc=next(x for x in app.documents if x.name=='FPGA_Inspector_R2a_P01_Slot56_Trial');d=adsk.fusion.Design.cast(doc.products.itemByProductType('DesignProductType'));c=next(o.component for o in d.rootComponent.occurrences if o.component.name.startswith('P01_'));body=c.bRepBodies.item(0);tm=adsk.fusion.TemporaryBRepManager.get();P=adsk.core.Point3D
 def cyl(x,y,z0,z1,r):return tm.createCylinderOrCone(P.create(x/10,y/10,z0/10),r/10,P.create(x/10,y/10,z1/10),r/10)
 def overlap(a,b):
  t=tm.copy(a);ok=tm.booleanOperation(t,b,adsk.fusion.BooleanTypes.IntersectionBooleanType);assert ok;return t.volume*1000 if t else 0
 tests=[]
 # Nominal pair centre +/-60; slots +/-49. End margin includes radius2.25 plus1.
 for side,nominal,shifts in [('rear',[54,66],[-29.75,0,7.75]),('front',[-66,-54],[-7.75,0,29.75])]:
  for shift in shifts:
   for y0 in nominal:
    y=y0+shift
    outer=cyl(0,y,184.5,184.55,4.5);inner=cyl(0,y,184.5,184.55,2.25)
    bearing=(overlap(body,outer)-overlap(body,inner))/.05
    screw=overlap(body,cyl(0,y,174.5,310,2))
    socket=overlap(body,cyl(0,y,149.5,184.499,6))
    tests.append({'side':side,'shift_mm':shift,'bolt_y_mm':y,'washer_annular_contact_mm2':bearing,'bolt_D4_swept_interference_mm3':screw,'socket_D12_below_interference_mm3':socket,'washer_outside_arm_front_margin_mm':y-4.5+80})
 assert all(q['bolt_D4_swept_interference_mm3']<.001 and q['socket_D12_below_interference_mm3']<.001 for q in tests)
 result={'tests':tests,'minimum_washer_annular_area_mm2':min(q['washer_annular_contact_mm2'] for q in tests),'slot_effective_pair_travel_mm':56-4.5-12-2,'nominal_pair_bolt_pitch_mm':12,'washer_outer_diameter_mm':9,'washer_inner_diameter_mm':4.5,'socket_assumption_outer_diameter_mm':12,'socket_to_rib_side_clearance_mm':2,'scope':'P01 local geometry at nominal and slot limit poses. Not an optical working travel approval.'}
 root='E:/2026FPGA/FPGA_Component_Inspector/开发实施/机械结构展示/机械装配_R2/打印准备_阶段2/P01修订_R2a/'
 open(root+'evidence/local_fit_checks.json','w').write(json.dumps(result,indent=2));print(json.dumps(result))
