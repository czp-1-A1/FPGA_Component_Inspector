def run(_context):
    os=[o for o in D.rootComponent.occurrences if o.component.name.startswith('H_CAM_')]
    print(json.dumps({'incomplete_camera_hardware':[o.name for o in os]},ensure_ascii=True))
    for o in reversed(os):o.deleteMe()
