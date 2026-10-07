"""Independent raster reference for the RTL test's complete 1024x600 frame."""
from pathlib import Path
import json
from PIL import Image,ImageDraw
p=Path(__file__).resolve().parent;a=p/'osd_assets';out=p/'osd_native';out.mkdir(exist_ok=True)
m=json.loads((a/'manifest.json').read_text(encoding='utf-8'));ids=m['cjk_glyph_ids']
ascii_rows=[int(v,16) for v in (a/'osd_ascii_rom.hex').read_text().split()]
cjk_rows=[int(v,16) for v in (a/'osd_cjk_rom.hex').read_text().split()]
colors={'orange':(255,174,100),'bg':(20,35,54),'text':(255,255,255),'muted':(176,192,212),'amber':(247,185,85),'green':(116,219,199)}
im=Image.new('RGB',(1920,1080),(85,102,119));d=ImageDraw.Draw(im)
d.rectangle((704,412,1215,667),fill=(85,102,119),outline=(0,255,64))
d.rectangle((920,500,999,579),outline=(0,255,255))
d.rectangle((0,0,1919,79),fill=colors['bg']);d.rectangle((0,984,1919,1079),fill=colors['bg'])
palette=[(255,255,255),(32,70,134),(204,37,59)]
logo_values=[int(v,16) for v in (a/'osd_logo_rom.hex').read_text().split()]
logo=Image.new('RGB',(96,64))
logo.putdata([palette[logo_values[y*128+x]] for y in range(64) for x in range(96)])
im.paste(logo,(16,8))
def text(x,y,t,scale=1,color='text',cjk=False):
 w,h=(24,24) if cjk else (8,16)
 for i,ch in enumerate(t):
  glyph=ids[ch] if cjk else ord(ch);rows=cjk_rows if cjk else ascii_rows;stride=32 if cjk else 16
  mask=Image.new('1',(w,h))
  for row in range(h):
   for col in range(w):mask.putpixel((col,row),(rows[glyph*stride+row]>>(w-1-col))&1)
  mask=mask.resize((w*scale,h*scale),Image.Resampling.NEAREST)
  im.paste(colors[color],(x+i*w*scale,y),mask)
text(128,24,'ANLOGIC',2)
text(128,56,'ER 1 LP 0280 WS 0123',color='orange')
text(360,8,'曝光',cjk=True);text(424,8,'EXP',2);text(360,40,' 2244',2);text(456,44,'半行',cjk=True)
text(688,8,'增益',cjk=True);text(752,8,'GAIN',2);text(688,40,'   48',2);text(784,44,'档号',cjk=True)
text(864,8,'MODE',2,'muted');text(864,40,'RAW',2)
text(16,990,'最近采样',color='muted',cjk=True);text(16,1020,'未标定',2,'amber',True)
for label,x,value in [('MEAN',304,'102'),('MIN',464,' 20'),('MAX',624,'240')]:
 text(x,990,label,2,'muted');text(x+80 if label=='MEAN' else x+64,990,value,2)
text(768,994,'采样有效',color='green',cjk=True)
text(304,1028,'IN  1920X 1080 FPS    30 CFG 1 L 0001 F 0002 I 0003 G 0004 HEX')
text(808,1028,'EC ---- GS ------ T 80',color='orange')
text(304,1056,'FR 1234ABCD SEC 00000708 HEX')
text(624,1052,'采样有效',color='muted',cjk=True);text(920,1052,'累计异常',color='amber',cjk=True)
text(536,1056,'OF 0012',color='orange');text(752,1056,'VF 0034',color='orange');text(832,1056,'UF 0056',color='orange')
im.save(out/'reference.png')
(out/'reference.hex').write_text(''.join('%02x%02x%02x\n'%rgb for rgb in im.getdata()),encoding='ascii')
base=im.copy()
for index,word in enumerate(['RAW','GRAY','EDGE','GRAY+EDGE']):
 im=base.copy();d=ImageDraw.Draw(im)
 d.rectangle((864,40,1007,71),fill=colors['bg']);text(864,40,word,2)
 d.rectangle((808,1028,975,1043),fill=colors['bg'])
 text(808,1028,'EC 000C GS 000159 T 80' if index&2 else 'EC ---- GS ------ T 80',color='orange')
 im.save(out/f'mode_{index}.png')
 (out/f'mode_{index}.hex').write_text(''.join('%02x%02x%02x\n'%rgb for rgb in im.getdata()),encoding='ascii')
for index,(word,color,valid,cfg,fps,reason) in enumerate([
 ('未标定','amber',True,1,30,'采样有效'),('等待采样','muted',False,1,30,'等待有效帧'),
 ('有件','green',True,1,30,'采样有效'),('空穴','orange',True,1,30,'采样有效'),
 ('等待采样','muted',False,0,30,'配置中'),('等待采样','muted',False,1,0,'无输入')]):
 colors['orange']=(255,174,100);colors['red']=(239,113,134)
 im=base.copy();d=ImageDraw.Draw(im)
 d.rectangle((16,1020,279,1079),fill=colors['bg']);text(16,1020,word,2,color,True)
 d.rectangle((304,984,1919,1079),fill=colors['bg'])
 for label,x,value in [('MEAN',304,'102'),('MIN',464,' 20'),('MAX',624,'240')]:
  text(x,990,label,2,'muted');text(x+80 if label=='MEAN' else x+64,990,value if valid else '---',2)
 if valid:text(768,994,'采样有效',color='green',cjk=True)
 text(304,1028,f'IN  1920X 1080 FPS {fps:5d} CFG {cfg} L 0001 F 0002 I 0003 G 0004 HEX')
 text(808,1028,'EC ---- GS ------ T 80',color='orange')
 text(304,1056,'FR 1234ABCD SEC 00000708 HEX')
 text(624,1052,reason,color='red' if index==5 else 'muted',cjk=True)
 text(920,1052,'累计异常',color='amber',cjk=True)
 text(536,1056,'OF 0012',color='orange');text(752,1056,'VF 0034',color='orange');text(832,1056,'UF 0056',color='orange')
 panel=im.crop((0,984,1920,1080));panel.save(out/f'state_{index}.png')
 (out/f'state_{index}.hex').write_text(''.join('%02x%02x%02x\n'%rgb for rgb in panel.getdata()),encoding='ascii')
print('Reference frame:',out/'reference.png')

import hashlib
(out/"oracle.json").write_text(json.dumps({p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in out.glob("*.hex")},indent=2)+"\n")
