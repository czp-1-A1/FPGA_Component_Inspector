from pathlib import Path
import json,csv,html,shutil,zipfile,hashlib,collections,re
import sys
sys.path.insert(0,r'E:\fusion360_codex_skill\.tools\python_deps')
R=Path(r'E:\2026FPGA\FPGA_Component_Inspector\开发实施\机械结构展示\机械装配_R2\打印准备_阶段2')
results={q['code']:q for q in json.loads((R/'evidence/slice_results.json').read_text())};meshes={q['code']:q for q in json.loads((R/'evidence/mesh_orientation.json').read_text())};parts={q['code']:q for q in json.loads((R/'evidence/part_exports.json').read_text())}
coupons={q['code']:q for q in json.loads((R/'evidence/coupons.json').read_text())};parts.update(coupons)
audit={q['code']:q for q in json.loads((R/'evidence/toolpath_audit.json').read_text())}
first=['HT01','CT01','CT02','CT03','P06A','P06B'];orient={c:('顶面朝下' if c.startswith('P03') or c=='CT02' else '侧面+X朝下' if c in ['P01','P05'] else '正面-Y朝下' if c=='P04' else '原生底面-Z朝下') for c in results}
rows=[]
for c,q in results.items():
 m=meshes[c];g=float(q['stats']['filament used [g]']);support=round(g-float(q.get('no_support_stats',{}).get('filament used [g]',g)),2)
 rows.append([c,parts[c]['qty'],orient[c],'×'.join(f'{v:.1f}' for v in m['print_size_mm']),'自动支撑/开放处清理' if q['support_enabled'] else '无支撑/桥接须试验',q['brim_mm'],g,support,q['stats']['estimated printing time (normal mode)'],'路径未超200³' if audit[c]['within_assumed_200_cube'] else '超界','仅小样试制' if c in first else '暂缓整套打印'])
def csvout(name,header,rs):
 with (R/name).open('w',encoding='utf-8-sig',newline='') as f:w=csv.writer(f);w.writerow(header);w.writerows(rs)
csvout('逐件切片用料估算.csv',['零件','整机数量或小样数量','打印朝向','本体打印包络mm','支撑','Brim毫米','每件克含支撑附着边','相较无支撑净增克','切片软件预计时间','路径范围','状态'],rows)
inventory=json.loads((R/'evidence/hardware_inventory.json').read_text());bolts=collections.Counter();nuts=washers=0
for n,qty in inventory.items():
 if 'Bolt_M4x' in n:bolts[('外六角' if 'HexHead' in n else '内六角圆柱头')+' M4×'+n.rsplit('M4x',1)[1]]+=qty
 if 'Countersunk_M4x20' in n:bolts['90°沉头 M4×20']+=qty
 if '_Nut_M4' in n:nuts+=qty
 if '_Washer_' in n: washers+=qty
bom=[[n,q,'名义尺寸；实购头部/有效螺纹核实'] for n,q in sorted(bolts.items())]+[['M4螺母，AF7，模型厚3.2',nuts,'普通螺母；防松措施试装后确定'],['M4平垫，内径4.5×外径9×厚0.8',washers,'托料板沉头顶面不加垫片'],['25×25×25×2 普通角码',18,'现货孔位核实后再钻木板'],['20×20×8底部防滑垫',4,'粘贴/固定方式待选型']]
csvout('紧固件清单_名义待实配.csv',['规格','数量','备注'],bom)
wood=[['W01','650×400×12',1,'结构孔10个；设备固定孔待定位'],['W02','300×360×12',1,'相机40孔、灯导板4孔、角码6孔，共50孔'],['W03','直角边120/200，厚12',2,'每件4个角码孔'],['W04','100×100×12',2,'每件2个通孔及90度沉孔；左件旋转180度安装'],['W05','12×80×68（高度暂定）',4,'每件2孔；按实测带面改高度及上孔']]
csvout('木板下料清单.csv',['编号','尺寸mm','数量','备注'],wood)
def table(headers,rs):return '| '+' | '.join(headers)+' |\n| '+' | '.join(['---']*len(headers))+' |\n'+'\n'.join('| '+' | '.join(str(x) for x in row)+' |' for row in rs)+'\n'
gfirst=sum(float(results[c]['stats']['filament used [g]']) for c in first);gfull=sum(float(q['stats']['filament used [g]'])*parts[c]['qty'] for c,q in results.items() if c.startswith('P'))
report=f'''# R2 第二阶段：切片可行性与关键小样交付

日期：2026-09-11。状态：试制方案；关键小样可进入试打准备，整套打印暂缓。R1与确认布局时的R2原生文件均保留。

## 本次实做与边界

- 已用 PrusaSlicer 2.9.6 对12种整机打印件及4种小样进行了实际离线切片。P03四角、P07左右为独立编号。16种网格均封闭，STEP读回通过实体有效性检查。
- 关键小样原生档重新导入Fusion：4独立实体、11用户参数、103时间线条目、33个完全约束草图，未发现特征错误。
- 在Fusion原生临时实体中，将P02及P03_RB移至小样坐标并裁切，与CT01/CT02求交；对称体积差绝对值均小于0.001 mm³，局部接口一致。外部内核对完全重合面的布尔结果出现异常，未采用该结果作为接口验收依据；原生验证记录另附。
- 逐件STEP共24份（含软垫/软衬和4种小样）；每种均有独立PDF，另附合订本。图纸由真实STEP隐藏线投影生成，含外形、孔槽及原生草图坐标，不是Fusion原生关联Drawing文档。参数改变后须重新导出图纸。
- 逐件图纸采用各视图标注的示意比例，不能按纸上比例量取尺寸；三视图位置按第三角布置。坐标是各组件原生建模坐标，安装位移另计。
- **P01整件暂缓：前侧60长槽最前端Y=-79，臂前缘Y=-80，只剩1 mm实体。建议下一修订将该承托槽缩至56以保留3 mm，复核垫片及装入路径后再放行。本次未悄然更改已确认整机。**这不是28 mm高度微调槽，不改变本报告已有高度行程。
- 16种零件连同实际生成的支撑/附着边挤出路径均在假设200×200×200范围内；不代表实机夹具、探针禁区或起始擦嘴动作已检查。
- 没有连接打印机，没有下发打印任务。evidence中的G-code仅为估算证据；首批包不含G-code。请在自己的打印机配置中导入毫米STL重新切片，确认平台与设备设置后使用。

## 切片基准（全部为预估假设）

200立方平台；0.4喷嘴；1.75 PETG，密度1.27 g/cm³；0.20层高；4圈壁；顶部/底部各5层；25% gyroid填充；0.45线宽。Brim一般3，P01为4。支撑阈值45°、snug，Z间隔0.25、XY间隔0.35，两层接触层。速度、加速度等见同目录INI。

估算配置使用喷嘴240°C、热床80°C、风扇30–60%；这是可复算的通用配置，尚未匹配用户打印机及PETG牌号。时间不是实机工时。材料含支撑和附着边，不含试错、换料和实际起始清料。

首批6件共 **{gfirst:.2f} g**，留15%试错备料约 **{gfirst*1.15:.0f} g**。全套18个PETG实体按当前方向逐件累计约 **{gfull:.2f} g**（仅预算，未放行）。软衬/软垫及木板不计入PETG。

## 逐件方向、支撑及用料

{table(['编号','数量','方向','本体包络mm','支撑','Brim','g/件','支撑净增g','预计时间','路径','状态'],rows)}
支撑净增为同配置有/无支撑两次切片的耗料差，包含与支撑相关的路径变化，不是称量值。层间强度未验证。

## 逐件工艺审查

- P01：侧面+X朝下，根部比臂宽，长臂底离床14 mm，因此需要长条支撑。4 mm Brim后190长本体仍可容纳；打印层沿侧向堆叠不能视为强度验证。1 mm槽端余量问题使其仍处于暂缓状态。
- P02 / CT01：底面朝下，承托面向上；上部Y止挡有2 mm伸出，使用支撑。支撑从开放前侧取出，不能把1.5 mm高止挡掰掉；止挡接触面毛刺应轻修并重新量间隙，不能靠打磨消除设计错误。
- P03 / CT02：顶面朝下，X止挡向上打印；两螺孔竖直，不需支撑。0.5 mm防抬间隙和亚克力接触面需实物量测。四个整机压片不可混用。
- P04：正面-Y朝下，两垫高脚朝上，180长方向在平台内；背面12 mm通道开放，先穿根部螺钉再固定导板。孔轴在打印Z方向。
- P05：侧放；上筋之间及根部台阶允许自动支撑，支撑可从侧面清除。孔槽及双螺栓垫片支承面清理后试装。
- P06A/B：底面朝下，以完整两半作为试配件。本轮不加支撑以检查16 mm窗口桥接和水平4.5孔；若窗口塌陷或孔内挂丝不合格，可在切片软件局部加可拆支撑重试。不要把自动切片成功当成桥接合格。
- P07L/R：平放，槽孔竖直，无支撑；避让口开通。连接短槽要容纳夹圈收紧，不能把桥板当作增加灯壳夹紧力的工具。
- CT03：平放，仅验证承托块与10 mm厚槽段/螺杆配合，不验证P01整臂、加强筋、最前端槽唇或承载。
- HT01：平放且不加支撑；六个竖孔、三种槽宽及一个横孔区分测试。保留原始测量，不先钻通再声称打印配合合格。

## 首批小样与装配试配

建议先HT01，再CT01+CT02+CT03，最后P06A+P06B。每一组通过后再推进下一组；灯圈合格前不整套打印。

### HT01 孔槽试片

80×60×6，左下3×3缺口为原点。X=10,22,34,46,58,70 / Y=10的孔依次直径4.0,4.2,4.4,4.5,4.6,4.8。三槽总长28：中心(20,26)宽4.2、(60,26)宽4.5、(20,44)宽4.8。横孔直径4.5沿Y，中心X60,Z11。

记录各实际孔径、槽宽、槽长、M4螺杆是否自由穿过、横孔顶部下垂、首层外扩。以实际螺杆和卡尺/量规检查，未经试片结果不要全局修改孔补偿。

### CT01 / CT02 / CT03 右后承托防脱小样

需2根M4×65、2个M4螺母、4片上述平垫；0.5 mm软垫一片；模拟上下亚克力与中间硬间隔，总高度30 mm。下/上亚克力各1 mm的假设意味着中间间隔28 mm。夹紧力路径是压片→板外硬支脚→底座→槽段，不能经过板卡叠层。

1. 将CT01放在CT03槽段上，两个孔对槽；放好0.5软垫。用稳定的亚克力角部模拟件和间隔块，禁止把整块FPGA只托在这一处小样上。
2. 垂直放入亚克力试件，最后装CT02；两M4×65贯穿并用垫片螺母锁住硬支脚，不靠继续拧螺钉消除防抬间隙。
3. CT01坐标下，板右边应在X=-20附近，板后边Y=45附近；检查右侧X挡内面-19.5、后侧Y挡内面45.5。上板最高面40.5、防脱底41，名义0.5间隙。
4. 用塞尺检查0.5防抬间隙，并检查最大允许抬起时X/Y止挡仍与上亚克力边缘重叠。量取实际厚度后记录偏差。
5. 本组仅验证右后局部+X/+Y接口；不能独立证明整机±X/±Y总间隙1.0。四点装配时另做四极限角及最大抬起试验。

默认右侧几何承托17×19；最不利误差沿两轴分别扣5，保留12×14=168 mm²。5 mm由板边内缩0.5、定位变化1、托臂误差1、打印偏差1、软垫贴放1.5组成。左侧名义57×19，预算后52×14。实际检验取亚克力、实体面、软垫三者交集；孔槽/倒角/缺口不能算承托区域。改变偏心、板尺寸或限位参数必须重算；小样不证明1 mm亚克力挠曲或总承重安全。

### P06A / P06B 灯圈试配

需2根M4×35、2螺母、4平垫，0.5 mm软衬；灯圈由完整成品几何导出。先空装螺钉检查穿入/退出及工具可达，再贴软衬，围合灯壳并交替轻紧两侧。

初始总缝2，几何闭合限位总缝1。若触及限位仍滑动，停止并修改衬垫/夹圈；不得继续过量挤压灯壳。限位不能证明壳体受力安全。此夹持方案没有已验证的失效承托，初次检查应在低高度软垫上进行，避免灯滑落。

必须实物记录：连续夹持接触、轻载自重防滑、夹持后灯壳是否变形、螺钉工具空间、实际线口位置与窗口对应、线缆弯曲、发光面/内孔遮挡、调焦手指空间、通电工作温升。未知安装面的4个M3孔仍不使用。灯不靠镜头承重。未完成的各项标“待验证”，不能用CAD无干涉代替。

## 有效行程保持

统一槽算法：槽总长−校核直径4.5−双螺栓中心距−两端各1余量。

|项目|槽几何允许|整机工作限制|
|---|---|---|
|相机短槽28，单螺杆|21.5；20分档交叠1.5|推荐拍摄距离D=50..200，须同时满足下列组合条件|
|灯竖槽140，双距16|117.5|保守灯发光面距检测面H=10..97|
|灯前后槽72，双距36|29.5，即±14.75|全前后范围并保留2 mm裕量要求D≥H+42|
|相机与灯对中Y=0|几何组合限制|D≥H+38；40 mm目标端未通过，D40/H10碰撞|

默认D100/H60：灯对中满足上述限制；前后全行程不满足2 mm裕量条件，向后建议Y≤10。灯前后调节用于装配/避让，偏离Y0时灯心不与检测点同轴，检测前复位对中。H<30人工取放受限，低位时先升灯再取样。40–200为机械目标，不保证光学合焦；本次没有扩大原报告工作范围。

## 木板与紧固件

{table(['编号','下料mm','数量','说明'],wood)}
木板逐件PDF附圆孔坐标。W01仅结构孔，设备孔继续待实物定位。W02和W03的上加强板角码连接Z=110。现货角码的2孔位置未确认，先用实物角码核孔位。托料板应水平进入/离开设备，名义机端间隙2须结合实际载带验证，不设计未知轮廓贴合导向件。

{table(['规格','数量','说明'],bom)}
合计{sum(bolts.values())}根螺钉、{nuts}个螺母、{washers}片垫片。未加采购备件。板卡叠层从30变35时，原M4×65可能不足，须重算有效伸出，预计改70并核实。灯导板背面根部使用外六角头以便7 mm开口扳手侧向进入；所有实购头部、螺纹长度、垫片实际厚度均需核对。

## 后续装配顺序与放行条件

关键小样→实测板卡叠层/镜头突出/带面高/灯线口→修订P01槽端并重新切片及校核→逐件打印→木板按实购角码定位钻孔→组装底板、立板、加强板→预装P04背槽根部螺钉再固定P04→装对称P01和四个P02→放板卡并装四个P03→独立安装灯臂、连接板与灯圈→调高/对中→手动带样通过两端托料板→低速启停观察位移。

全套打印放行前必须：关键小样记录通过、P01修订复核、四点限位与承托交集复查、亚克力不被压弯、灯圈夹持实测、实机切片配置确认。承载、长时间运行、光学和温升另行验证；不存在工业验收结论。

## 文件与证据

`首批小样_STL_毫米_已定向`仅含上述6件。`小样STEP`含4新小样；灯圈STEP在`零件STEP`。`R2_关键配合小样.f3d`保存用户参数和特征历史。`逐件工程图_试制`有独立PDF与合订本；`evidence`保留切片日志、参数、路径边界、实体和原生档检查结果。

软件来源：[PrusaSlicer 2.9.6官方发布](https://github.com/prusa3d/PrusaSlicer/releases/tag/version_2.9.6)、[官方命令行说明](https://github.com/prusa3d/PrusaSlicer/wiki/Command-Line-Interface)。用量来自本机实际切片输出，非网页估计。
'''
(R/'R2_切片与小样检查报告.md').write_text(report,encoding='utf8')
try:
 import markdown
 body=markdown.markdown(report,extensions=['tables','fenced_code'])
except ImportError:
 body='<pre>'+html.escape(report)+'</pre>'
(R/'R2_切片与小样检查报告.html').write_text('<!doctype html><meta charset="utf-8"><title>R2 切片与小样报告</title><style>body{font:16px/1.75 "Microsoft YaHei",sans-serif;color:#233544;max-width:1250px;margin:35px auto;padding:0 25px}h1,h2{color:#154d66}table{border-collapse:collapse;font-size:13px}td,th{border:1px solid #cad4dc;padding:7px}th{background:#e9f0f4}pre{white-space:pre-wrap}strong{color:#9b3c25}img{max-width:100%}</style>'+body,encoding='utf8')
stl=R/'首批小样_STL_毫米_已定向';stl.mkdir(exist_ok=True)
for code in first:shutil.copy2(R/'evidence/打印方向网格'/(code+'.stl'),stl/(code+'.stl'))
checkrows=[]
for group,items in [('HT01',['六竖孔实测/螺杆通行','三槽宽长实测','横孔桥接质量','首层外扩']),('CT01-03',['0.5软垫实厚','30叠层实厚','防抬间隙','X/Y止挡接触','局部最不利12×14承托','硬支脚传力/无板弯曲']),('P06A/B',['贴衬接触','轻紧及防滑','未过压/未强拧闭合限位','工具装入退出','线口/线缆弯曲','光面无遮挡','工作温升']),('整机后续',['四极限角及最大抬起','四处承托交集','P01修订','相机灯有效组合范围','真实带面与托板齐平'])]:
 for item in items:checkrows.append([group,item,'待验证','','',''])
csvout('小样实测记录表.csv',['组别','检查项','状态','实测值/现象','处理措施','日期/检查人'],checkrows)
pres=[]
for q in json.loads((R.parent/'交付文件校验.json').read_text(encoding='utf8')):
 p=R.parent/q['file'];pres.append({'file':q['file'],'unchanged':hashlib.sha256(p.read_bytes()).hexdigest()==q['sha256']})
(R/'evidence/phase1_preservation.json').write_text(json.dumps(pres,ensure_ascii=False,indent=2),encoding='utf8')
assert all(q['unchanged'] for q in pres)
print({'first_batch_g':gfirst,'full_set_g':gfull,'bolts':sum(bolts.values()),'nuts':nuts,'washers':washers,'phase1_unchanged':True})
