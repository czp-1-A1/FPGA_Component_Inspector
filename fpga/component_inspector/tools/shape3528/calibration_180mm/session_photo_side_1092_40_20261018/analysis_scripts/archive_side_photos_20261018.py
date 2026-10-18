from pathlib import Path
import hashlib,json,shutil,zipfile
import cv2,numpy as np
from PIL import Image,ImageDraw
r=Path.cwd();p=r/'fpga/component_inspector';out=p/'tools/shape3528/calibration_180mm/session_photo_side_1092_40_20261018';out.mkdir(exist_ok=False)
sha=lambda q:hashlib.sha256(q.read_bytes()).hexdigest()
def write(q,s):q.parent.mkdir(parents=True,exist_ok=True);q.write_bytes(s.encode())
def save(q,d):write(q,json.dumps(d,ensure_ascii=False,indent=2)+'\n')
uids=['9462feb8-0637-452d-bbca-79fbd3747980','bd871871-8dcd-436b-a18b-4ced9645929c','1e97e1cc-7e76-4372-9550-f5faa1217d65','f2bb1963-44b9-42c7-bffa-69f4d97b7b8c','08b649d6-84be-4958-9e91-c445149968fb','a576c9bc-92c1-4db2-817a-7374b3cad946','e696ebd3-f846-4e38-bbec-8a624508f670','08085489-6582-4e64-8342-ef75e1fbc6d3']
modes=['GRAY+EDGE','GRAY+EDGE','GRAY','GRAY','EDGE','EDGE','GRAY+EDGE','GRAY+EDGE']
boxes=[(627,542,950,718),(611,528,940,703),(651,522,967,686),(616,536,930,700),(610,511,921,680),(637,511,950,677),(651,527,964,696),(642,518,971,693)]
photos=[];canvas=Image.new('RGB',(800,4*230),(235,235,235));d=ImageDraw.Draw(canvas)
for idx,(uid,mode,box) in enumerate(zip(uids,modes,boxes),1):
 src=Path('C:/Users/yiziw/AppData/Local/Temp')/f'codex-clipboard-{uid}.jpg';dst=out/f'S{idx:02d}.jpg';shutil.copy2(src,dst);assert sha(src)==sha(dst)
 crop=Image.open(dst).crop(box);crop.save(out/f'S{idx:02d}_carrier_crop.png')
 x=((idx-1)%2)*400;y=((idx-1)//2)*230;canvas.paste(crop,(x+8,y+27));d.text((x+8,y+6),f'S{idx:02d} {mode} - user: side standing',fill='black')
 photos.append(dict(id=idx,archived=dst.name,original=src.as_posix(),sha256=sha(dst),bytes=dst.stat().st_size,mode=mode,state='present',quality='placement_abnormal',physical_truth='side_standing_user_confirmed',objects_left_to_right=[dict(index=k,presence='present',quality='placement_abnormal',truth='user-confirmed side-standing group; no automatic relabeling as flipped/normal') for k in range(1,5)],partial_edge_holes_excluded=True,actual_detection_not_required=True,photo_crop_xyxy=list(box)))
canvas.save(out/'side_contact_sheet.jpg',quality=94)
save(out/'sources.json',dict(photos=photos,camera=dict(exposure=1092,gain=40,wb_r=100,wb_b=100),visible_title='PHOTO ONLY / DETECT OFF',expected_observer_bit_sha256='66f9be7c5bc4103abb9c8f4718c2e64bdbca04ecc637e016691c7b40e99c011a',hardware_hash_readback=False,independent_scenes=1,raw_photos_in_this_batch=0))

# Pure GRAY only; never count the orange rendered Sobel overlay as foreground.
# User labels establish truth. Threshold masks describe photographic evidence,
# not native FPGA mask80/100. Preserve all resulting fragments for review.
centers={3:dict(body=[(710,578),(790,578),(847,582),(921,585)],locating=[(744,640),(815,640),(884,640)]),4:dict(body=[(673,598),(755,597),(809,600),(881,603)],locating=[(709,658),(777,658),(847,658)])}
measure=[];checks=[]
for idx,groups in centers.items():
 im=cv2.imread(str(out/f'S{idx:02d}.jpg'));gray=cv2.cvtColor(im,cv2.COLOR_BGR2GRAY)
 for category,pts in groups.items():
  for obj,(cx,cy) in enumerate(pts,1):
   hx=29 if category=='body' else 19;hy=36 if category=='body' else 19
   roi=gray[cy-hy:cy+hy+1,cx-hx:cx+hx+1]
   low=float(np.percentile(roi,15));high=float(np.percentile(roi,97))
   for f in [.35,.5,.65]:
    mask=(roi>low+f*(high-low)).astype(np.uint8)
    n,lab,stats,cent=cv2.connectedComponentsWithStats(mask,8)
    candidates=[]
    for c in range(1,n):
     x,y,w,h,a=map(int,stats[c]);dx,dy=cent[c]-np.array([hx,hy])
     if a>=8 and abs(dx)<hx-3 and abs(dy)<hy-3:candidates.append((a,c))
    if not candidates:continue
    a,c=max(candidates);x,y,w,h,_=map(int,stats[c]);cnt=max(cv2.findContours((lab==c).astype(np.uint8),cv2.RETR_EXTERNAL,cv2.CHAIN_APPROX_SIMPLE)[0],key=cv2.contourArea)
    (_, _),(rw,rh),angle=cv2.minAreaRect(cnt)
    z=dict(photo=idx,object=obj,category=category,truth='side-standing present/placement abnormal' if category=='body' else 'large locating hole',contrast_fraction=f,phone_bbox_wh=[w,h],phone_component_area=a,photo_fill=round(a/(w*h),3),axis_aspect=round(max(w,h)/min(w,h),3),oriented_aspect=round(max(rw,rh)/min(rw,rh),3) if min(rw,rh)>0 else None,number_of_local_components=len(candidates))
    measure.append(z)
    if f==.5:
     color=(80,220,80) if category=='body' else (240,200,60)
     cv2.rectangle(im,(cx-hx+x,cy-hy+y),(cx-hx+x+w-1,cy-hy+y+h-1),color,1)
     checks.append(z)
 cv2.imwrite(str(out/f'S{idx:02d}_geometry_annotation.png'),im[510:706,608:978])
save(out/'photo_measurements.json',dict(method='GRAY S03/S04, manual centers, local15th/97th percentile contrast35/50/65%, original8-connected masks with no morphology. Largest local component only plus fragment count; units are phone photo pixels, not native1280x720 or half-mask. Third object truth remains user-confirmed side-standing irrespective of aspect.',measurements=measure,manual_centers=centers,selected50=checks))
print(json.dumps(checks,ensure_ascii=False,indent=2))
print('ARCHIVED',out.as_posix())
