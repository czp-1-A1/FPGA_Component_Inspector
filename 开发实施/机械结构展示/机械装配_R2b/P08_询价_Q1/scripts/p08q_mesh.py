from pathlib import Path
import sys,json,numpy as np
sys.path[:0]=['E:/2026FPGA/FPGA_Component_Inspector/开发实施/机械结构展示/.cad_runtime','E:/fusion360_codex_skill/.tools/python_deps']
import trimesh
from OCP.STEPControl import STEPControl_Reader,STEPControl_Writer,STEPControl_AsIs
from OCP.BRepCheck import BRepCheck_Analyzer
from OCP.BRepBuilderAPI import BRepBuilderAPI_Transform
from OCP.gp import gp_Trsf,gp_Vec
from OCP.BRepMesh import BRepMesh_IncrementalMesh
from OCP.StlAPI import StlAPI_Writer
from OCP.GProp import GProp_GProps
from OCP.BRepGProp import BRepGProp
R=Path('E:/2026FPGA/FPGA_Component_Inspector/开发实施/机械结构展示/机械装配_R2b/P08_询价_Q1')
rd=STEPControl_Reader();assert rd.ReadFile(str(R/'evidence/P08_native_assembly_coords.step'))==1;rd.TransferRoots();shape=rd.OneShape();assert BRepCheck_Analyzer(shape).IsValid()
tr=gp_Trsf();tr.SetTranslation(gp_Vec(0,0,-167));shape=BRepBuilderAPI_Transform(shape,tr,True).Shape()
w=STEPControl_Writer();w.Transfer(shape,STEPControl_AsIs);assert w.Write(str(R/'P08_Q1.step'))==1
rd2=STEPControl_Reader();rd2.ReadFile(str(R/'P08_Q1.step'));rd2.TransferRoots();shape=rd2.OneShape();assert BRepCheck_Analyzer(shape).IsValid()
props=GProp_GProps();BRepGProp.VolumeProperties_s(shape,props);vol=props.Mass()
BRepMesh_IncrementalMesh(shape,.01,False,.1,True);sw=StlAPI_Writer();sw.ASCIIMode=False;assert sw.Write(shape,str(R/'evidence/P08_unoriented.stl'))
m=trimesh.load_mesh(R/'evidence/P08_unoriented.stl');rotation=trimesh.transformations.rotation_matrix(np.pi,[1,0,0]);m.apply_transform(rotation);offset=-m.bounds[0];m.apply_translation(offset);dest=R/'P08_Q1_顶面贴床_支脚朝上_数量2.stl';m.export(dest)
re=trimesh.load_mesh(dest);assert re.is_watertight and re.volume>0 and len(re.split())==1
assert np.allclose(re.extents,[137,72,9],atol=.001)
upward=(re.face_normals[:,2]>.999);downward=(re.face_normals[:,2]<-.999)
# No unsupported downward-facing shelves above Z0 for this orientation.
unsupported=int(np.sum(downward & (re.triangles_center[:,2]>.02)))
assert unsupported==0
out={'STEP_valid':True,'STEP_volume_mm3':vol,'native_volume_mm3':json.loads((R/'evidence/native_export.json').read_text(encoding='utf8'))['native_volume_mm3'],'STL_volume_mm3':re.volume,'volume_error_percent':abs(re.volume-vol)/vol*100,'watertight':bool(re.is_watertight),'connected_solids':len(re.split()),'triangles':len(re.faces),'dimensions_mm':re.extents.tolist(),'bounds_mm':re.bounds.tolist(),'STEP_datum':'Original lamp XY origin retained; foot contact Z=0, plate underside Z=3, top Z=9','STL_orientation':'Original top surface down; 180deg around X then translated to positive XY, bed Z0; feet point upwards','rotation':rotation.tolist(),'translation_after_rotation_mm':offset.tolist(),'tessellation_mm':.01,'unsupported_downward_faces_above_bed':unsupported,'quantity':2,'material':'PETG','infill_percent':100,'support':'none','brim_mm':3,'print_bed_with_brim_mm':[143,78,9]}
(R/'evidence/mesh_checks.json').write_text(json.dumps(out,ensure_ascii=False,indent=2),encoding='utf8');print(json.dumps(out,ensure_ascii=False))
