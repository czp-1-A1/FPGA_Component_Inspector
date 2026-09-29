def run(_context):
    os=[o for o in D.rootComponent.occurrences if o.component.name=='DEBUG_OWN_TEMP']
    for o in os:o.deleteMe()
    print(json.dumps({'removed_own_debug':len(os),'remaining':D.rootComponent.occurrences.count}))
