import re, math, json, html
from pathlib import Path
from reportlab.pdfgen import canvas
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from OCP.gp import gp_Ax2,gp_Pnt,gp_Dir
from OCP.HLRBRep import HLRBRep_Algo,HLRBRep_HLRToShape
from OCP.HLRAlgo import HLRAlgo_Projector
from OCP.BRepLib import BRepLib
from cadquery.occ_impl.shapes import Shape
from cadquery.occ_impl.exporters.svg import getPaths

W,H=1190.55,841.89
pdfmetrics.registerFont(TTFont('CJK','C:/Windows/Fonts/simhei.ttf'))
class Sheet:
    def __init__(self,c): self.c=c;self.svg=[]
    def text(self,x,y,t,size=11,color='#182b35'):
        t=str(t).replace('−','-').replace('Ø','直径');self.c.setFillColor(color);self.c.setFont('CJK',size);self.c.drawString(x,y,t)
        self.svg.append(f'<text x="{x}" y="{H-y}" font-family="Microsoft YaHei,sans-serif" font-size="{size}" fill="{color}">{html.escape(t)}</text>')
    def line(self,x,y,a,b,width=.6,color='#223943',dash=False):
        self.c.setStrokeColor(color);self.c.setLineWidth(width);self.c.setDash([3,2] if dash else []);self.c.line(x,y,a,b)
        self.svg.append(f'<path d="M{x},{H-y} L{a},{H-b}" stroke="{color}" stroke-width="{width}" fill="none"'+(' stroke-dasharray="3 2"' if dash else '')+'/>')
    def rect(self,x,y,w,h):
        for u,v,a,b in [(x,y,x+w,y),(x+w,y,x+w,y+h),(x+w,y+h,x,y+h),(x,y+h,x,y)]:self.line(u,v,a,b)
    def path(self,pts,dash=False):
        if len(pts)<2:return
        p=self.c.beginPath();p.moveTo(*pts[0]);
        for q in pts[1:]:p.lineTo(*q)
        self.c.setDash([3,2] if dash else []);self.c.setStrokeColor('#89969c' if dash else '#152c37');self.c.setLineWidth(.45 if dash else .8);self.c.drawPath(p)
        d='M'+' L'.join(f'{x},{H-y}' for x,y in pts)
        self.svg.append(f'<path d="{d}" stroke="'+('#89969c' if dash else '#152c37')+'" stroke-width="'+('.45' if dash else '.8')+'" fill="none"'+(' stroke-dasharray="3 2"' if dash else '')+'/>')
    def save(self,file):
        file.write_text(f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}"><rect width="100%" height="100%" fill="white"/>'+''.join(self.svg)+'</svg>',encoding='utf8')
    def arrow(self,x,y,dx,dy):
        self.line(x,y,x+dx,y+dy)
        ang=math.atan2(dy,dx)
        for a in [ang+.5,ang-.5]:self.line(x+dx,y+dy,x+dx-5*math.cos(a),y+dy-5*math.sin(a))
    def dim(self,x,y,w,h,a,b):
        yy=y-18;xx=x+w+20
        self.line(x,y-3,x,yy-5);self.line(x+w,y-3,x+w,yy-5)
        self.arrow(x,yy,w,0);self.arrow(x+w,yy,-w,0);self.text(x+w/2-7,yy-14,f'{a:g}',10)
        self.line(x+w+3,y,xx+5,y);self.line(x+w+3,y+h,xx+5,y+h)
        self.arrow(xx,y,0,h);self.arrow(xx,y+h,0,-h);self.text(xx+7,y+h/2,f'{b:g}',10)

def project(shape,view):
    directions={'top':((0,0,1),(1,0,0)),'front':((0,-1,0),(1,0,0)),'right':((1,0,0),(0,1,0))}
    d,xd=directions[view];alg=HLRBRep_Algo();alg.Add(shape.wrapped);alg.Projector(HLRAlgo_Projector(gp_Ax2(gp_Pnt(),gp_Dir(*d),gp_Dir(*xd))));alg.Update();alg.Hide();s=HLRBRep_HLRToShape(alg)
    visible=[];hidden=[]
    for method,dest in [(s.VCompound,visible),(s.Rg1LineVCompound,visible),(s.OutLineVCompound,visible),(s.HCompound,hidden),(s.OutLineHCompound,hidden)]:
        obj=method()
        if not obj.IsNull():BRepLib.BuildCurves3d_s(obj,1e-6);dest.append(Shape(obj))
    return getPaths(visible,hidden)

def wrap(t,n=49):
    # Chinese characters are roughly one em; cap lines conservatively.
    return [t[i:i+n] for i in range(0,len(t),n)]
def frame(s,title,page,total):
    s.rect(20,20,W-40,H-40);s.text(40,795,title,23);s.text(40,769,'R1 试制工程图 | 单位 mm | 第三角投影 | 按标注及坐标建模，禁止按图片比例量取',12)
    s.line(20,750,W-20,750);s.line(20,82,W-20,82)
    s.text(38,60,'载带检测支架 / 木板＋小打印件',12);s.text(38,38,'设计：AI参数化生成；审核/试装：待完成；日期：2026-09-09',10)
    s.text(625,60,'状态：试制，未发布量产；无实物承重、光学或整机干涉验收',11,'#975127');s.text(965,38,f'图册 {page}/{total}',10)

def make_sheets(parts,out):
    total=len(parts)+2;c=canvas.Canvas(str(out/'零件三视工程图_R1_试制.pdf'),pagesize=(W,H));c.setTitle('载带检测支架 零件三视工程图 R1 试制')
    s=Sheet(c);frame(s,'图册说明、木板尺寸与打印清单',1,total)
    lines=[
    '本图册含8种实体零件，分别给正视、俯视、右视、孔槽坐标和STEP；不再使用旧的仅外形占位图。',
    '重要边界：这是按用户允许的假设形成的试制图，不是已通过实物验证的工业生产发布图。',
    '已知：板/亚克力130×90；机身420×110×80；灯90/40/22；镜头外径14、高18.3。',
    '假设：亚克力厚1、镜头偏心20、工作距离默认100；主体仍需实拍与试装后调整。',
    '材料：打印件PETG，先打印小试件；木板统一12厚胶合板。打印尺寸能力按至少200×200×200准备。',
    '建议试制验收：打印件一般外形±0.3、孔中心±0.2，配合孔槽先试片；这是目标，不是打印设备精度保证。',
    '全部Ø4.5为M4间隙孔；打印后按试片检查/清孔。槽标总长，圆头R2.25；去毛刺锐边，不擅改接触面。',
    '每页三视共用比例；模型局部原点见坐标说明；孔轴方向以X/Y/Z明确标出。虚线为隐藏轮廓。',
    '托臂中心保持X=±65。P02宽64，板中心−20时，右承托名义重叠12，左52；固定前仍须检查实物接触。']
    y=717
    for line in lines:s.text(40,y,line,12);y-=27
    s.text(40,442,'木板大致下料尺寸（孔位试装后再钻）',16)
    wood=[('W01','底板','650×350×12','1'),('W02','立板','300×360×12','1'),('W03','三角加强板','直角边120×200，厚12','2'),('W04','进/出料托板','100×100×12','2')]
    for i,row in enumerate(wood):
        yy=411-i*30
        for x,t in zip([45,125,285,560],row):s.text(x,yy,t,13)
    s.text(40,275,'托料脚不预切：按实际带面、载带下凸高度及12厚托板反算；底板+立板木结构高约372。',12)
    s.text(40,242,'打印数量',16)
    for i,p in enumerate(parts):
        col=i//4;row=i%4;s.text(45+col*560,211-row*27,f"{p['id']}  {p['name']}  ×{p['qty']}   /   "+'×'.join(f'{v:g}' for v in p['dims']),12)
    s.save(out/'00_说明与木板.svg');c.showPage()
    for i,p in enumerate(parts):
        s=Sheet(c);frame(s,f"{p['id']}  {p['name']} / 数量 {p['qty']} / {p['material']}",i+2,total)
        x,y,z=p['dims'];bx,by,bz,_,_,_=p['bounds'];scale=min(6,230/max(y,z),270/x,330/y)
        s.text(60,724,'俯视：沿−Z看，横向X，纵向Y',12);s.text(60,422,'正视：沿+Y看，横向X，纵向Z',12);s.text(640,422,'右视：沿−X看，横向Y，纵向Z',12)
        for view,(left,bottom,dx,dy,minx,miny) in {'top':(150,470,x,y,bx,by),'front':(150,145,x,z,bx,bz),'right':(650,145,y,z,by,bz)}.items():
            hidden,visible=project(p['model'].val(),view)
            for paths,dashed in [(hidden,True),(visible,False)]:
                for path in paths:
                    nums=[float(v) for v in re.findall(r'[-+]?(?:\d*\.\d+|\d+)(?:[eE][-+]?\d+)?',path)]
                    pts=[(left+(nums[k]-minx)*scale,bottom+(nums[k+1]-miny)*scale) for k in range(0,len(nums)-1,2)]
                    s.path(pts,dashed)
            s.dim(left,bottom,dx*scale,dy*scale,dx,dy)
        yy=715;s.text(570,yy,'尺寸与孔槽坐标（局部坐标，详见实体STEP）',14);yy-=26
        for line in p['notes']+p['features']:
            for ln in wrap(line,45):s.text(570,yy,ln,11);yy-=18
            yy-=5
        s.text(570,yy-2,f"实体包络起点：X={bx:g}，Y={by:g}，Z={bz:g}。",10)
        s.text(570,yy-22,f"同页比例约 {scale/2.8346457:.3f}:1；请以尺寸为准。",10)
        s.save(out/(p['id']+'_三视工程图.svg'));c.showPage()
    s=Sheet(c);frame(s,'试装顺序、紧固件与未完成验证',total,total)
    notes=[
    '1. 木板先按大外形下料；托臂仍左右对称。先摆实物、对光轴，再钻安装孔。',
    '2. P01两件；P02/P03各四件。板接触区朝内，固定螺栓放到亚克力板外侧，禁止挤压PCB。',
    '3. P02局部Y=0..14接触板；前后两组相向摆放。与P01两个长槽相配，默认留约±10前后微调。',
    '4. P04安装X=±100，不与相机托臂根部重叠。P05根部各用两根螺栓穿P04长槽锁紧。',
    '5. P06A/B从灯外壳侧面夹持，初始分缝2；薄软垫试配，不能夹LED、线口或镜头。',
    '6. P07四件连接灯圈的X=±48安装孔与X=±100灯托臂；名义中心距52，均位于灯背面。',
    '7. 灯圈夹紧、防滑确认后再装P07；确认线口是否需避让。夹不牢时停用此夹圈，不能强拧损伤灯壳。',
    '8. 本图册验证了8件实体有效性、单实体、包络尺寸；没有完成整机各调节位置的干涉或强度验证。',
    '9. 40—200只是目标工作距离范围，灯厚22会限制近距离布局；先试拍，再限定有效调节行程。',
    '10. 载带导向件待样带轮廓确定。本图册覆盖相机承托与灯架，不把未知载带导向图伪装成定稿。']
    yy=713
    for note in notes:s.text(40,yy,note,12);yy-=29
    s.text(40,390,'M4紧固件建议备料（不含木角码与设备固定）',16)
    rows=[('P01根部/木板','4套 M4×30','根部10＋木板12＋垫片/螺母'),('P01+P02+P03','8套 M4×40','10＋10＋8＋垫片/螺母；核实露出'),('P04/木板','4套 M4×35','导板12＋木板12＋垫片/螺母'),('P05/P04','4套 M4×35','根部12＋导板12＋垫片/螺母'),('P06两半夹紧','2套 M4×35','两夹耳12＋12＋分缝2＋垫片/螺母'),('P07/P06','4套 M4×35','连接片8＋灯圈16＋垫片/螺母'),('P07/P05','4套 M4×30','连接片8＋托臂12＋垫片/螺母')]
    for j,row in enumerate(rows):
        for xx,t in zip([45,285,515],row):s.text(xx,358-j*28,t,12)
    s.text(40,143,'共30套：M4×30 8根、×35 14根、×40 8根；M4螺母30、大垫片60，备料可加约20%。',12)
    s.text(40,119,'默认螺母；可在调节处换手拧件，但其实际厚度会改变所需螺栓长度。先核对再整批采购。',11)
    s.save(out/'09_装配与采购.svg');c.showPage();c.save()
    files=['00_说明与木板.svg']+[p['id']+'_三视工程图.svg' for p in parts]+['09_装配与采购.svg']
    doc='<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>零件工程图R1</title><style>body{font-family:Microsoft YaHei,sans-serif;background:#edf2f3;max-width:1250px;margin:20px auto}header{padding:18px}section{background:white;margin:18px 0;padding:8px}img{width:100%;height:auto}a{color:#087c6c}</style><header><h1>零件三视工程图 R1</h1><p>8种真实实体零件，逐件三视、孔槽坐标、材料和数量。试制版，尚未实物验收。</p><p><a href="零件三视工程图_R1_试制.pdf">下载PDF图册</a></p></header>'
    for f in files:doc+=f'<section><img src="{f}" alt="{f}"></section>'
    (out/'零件图册_浏览.html').write_text(doc+'</html>',encoding='utf8')
    print('PDF/SVG/HTML sheets complete',flush=True)
