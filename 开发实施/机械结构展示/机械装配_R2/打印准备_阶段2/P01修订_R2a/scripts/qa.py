from pathlib import Path
import json,subprocess,concurrent.futures,sys,re,math
sys.path.insert(0,r'E:\fusion360_codex_skill\.tools\python_deps')
import numpy as np
import matplotlib;matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.collections import LineCollection
from PIL import Image,ImageDraw
from pypdf import PdfReader
R=Path(r'E:\2026FPGA\FPGA_Component_Inspector\开发实施\机械结构展示\机械装配_R2\打印准备_阶段2\P01修订_R2a');out=R/'evidence/图纸复核';out.mkdir(exist_ok=True)
exe=r'C:\Users\dell\.cache\codex-runtimes\codex-primary-runtime\dependencies\native\poppler\Library\bin\pdftoppm.exe'
index=json.loads((R/'evidence/drawing_index.json').read_text())
def render(q):
 p=Path(q['file']);rc=subprocess.run([exe,'-r','70','-png',str(p),str(out/q['code'])],capture_output=True);assert rc.returncode==0,rc.stderr
 return len(PdfReader(str(p)).pages)
with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:counts=list(pool.map(render,index))
imgs=sorted(out.glob('*.png'));pages=[]
for off in range(0,len(imgs),12):
 sheet=Image.new('RGB',(1800,4*340),'#dddddd');draw=ImageDraw.Draw(sheet)
 for i,p in enumerate(imgs[off:off+12]):
  im=Image.open(p);im.thumbnail((585,315));x=(i%3)*600;y=(i//3)*340;sheet.paste(im,(x,y+20));draw.text((x+5,y+3),p.stem,fill='black')
 dest=out/f'contact_{off//12+1}.jpg';sheet.save(dest);pages.append(str(dest))
# Inspect actual extruding XY toolpaths including brim/support; ignore travel/retraction.
stats=[];previews=R/'切片预览';previews.mkdir(exist_ok=True)
for q in json.loads((R/'evidence/slice_results.json').read_text()):
 code=q['code'];f=R/'evidence/slice_estimate'/(code+'.gcode');pos={'X':0.,'Y':0.,'Z':0.,'E':0.};typ='';absolute=True;layers={};lo=np.full(3,np.inf);hi=np.full(3,-np.inf);types={}
 for line in f.read_text(encoding='utf8').splitlines():
  if line.startswith(';TYPE:'):typ=line[6:]
  cmd=line.split(';')[0].strip()
  if cmd=='M82':absolute=True
  if cmd=='M83':absolute=False
  if not cmd.startswith(('G0 ','G1 ','G92 ')):continue
  args={k:float(v) for k,v in re.findall(r'([XYZE])([+-]?(?:\d+(?:\.\d*)?|\.\d+))',cmd)};new=pos.copy();new.update(args)
  if cmd.startswith('G92'):pos.update(args);continue
  de=(args.get('E',pos['E'])-pos['E']) if absolute else args.get('E',0)
  if not absolute:new['E']=pos['E']+de
  if de>1e-6 and ('X'in args or 'Y'in args):
   a=[pos[k] for k in 'XYZ'];b=[new[k] for k in 'XYZ'];lo=np.minimum(lo,np.minimum(a,b));hi=np.maximum(hi,np.maximum(a,b));types[typ]=types.get(typ,0)+de
   if code in ['CT01','CT02','HT01','P06A','P01']:
    layers.setdefault(round(new['Z'],3),[]).append(([a[:2],b[:2]],typ))
  pos=new
 ok=bool(np.all(lo>=-0.01) and np.all(hi<=200.01))
 stats.append({'code':code,'extrusion_bounds_mm':[lo.tolist(),hi.tolist()],'within_assumed_200_cube':ok,'filament_by_role_mm':types})
 if layers:
  targets=([.2,10.2,39.8] if code=='CT01' else [.2,4.2,12.2] if code=='P06A' else [.2,10.2,12.8] if code=='HT01' else [.2,2,6.4] if code=='CT02' else [.2,14.2,26.2])
  fig,axs=plt.subplots(1,3,figsize=(12,4))
  for ax,t in zip(axs,targets):
   z=min(layers,key=lambda z:abs(z-t));data=layers[z];seg=[a for a,b in data];colors=['#df7d25' if 'Support'in b else '#23978c' if 'Bridge'in b else '#264c6b' for a,b in data];ax.add_collection(LineCollection(seg,colors=colors,linewidths=.55));ax.autoscale();ax.set_aspect('equal');ax.set_title(f'{code} | Z {z:g} mm');ax.set_xlabel('X mm');ax.set_ylabel('Y mm')
  fig.suptitle('Actual sliced extrusion paths: blue=part, orange=support, green=bridge');fig.tight_layout();fig.savefig(previews/(code+'_layers.png'),dpi=150);plt.close(fig)
(R/'evidence/toolpath_audit.json').write_text(json.dumps(stats,indent=2),encoding='utf8')
(R/'evidence/pdf_render_qa.json').write_text(json.dumps({'pdf_files':len(index),'pages_rendered':sum(counts),'contacts':pages},indent=2),encoding='utf8')
print({'pages':sum(counts),'all_paths_fit':all(q['within_assumed_200_cube'] for q in stats),'contacts':pages})

