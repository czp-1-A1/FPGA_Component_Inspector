def run(_context):
    c=next(o.component for o in D.rootComponent.occurrences if o.component.name.startswith('P01'))
    fs=[f for f in c.features.extrudeFeatures if f.name=='Split_gap']
    assert len(fs)==1
    fs[0].deleteMe();D.computeAll()
    print(json.dumps({'removed_own_erroneous_cross_component_cut':True,'P01_volume_mm3':c.bRepBodies.item(0).volume*1000}))
