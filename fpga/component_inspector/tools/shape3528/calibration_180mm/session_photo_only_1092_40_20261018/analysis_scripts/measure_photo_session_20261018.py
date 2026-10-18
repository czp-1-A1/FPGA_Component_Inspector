from pathlib import Path
import json,cv2,numpy as np
from PIL import Image,ImageDraw
r=Path.cwd();out=r/'fpga/component_inspector/tools/shape3528/calibration_180mm/session_photo_only_1092_40_20261018'
# Label centers are manually anchored to the visible real state/row, never the
# current FPGA result (recognition is off). Exclude partial holes at cut ends.
centers={
5:dict(empty=[(561,582),(627,581),(695,580),(760,579),(826,578),(892,577)],locating=[(596,641),(661,641),(729,640),(794,640),(860,640)]),
6:dict(empty=[(577,598),(644,597),(712,597),(778,597),(845,596),(912,595)],locating=[(612,657),(679,657),(746,657),(813,656),(879,656)]),
7:dict(present=[(634,593),(704,594),(776,594),(846,594)],locating=[(669,651),(740,651),(810,652)]),
8:dict(present=[(659,551),(730,552),(800,552),(869,553)],locating=[(694,612),(764,612),(834,613)]),
9:dict(present=[(645,584),(715,585),(785,586),(855,587)],locating=[(679,645),(749,647),(819,648)]),
10:dict(present=[(639,575),(709,578),(779,580),(848,582)],locating=[(672,635),(742,638),(812,640)])}
rows=[];annotated=[]
for idx,groups in centers.items():
 im=cv2.imread(str(out/f'P{idx:02d}.jpg'));g=cv2.cvtColor(im,cv2.COLOR_BGR2GRAY)
 image_rows=[]
 for category,pts in groups.items():
  for k,(cx,cy) in enumerate(pts,1):
   half=31 if category=='present' else 19
   roi=g[cy-half:cy+half+1,cx-half:cx+half+1]
   tape=float(np.percentile(roi,15));bright=float(np.percentile(roi,97))
   contrast=bright-tape
   for fraction in [0.35,0.50,0.65]:
    threshold=tape+fraction*contrast
    mask=(roi>threshold).astype(np.uint8)
    # Measure the original threshold mask. No closing or dilation is applied.
    n,labels,stats,cents=cv2.connectedComponentsWithStats(mask,8)
    choices=[]
    for comp in range(1,n):
     x,y,w,h,a=stats[comp];px,py=cents[comp]
     if (px-half)**2+(py-half)**2<=half**2:choices.append((a,comp))
    if not choices:continue
    _,comp=max(choices);x,y,w,h,a=map(int,stats[comp]);m=(labels==comp).astype(np.uint8)
    cnt=max(cv2.findContours(m,cv2.RETR_EXTERNAL,cv2.CHAIN_APPROX_SIMPLE)[0],key=cv2.contourArea)
    peri=cv2.arcLength(cnt,True);carea=cv2.contourArea(cnt)
    z=dict(photo=idx,mode='RAW' if idx<=8 else 'GRAY',category=category,index=k,phone_center_xy=[cx,cy],contrast_fraction=fraction,phone_threshold=round(threshold,2),photo_bbox_wh=[w,h],phone_area=a,photo_fill=round(a/(w*h),3),photo_circularity=round(4*np.pi*carea/(peri*peri),3) if peri else 0,photo_foreground_to_tape_contrast=round(contrast,2))
    rows.append(z)
    if fraction==0.50:
     x0=cx-half+x;y0=cy-half+y
     color={'present':(120,240,130),'empty':(30,210,255),'locating':(255,210,50)}[category]
     cv2.rectangle(im,(x0,y0),(x0+w-1,y0+h-1),color,1)
     image_rows.append(z)
 crop=im[480:715,470:980];cv2.imwrite(str(out/f'P{idx:02d}_geometry_annotation.png'),crop)
 annotated.append(Image.fromarray(cv2.cvtColor(crop,cv2.COLOR_BGR2RGB)))
summary={}
for category in ['empty','locating','present']:
 selected=[z for z in rows if z['category']==category and z['contrast_fraction']==0.5]
 summary[category]=dict(objects_measured=len(selected),photo_width_range=[min(z['photo_bbox_wh'][0] for z in selected),max(z['photo_bbox_wh'][0] for z in selected)],photo_height_range=[min(z['photo_bbox_wh'][1] for z in selected),max(z['photo_bbox_wh'][1] for z in selected)],photo_area_range=[min(z['phone_area'] for z in selected),max(z['phone_area'] for z in selected)],photo_fill_range=[min(z['photo_fill'] for z in selected),max(z['photo_fill'] for z in selected)])
data=dict(method='Original RAW/GRAY phone photos, manually labeled object centers, local-tape-relative contrast threshold sweep 35/50/65%; only photographic geometry evidence. No monitor gamma inversion, no native FPGA threshold80/100 readback, no claim these pixel units are1280x720. Do not use photo gray levels as FPGA gray values.',summary=summary,measurements=rows,manual_centers=centers)
(out/'photo_geometry.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
canvas=Image.new('RGB',(1020,3*265),(245,245,245));d=ImageDraw.Draw(canvas)
for i,(idx,im) in enumerate(zip(centers,annotated)):
 x=(i%2)*510;y=(i//2)*265;canvas.paste(im,(x,y+22));d.text((x+5,y+3),f'P{idx:02d} photo geometry; 50% local contrast',fill='black')
canvas.save(out/'geometry_contact_sheet.jpg',quality=94)
print(json.dumps(summary,indent=2))
