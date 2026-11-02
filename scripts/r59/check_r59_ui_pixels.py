from pathlib import Path
import json,hashlib,re
import numpy as np
from PIL import Image

root=Path('D:/FpgaWork/r59_field_20261102');work=root/'ui_c'
reference=json.loads((Path('D:/FpgaWork/r28_field_20261102/r57_font_reference.json')).read_text(encoding='utf8'))
font=reference['font_bytes'];tokens=reference['template_cells'];tokens[13]=ord('9')
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
   if 896<=xx<1264 and 8<=yy<72:
    source_line=yy>=40
    message=('SRC '+('4294967295' if frame!=1 else '-'*10)+' '*8) if source_line else ('LAT 0041.4ms  LAG 002f' if frame!=1 else 'LAT ----.-ms  LAG ---f')
    char_pos=(xx-896)//16
    overlay_code=ord(message[char_pos]) if char_pos<len(message) else 32
    overlay_row=(yy-(40 if source_line else 8))//2;overlay_col=((xx-896)%16)//2
    byte=font[(overlay_code-32)*16+overlay_row];overlay_ink=bool(byte&(128>>overlay_col))
    expected=(0xff80df if source_line else 0x40c8ff) if overlay_ink else 0x142336
   assert int(rgb[yy,xx])==expected,(frame,xx,yy,line,row,code,hex(int(rgb[yy,xx])),hex(expected))
   checks+=1
 for yy in range(8,72):
  for xx in range(1160,1264):
   source_line=yy>=40;message=('SRC '+('4294967295' if frame!=1 else '-'*10)+' '*8) if source_line else ('LAT 0041.4ms  LAG 002f' if frame!=1 else 'LAT ----.-ms  LAG ---f')
   c=(xx-896)//16;code=ord(message[c]) if c<len(message) else 32
   row=(yy-(40 if source_line else 8))//2;col=((xx-896)%16)//2
   ink=bool(font[(code-32)*16+row]&(128>>col));expected=(0xff80df if source_line else 0x40c8ff) if ink else 0x142336
   assert int(rgb[yy,xx])==expected,(frame,xx,yy,hex(int(rgb[yy,xx])),hex(expected));checks+=1
 if frame==0:
  image=np.stack([(rgb>>16)&255,(rgb>>8)&255,rgb&255],axis=-1).astype(np.uint8)
  Image.fromarray(image).save(root/'R59_UI_Actual_Simulation.png')
assert glyph_rows=={(glyph,row) for glyph in range(1,8) for row in range(16)}
receipt={'status':'PASS_INDEPENDENT_R59_UI_RGB_PIXELS_AND_COMPLETE_SECOND_LANE_CJK','compared_pixels':checks,'rasters':3,'second_lane_glyph_rows':len(glyph_rows),'expected_glyph_rows':112,'font':'16x16 CJK; upper-right16x32 scaled ASCII','source':'Actual vendor-font RTL simulation RGB dumps, independent font/template reference','preview_sha256':hashlib.sha256((root/'R59_UI_Actual_Simulation.png').read_bytes()).hexdigest()}
(root/'R59_UI_PIXEL_VERIFICATION.json').write_text(json.dumps(receipt,indent=2),encoding='utf8')
print(json.dumps(receipt,indent=2))
