from pathlib import Path
import sys,json,math
sys.path[:0]=['E:/2026FPGA/FPGA_Component_Inspector/开发实施/机械结构展示/.cad_runtime','E:/fusion360_codex_skill/.tools/python_deps']
from OCP.STEPControl import STEPControl_Reader
from OCP.HLRBRep import HLRBRep_Algo,HLRBRep_HLRToShape
from OCP.HLRAlgo import HLRAlgo_Projector
from OCP.gp import gp_Ax2,gp_Pnt,gp_Dir,gp_Pln
from OCP.TopExp import TopExp_Explorer
from OCP.TopAbs import TopAbs_EDGE
from OCP.TopoDS import TopoDS
from OCP.BRepAdaptor import BRepAdaptor_Curve
from OCP.GeomAbs import GeomAbs_Line
from OCP.BRepAlgoAPI import BRepAlgoAPI_Section
from reportlab.pdfgen import canvas
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.lib.units import mm
R=Path('E:/2026FPGA/FPGA_Component_Inspector/开发实施/机械结构展示/机械装配_R2b/P08_询价_Q1')
pdfmetrics.registerFont(TTFont('P08Font','C:/Windows/Fonts/msyh.ttc',subfontIndex=0))
c=canvas.Canvas(str(R/'P08_Q1_工程图及紧固件.pdf'),pagesize=(420*mm,297*mm));c.setTitle('P08 Q1 背孔连接板 - 询价用工程图 - PETG 100% 数量2')
rd=STEPControl_Reader();rd.ReadFile(str(R/'P08_Q1.step'));rd.TransferRoots();shape=rd.OneShape()
def tx(x,y,s,size=9):c.setFillColorRGB(.08,.15,.2);c.setFont('P08Font',size);c.drawString(x*mm,y*mm,s.replace('−','-'))
def line(x1,y1,x2,y2):c.line(x1*mm,y1*mm,x2*mm,y2*mm)
def header(page,title):
 c.setStrokeColorRGB(.16,.23,.3);c.setLineWidth(.6);c.rect(8*mm,8*mm,404*mm,281*mm)
 tx(16,278,'P08 / Q1   背面螺纹孔连接板 - '+title,16)
 tx(16,267,'R2b派生 | 询价用，非打印订单 | 单位 mm | 第三角法 | PETG / 100%填充 / 同款共2件',10)
 line(15,261,405,261);line(15,23,405,23)
 tx(16,14,'2026-09-19 | STEP实体投影与剖切 | 未注明圆角不额外添加；尺寸优先于图形比例',8)
 tx(373,14,f'第 {page} / 3 页',9)
def edges(s,axes=(0,1)):
 out=[]
 if s.IsNull():return out
 ex=TopExp_Explorer(s,TopAbs_EDGE)
 while ex.More():
  cv=BRepAdaptor_Curve(TopoDS.Edge_s(ex.Current()));a,b=cv.FirstParameter(),cv.LastParameter();n=2 if cv.GetType()==GeomAbs_Line else 65;pts=[]
  for i in range(n):
   p=cv.Value(a+(b-a)*i/(n-1));v=(p.X(),p.Y(),p.Z());pts.append((v[axes[0]],v[axes[1]]))
  out.append(pts);ex.Next()
 return out
def proj(normal,xdir):
 a=HLRBRep_Algo();a.Add(shape);a.Projector(HLRAlgo_Projector(gp_Ax2(gp_Pnt(),gp_Dir(*normal),gp_Dir(*xdir))));a.Update();a.Hide();b=HLRBRep_HLRToShape(a);return edges(b.VCompound())+edges(b.OutLineVCompound()),edges(b.HCompound())+edges(b.OutLineHCompound())
def strokes(seq,x,y,scale,lo,hidden=False):
 c.setStrokeColorRGB(.55,.6,.65) if hidden else c.setStrokeColorRGB(.08,.13,.18);c.setLineWidth(.4 if hidden else .7);c.setDash(2,2) if hidden else c.setDash()
 for points in seq:
  p=c.beginPath();p.moveTo((x+(points[0][0]-lo[0])*scale)*mm,(y+(points[0][1]-lo[1])*scale)*mm)
  for a,b in points[1:]:p.lineTo((x+(a-lo[0])*scale)*mm,(y+(b-lo[1])*scale)*mm)
  c.drawPath(p)
 c.setDash()
def view(v,x,y,scale,lo):strokes(v[1],x,y,scale,lo,True);strokes(v[0],x,y,scale,lo)
def dh(x1,x2,y,label):
 c.setLineWidth(.4);c.setStrokeColorRGB(.15,.3,.42);line(x1,y,x2,y)
 for x in (x1,x2):line(x,y-2,x,y+3);line(x-1,y-1,x+1,y+1)
 tx((x1+x2)/2-len(label)*.85,y+2,label,8)
def dv(x,y1,y2,label):
 c.setLineWidth(.4);c.setStrokeColorRGB(.15,.3,.42);line(x,y1,x,y2)
 for y in (y1,y2):line(x-2,y,x+3,y);line(x-1,y-1,x+1,y+1)
 tx(x+2,(y1+y2)/2+1,label,8)
def table(x,y,widths,rows,head=True,height=9,font=9):
 for j,row in enumerate(rows):
  xx=x
  if j==0 and head:c.setFillColorRGB(.91,.95,.97);c.rect(x*mm,(y-height)*mm,sum(widths)*mm,height*mm,fill=1,stroke=0)
  for w,s in zip(widths,row):
   c.setStrokeColorRGB(.6,.67,.71);c.setLineWidth(.3);c.rect(xx*mm,(y-height)*mm,w*mm,height*mm);tx(xx+2,y-height+3,str(s),font);xx+=w
  y-=height
 return y
def notes(x,y,lines,size=9,step=6):
 for t in lines:tx(x,y,t,size);y-=step
 return y

header(1,'单件三视图')
s=1.25;x0=35;y0=150
view(proj((0,0,1),(1,0,0)),x0,y0,s,(-7,-26));tx(35,245,'俯视 X-Y / 1.25:1',10)
dh(x0,x0+137*s,255,'137');dv(23,y0,y0+72*s,'72')
for label,x,y in [('H1',39,0),('H2',0,39),('H3',120,-18),('H4',120,18)]:
 xx=x0+(x+7)*s;yy=y0+(y+26)*s
 c.setStrokeColorRGB(.2,.4,.6);c.setDash(3,2);line(xx-5,yy,xx+5,yy);line(xx,yy-5,xx,yy+5);c.setDash();tx(xx+4,yy+4,label,9)
dh(x0+117*s,x0+137*s,140,'20');dv(217,y0,y0+52*s,'52');dv(230,y0+8*s,y0+44*s,'36')
dh(x0+39*s,x0+53*s,218,'14')
c.setStrokeColorRGB(.18,.35,.46);c.setDash([5,2,1,2]);xx=x0+46*s;line(xx,y0+12*s,xx,y0+76*s);c.setDash();tx(xx+2,y0+76*s,'A',9);tx(xx+2,y0+10*s,'A',9)
view(proj((0,-1,0),(1,0,0)),35,92,s,(-7,0));tx(35,115,'正视 X-Z / 1.25:1',10);dh(35,35+137*s,81,'137');dv(216,92,92+9*s,'9')
view(proj((1,0,0),(0,1,0)),270,92,s,(-26,0));tx(270,115,'右视 Y-Z / 1.25:1',10);dh(270,270+72*s,81,'72');dv(371,92,92+9*s,'9')
notes(267,244,['主体厚6；两处Ø10支脚高3。','总安装厚度9，含支脚。','2×Ø3.6通孔：H1、H2。','2×Ø4.5通孔：H3、H4。','所有孔均非沉孔、非打印螺纹。','孔位坐标及轮廓定义见第2页。','虚线为隐藏轮廓，包括下方支脚。','两件同款，绕灯轴旋转180°装配。','实物互换尚待首次装配验证。'],9,8)
notes(25,61,['CAD实测包络137×72×9；单件实体体积19441.169 mm³。','四个支脚落点按用户确认可贴平处理；当前不改板形与支脚。','M3孔不引用HT01的M4结果。必要时仅轻修打印通孔并记录，不得扩大灯壳螺纹孔。','承载、挠曲、温升及实物互换均待验证；本图可用于询价，不构成批量制造或打印订单。'],9,7)
c.showPage()

header(2,'孔位、轮廓与剖视')
tx(18,249,'加工坐标：保留灯心X/Y原点，支脚接触面Z=0；主体下表面Z=3，上表面Z=9。',10)
table(18,239,[20,26,26,26,67],[['孔','X','Y','通孔直径','轴向范围'],['H1',39,0,'Ø3.6','Z=0～9'],['H2',0,39,'Ø3.6','Z=0～9'],['H3',120,-18,'Ø4.5','Z=3～9'],['H4',120,18,'Ø4.5','Z=3～9']],height=10)
notes(210,235,['H1、H2各有同轴Ø10×3支脚。','M3孔中心距外条边7；孔边余量5.2。','M3垫片OD7在主体上的最小边余量3.5。','M4孔距安装耳近端边8，孔边余量5.75。','孔位取灯心原点；不要按STL平移坐标放样。'],9,8)
table(18,178,[38,37,37,53],[['主体矩形并集','X范围','Y范围','Z范围'],['上侧横条','−7～46','32～46','3～9'],['竖向连接条','32～46','−7～46','3～9'],['外伸横条','32～120','−7～7','3～9'],['安装耳','110～130','−26～26','3～9']],height=10)
notes(210,173,['外形由四矩形并集形成一个连续实体。','条宽14；安装耳20×52；主体统一厚6。','不要在内角自行增加影响装配的圆角。','去毛刺，不得削薄支脚承压面或垫片座面。','模型控制外形；本页坐标控制孔位与实体尺寸。'],9,8)
sec=BRepAlgoAPI_Section(shape,gp_Pln(gp_Pnt(39,0,0),gp_Dir(1,0,0)),False);sec.Build();assert sec.IsDone()
strokes(edges(sec.Shape(),(1,2)),30,76,2,(-7,0));tx(22,110,'A-A实体剖切：X=39，沿+X观察 / 2:1',10)
dh(34,54,65,'Ø10');dv(145,76,82,'3');dv(160,82,94,'6');dv(176,76,94,'9')
tx(28,54,'孔贯穿主体及支脚；剖切轮廓取自STEP实体。',9)
notes(212,113,['询价尺寸控制目标（供方需确认可达性）：','主体6±0.15；支脚3±0.15；总厚9±0.20。','总厚需直接测量控制，不因分项公差放宽。','一般线性尺寸±0.20；孔中心坐标±0.15。','M3孔Ø3.6 +0.20/0（允许轻修PETG后达到）；','M4孔Ø4.5 +0.20/0；均须去毛刺、试穿。','这些是拟定制造要求，不是已测得的打印精度。','供方若无法达到，应在报价中注明，先修订再生产。'],9,8)
c.showPage()

header(3,'紧固件、打印要求及首次装配')
table(18,249,[66,16,92,194],[['项目','数量','规格 / 当前选择','状态'],['P08连接板',2,'PETG，100%填充','同款，按已定向STL；无独立试片'],['灯背面螺丝',4,'M3×12，非沉头，建议内六角圆柱头','暂选；头部包络≤Ø5.5×3，供方核实'],['M3平垫片',4,'OD7 / ID3.6 / 厚0.5','厚度预算±0.05；实购核实'],['P08/P05螺栓',4,'M4×30','沿用，夹持厚18；露出螺母名义7.2'],['M4螺母',4,'M4，模型厚3.2','沿用；核实实际尺寸'],['M4平垫片',8,'OD9 / ID4.5 / 厚0.8','沿用，每个M4上下各一片']],height=10,font=9)
notes(20,166,['M3安装厚度按CAD复核为9 mm（主体6+支脚3）；打印后的实际厚度尚未测量。','名义拧入：e=L−A−w=12−9−0.5=2.5 mm。图示孔深4 mm仅作为设计输入。'],10,8)
table(18,145,[52,69,67,180],[['输入或结果','名义','询价/核验公差预算','说明'],['螺丝头下长度L','12','±0.20','采购核实；非沉头长度从头下承压面起算'],['实际安装厚度A','9','±0.20','两处逐点测量，含一体支脚'],['平垫片厚w','0.5','±0.05','实际采购件测量'],['拧入e','2.5','2.05～2.95','e_max=12.2−8.8−0.45=2.95'],['相对图示4mm的余量','1.5','最小1.05','仅理想几何预算，不证明4mm全深可用']],height=9,font=9)
notes(20,82,['实际有效螺纹、入口不完整牙和孔底形状未确认；不得把上表的余量写成厂家认可的顶底安全余量。','首次装配：核实A、w、L及有效孔深；手拧确认未顶底，再检查螺纹啮合和固定可靠性，不得强拧补偿。','若有效可用深度不足以容纳实际拧入并留余量，暂停紧固，复核螺丝/垫片方案后再装，不扩大灯壳螺纹孔。','打印：主体大平面贴床、支脚向上；0.4喷嘴/0.2层高为估算基准，4壁，100%直线填充，无支撑，3mm裙边。','STL单件137×72×9（含裙边143×78×9）；估算25.32g/件、约2h03/件；两件约50.64g，供方实际切片为准。','维护：D120/H60、Y0，台面组装灯与P08，抬高5mm从前送入后落座，装M4，再恢复工作姿态。','承载/挠曲/松动、温升、实物180°互换与M3通孔适配均列首次装配待验证；不增加HT02，不下发打印订单。'],8.4,7)
c.save()
print(R/'P08_Q1_工程图及紧固件.pdf')
