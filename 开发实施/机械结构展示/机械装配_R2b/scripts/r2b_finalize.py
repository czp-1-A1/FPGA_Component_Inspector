import adsk.core,adsk.fusion,json
OUT='E:/2026FPGA/FPGA_Component_Inspector/开发实施/机械结构展示/机械装配_R2b/'
def run(_context):
 app=adsk.core.Application.get();d=adsk.fusion.Design.cast(app.activeProduct);d.activateRootComponent()
 d.userParameters.itemByName('camera_wd').comment='R2b trial operating envelope D50..200; D>=H+40. Optical focus unverified. Service default D120/H60.'
 d.userParameters.itemByName('lamp_clearance').comment='R2b trial H10..92, with D>=H+40. H94 collides with upper rail fixing; H93.5 nominal touch boundary.'
 d.userParameters.itemByName('lamp_y').comment='Detection alignment Y=0. Slot +/-14.75. For reserved hand access at H<16, use Y>=-13. Unknown cables not validated.'
 d.rootComponent.attributes.add('R2b','print_hold','P08 not released to print: confirm lamp rear contact/cable/vent interface and permitted thread engagement. No HT02. Old P06 printing paused. CT01/02/03 unchanged.')
 d.rootComponent.attributes.add('R2b','service','At default H60 raise camera to D120 before inserting/removing the bench-assembled lamp and P08 module. Front insertion with 5mm lift; lower to seat; fit M4 fasteners.')
 d.rootComponent.attributes.add('R2b','M3_selection','L - plate6 - foot3 - washer0.5 = engagement. Final L TBD; drawing depth4 is not permissible engagement.')
 assert d.exportManager.execute(d.exportManager.createFusionArchiveExportOptions(OUT+'FPGA_Inspector_R2b_Parametric.f3d'))
 print(json.dumps({'saved':True,'timeline':d.timeline.count,'parameters':d.userParameters.count}))
