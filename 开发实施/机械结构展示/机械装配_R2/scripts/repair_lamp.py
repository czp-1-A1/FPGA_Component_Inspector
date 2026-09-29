def run(_context):
    assert APP.activeDocument.name.startswith('FPGA_Carrier_Inspector_R2')
    targets=[o for o in D.rootComponent.occurrences if o.component.name.startswith(('P06','P07','E08'))]
    names=[o.name for o in targets]
    for o in reversed(targets):o.deleteMe()
    c,o=component('E08_环形灯_90x40x22')
    cylinder(c,'Ring_light','z','lamp_bottom','lamp_h',0,'lamp_y','lamp_od',inner='lamp_id')
    D.computeAll()
    print(json.dumps({'rebuilt_reference':c.name,'removed_own_components':names,'body_volumes':[b.volume*1000 for b in c.bRepBodies]},ensure_ascii=True))
