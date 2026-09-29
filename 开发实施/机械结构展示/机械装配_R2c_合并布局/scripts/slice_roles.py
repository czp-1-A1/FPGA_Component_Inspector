from pathlib import Path
import json,re,math,csv
Q=Path('E:/2026FPGA/FPGA_Component_Inspector/开发实施/机械结构展示/机械装配_R2c_合并布局');T=Path('E:/fusion360_codex_skill/.tools/tmp/R2c_offline')
for group in ['baseline','new']:
 f=Q/'evidence'/(group+'_slicing.json')
 if not f.exists():continue
 rows=json.loads(f.read_text(encoding='utf8'))
 for r in rows:
  label=r['id']+'_'+r['orientation']+'_'+str(r['fill_percent']);g=T/(label+'.gcode');role='unknown';pos={'X':0.,'Y':0.,'Z':0.,'E':0.};lengths={}
  if not g.exists():continue
  for line in g.read_text(encoding='utf8').splitlines():
   if line.startswith(';TYPE:'):role=line[6:].strip()
   elif line.startswith('G92 '):
    for a,v in re.findall(r'([XYZE])(-?[\d.]+)',line):pos[a]=float(v)
   elif line.startswith(('G1 ','G0 ')):
    nxt=pos.copy()
    for a,v in re.findall(r'([XYZE])(-?[\d.]+)',line):nxt[a]=float(v)
    de=nxt['E']-pos['E']
    if de>0 and (nxt['X']!=pos['X'] or nxt['Y']!=pos['Y']):lengths[role]=lengths.get(role,0)+de
    pos=nxt
  grams={k:v*math.pi*(1.75/2)**2*1.27/1000 for k,v in lengths.items()}
  r['path_role_mass_estimate_g']=grams;r['support_g']=sum(v for k,v in grams.items() if 'Support' in k);r['brim_g']=sum(v for k,v in grams.items() if 'Brim' in k)
  r['time_seconds']=sum(int(n)*{'h':3600,'m':60,'s':1}[u] for n,u in re.findall(r'(\d+)\s*([hms])',r.get('time') or ''))
  lo,hi=r['extrusion_path_bounds_mm'];r['bead_edge_fit_200']=all(lo[i]-.225>=0 and hi[i]+.225<=200 for i in [0,1]) and hi[2]<=200
 f.write_text(json.dumps(rows,ensure_ascii=False,indent=2),encoding='utf8')
print('Role-based support/brim estimate updated; travel and retraction excluded')
