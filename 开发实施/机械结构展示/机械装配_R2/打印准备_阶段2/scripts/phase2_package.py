from pathlib import Path
import json,hashlib,zipfile,shutil
R=Path(r'E:\2026FPGA\FPGA_Component_Inspector\开发实施\机械结构展示\机械装配_R2\打印准备_阶段2')
first=['HT01','CT01','CT02','CT03','P06A','P06B']
# Preserve the external-kernel diagnostic, use native evidence for coincident interfaces.
p=R/'evidence/step_verification.json';data=json.loads(p.read_text());diag=R/'evidence/ocp_coincident_boolean_diagnostic.json'
if 'coupon_interface_comparison' in data:
 diag.write_text(json.dumps(data,indent=2),encoding='utf8')
 data={'parts':data['parts'],'interface_check_authority':'native_interface_comparison.json','external_coincident_boolean_status':'INCONCLUSIVE_KERNEL_DIAGNOSTIC_NOT_USED'}
 p.write_text(json.dumps(data,indent=2),encoding='utf8')
assert all(q['valid'] and q['solids']==1 for q in data['parts'])
assert all(q['matching'] for q in json.loads((R/'evidence/native_interface_comparison.json').read_text()))
assert all(q['within_assumed_200_cube'] for q in json.loads((R/'evidence/toolpath_audit.json').read_text()))
for p in Path('scripts').glob('phase2_*.py'):shutil.copy2(p,R/'scripts'/p.name)
shutil.copy2(Path('scripts/r2_direct_mcp.py'),R/'scripts/r2_direct_mcp.py')
readme='''R2 第二阶段交付 / 试制方案

先阅读 R2_切片与小样检查报告.html。
首批包只有6个STL，均为毫米、已按推荐方向放置，导入切片器后不要自动缩放。
顺序：HT01孔槽 → CT01/02/03承托防脱配合 → P06A/B完整灯圈试配。
合计122.12 g PETG（通用配置离线估算），含15%试错备料约140 g。
配置INI是估算基准，未匹配实际打印机；请换成自己的设备配置再切片。
不提供可直接发给打印机的G-code。

CT02顶面朝下，CT01/CT03/HT01/P06A/B底面朝下；CT01开支撑，其余首轮无支撑。
CT小样需M4×65两根；灯圈需M4×35两根，共M4螺母4个、平垫8片。
准备0.5 mm软垫/软衬和模拟上下亚克力叠层；实际尺寸应记录。
小样不能替代四点装配、薄亚克力挠曲、灯壳夹持/线口/温升和光学验证。

整套打印暂缓：关键小样未实測通过；P01槽端1 mm余量尚待修订。
报告中的有效行程限制继续有效，40 mm目标端未通过。
原生整机及R1不变。图纸与STL为本次默认参数快照，参数改变须重导出。
'''
(R/'开始阅读.txt').write_text(readme,encoding='utf8')
common=[R/n for n in ['开始阅读.txt','R2_切片与小样检查报告.html','R2_切片与小样检查报告.md','逐件切片用料估算.csv','小样实测记录表.csv','通用PETG_仅预估.ini']]
small=common+[R/'R2_关键配合小样.f3d']
for c in first:
 small += [R/'首批小样_STL_毫米_已定向'/(c+'.stl'),R/('小样STEP' if c.startswith(('CT','HT')) else '零件STEP')/(c+'.step'),R/'逐件工程图_试制'/(c+'.pdf')]
small+=list((R/'切片预览').glob('*.png'))+[R/'小样视图/小样组合.png']
full=common+list((R/'零件STEP').glob('*.step'))+list((R/'小样STEP').glob('*.step'))+list((R/'逐件工程图_试制').glob('*.pdf'))+[R/'木板下料清单.csv',R/'紧固件清单_名义待实配.csv',R/'R2_关键配合小样.f3d']
for name,files in [('R2_首批关键小样优先包.zip',small),('R2_逐件STEP工程图与清单.zip',full)]:
 with zipfile.ZipFile(R/name,'w',zipfile.ZIP_DEFLATED) as z:
  for p in files:assert p.is_file();z.write(p,str(p.relative_to(R)))
  if name.startswith('R2_逐件'):
   for n in ['FPGA_Inspector_R2_Prototype.f3d','FPGA_Inspector_R2_Assembly.step']:z.write(R.parent/n,'已确认整体/'+n)
 with zipfile.ZipFile(R/name) as z:assert z.testzip() is None;assert not any(n.endswith('.gcode') for n in z.namelist())
manifest=[]
for p in sorted(set(small+full+[R/'R2_首批关键小样优先包.zip',R/'R2_逐件STEP工程图与清单.zip'])):
 manifest.append({'file':str(p.relative_to(R)),'bytes':p.stat().st_size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()})
(R/'阶段2文件校验.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf8')
print({'deliverable_files':len(manifest),'archives':[(p.name,p.stat().st_size) for p in R.glob('*.zip')]})
