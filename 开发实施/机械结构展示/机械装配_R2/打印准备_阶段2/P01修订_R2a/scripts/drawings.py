from pathlib import Path
import sys,json,math,re
sys.path.insert(0,r'E:\2026FPGA\FPGA_Component_Inspector\开发实施\机械结构展示\.cad_runtime')
from OCP.STEPControl import STEPControl_Reader
from OCP.HLRBRep import HLRBRep_Algo,HLRBRep_HLRToShape
from OCP.HLRAlgo import HLRAlgo_Projector
from OCP.gp import gp_Ax2,gp_Pnt,gp_Dir
from OCP.TopExp import TopExp_Explorer
from OCP.TopAbs import TopAbs_EDGE
from OCP.TopoDS import TopoDS
from OCP.BRepAdaptor import BRepAdaptor_Curve
from OCP.GeomAbs import GeomAbs_Line
from reportlab.pdfgen import canvas
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.cidfonts import UnicodeCIDFont
from reportlab.lib.units import mm
from pypdf import PdfReader,PdfWriter
R=Path(r'E:\2026FPGA\FPGA_Component_Inspector\开发实施\机械结构展示\机械装配_R2\打印准备_阶段2\P01修订_R2a')
O=R/'逐件工程图_试制';O.mkdir(exist_ok=True)
pdfmetrics.registerFont(UnicodeCIDFont('STSong-Light'))
meta={q['code']:q for q in json.loads((R/'evidence/part_exports.json').read_text())}
for q in json.loads((R/'evidence/coupons.json').read_text()):meta[q['code']]=q
geometry=json.loads((R/'evidence/drawing_geometry.json').read_text())
notes={
'P01':['R2a：安装槽总长56；前端实体余量3；整套打印仍暂缓。','根部 52×10×50；臂 24×190×10；两筋厚 4。','根部双槽：总长 28、宽 4.5，中心 X=±18，Z=184.5。','承托槽：总长 56、宽 4.5，中心 X=0，Y=±49。','双螺杆距12，槽内有效位移37.5；默认Y=±54/±66。','槽端至臂前缘余量3；两承托槽中心距98。','高度微调有效 21.5；20 分档交叠 1.5。'],
'P02':['底座 74×44×10；硬支脚总高 41。','承托台 Y=26..45，名义 74×19；软垫厚 0.5。','Y 止挡内面 Y=45.5；下止挡高 1.5，上止挡高 1.5。','硬支脚 Y=47.5..70；板叠层假设 30，防抬间隙 0.5。','2×直径4.5 通孔，X=0，Y=54/66，孔距12。'],
'P04':['主体 24×12×180；背部开放间隙 12。','两脚长度18，Y=98..110，Z=70..88 / 232..250。','竖槽总长140、宽4.5，中心Z=160，X=0。','固定孔直径4.5，X=0，Z=80/240，孔距160。','双螺栓距16：槽有效117.5；装配范围另见报告。'],
'P05':['臂20×150×12；根部20×12×44；两侧筋厚4。','根部孔直径4.5，X=0，Z=170/186，中心距16。','前后槽总长72、宽4.5，中心X=0，Y=0。','双螺栓距36：槽有效29.5，即±14.75。','筋顶截面三点(Y,Z)：(74,164),(45,164),(74,192)。'],
'P06':['主体内径91、外径110、高16；初始总分缝2。','灯假设外径90，软衬径向厚0.5，软衬不是PETG。','夹耳20×12×16，X=-68..-48 / 48..68。','夹紧孔直径4.5，轴Y，X=±61，Z=156。','连接加厚圆直径14，孔直径4.5，X=±48，Y=±18。','窗口宽16×高8；Z=152..160，保留连续接触区。','闭合止挡4×0.5×4，闭合总缝下限1；不可继续强拧。','需实测夹持、防滑、线口、散热；允许试配，未验收。'],
'P07':['总包络88×52×8；侧向孔/槽中心Y=±18，距36。','灯侧槽总长8.5、宽4.5，X=±48。','托臂孔直径4.5，X=±120；内侧避让直径92。','中央直通缺口68×20，Y=-10..10。','左右件不可直接互换，按独立编号制作。'],
'CT01':['右后角局部试样，43×44×41，非整件承重替代。','X=-37..6；Y=26..70；Z=0..41。','底厚10；下Y挡 Z=10..11.5，上Y挡Z=39.5..41。','2×直径4.5通孔，X=0，Y=54/66。','配0.5软垫、30厚模拟叠层、CT02及CT03。'],
'CT02':['顶板43×30×6；顶部Z=47，底面Z=41。','X限位块4×4.75×1.5，X=-19.5..-15.5。','Y=40..44.75，Z=39.5..41；对应右后角。','2×直径4.5通孔，X=0，Y=54/66。','顶面朝下打印；装配不得用压片夹紧薄亚克力。'],
'CT03':['试装垫座24×84×10；X=±12，Y=10..94。','槽总长60、宽4.5；中心X=0，Y=49；贯穿。','仅检查承托块螺栓配合，不验证P01整臂及加强筋。'],
'HT01':['基片80×60×6；左下3×3缺口标识原点。','竖孔由左至右：4 / 4.2 / 4.4 / 4.5 / 4.6 / 4.8。','孔中心X=10,22,34,46,58,70；Y=10。','三槽总长28：中心(20,26)宽4.2；(60,26)宽4.5；','(20,44)宽4.8；槽长沿X。','横孔凸台20×16×10：X50..70,Y40..56,Z6..16。','横孔直径4.5，轴Y，中心X60,Z11；无支撑试桥接。'],
'W01':['胶合板650×400×12，1件；机身固定孔待实物定位。','本图仅含结构连接孔，角码实购孔位核实后钻孔。','原点为检测点投影；板范围X=-325..325,Y=-140..260。','若从左前角放样：表中X加325，Y加140。'],
'W02':['胶合板300×360×12，1件。','相机孔列X=-83,-47,47,83；Z=125..305，步距20。','40个相机孔；灯导板4孔：X=±120，Z=80/240。','其余6孔为角码；上加强板连接已改Z=110。','以板左下角放样：表中X加150，Z保持不变。'],
'W03':['胶合板直角三角形120×200×12，2件。','平面YZ三点(122,0),(242,0),(122,200)。','4个角码孔，孔轴X；从后墙底部原点：Y减122。','现货角码孔距核实后定位。'],
'W04':['胶合板100×100×12，2件；托料顶面暂定Z=80。','2×直径4.5通孔；顶面90度沉孔直径8.4、深2。','沉孔底直径4.4；按实购M4沉头修配，头低顶面0.2。','上表面不加垫片；避免载带被螺钉头挂住。','右侧本图；左侧整件绕Z旋转180度安装。','左前角放样：表中X减212，Y加50。'],
'W05':['胶合板12×80×68，4件；68高度为带面80的假设值。','孔轴X；中心(Y,Z)=(-25,12.5),(-25,55.5)。','从Y=-40边放样，孔距边15；上下孔距43。','托料脚实际高度与垫片由实测带面确定。'],
'S01':['软垫74×19×0.5，4件；材料硬度、胶粘待试配。','贴放不得侵入孔槽；软垫内缩误差预算1.5。','非PETG打印件。'],
'S03':['软衬内径90、外径91、高12；两半各1。','沿用灯圈分缝与线口窗口；非PETG。','可从0.5厚软片裁条试贴，长度需按实物缝隙修配。']}
def text(c,x,y,s,size=8):
 c.setFont('STSong-Light',size);c.drawString(x*mm,y*mm,s)
def wrap(s,n=34):
 lines=[];line=''
 for token in re.findall(r'[A-Za-z0-9_.±=×/+\-]+|.',s):
  if len(line)+len(token)>n and line:lines.append(line);line=''
  line+=token
 if line:lines.append(line)
 return lines
def edges(shape):
 result=[]
 if shape.IsNull():return result
 ex=TopExp_Explorer(shape,TopAbs_EDGE)
 while ex.More():
  cv=BRepAdaptor_Curve(TopoDS.Edge_s(ex.Current()));a,b=cv.FirstParameter(),cv.LastParameter();n=2 if cv.GetType()==GeomAbs_Line else 49
  result.append([(cv.Value(a+(b-a)*i/(n-1)).X(),cv.Value(a+(b-a)*i/(n-1)).Y()) for i in range(n)])
  ex.Next()
 return result
def project(shape,normal,xdir):
 algo=HLRBRep_Algo();algo.Add(shape);algo.Projector(HLRAlgo_Projector(gp_Ax2(gp_Pnt(),gp_Dir(*normal),gp_Dir(*xdir))));algo.Update();algo.Hide();out=HLRBRep_HLRToShape(algo)
 return edges(out.VCompound()),edges(out.HCompound())
def view(c,vs,region,label):
 lines,hidden=vs;pts=[p for e in lines+hidden for p in e];lo=[min(p[i] for p in pts) for i in [0,1]];hi=[max(p[i] for p in pts) for i in [0,1]]
 x,y,w,h=region;scale=min((w-18)/max(hi[0]-lo[0],1),(h-20)/max(hi[1]-lo[1],1));cx=x+(w-(hi[0]-lo[0])*scale)/2;cy=y+(h-(hi[1]-lo[1])*scale)/2
 for seq,is_hidden in [(hidden,True),(lines,False)]:
  c.setDash(2,2) if is_hidden else c.setDash();c.setStrokeColorRGB(.65,.65,.65) if is_hidden else c.setStrokeColorRGB(.12,.18,.22);c.setLineWidth(.35 if is_hidden else .65)
  for e in seq:
   p=c.beginPath();p.moveTo((cx+(e[0][0]-lo[0])*scale)*mm,(cy+(e[0][1]-lo[1])*scale)*mm)
   for px,py in e[1:]:p.lineTo((cx+(px-lo[0])*scale)*mm,(cy+(py-lo[1])*scale)*mm)
   c.drawPath(p)
 c.setDash();c.setStrokeColorRGB(.15,.3,.4);c.setLineWidth(.4)
 dx=(hi[0]-lo[0])*scale;dy=(hi[1]-lo[1])*scale
 c.line(cx*mm,(cy-4)*mm,(cx+dx)*mm,(cy-4)*mm)
 for xx in [cx,cx+dx]:c.line(xx*mm,(cy-5)*mm,xx*mm,(cy-2)*mm)
 text(c,cx+dx/2-5,cy-8,f'{hi[0]-lo[0]:.2f}')
 c.line((cx-4)*mm,cy*mm,(cx-4)*mm,(cy+dy)*mm)
 for yy in [cy,cy+dy]:c.line((cx-5)*mm,yy*mm,(cx-2)*mm,yy*mm)
 text(c,cx-13,cy+dy/2,f'{hi[1]-lo[1]:.2f}')
 text(c,x+5,y+h-5,label+' / 示意比例 '+f'{scale:.3f}:1',9)
def header(c,code,name,page):
 c.setStrokeColorRGB(.1,.2,.3);c.rect(8*mm,8*mm,404*mm,281*mm);text(c,15,279,code+'  '+name[len(code)+1:],14);text(c,15,269,'R2 · 试制工程图 / 单位 mm / 第三角法投影 / 禁止按图缩放量取尺寸',9)
 text(c,15,12,'2026-09-10 | Fusion BRep → STEP → CAD隐藏线投影 | 实物试配、承载、光学及温升均待验证',8);text(c,385,12,str(page),8)
files=sorted((R/'零件STEP').glob('*.step'))+sorted((R/'小样STEP').glob('*.step'))
writer=PdfWriter();index=[]
for path in files:
 code=path.stem;q=meta[code];name=q['name'];r=STEPControl_Reader();r.ReadFile(str(path));r.TransferRoots();shape=r.OneShape()
 pdf=O/(code+'.pdf');c=canvas.Canvas(str(pdf),pagesize=(420*mm,297*mm));header(c,code,name,1)
 bounds=q['bounds_mm'] if 'bounds_mm' in q else q['bodies'][0]['bounds_mm']
 dx,dy,dz=[bounds[i+3]-bounds[i] for i in range(3)]
 common_scale=min(209/max(dx+dy,1),173/max(dy+dz,1))
 vx,vy,vz=[v*common_scale for v in [dx,dy,dz]]
 view(c,project(shape,(0,0,1),(1,0,0)),(20,30+vz+35,vx+18,vy+20),'俯视 X-Y')
 view(c,project(shape,(0,-1,0),(1,0,0)),(20,30,vx+18,vz+20),'正视 X-Z')
 view(c,project(shape,(1,0,0),(0,1,0)),(20+vx+33,30,vy+18,vz+20),'右视 Y-Z')
 y=252;text(c,292,y,'数量 '+str(q['qty'])+'  材料 '+('12 mm胶合板' if code.startswith('W') else '软片 / 待选型' if code.startswith('S') else 'PETG / 待试制'),10);y-=10
 ns=notes.get(code,notes.get(code[:3],[]))
 if code.startswith('P03'):ns=['板74×30×6；下侧X止挡4×4.75×1.5。','四个角独立编号；LF左前/LB左后/RF右前/RB右后。','双孔直径4.5，中心距12；具体坐标见孔表。','压片底面Z=235.5，止挡Z=234..235.5。','上亚克力顶面假设Z=235，防抬间隙0.5。','反放顶部朝下；不得把压片锁紧力传入板卡叠层。']
 for line in ns+['所有未指定孔槽按图中名义值，打印偏差由HT01试片确定。','下页为原生组件坐标孔表/草图轮廓；装配位移不计入。','孔槽尺寸为CAD值；不代表实测制造公差。']:
  for s in wrap(line):text(c,292,y,s,8);y-=5
  y-=3
 c.showPage();page=2;header(c,code,name,page);y=255
 text(c,15,y,'原生草图坐标说明：X 沿输送，Y 向后，Z 向上。圆为孔或圆轮廓；关联用途见特征名。',9);y-=10
 for sk in geometry.get(code,{}).get('sketches',[]):
  circles=[v for v in sk['curves'] if v['type']=='circle'];points=[p for v in sk['curves'] if v['type']=='line' for p in v['points']]
  if circles:lines=[f"圆直径 {v['radius']*2:.3f}; 中心 ({', '.join(f'{z:.3f}' for z in v['center'])})" for v in circles]
  elif points:
   unique=sorted(set(tuple(round(z,3) for z in p) for p in points));lines=['轮廓顶点 '+str(p) for p in unique]
  else:continue
  if y<45:c.showPage();page+=1;header(c,code,name,page);y=255
  text(c,15,y,sk['name']+'  [原生草图'+('已约束' if sk['constrained'] else '未全约束')+']',9);y-=6
  # Compact in two columns without truncating coordinates.
  for i in range(0,len(lines),2):
   if y<30:c.showPage();page+=1;header(c,code,name,page);y=255
   text(c,20,y,lines[i],8)
   if i+1<len(lines):text(c,213,y,lines[i+1],8)
   y-=5
  y-=4
 c.save();writer.append(str(pdf));index.append({'code':code,'pages':page,'file':str(pdf)})
 print(code,page,flush=True)
with open(O/'R2_逐件工程图合订本.pdf','wb') as f:writer.write(f)
(R/'evidence/drawing_index.json').write_text(json.dumps(index,ensure_ascii=False,indent=2),encoding='utf8')

