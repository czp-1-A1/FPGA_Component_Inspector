"""Independent display contract: literal field values, frozen R12 font/logo bits,
fixed ROI geometry and the four known source snapshots. No DUT token/formatter
functions are evaluated and no golden output is derived from simulation output.
"""
from pathlib import Path
import re,json,hashlib,sys
import numpy as np
from PIL import Image
r=Path(__file__).resolve().parent;c=r;p=r.parents[1];sim=r/'ui_out'
h=p/'user_source/hdl_source';out=c/'independent_pixels';out.mkdir(exist_ok=True)
sha=lambda q:hashlib.sha256(q.read_bytes()).hexdigest()
def rom(name,width):
 s=(h/(name+'.v')).read_text();vals={int(i):int(v,16) for i,v in re.findall(r"memory\[(\d+)\]\s*=\s*"+str(width)+r"'h([0-9a-fA-F]+)",s)}
 return vals
ascii_rom=rom('compact_ascii_rom',8);logo=rom('osd_logo_rom',2);cjk=rom('compact_cjk_rom',24)
original_ascii=rom('osd_ascii_rom',8)
for ch in range(128):
 if any(original_ascii[ch*16+y] for y in range(16)):
  assert all(ascii_rom[ch*16+y]==original_ascii[ch*16+y] for y in range(16))
assert all(any(ascii_rom[ch*16+y] for y in range(16)) for ch in range(33,127))
glyphs={ch:i+1 for i,ch in enumerate('有件空穴待复核')}
Y,X=np.mgrid[0:720,0:1280];BG=0x142336;INK=0x70ffdd;WARN=0xffe080
records=[]
def draw(im,text,x,y,color=INK):
 for ch in text:
  if ch in glyphs:
   g=glyphs[ch]
   for row in range(24):
    bits=cjk[g*32+row]
    for col in range(24):
     if bits>>(23-col)&1:im[y+row,x+col]=color
   x+=24
  else:
   for row in range(16):
    bits=ascii_rom[ord(ch)*16+row]
    for col in range(8):
     if bits>>(7-col)&1:im[y+row,x+col]=color
   x+=8
def field(im,line,col,text,color=INK):draw(im,text,136+col*8,[8,32,56,632,656,680,704][line],color)
for frame in range(4):
 im=np.full((720,1280),0x556677,dtype=np.uint32);im[(Y<80)|(Y>=624)]=BG
 guide=((((X==400)|(X==879))&(((Y>=240)&(Y<400))|((Y>=432)&(Y<600))))|(((Y==240)|(Y==399)|(Y==432)|(Y==599))&(X>=400)&(X<880)))&(((X//8)%2!=0)|((Y//8)%2!=0))
 guide|=(X==640)&((Y//4)%2!=0)&(((Y>=240)&(Y<400))|((frame==0)&(Y>=432)&(Y<600)))
 im[guide]=0x00d8d0
 for y in range(64):
  for x in range(96):im[y+8,x+16]={0:0xffffff,1:0x204686,2:0xcc253b,3:0xffffff}[logo[y*128+x]]
 field(im,0,0,'DETECT R17' if frame==0 else 'COUNT R17')
 for col,text in [(12,'EXP'),(16,'01092'),(23,'GAIN'),(28,'00040'),(35,'FPS'),(39,'027'),(44,'MODE'),(49,'3'),(52,'WB'),(55,'100/100'),(63,'L'),(67,'CFG'),(71,'1'),(74,'V'),(76,'0' if frame==2 else '1')]:field(im,0,col,text)
 if frame==0:
  for col,text in [(0,'GRAY'),(5,'149'),(10,'MIN'),(14,'124'),(19,'MAX'),(23,'176'),(30,'OBJ W'),(36,'032'),(41,'H'),(43,'032'),(48,'A'),(50,'00956')]:field(im,1,col,text)
  for col,text in [(0,'UI OBS P'),(9,'2'),(12,'E'),(14,'1'),(17,'U'),(19,'1'),(23,'2/ROI'),(31,'WAIT'),(36,'0'),(40,'EDGE'),(45,'00000')]:field(im,2,col,text)
  values=[('94','7C','B0','20','20','03BC','1'),('C8','50','F0','28','20','0500','0')]
  for line,v in zip([3,4],values):
   for col,text in [(0,'CAL1 M' if line==3 else 'CAL2 M'),(7,v[0]),(11,'MIN'),(15,v[1]),(19,'MAX'),(23,v[2]),(27,'W'),(29,v[3]),(33,'H'),(35,v[4]),(39,'A'),(41,v[5]),(47,'CLIP'),(52,v[6])]:field(im,line,col,text)
  field(im,4,56,'CAL V');field(im,4,62,'1')
 else:
  gap=False;color=WARN if gap else INK;nonzero=frame==1
  for col,text in [(0,'RUN GAP ' if gap else 'READY   ' if frame==2 else 'RUN     '),(10,'TOTAL'),(16,'027' if nonzero else '000'),(22,'有件'),(29,'020' if nonzero else '000'),(35,'空穴'),(42,'007' if nonzero else '000'),(48,'待复核'),(58,'002' if nonzero else '000'),(64,'C'),(66,'0')]:field(im,1,col,text,color)
  for col,text in [(0,'RUN'),(4,'65535' if nonzero else '00000'),(12,'LAST'),(17,'R027' if gap else 'N027' if nonzero else 'N000'),(34,'R009' if gap else ''),(58,'FIRST'),(64,'4021' if nonzero else '0000')]:field(im,2,col,text,color)
  if gap:field(im,2,25,'GAP FROM',color);field(im,2,39,'IDS UNCONFIRMED',color)
  field(im,3,0,'EMPTY IDS PAGE',color);field(im,3,15,'001',color);field(im,3,20,':',color)
  for i,v in enumerate([1,9,13,14,15,20,24,0] if nonzero else [0]*8):field(im,3,23+i*5,f'{v:03}',color)
  field(im,4,0,'LAST');field(im,4,6,'空穴' if nonzero else '');field(im,4,18,'WHY');field(im,4,22,'0');field(im,4,26,'REVIEW = PRESENT SUBSET');field(im,4,53,'ROI');field(im,4,57,'1');field(im,4,60,'DIR');field(im,4,64,'R' if nonzero else '?')
 src='89ABCDEF' if frame==0 else '12345678';first='4021' if frame<=1 else '0000'
 for col,text in [(0,'SRC'),(4,src),(15,'IN'),(18,'1920X1080'),(30,'OF'),(33,'0000'),(39,'UF'),(42,'0000'),(48,'LOST'),(53,'0000'),(60,'FIRST'),(66,first)]:field(im,5,col,text)
 for col,text in [(0,'L'),(2,'0000'),(8,'F'),(10,'0000'),(16,'I'),(18,'0000'),(24,'G'),(26,'0000'),(32,'D'),(34,'000000000'),(44,'P'),(46,'00000000'),(57,'FR'),(60,'00000011')]:field(im,6,col,text)
 objects=[(550,581,300,331,'有件',INK),(650,659,310,319,'空穴',WARN),(550,581,470,501,'待复核',0xffb070),(690,711,480,497,'待复核',0xffb070)]
 if frame==2:objects=[]
 elif frame!=0:objects=objects[:2]
 for i,(x0,x1,y0,y1,kind,color) in enumerate(objects):
  im[y0:y1+1,x0]=0x00d8d0;im[y0:y1+1,x1]=0x00d8d0;im[y0,x0:x1+1]=0x00d8d0;im[y1,x0:x1+1]=0x00d8d0
  ly=y0-28 if i%2==0 else y1+4;lx=x0
  text=('N008 ' if i==0 else 'N009 ')+kind if frame==1 else kind
  im[ly:ly+24,lx:lx+(112 if frame==1 else 72)]=BG;draw(im,text,lx,ly,color)
 file=sim/f'surface_ui_{frame}.hex';raw=np.array([int(s,16) for s in file.read_text().split()],dtype=np.uint32).reshape(720,1280)
 def rgb(a):return np.stack(((a>>16)&255,(a>>8)&255,a&255),axis=-1).astype('uint8')
 Image.fromarray(rgb(raw)).save(out/f'actual_{frame}.png');Image.fromarray(rgb(im)).save(out/f'expected_{frame}.png')
 mismatch=raw!=im;coords=np.argwhere(mismatch);details=[]
 for y,x in coords[:20]:details.append(dict(x=int(x),y=int(y),expected=f'{im[y,x]:06x}',actual=f'{raw[y,x]:06x}'))
 records.append(dict(frame=frame,pixels=921600,mismatch=int(mismatch.sum()),first_differences=details,captured_sha256=sha(file)))
report=dict(status='PASS' if all(d['mismatch']==0 for d in records) else 'FAIL_RETAINED',source_manifest_sha256=sha(p/'R17_FROZEN_INPUTS.json'),frames=records,expected_contract='Literal fixed values and UI geometry; no DUT template/formatter evaluated')
(out/'verification.json').write_text(json.dumps(report,indent=2),encoding='utf-8');print(json.dumps(report,indent=2))
if report['status']!='PASS':raise SystemExit(1)
