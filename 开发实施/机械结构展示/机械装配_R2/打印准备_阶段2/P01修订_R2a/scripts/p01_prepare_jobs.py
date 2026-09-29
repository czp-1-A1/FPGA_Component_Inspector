from pathlib import Path
import shutil
S=Path(r'E:\2026FPGA\FPGA_Component_Inspector\开发实施\机械结构展示\机械装配_R2\打印准备_阶段2');R=S/'P01修订_R2a';orig=S.parent/'scripts'
old=str(S);new=str(R)
for src,dest in [(S/'scripts/03_orient_meshes.py','mesh.py'),(S/'scripts/04_slice_all.py','slice.py'),(Path('scripts/phase2_drawings.py'),'drawings.py')]:
 t=src.read_text(encoding='utf8').replace(old,new)
 if dest=='drawings.py':
  t=t.replace('暂缓整件打印：前端槽端实体仅 1 mm，需修订后重查。','R2a：安装槽总长56；前端实体余量3；整套打印仍暂缓。').replace('承托槽：总长 60','承托槽：总长 56')
 (R/'scripts'/dest).write_text(t,encoding='utf8')
for src,dest in [(orig/'11_geometry_check.py','geometry.py'),(orig/'21_access_check.py','access.py')]:
 t=src.read_text(encoding='utf8').replace('d=adsk.fusion.Design.cast(adsk.core.Application.get().activeProduct)',"d=adsk.fusion.Design.cast(next(doc for doc in adsk.core.Application.get().documents if doc.name=='FPGA_Inspector_R2a_P01_Slot56_Trial').products.itemByProductType('DesignProductType'))")
 t=t.replace(str(S.parent).replace('\\','/'),str(R).replace('\\','/'))
 if dest=='access.py':
  t=t.replace("(x,y,164.5),(x,y,184.5),5","(x,y,149.5),(x,y,184.5),6")
  t=t.replace("pad_bottom_socket_D10_","pad_bottom_socket_D12_")
  t=t.replace("   tests.append(('pad_top_tool_D10_", "   tests.append(('pad_shank_insertion_D4_'+str((x,y)),cyl((x,y,174.5),(x,y,310),2),('H_CAM_PAD',)))\n   tests.append(('pad_top_tool_D10_")
 (R/'scripts'/dest).write_text(t,encoding='utf8')
t=Path('scripts/phase2_extract.py').read_text(encoding='utf8').replace(str(S).replace('\\','/'),str(R).replace('\\','/'))
(R/'scripts/extract.py').write_text(t,encoding='utf8')
shutil.copy2(S/'通用PETG_仅预估.ini',R/'通用PETG_仅预估.ini')
print(str(R))
