from pathlib import Path
import json
root=Path(__file__).resolve().parent;result={}
for old_i,new_i,key in [(0,4,'feed_roles'),(1,5,'aperture_quantization')]:
 old=json.loads((root/f'run_r{old_i}/diagnostic.json').read_text())['cases'];new=json.loads((root/f'run_r{new_i}/diagnostic.json').read_text())['cases'];assert len(old)==len(new)
 for a,b in zip(old,new):
  assert all(a[k]==v for k,v in b.items() if k not in ['feed_E','feed_P','feed_U','pocket_E']),(a,b)
 v={'cases':len(old),'old_wrong_feed':sum(bool(x['feed_E'] or x['feed_P']) for x in old),'new_wrong_feed':sum(bool(x['feed_E'] or x['feed_P']) for x in new),'previous_positive_regressions':[a['case'] for a,b in zip(old,new) if a['pocket_E']>b['pocket_E']],'pocket_improvements':[a['case'] for a,b in zip(old,new) if a['pocket_E']<b['pocket_E']],'retained_unclassified_cases':[x['case'] for x in new if not x['pocket_E']]}
 assert v['new_wrong_feed']==0 and not v['previous_positive_regressions'];result[key]=v
(root/'probe_comparison_r1.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2))
