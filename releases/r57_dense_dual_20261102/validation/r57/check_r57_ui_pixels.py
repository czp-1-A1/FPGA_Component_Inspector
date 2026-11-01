from pathlib import Path
import json,hashlib,re
import numpy as np
from PIL import Image

root=Path('D:/FpgaWork/r28_field_20261102');work=root/'r57_ui_a'
reference=json.loads((root/'r57_font_reference.json').read_text(encoding='utf8'))
font=reference['font_bytes'];tokens=reference['template_cells']
numbers=[27,20,7,2,0,1,1,9,13,14,15,20,24,0,27,1920,1080,1,43,40,3,5,0,2,21,43,0,0,0,0,0]
checks=0;glyph_rows=set()
for frame in range(3):
 actual=np.loadtxt(work/f'essential_ui_{frame}.hex',dtype=str)
 assert len(actual)==1280*720
 rgb=np.array([int(x,16) for x in actual],dtype=np.uint32).reshape(720,1280)
 state1='RUN     ';state2='LOST    ' if frame==1 else 'RUN     '
 specials={1:state1,2:state2,3:'ALARM K3',4:' CLEAR  '}
 def decode(token):
  mode=token>>8;slot=(token>>3)&31;pos=token&7
  if mode==0:return token&255
  if mode==1:return ord('0')+int(f'{numbers[slot]:05}'[-1-pos])
  assert mode==3 and slot in specials
  return ord(specials[slot][7-pos])
 for yy in list(range(80))+list(range(624,720)):
  line,row=next(((l,yy-y0) for l,y0,y1 in [(0,8,32),(1,32,56),(2,56,72),(3,632,656),(4,656,680),(5,680,704),(6,704,720)] if y0<=yy<y1),(0,31))
  for xx in range(136,1160):
   dx=xx-136;token=tokens[line*128+dx//8];code=32 if row==31 else decode(token);ink=False
   if code&128:
    glyph=code&7;col=((code>>4)&3)*8+(dx&7)
    if row<16 and col<16:
     byte=font[1520+(glyph-1)*32+row*2+col//8];ink=bool(byte&(128>>(col%8)))
     if line==2:glyph_rows.add((glyph,row))
   elif 32<=code<=126 and row<16:
    byte=font[(code-32)*16+row];ink=bool(byte&(128>>(dx&7)))
   expected=(0xff7060 if line==6 else 0x70ffdd) if ink else 0x142336
   assert int(rgb[yy,xx])==expected,(frame,xx,yy,line,row,code,hex(int(rgb[yy,xx])),hex(expected))
   checks+=1
 if frame==0:
  image=np.stack([(rgb>>16)&255,(rgb>>8)&255,rgb&255],axis=-1).astype(np.uint8)
  Image.fromarray(image).save(root/'R57_UI_Actual_Simulation.png')
assert glyph_rows=={(glyph,row) for glyph in range(1,8) for row in range(16)}
receipt={'status':'PASS_INDEPENDENT_R57_UI_RGB_PIXELS_AND_COMPLETE_SECOND_LANE_CJK','compared_pixels':checks,'rasters':3,'second_lane_glyph_rows':len(glyph_rows),'expected_glyph_rows':112,'font':'16x16 CJK / original8x16 ASCII','source':'Actual vendor-font RTL simulation RGB dumps, independent font/template reference','preview_sha256':hashlib.sha256((root/'R57_UI_Actual_Simulation.png').read_bytes()).hexdigest()}
(root/'R57_UI_PIXEL_VERIFICATION.json').write_text(json.dumps(receipt,indent=2),encoding='utf8')
print(json.dumps(receipt,indent=2))
