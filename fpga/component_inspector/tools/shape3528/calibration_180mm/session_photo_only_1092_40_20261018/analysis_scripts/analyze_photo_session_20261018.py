from pathlib import Path
import hashlib,json,shutil
import cv2,numpy as np
from PIL import Image,ImageDraw

root=Path.cwd();p=root/'fpga/component_inspector'
out=p/'tools/shape3528/calibration_180mm/session_photo_only_1092_40_20261018'
out.mkdir(exist_ok=False)
sha=lambda q:hashlib.sha256(q.read_bytes()).hexdigest()
names=['93ef23e7-0db5-400f-b566-25b28169fb02','9b2b02a4-4d60-447c-bb9c-f252141aa411','8234d802-1db2-4f5f-8091-28bf51312d83','2afc9b04-bfd0-4b15-86ec-e72bcbac1510','47f21c20-c6bb-4751-8617-cf926d2f41f4','78608e69-6e5e-43f9-a1a8-62eaeadbdfc5','478393ce-6b3a-4131-9adb-3a88e935711e','fcd769f9-6d4e-40db-8755-e391052b7404','2b3c79c7-671b-4b12-80aa-890269e1b7a9','a509668e-2c3f-42e0-8aab-e223be3117df','01d6bd3d-e109-4e6f-b8e3-ad24a532f03a','57752db3-5d37-4b8d-8e29-d8bd3716eb5c']
modes=['GRAY+EDGE','GRAY+EDGE','EDGE','EDGE','RAW','RAW','RAW','RAW','GRAY','GRAY','GRAY+EDGE','GRAY+EDGE']
boxes=[(460,570,890,745),(480,515,930,685),(498,541,955,713),(515,545,962,728),(520,527,943,682),(535,542,961,699),(579,531,894,697),(606,492,918,655),(593,524,900,690),(583,517,894,685),(591,508,914,679),(583,516,897,688)]
records=[]
canvas=Image.new('RGB',(1200,6*240),(235,235,235));draw=ImageDraw.Draw(canvas)
for i,(uid,mode,box) in enumerate(zip(names,modes,boxes),1):
 src=Path('C:/Users/yiziw/AppData/Local/Temp')/f'codex-clipboard-{uid}.jpg';dst=out/f'P{i:02d}.jpg'
 shutil.copy2(src,dst);assert sha(src)==sha(dst)
 im=Image.open(dst);crop=im.crop(box);crop.thumbnail((580,205))
 x=((i-1)%2)*600;y=((i-1)//2)*240
 canvas.paste(crop,(x+8,y+26));draw.text((x+8,y+5),f'P{i:02d} {mode}: '+('EMPTY small apertures + LARGE locating holes' if i<=6 else 'PRESENT 4 bodies + LARGE locating holes'),fill='black')
 crop.save(out/f'P{i:02d}_carrier_crop.png')
 records.append(dict(id=i,archived=dst.name,original=src.as_posix(),bytes=dst.stat().st_size,sha256=sha(dst),screen_mode=mode,scene='empty_and_large_locating_holes' if i<=6 else 'four_front_facing_present_and_large_locating_holes',truth_source='Human user explicitly identifies the larger round openings as locating holes; smaller openings on empty carrier are empty sites. Visible bodies in P07-P12.',existing_detection_required=False,native_pixel_readback=False,phone_crop_xyxy=list(box)))
canvas.save(out/'carrier_contact_sheet.jpg',quality=94)
(out/'sources.json').write_text(json.dumps(dict(photo_bit_sha256='66f9be7c5bc4103abb9c8f4718c2e64bdbca04ecc637e016691c7b40e99c011a',version_binding='Visible PHOTO ONLY / DETECT OFF title and EXP1092 GAIN40 WB100/100; file hash not read back from physical FPGA.',images=records),ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(out.as_posix())
