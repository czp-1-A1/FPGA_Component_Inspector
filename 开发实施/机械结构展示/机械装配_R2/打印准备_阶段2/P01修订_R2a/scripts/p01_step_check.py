import sys,json
from pathlib import Path
sys.path.insert(0,r'E:\2026FPGA\FPGA_Component_Inspector\开发实施\机械结构展示\.cad_runtime')
from OCP.STEPControl import STEPControl_Reader
from OCP.BRepCheck import BRepCheck_Analyzer
from OCP.TopExp import TopExp_Explorer
from OCP.TopAbs import TopAbs_SOLID
R=Path(r'E:\2026FPGA\FPGA_Component_Inspector\开发实施\机械结构展示\机械装配_R2\打印准备_阶段2\P01修订_R2a');out=[]
for p,n_expected in [(R/'零件STEP/P01.step',1),(R/'FPGA_Inspector_R2a_Assembly.step',324)]:
 reader=STEPControl_Reader();reader.ReadFile(str(p));reader.TransferRoots();s=reader.OneShape();valid=BRepCheck_Analyzer(s).IsValid();n=0;ex=TopExp_Explorer(s,TopAbs_SOLID)
 while ex.More():n+=1;ex.Next()
 assert valid and n==n_expected;out.append({'file':p.name,'valid':valid,'solids':n})
(R/'evidence/step_readback.json').write_text(json.dumps(out,indent=2),encoding='utf8');print(out)
