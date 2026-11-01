from pathlib import Path
from PIL import Image,ImageDraw
root=Path(__file__).resolve().parent/'video_r0';frames=sorted(root.glob('frame_*.png'))
for start in range(0,len(frames),12):
 group=frames[start:start+12];canvas=Image.new('RGB',(1920,4*386),'#191919');d=ImageDraw.Draw(canvas)
 for j,p in enumerate(group):
  x=j%3*640;y=j//3*386;d.text((x+8,y+6),f't={(start+j)*0.5:.1f}s file={p.name}',fill='white')
  im=Image.open(p).convert('RGB');im.thumbnail((640,360));canvas.paste(im,(x,y+24))
 canvas.save(root/f'sheet_{start//12:02d}.jpg',quality=95)
print('frames',len(frames),'sheets',(len(frames)+11)//12,'size',Image.open(frames[0]).size)
