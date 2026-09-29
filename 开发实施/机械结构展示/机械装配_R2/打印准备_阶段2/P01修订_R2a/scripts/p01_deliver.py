from pathlib import Path
import sys,json,csv,shutil,hashlib,zipfile
sys.path.insert(0,r'E:\fusion360_codex_skill\.tools\python_deps')
import markdown
S=Path(r'E:\2026FPGA\FPGA_Component_Inspector\开发实施\机械结构展示\机械装配_R2\打印准备_阶段2');R=S/'P01修订_R2a';H=S/'首件HT01_仅此件试打准备';H.mkdir(exist_ok=True)
q=json.loads((R/'evidence/slice_results.json').read_text())[0];checks=json.loads((R/'evidence/local_fit_checks.json').read_text());geom=json.loads((R/'evidence/geometry_check.json').read_text());access=json.loads((R/'evidence/access_checks.json').read_text());archive=json.loads((R/'evidence/native_archive_check.json').read_text());old=json.loads((S/'evidence/slice_results.json').read_text());ht=next(q for q in old if q['code']=='HT01')
assert not geom['clashes_mm3'] and not geom['health'] and not geom['boolean_failures']
assert all(not x['clashes'] for x in access)
assert abs(archive['pad_mount_slot_l_mm']-56)<1e-6 and archive['two_shared_arms'] and not archive['feature_errors']
assert all(x['within_assumed_200_cube'] for x in json.loads((R/'evidence/toolpath_audit.json').read_text()))
report=f'''# P01 R2a 槽端修订及打印顺序更新

2026-09-11 / 试制方案。当前仅HT01进入试打准备；CT01+CT02+CT03等待HT01结果，之后再试P06A+B。整套打印继续暂缓。本说明优先于旧“六件首批包”的排产描述，旧包保留作历史记录，不应一次全部打印。

## 模型改动

在旧R2原生档的独立副本上新增用户参数 `pad_mount_slot_l=56 mm`，修改P01两条承托安装槽的8个关联尺寸表达式。槽宽4.5、中心Y=±49、孔组位置、两根托臂X=±65以及其余零件不改。

两托臂继续共享同一零件定义。旧R2、旧P01 STEP/PDF/STL和旧切片记录未覆盖。新版整体原生档、整体STEP、P01 STEP、独立PDF及重新切片证据位于本目录。

|校核项|旧60槽|新56槽|
|---|---:|---:|
|前槽实体范围Y|−79..−19|−77..−21|
|后槽实体范围Y|19..79|21..77|
|臂前缘Y=-80处槽端实体余量|1|3|
|单螺杆槽内有效位移（扣4.5及两端各1）|53.5|49.5|
|双螺杆组有效位移（再扣中心距12）|41.5|37.5|
|前后孔组共同平移的槽约束交集|±9.75|±7.75|

这些尺寸是CAD名义值；3 mm端部和4.5 mm槽宽还需计入打印偏差，不能由本次几何检查推断承载安全。

## 双螺栓与调节范围

默认后组螺栓中心Y=54/66，前组=-66/-54，每组中心距12。新的槽边至螺杆中心需至少3.25（半校核直径2.25+端余量1）。

- 后组相对默认位置可平移 **−29.75..+7.75**；前组为 **−7.75..+29.75**。默认螺杆中心至近侧允许极限还有7.75。
- 37.5是每个双螺栓组在单条槽中的几何位移，不是两螺栓分别各享一条49.5行程。
- 若前后承托组共同平移，槽条件交集是±7.75；这仍只是槽条件。板卡对中、四向总定位间隙1.0及最不利承托面同时保留时，默认安装孔组仍为Y=±54/±66，**不开放新增前后工作移动行程**。不能把承托块推至槽端仍宣称板卡、镜头和灯心对中。
- 未将单独P01的槽端检查宣称为整机在这些承托块位置的无碰撞范围。CT03仍是60槽的独立10厚试装垫座，用于螺栓和承托防脱接口试配，不用于验证R2a槽端余量或P01有效行程。

## 垫片、螺母和装入路径

采用原设计M4、Ø9×Ø4.5×0.8平垫和12 mm双螺杆距；P01臂宽24，槽宽4.5，筋内侧X=±8。

1. 在前后槽默认位置及各自两端位置，共12个螺杆位置上，通过原生临时实体求交检查Ø4螺杆沿Z的穿入通道，以及P01下方Ø12套筒通道；均无实体干涉。12 mm为假设套筒外径，不是实购物料保证。
2. Ø9平垫跨槽两侧，最小实体接触面积 **{checks['minimum_washer_annular_area_mm2']:.2f} mm²**，来自0.05 mm薄层与实体相交体积换算。该面积小于完整垫圈环形面积，不能把槽上方悬空部分算成承托。直段两侧各有2.25 mm横向接触带。
3. 最前端允许螺杆中心Y=-73.75，Ø9垫片外缘距臂前缘仍1.75；默认最前螺杆Y=-66时为9.5。筋内侧至Ø12套筒外缘名义侧隙2。相邻螺杆距12，套筒Ø12与邻近Ø9垫片名义平面间隙1.5；工具应逐个操作。
4. 推荐先固定托臂、摆好P02并确认孔位；板卡垂直放入后最后安装P03防脱片。螺杆从上方插入，平垫及螺母由下方开放区域装入，套筒从下方进入。螺母不需要从槽端塞入，槽缩短没有封闭新的装入通道。板外硬支脚承担锁紧力。
5. 整机默认位置另外检查了{len(access)}个操作/插入包络，包括8条新增Ø4贯穿插入包络、上方工具及下方Ø12工具，均未发现干涉。配合螺杆本身从工具检查中排除，避免把工具套住螺母的预期接触误报。

需实物检查：实际螺杆长度、螺纹露出、垫片弯曲、工具外径、PETG压溃/开裂和反复锁紧。模型面积与无干涉不等于紧固连接强度验证。

## 保持的相机与灯有效行程

相机根部微调槽仍为28×4.5，单螺杆有效21.5，20分档交叠1.5。灯竖向双螺杆有效117.5，前后双螺杆有效29.5（±14.75）。本次没有修改这些槽。

继续保留原报告：D=50..200；H=10..97；对中Y=0时D≥H+38；灯前后全范围并留2 mm裕量要求D≥H+42。默认D100/H60时向后建议Y≤10。D40/H10碰撞，40 mm目标端不开放。光学合焦、实物刚度与温升待验证。本轮没有将P01局部极限测试冒充重新完成全部整机姿态验证。

## 模型及切片核验

新整体档重新打开后：时间线{archive['timeline']}、参数{archive['parameters']}、P01草图全约束、两托臂仍在±65并共享定义，特征错误0。整机324实体，默认装配522对候选检查，干涉0、布尔失败0。

使用与旧版相同PrusaSlicer 2.9.6、PETG0.4喷嘴/0.2层高、4壁、25%填充、侧面+X朝下、4 mm Brim及自动支撑重新切片。包络50×190×52；实际挤出路径含支撑/附着边仍在200立方假设平台内。

|记录|旧版/件|R2a/件|
|---|---:|---:|
|含支撑与附着边耗料|68.42 g|{q['stats']['filament used [g]']} g|
|无支撑对照耗料|57.70 g|{q['no_support_stats']['filament used [g]']} g|
|切片预计时间|5h 40m 22s|{q['stats']['estimated printing time (normal mode)']}|

R2a两件按当前配置约137.20 g，仅预算。打印机和材料牌号未确定，不能直接使用证据G-code；P01 STL只作为切片复核数据，不在本次HT01首件打印包里。

## 首件HT01

仅提供HT01一个STL、STEP、图纸和测量记录表。保持原模型孔槽不补偿，底面朝下、无支撑，以便测量六竖孔/三槽/横孔实际结果。当前离线估算 **{ht['stats']['filament used [g]']} g**，{ht['stats']['estimated printing time (normal mode)']}；建议备料约28 g（含约15%试错余量），不是实测用量。

记录打印机、喷嘴、PETG、层高和配置；冷却后测孔/槽及实际螺杆，记录能否自由通过、毛刺、横孔下垂和首层外扩。首次试验不要先钻孔再填“直接穿过”。有轻修结果应另列。

HT01通过后再依据实际偏差决定CT和灯圈孔槽补偿；优先修正孔/槽局部尺寸或切片补偿，不整体缩放模型。竖孔、横孔和不同打印方向不可自动共用补偿。若需要补偿，重新检查垫片接触、孔边余量、硬限位间隙和新切片。CT通过后才进入灯圈试配，灯圈仍须检查夹持、线口与遮光，不一次打印六件。
'''
(R/'P01_R2a修订复核报告.md').write_text(report,encoding='utf8')
(R/'P01_R2a修订复核报告.html').write_text('<!doctype html><meta charset="utf-8"><style>body{font:16px/1.7 "Microsoft YaHei",sans-serif;max-width:1080px;margin:30px auto;color:#233544}table{border-collapse:collapse}td,th{border:1px solid #bbb;padding:8px}strong{color:#903820}</style>'+markdown.markdown(report,extensions=['tables']),encoding='utf8')
for p in [S/'首批小样_STL_毫米_已定向/HT01.stl',S/'小样STEP/HT01.step',S/'逐件工程图_试制/HT01.pdf',S/'通用PETG_仅预估.ini']:shutil.copy2(p,H/p.name)
readme='''当前只打印HT01一件；不要使用旧六件包同时排版。
STL单位毫米，底面朝下，保持100%尺寸，不加支撑，先不做孔槽补偿。
通用INI仅用于复现估算；打印前选择实际设备配置，检查平台及温度/材料参数。
耗料估算23.90g，建议备约28g。本包没有可直接发给机器的G-code，也没有下发打印任务。
冷却后填写实测记录表；先记录未修孔的螺杆通过性，修孔结果单列。
HT01结果出来后再决定CT01/02/03的孔槽补偿；CT通过后再试P06A/B。
整套打印继续暂缓。P01结构修订见相邻P01修订_R2a目录，不代表P01已实物验收。
'''
(H/'先读_仅HT01.txt').write_text(readme,encoding='utf8')
rows=[]
for i,v in enumerate([4,4.2,4.4,4.5,4.6,4.8]):rows.append([f'竖孔{i+1}',f'({10+i*12},10)',v,'','','','',''])
for x,y,w in [(20,26,4.2),(60,26,4.5),(20,44,4.8)]:rows.append(['槽',f'({x},{y})',f'宽{w}/总长28','','','','',''])
rows.append(['横孔','轴Y; X60,Z11',4.5,'','','','',''])
with (H/'HT01实测记录.csv').open('w',encoding='utf-8-sig',newline='') as f:
 w=csv.writer(f);w.writerow(['对象','原生坐标mm','名义尺寸mm','实测孔径/槽宽','实测槽总长','未修孔螺杆是否自由穿过','轻修后结果(另列)','毛刺/下垂/首层外扩']);w.writerows(rows)
(H/'打印条件记录.txt').write_text('打印机：\n喷嘴直径：\n材料品牌/牌号：\n层高：\n孔槽/象脚补偿设置：\n实际螺杆直径：\n温度与风扇：\n测量工具：\n日期：\n',encoding='utf8')
notice='当前排产：仅HT01 → 依据结果补偿并试CT01+CT02+CT03 → CT通过后试P06A+B。整套打印暂停。\n旧六件首批包保留历史，不按六件一起打印。最新P01为P01修订_R2a；旧R2文件未覆盖。\n'
(S/'00_当前打印顺序_仅HT01.txt').write_text(notice,encoding='utf8')
pres=[]
for manifest,base in [(S.parent/'交付文件校验.json',S.parent),(S/'阶段2文件校验.json',S)]:
 for item in json.loads(manifest.read_text(encoding='utf8')):
  p=base/item['file'];pres.append({'path':str(p),'unchanged':hashlib.sha256(p.read_bytes()).hexdigest()==item['sha256']})
assert all(p['unchanged'] for p in pres)
(R/'evidence/old_files_preserved.json').write_text(json.dumps(pres,ensure_ascii=False,indent=2),encoding='utf8')
for p in Path('scripts').glob('p01_*.py'):shutil.copy2(p,R/'scripts'/p.name)
for target,folder,include in [('HT01_仅首件试打准备.zip',H,list(H.iterdir())),('P01_R2a修订模型图纸及复核.zip',R,[R/'FPGA_Inspector_R2a_Parametric.f3d',R/'FPGA_Inspector_R2a_Assembly.step',R/'零件STEP/P01.step',R/'逐件工程图_试制/P01.pdf',R/'P01_R2a修订复核报告.md',R/'P01_R2a修订复核报告.html',R/'R2a_整体.png']+list((R/'evidence').glob('*.json'))+list((R/'切片预览').glob('*.png')))]:
  with zipfile.ZipFile(S/target,'w',zipfile.ZIP_DEFLATED) as z:
   for p in include:
    if p.is_file():z.write(p,str(p.relative_to(folder)))
  with zipfile.ZipFile(S/target) as z:assert z.testzip() is None
manifest=[]
for p in [S/'HT01_仅首件试打准备.zip',S/'P01_R2a修订模型图纸及复核.zip']:
 manifest.append({'file':p.name,'bytes':p.stat().st_size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()})
(R/'交付校验.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf8');print(manifest)
