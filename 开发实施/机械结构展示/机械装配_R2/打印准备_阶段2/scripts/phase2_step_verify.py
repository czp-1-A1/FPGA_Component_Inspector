from pathlib import Path
import sys,json
sys.path.insert(0,r'E:\2026FPGA\FPGA_Component_Inspector\开发实施\机械结构展示\.cad_runtime')
from OCP.STEPControl import STEPControl_Reader
from OCP.BRepCheck import BRepCheck_Analyzer
from OCP.BRepGProp import BRepGProp
from OCP.GProp import GProp_GProps
from OCP.BRepBuilderAPI import BRepBuilderAPI_Transform
from OCP.BRepPrimAPI import BRepPrimAPI_MakeBox
from OCP.BRepAlgoAPI import BRepAlgoAPI_Common,BRepAlgoAPI_Cut
from OCP.gp import gp_Trsf,gp_Vec,gp_Pnt
from OCP.TopExp import TopExp_Explorer
from OCP.TopAbs import TopAbs_SOLID
from OCP.TopoDS import TopoDS
from OCP.Bnd import Bnd_Box
from OCP.BRepBndLib import BRepBndLib
R=Path(r'E:\2026FPGA\FPGA_Component_Inspector\开发实施\机械结构展示\机械装配_R2\打印准备_阶段2');shapes={};rows=[]
def vol(s):g=GProp_GProps();BRepGProp.VolumeProperties_s(s,g);return g.Mass()
for p in sorted((R/'零件STEP').glob('*.step'))+sorted((R/'小样STEP').glob('*.step')):
 r=STEPControl_Reader();r.ReadFile(str(p));r.TransferRoots();s=r.OneShape();shapes[p.stem]=s;n=0;it=TopExp_Explorer(s,TopAbs_SOLID)
 while it.More():
  n+=1;shapes[p.stem]=TopoDS.Solid_s(it.Current());it.Next()
 rows.append({'code':p.stem,'valid':BRepCheck_Analyzer(s).IsValid(),'solids':n,'volume_mm3':vol(s)})
assert all(q['valid'] and q['solids']==1 for q in rows)
comparisons=[]
for small,big,shift in [('CT01','P02',(0,0,-194.5)),('CT02','P03_RB',(-65,0,-194.5))]:
 t=gp_Trsf();t.SetTranslation(gp_Vec(*shift));a=BRepBuilderAPI_Transform(shapes[big],t,True).Shape();clip=BRepPrimAPI_MakeBox(gp_Pnt(-37,0,-20),43,100,120).Shape();a=BRepAlgoAPI_Common(a,clip).Shape();b=shapes[small]
 aa=Bnd_Box();bb=Bnd_Box();BRepBndLib.Add_s(a,aa);BRepBndLib.Add_s(b,bb);print(small,aa.Get(),bb.Get())
 print('Volumes',vol(a),vol(b),vol(BRepAlgoAPI_Common(a,b).Shape()))
 delta=0
 for l,r in [(a,b),(b,a)]:
  cut=BRepAlgoAPI_Cut(l,r);cut.SetFuzzyValue(.00001);cut.Build();assert cut.IsDone();delta+=abs(vol(cut.Shape()))
 comparisons.append({'coupon':small,'source':big,'boolean_fuzzy_mm':.00001,'symmetric_difference_mm3':delta,'matches_cropped_interface':delta<.001})
(R/'evidence/ocp_coincident_boolean_diagnostic.json').write_text(json.dumps({'status':'INCONCLUSIVE_KERNEL_DIAGNOSTIC_NOT_USED','comparisons':comparisons},indent=2),encoding='utf8')
(R/'evidence/step_verification.json').write_text(json.dumps({'parts':rows,'interface_check_authority':'native_interface_comparison.json','external_coincident_boolean_status':'INCONCLUSIVE_KERNEL_DIAGNOSTIC_NOT_USED'},indent=2),encoding='utf8')
print({'solids_valid':len(rows),'interface_check':'See independent native_interface_comparison.json'})
