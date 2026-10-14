from pathlib import Path
import sys,json
import numpy as np
import cv2
from PIL import Image
# Run with the frozen model/probe provided alongside this reproduction script.
import probe
folder=Path(sys.argv[1]);model=json.loads((folder/'model_frozen.json').read_text(encoding='utf-8'));manifest=json.loads((folder/'photos.json').read_text(encoding='utf-8'))
native=np.float32([[472,260],[551,260],[551,339],[472,339]])
planes={};homographies={}
for case in manifest['cases']:
 photo=np.asarray(Image.open(folder/case['photo']).convert('RGB'))
 h=cv2.getPerspectiveTransform(np.float32(case['cyan_quad_photo']),native);homographies[case['id']]=h
 planes[case['id']]=cv2.warpPerspective(photo,h,(1024,600))
 if case['id']=='present':present=photo
roi=[1063,438,1208,607];reference=probe.extract(present[roi[1]:roi[3],roi[0]:roi[2]])
assert reference['quality']=='MEASURED'
outline=np.float32(reference['outline'])+np.float32(roi[:2]);rect=cv2.minAreaRect(cv2.perspectiveTransform(outline[None,:,:],homographies['present'])[0]);short,long=sorted(rect[1])
results=[]
for case in manifest['cases']:
 feature=probe.extract(planes[case['id']][262:338,474:550])
 if feature['quality']=='MEASURED':feature['relative_size']=feature['long_px']/long
 results.append(dict(id=case['id'],mean_osd=case['mean_from_osd'],features=feature,comparison=probe.compare(feature,model['prototypes'])))
actual=dict(reference_estimated_long_px=long,reference_estimated_short_px=short,cases=results)
expected=json.loads((folder/'assessment_results.json').read_text(encoding='utf-8'))
assert abs(long-expected['reference_estimated_long_px'])<1e-5 and abs(short-expected['reference_estimated_short_px'])<1e-5
for a,b in zip(results,expected['cases']):
 assert a['id']==b['id'] and a['comparison']['match']==b['comparison']['match']
 if a['features']['quality']=='MEASURED':
  for k in ['extent','corner_fill','aspect','long_px','relative_size']:assert abs(a['features'][k]-b['features'][k])<1e-6,(a['id'],k)
(folder/'assessment_reproduced.json').write_text(json.dumps(actual,ensure_ascii=False,indent=2),encoding='utf-8')
print('PASS reproduced four phone-photo comparisons with unchanged model; positive crop remains rejected')
