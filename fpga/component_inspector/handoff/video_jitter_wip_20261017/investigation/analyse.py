from pathlib import Path
import cv2,numpy as np,json
out=Path(__file__).resolve().parent
src=json.loads((out/'inventory.json').read_text('utf-8'))['path']
c=cv2.VideoCapture(src);frames=[]
while True:
 ok,f=c.read()
 if not ok:break
 frames.append(f)
c.release();ref=frames[0];g0=cv2.cvtColor(ref,cv2.COLOR_BGR2GRAY);mask=np.zeros(g0.shape,np.uint8)
mask[70:173,30:1215]=255;mask[600:695,80:1140]=255
mask[300:325,365:500]=255;mask[464:489,385:520]=255
orb=cv2.ORB_create(nfeatures=4000,edgeThreshold=8,fastThreshold=8)
k0,d0=orb.detectAndCompute(g0,mask);matcher=cv2.BFMatcher(cv2.NORM_HAMMING)
registered=[];quality=[]
for i,f in enumerate(frames):
 g=cv2.cvtColor(f,cv2.COLOR_BGR2GRAY);k,d=orb.detectAndCompute(g,mask)
 pairs=matcher.knnMatch(d,d0,k=2);matches=[a for a,b in pairs if a.distance<.72*b.distance]
 a=np.float32([k[m.queryIdx].pt for m in matches]);b=np.float32([k0[m.trainIdx].pt for m in matches])
 H,inliers=cv2.findHomography(a,b,cv2.RANSAC,1.2)
 registered.append(cv2.warpPerspective(f,H,(1280,720)))
 err=np.linalg.norm(cv2.perspectiveTransform(a.reshape(-1,1,2),H).reshape(-1,2)-b,axis=1)
 quality.append({'frame':i,'matches':len(matches),'inliers':int(inliers.sum()),'median_inlier_error':float(np.median(err[inliers.ravel()>0]))})
np.savez_compressed(out/'aligned.npz',frames=np.asarray(registered))
# Track physical tape edge and component corners after registering fixed UI.
base=cv2.cvtColor(registered[0],cv2.COLOR_BGR2GRAY);points=cv2.goodFeaturesToTrack(base[450:552,925:1175],maxCorners=100,qualityLevel=.04,minDistance=6)
points+=np.array([[[925,450]]],dtype=np.float32);track=[]
for i,f in enumerate(registered):
 g=cv2.cvtColor(f,cv2.COLOR_BGR2GRAY)
 q,s,e=cv2.calcOpticalFlowPyrLK(base,g,points,None,winSize=(19,19),maxLevel=2,criteria=(cv2.TERM_CRITERIA_EPS|cv2.TERM_CRITERIA_COUNT,40,.001))
 back,sb,eb=cv2.calcOpticalFlowPyrLK(g,base,q,None,winSize=(19,19),maxLevel=2)
 keep=(s.ravel()>0)&(sb.ravel()>0)&(np.linalg.norm(back-points,axis=2).ravel()<.5)
 shift=(q-points)[keep,0,:];track.append({'frame':i,'time':i/29,'points':int(keep.sum()),'dx':float(np.median(shift[:,0])),'dy':float(np.median(shift[:,1])),'spread':float(np.median(np.linalg.norm(shift-np.median(shift,axis=0),axis=1)))})
# Presentation of identical screen-relative crops at selected adjacent frames.
tiles=[]
for i in [0,1,2,3,4,5,29,30,31,32,33,34,87,88,89,90,91,92]:
 f=registered[i];a=f[450:555,925:1178];a=cv2.resize(a,(506,210));a=cv2.copyMakeBorder(a,28,0,0,0,cv2.BORDER_CONSTANT,value=(30,30,30));cv2.putText(a,f'{i/29:.3f}s f{i} dx={track[i]["dx"]:.2f} dy={track[i]["dy"]:.2f}',(6,20),cv2.FONT_HERSHEY_SIMPLEX,.47,(255,255,255),1);tiles.append(a)
cv2.imwrite(str(out/'aligned_tape_sheet.jpg'),np.vstack([np.hstack(tiles[i:i+3]) for i in range(0,len(tiles),3)]))
# Side-by-side aligned reference/difference for greatest adjacent tape shift.
delta=np.diff([[v['dx'],v['dy']] for v in track],axis=0);j=int(np.argmax(np.linalg.norm(delta,axis=1)))+1
f0=registered[j-1];f1=registered[j];diff=cv2.absdiff(f0,f1);cv2.imwrite(str(out/'largest_pair.jpg'),np.vstack([f0,f1,np.minimum(diff.astype(np.uint16)*4,255).astype(np.uint8)]))
metrics={'alignment':quality,'tape_tracking':track,'largest_adjacent':{'before':j-1,'after':j,'dx':float(delta[j-1,0]),'dy':float(delta[j-1,1])},'ui_median_alignment_error':float(np.median([v['median_inlier_error'] for v in quality])),'tape_x_range':[min(v['dx'] for v in track),max(v['dx'] for v in track)],'tape_y_range':[min(v['dy'] for v in track),max(v['dy'] for v in track)]}
(out/'analysis.json').write_text(json.dumps(metrics,indent=2),'utf-8');print(json.dumps({k:v for k,v in metrics.items() if k not in ['alignment','tape_tracking']},indent=2))
