from pathlib import Path
import sys,json,csv,hashlib,zipfile,shutil
sys.path[:0]=['E:/2026FPGA/FPGA_Component_Inspector/开发实施/机械结构展示/.cad_runtime','E:/fusion360_codex_skill/.tools/python_deps']
R=Path('E:/2026FPGA/FPGA_Component_Inspector/开发实施/机械结构展示/机械装配_R2b/P08_询价_Q1')
import numpy as np,trimesh,matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from mpl_toolkits.mplot3d.art3d import Poly3DCollection
from matplotlib.font_manager import FontProperties
font=FontProperties(fname='C:/Windows/Fonts/msyh.ttc')
m=trimesh.load_mesh(next(R.glob('*.stl')))
from matplotlib.patches import Polygon,Circle
fig,ax=plt.subplots(figsize=(10,6),dpi=160)
outline=np.array([[-7,32],[32,32],[32,-7],[110,-7],[110,-26],[130,-26],[130,26],[110,26],[110,7],[46,7],[46,46],[-7,46]])
outline[:,0]+=7;outline[:,1]=46-outline[:,1]
ax.add_patch(Polygon(outline,facecolor='#68adc7',edgecolor='#173c4a',lw=1.5))
for x,y in [(46,46),(7,7)]:
 ax.add_patch(Circle((x,y),5,facecolor='#e2a659',edgecolor='#785012'));ax.add_patch(Circle((x,y),1.8,facecolor='white',edgecolor='#173c4a'))
for x,y in [(127,64),(127,28)]:ax.add_patch(Circle((x,y),2.25,facecolor='white',edgecolor='#173c4a'))
ax.set(xlim=(-8,145),ylim=(-8,80),xlabel='STL X / mm',ylabel='STL Y / mm');ax.set_aspect('equal');ax.grid(alpha=.15)
ax.set_title('已定向STL上视图：主体大平面贴床，支脚朝上\n蓝色主体 Z=0～6；橙色支脚 Z=6～9；白色为通孔\n单件137×72×9 mm；PETG，100%填充，共2件',fontproperties=font,fontsize=12)
fig.tight_layout();fig.savefig(R/'P08_打印方向.png');plt.close(fig)
items=[['P08','背孔连接板','PETG；100%填充',2,'件','询价；同款2件','主体上表面贴床，支脚向上；不增加独立试片'],['M3-S','非沉头螺丝','M3×12，建议内六角圆柱头',4,'颗','暂选，首次装配核实','头部包络≤Ø5.5×3；头下长12±0.20为核验预算，不是实购物料公差已确认'],['M3-W','平垫片','OD7 / ID3.6 / 厚0.5',4,'片','采购尺寸核实','厚0.50±0.05为核验预算；实际测量'],['M4-S','外侧连接螺栓','M4×30',4,'颗','沿用，不重复采购','名义夹持厚18；螺母外露7.2'],['M4-N','螺母','M4；模型厚3.2',4,'颗','沿用','实际规格核实'],['M4-W','平垫片','OD9 / ID4.5 / 厚0.8',8,'片','沿用','每颗M4上下各一片']]
with (R/'P08_Q1_紧固件及数量.csv').open('w',encoding='utf-8-sig',newline='') as f:
 w=csv.writer(f);w.writerow(['编号','名称','规格','数量','单位','状态','说明']);w.writerows(items)
checks=[('四脚落点','按用户确认可贴平；实装记录接触均匀性','用户确认，实装记录待填'),('安装总厚A','两处均9±0.20；逐件逐点测量','待实测'),('主体/支脚厚度','6±0.15、3±0.15；总厚优先控制','待实测'),('螺丝头下长度L','M3×12；核验预算12±0.20','待实测'),('垫片厚w','0.50±0.05核验预算','待实测'),('实际拧入e','逐处 L-A-w；名义2.5，预算2.05～2.95','待实测'),('孔底与有效螺纹','4mm为图纸输入，不是厂家确认全深可用；记录有效孔深/入口不完整牙','待实测'),('螺纹啮合与固定可靠性','先手拧排除顶底；不得以增大扭矩试探；若不足复核方案','待验证'),('M3通孔','Ø3.6；不引用HT01，记录首次试穿','待验证'),('轻修记录','仅PETG通孔；记录工具及前后孔径；禁止扩大灯壳螺纹孔','如发生则记录'),('实物180度互换','仅旋转180°，不得分别强行修形对孔','待验证'),('承载/挠曲/蠕变/松动','记录试验载荷、时间和变形/松动','待验证'),('温升','记录灯工况、环境温度、运行时间和稳定温度','待验证'),('D120/H60维护','Y0，抬高5mm前送入后落座，再装M4并恢复工作姿态','待实装'),('线缆及光学','线口、弯曲、散热、遮光和焦距','待验证')]
with (R/'P08_Q1_首次装配记录.csv').open('w',encoding='utf-8-sig',newline='') as f:
 w=csv.writer(f);w.writerow(['项目','设计输入/要求','当前状态','左件/位置1实测','左件/位置2实测','右件/位置1实测','右件/位置2实测','结果及处理','日期/人员'])
 for a,b,d in checks:w.writerow([a,b,d,'','','','','',''])
note='''# P08 Q1 询价文件说明

用途：供询价和工艺评估，不是打印订单；未发送给任何供方或打印机。R2b、R2a、R2原模型保留不变。此次P08实体形状未改，仅从R2b原生参数化实体导出单件制造文件。

## 文件与数量
- P08_Q1.step：单一有效实体，灯心X/Y坐标保留；支脚接触面Z=0，主体底Z=3、顶Z=9。
- P08_Q1_顶面贴床_支脚朝上_数量2.stl：一个零件，单位按mm导入，打印数量2；不要当作已包含两个零件，也不要缩放。
- P08_Q1_工程图及紧固件.pdf：3张A3页，单件三视图、孔位/实体坐标与剖视、紧固件及公差预算；已逐页渲染检查。
- P08_Q1_紧固件及数量.csv：两件P08所需数量，明确新选M3与沿用M4。
- P08_Q1_首次装配记录.csv：保留未验证项目；不增加HT02或其他独立试片。

## 制作与切片
P08同款2件，PETG，100%填充，M3通孔名义Ø3.6。主体大平面贴床、支脚向上，无支撑；估算采用0.4mm喷嘴、0.2mm层高、4壁、100%直线填充、3mm裙边。单件含裙边143×78×9mm，可放入200×200×200mm空间。使用一次两件排布时仍需供方检查实际间距、裙边和热床范围。

离线PrusaSlicer估算：25.32g/件（含裙边），约2h03m/件；两件约50.64g，顺序打印约4h06m。实际材料、机器、速度、排布会改变报价。100%填充不等于无孔隙或强度已经验证。未交付机器G-code。

网格检查：封闭、单一连通实体，3084三角面；STL包络137×72×9mm；原生与STEP体积一致，STL体积差约0.00021%。已定向网格没有高于床面的向下悬空平面，离线无支撑切片成功。未将切片成功当作实际打印验收。

## M3×12复核
四个Ø10支脚落点按用户确认可贴平处理。灯图纸孔深4mm仅是设计输入，不表述为厂家确认4mm全深可用。

CAD总安装厚A=主体6+支脚3=9mm。配0.5mm平垫片，4颗M3×12非沉头螺丝，名义e=12-9-0.5=2.5mm。

为询价和首次核验拟定：A=9±0.20mm、螺丝头下L=12±0.20mm、垫片w=0.50±0.05mm。得e_min=11.8-9.2-0.55=2.05mm；e_max=12.2-8.8-0.45=2.95mm。相对理想4mm深度的最小剩余量=1.05mm。以上公差须供方确认或实测，不是现成物料标准公差的引用；实际厚度现在没有测量值。

主体6±0.15、支脚3±0.15，同时总厚9±0.20需直接控制；不能把两个分项极限简单叠加到±0.30后仍引用上述结果。供方若不能达到，请在报价标明，不自行变更尺寸。

图纸孔深不提供有效完整螺纹长度，也不说明孔底几何。1.05mm仅是相对图示理想孔底的几何预算，不能据此保证不顶底。首次装配记录A、L、w、有效孔深与实际啮合，先手拧排除顶底，再检查固定可靠性；不以增大扭矩试探。若不足，暂停紧固并复核螺丝/垫片方案，不扩大灯壳螺纹孔。四处均需检查。

暂按非沉头内六角圆柱头包络≤Ø5.5×3选择，配OD7/ID3.6平垫片；供方须确认实物头部尺寸。螺丝12mm从头下承压面起算，不含头高。头部外形沿用已检查包络，伸入灯壳的杆段按上述预算新增，真实牙型/啮合可靠性未模拟。

## 继续保留的限制
沿用R2b报告有效行程：建议D50～200、H10～92且D≥H+40；H<16时Y≥-13，H≥16时前后槽±14.75，检测对中Y=0。没有扩大使用窗口。

维护固定为D120/H60、Y0：台面装好灯与P08，外侧M4暂不装；灯组件抬高5mm从前方送入后落座，再装M4，随后恢复工作姿态。默认D100下不得强行抬高送入。

首次装配仍须验证：M3孔试穿、实际螺纹啮合、固定可靠性、承载/挠曲/蠕变/松动、工作温升、实物180°互换、线缆及光学。必要时允许轻修PETG通孔并记录，禁止扩大灯壳螺纹孔。HT01的M4结果不作为M3验证；无独立试片费用。
'''
(R/'00_询价说明_不下单.md').write_text(note,encoding='utf8')
from pypdf import PdfReader
pdf=PdfReader(R/'P08_Q1_工程图及紧固件.pdf');assert len(pdf.pages)==3
txt='\n'.join(p.extract_text() for p in pdf.pages)
for phrase in ['Ø3.6','M3×12','2.05','2.95','100%','D120/H60']:assert phrase in txt,phrase
report={'pdf_pages':3,'pdf_visual_qa':'All three final Poppler renders inspected; embedded YaHei font; diameter/minus symbols and cylindrical silhouettes verified','source_native_sha256':hashlib.sha256((R.parent/'FPGA_Inspector_R2b_Parametric.f3d').read_bytes()).hexdigest(),'outputs_quote_only':True,'M3_nominal_engagement_mm':2.5,'M3_budget_range_mm':[2.05,2.95],'drawing_depth_mm':4,'full_4mm_usable_confirmed':False,'actual_printed_thickness_measured':False,'bearing_heat_swap':'pending first assembly','foot_contact':'user confirmed flat','separate_coupon_count':0,'order_sent':False}
(R/'evidence/final_review.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf8')
for p in Path('E:/fusion360_codex_skill/scripts').glob('p08q_*.py'):shutil.copy2(p,R/'scripts'/p.name)
files=[p for p in R.iterdir() if p.is_file() and p.suffix!='.zip' and p.name!='询价文件校验.json']
manifest={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in files};(R/'询价文件校验.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf8');files.append(R/'询价文件校验.json')
with zipfile.ZipFile(R/'P08_Q1_询价包_2件PETG100填充_不含订单.zip','w',zipfile.ZIP_DEFLATED) as z:
 for p in files:z.write(p,p.name)
 assert not any(p.suffix=='.gcode' for p in files)
print(json.dumps({'delivered_files':[p.name for p in files],'review':report},ensure_ascii=False))
