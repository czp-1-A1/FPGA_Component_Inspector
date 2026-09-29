import adsk.core,adsk.fusion,json
def run(_context):
 a=adsk.core.Application.get();d=adsk.fusion.Design.cast(a.activeProduct)
 out={'doc':a.activeDocument.name,'timeline':d.timeline.count,'parameters':d.userParameters.count,'p08':[o.fullPathName for o in d.rootComponent.allOccurrences if o.component.name.startswith(('P08','A08','H_M3','REF_M3','H_P08'))],'remaining_old':[o.name for o in d.rootComponent.occurrences if o.component.name.startswith(('P06','P07','S03','H_RING','H_BRIDGE'))]}
 print(json.dumps(out))
