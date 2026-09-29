from pathlib import Path
import sys,json,subprocess,re,concurrent.futures
sys.path[:0]=['E:/2026FPGA/FPGA_Component_Inspector/开发实施/机械结构展示/.cad_runtime','E:/fusion360_codex_skill/.tools/python_deps']
import numpy as np,trimesh
from OCP.STEPControl import STEPControl_Reader
from OCP.BRepCheck import BRepCheck_Analyzer
from OCP.BRepMesh import BRepMesh_IncrementalMesh
from OCP.StlAPI import StlAPI_Writer
from OCP.GProp import GProp_GProps
from OCP.BRepGProp import BRepGProp
Q=Path('E:/2026FPGA/FPGA_Component_Inspector/开发实施/机械结构展示/机械装配_R2c_合并布局');E=Q/'evidence';tmp=Path('E:/fusion360_codex_skill/.tools/tmp/R2c_offline');tmp.mkdir(exist_ok=True)
base=Path('E:/2026FPGA/FPGA_Component_Inspector/开发实施/机械结构展示/机械装配_R2/打印准备_阶段2/通用PETG_仅预估.ini').read_text(encoding='utf8')
slicer='E:/fusion360_codex_skill/.tools/PrusaSlicer2.9.6/PrusaSlicer-2.9.6/prusa-slicer-console.exe'
mode=sys.argv[1]
files=list(E.glob(('baseline_' if mode=='baseline' else 'new_')+'*.step'))
checks=[];jobs=[]
for f in files:
 ident=f.stem;part=ident.split('_')[1]
 rd=STEPControl_Reader();assert rd.ReadFile(str(f))==1;rd.TransferRoots();sh=rd.OneShape();assert BRepCheck_Analyzer(sh).IsValid()
 g=GProp_GProps();BRepGProp.VolumeProperties_s(sh,g)
 BRepMesh_IncrementalMesh(sh,.03,False,.1,True);sw=StlAPI_Writer();sw.ASCIIMode=False;raw=tmp/(ident+'_raw.stl');assert sw.Write(sh,str(raw))
 m=trimesh.load_mesh(raw);assert m.is_watertight
 variants=[('sideX',np.pi/2,[0,1,0])] if part in ['P01','P05','P09L','P09R'] else [('top',np.pi,[1,0,0])] if part.startswith(('P03','P08','P10')) else [('frontY',np.pi/2,[1,0,0])] if part=='P04' else [('bottom',0,[1,0,0])]
 if part.startswith('P09'):variants.append(('bottom',0,[1,0,0]))
 for orient,angle,axis in variants:
  mesh=m.copy();mesh.apply_transform(trimesh.transformations.rotation_matrix(angle,axis));mesh.apply_translation(-mesh.bounds[0]);out=tmp/(ident+'_'+orient+'.stl');mesh.export(out)
  row={'id':ident,'part':part,'orientation':orient,'volume_mm3':g.Mass(),'mesh_volume_mm3':mesh.volume,'watertight':bool(mesh.is_watertight),'solid_count':len(mesh.split()),'dimensions_mm':mesh.extents.tolist(),'stl_internal':str(out)};checks.append(row)
  for pct in [100,25]:
   if part=='P08' and pct==25:continue
   label=ident+'_'+orient+'_'+str(pct)
   cfg=base.replace('fill_density = 25%',f'fill_density = {pct}%').replace('fill_pattern = gyroid','fill_pattern = rectilinear' if pct==100 else 'fill_pattern = gyroid')
   if part.startswith(('P03','P08','P10')) or part=='P04':cfg=cfg.replace('support_material = 1','support_material = 0')
   ini=tmp/(label+'.ini');ini.write_text(cfg,encoding='utf8');jobs.append((row,pct,label,ini,out))
(E/(mode+'_mesh.json')).write_text(json.dumps(checks,ensure_ascii=False,indent=2),encoding='utf8')
def do(job):
 row,pct,label,ini,stl=job;gc=tmp/(label+'.gcode')
 p=subprocess.run([slicer,'--load',str(ini),'--export-gcode','--center','100,100','--output',str(gc),str(stl)],capture_output=True,text=True,encoding='utf8',errors='replace')
 (E/(label+'_slice.log')).write_text(p.stdout+'\n'+p.stderr,encoding='utf8');ans={**row,'fill_percent':pct,'exit_code':p.returncode}
 if gc.exists():
  text=gc.read_text(encoding='utf8');
  for key,pat in [('mass_g',r'; filament used \[g\] = ([\d.]+)'),('volume_cm3',r'; filament used \[cm3\] = ([\d.]+)'),('time',r'; estimated printing time \(normal mode\) = ([^\n]+)')]:
   ma=re.search(pat,text);ans[key]=(ma.group(1).strip() if key=='time' else float(ma.group(1))) if ma else None
  # Track extrusion moves; distinguish deposited paths from travel.
  pos={'X':0.,'Y':0.,'Z':0.,'E':0.};lo=[1e9]*3;hi=[-1e9]*3
  for line in text.splitlines():
   if line.startswith('G92 '):
    for a,v in re.findall(r'([XYZE])(-?[\d.]+)',line):pos[a]=float(v)
   elif line.startswith(('G1 ','G0 ')):
    nxt=pos.copy()
    for a,v in re.findall(r'([XYZE])(-?[\d.]+)',line):nxt[a]=float(v)
    if nxt['E']>pos['E'] and (nxt['X']!=pos['X'] or nxt['Y']!=pos['Y']):
     for k,a in enumerate('XYZ'):lo[k]=min(lo[k],pos[a],nxt[a]);hi[k]=max(hi[k],pos[a],nxt[a])
    pos=nxt
  ans['extrusion_path_bounds_mm']=[lo,hi];ans['bed_200_fit']=all(lo[i]>=0 and hi[i]<=200 for i in range(3))
 print(json.dumps({k:ans.get(k) for k in ['id','orientation','fill_percent','exit_code','mass_g','time','bed_200_fit']}),flush=True);return ans
with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:results=list(pool.map(do,jobs))
(E/(mode+'_slicing.json')).write_text(json.dumps(results,ensure_ascii=False,indent=2),encoding='utf8')
