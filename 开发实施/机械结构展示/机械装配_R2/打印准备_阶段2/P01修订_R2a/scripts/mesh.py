from pathlib import Path
import sys,json,numpy as np
sys.path.insert(0,r'E:\2026FPGA\FPGA_Component_Inspector\开发实施\机械结构展示\.cad_runtime');sys.path.insert(0,r'E:\fusion360_codex_skill\.tools\python_deps')
import trimesh
from OCP.STEPControl import STEPControl_Reader
from OCP.BRepCheck import BRepCheck_Analyzer
from OCP.BRepMesh import BRepMesh_IncrementalMesh
from OCP.StlAPI import StlAPI_Writer
R=Path(r'E:\2026FPGA\FPGA_Component_Inspector\开发实施\机械结构展示\机械装配_R2\打印准备_阶段2\P01修订_R2a')
O=R/'evidence/打印方向网格';O.mkdir(exist_ok=True)
meta=[]
for p in sorted((R/'零件STEP').glob('P*.step'))+sorted((R/'小样STEP').glob('*.step')):
 r=STEPControl_Reader();r.ReadFile(str(p));r.TransferRoots();s=r.OneShape();assert BRepCheck_Analyzer(s).IsValid()
 BRepMesh_IncrementalMesh(s,.025,False,.15,True);w=StlAPI_Writer();w.ASCIIMode=False;tmp=O/(p.stem+'_cad.stl');w.Write(s,str(tmp))
 m=trimesh.load_mesh(tmp);before=m.bounds.copy();volume=abs(m.volume)
 axis='native +Z';a=0;v=[0,0,1]
 if p.stem in ['P01','P05']:axis='native +X side down';a=np.pi/2;v=[0,1,0]
 elif p.stem=='P04':axis='native -Y front down';a=np.pi/2;v=[1,0,0]
 elif p.stem.startswith('P03') or p.stem=='CT02':axis='native +Z top down';a=np.pi;v=[1,0,0]
 if a:m.apply_transform(trimesh.transformations.rotation_matrix(a,v))
 m.apply_translation(-m.bounds[0]);dest=O/(p.stem+'.stl');m.export(dest);tmp.unlink()
 meta.append({'code':p.stem,'source':str(p),'orientation':axis,'rotation_radians':a,'axis':v,'native_bounds_mm':before.tolist(),'print_size_mm':m.extents.tolist(),'volume_mm3':volume,'watertight':bool(m.is_watertight),'triangles':len(m.faces),'positive_volume':bool(m.volume>0)})
(R/'evidence/mesh_orientation.json').write_text(json.dumps(meta,indent=2),encoding='utf8');print([(q['code'],q['watertight'],q['triangles'],[round(x,2) for x in q['print_size_mm']]) for q in meta])

