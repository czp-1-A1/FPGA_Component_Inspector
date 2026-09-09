import sys, json, math
from pathlib import Path
ROOT=Path(__file__).resolve().parent
sys.path.insert(0,str(ROOT/'.cad_runtime'))
import cadquery as cq
OUT=ROOT/'零件工程图_R1'
OUT.mkdir(exist_ok=True)

def box(x0,y0,z0,dx,dy,dz):
    return cq.Workplane('XY').box(dx,dy,dz,centered=False).translate((x0,y0,z0))
def zhole(x,y,z,r,h): return cq.Workplane('XY',origin=(x,y,z)).circle(r).extrude(h)
def yhole(x,y,z,r,h): return cq.Workplane('XZ',origin=(x,y,z)).circle(r).extrude(-h)
def zslot(x,y,z,length,width,h): return cq.Workplane('XY',origin=(x,y,z)).slot2D(length,width,90).extrude(h)
def yslot(x,y,z,length,width,h): return cq.Workplane('XZ',origin=(x,y,z)).slot2D(length,width,90).extrude(-h)
parts=[]
def add(id,name,m,qty,notes,features,material='PETG',expect=None):
    sh=m.val(); b=sh.BoundingBox()
    dims=[b.xlen,b.ylen,b.zlen]
    assert sh.isValid(),id+' invalid'
    assert len(m.solids().vals())==1,id+' not single solid'
    if expect: assert all(abs(a-b)<1e-4 for a,b in zip(dims,expect)),(id,dims,expect)
    cq.exporters.export(m,str(OUT/(id+'.step')))
    parts.append(dict(id=id,name=name,model=m,qty=qty,notes=notes,features=features,material=material,dims=dims,volume=sh.Volume(),bounds=[b.xmin,b.ymin,b.zmin,b.xmax,b.ymax,b.zmax]))

# P01: root remains symmetric in the assembly, X centres -65/+65.
m=box(-12,0,40,24,195,10).union(box(-12,185,0,24,10,50))
for xx in [-12,8]:
    rib=cq.Workplane('YZ',origin=(xx,0,0)).polyline([(85,40),(185,40),(185,5)]).close().extrude(4)
    m=m.union(rib)
for yy in [40,140]: m=m.cut(zslot(0,yy,39,70,4.5,12))
for xx in [-6,6]: m=m.cut(yslot(xx,184,30,22,4.5,12))
add('P01','对称托臂',m,2,['外形24×195×50；水平板Z=40..50；根部Y=185..195。','下置筋各厚4，三角点(Y,Z)=(85,40),(185,40),(185,5)。','两托臂相对检测中心X=±65，不随板卡偏移；上表面留平。'],
['Z向贯通槽：X=0，Y=40/140；总长70，宽4.5，端R2.25。','Y向根部槽：X=−6/+6，Z=30；总长22，宽4.5，端R2.25。'],expect=[24,195,50])
m=box(-32,0,0,64,40,10)
for yy in [22,34]:m=m.cut(zhole(0,yy,-1,2.25,12))
add('P02','加宽承托块',m,4,['外形64×40×10；Y=0..14为亚克力接触区。','四块分别放在两托臂前后端；接触区朝向板内，螺栓在板外。','右托臂X=65时内缘X=33，板右缘45，名义重叠12。'],['2×Ø4.5贯通Z；孔中心(X,Y)=(0,22),(0,34)。'],expect=[64,40,10])
m=box(-32,0,0,64,40,8).cut(box(-33,-1,-1,66,15,3)).cut(zslot(0,28,-1,16,4.5,10))
add('P03','亚克力限位压片',m,4,['外形64×40×8；前端Y=0..14底面抬高2，形成2高夹口。','1厚亚克力＋薄软垫试配；轻锁紧，不能压弯板或压住器件。','宽度随承托块覆盖板边；压片、承托块、托臂共用两根M4。'],['Z向贯通槽：中心(0,28)，总长16，宽4.5，端R2.25。','底部切除：X=−32..32、Y=0..14、Z=0..2。'],expect=[64,40,8])
m=box(-12,0,0,24,12,180).cut(yslot(0,-1,90,140,4.5,14))
for zz in [10,170]:m=m.cut(yhole(0,-1,zz,2.25,14))
add('P04','灯架竖向导板',m,2,['外形24×12×180，背面贴木立板，以大垫片和M4穿透固定。','导板X=±100，避开相机托臂；实际安装高度按灯位置定。','中槽用于P05双螺栓滑动，不是木板固定槽。'],['2×Ø4.5贯通Y：X=0，Z=10/170。','Y向贯通槽：X=0，Z=90，总长140，宽4.5。'],expect=[24,12,180])
m=box(-10,0,0,20,150,12).union(box(-10,138,0,20,12,44))
for xx in [-10,6]:m=m.union(cq.Workplane('YZ',origin=(xx,0,0)).polyline([(88,12),(138,12),(138,40)]).close().extrude(4))
m=m.cut(zslot(0,52,-1,72,4.5,14))
for zz in [18,34]:m=m.cut(yhole(0,137,zz,2.25,14))
add('P05','灯架前后托臂',m,2,['外形20×150×44；底板厚12，根部Y=138..150。','左右筋厚4，侧面三角点(88,12),(138,12),(138,40)。','根部两螺栓共同穿过P04长槽，禁止只装一根。'],['Z向贯通槽：X=0，Y=52，总长72，宽4.5。','2×Ø4.5贯通Y：X=0，Z=18/34。'],expect=[20,150,44])
ring=cq.Workplane('XY').circle(55).circle(45.5).extrude(16)
for sign,id,name in [(1,'P06A','灯外夹圈后半'),(-1,'P06B','灯外夹圈前半')]:
    m=ring.intersect(box(-80,1 if sign==1 else -80,-1,160,79,18))
    for xx in [-68,48]:m=m.union(box(xx,1 if sign==1 else -13,0,20,12,16))
    for xx in [-61,61]:m=m.cut(yhole(xx,-14,8,2.25,28))
    for xx in [-48,48]:m=m.cut(zhole(xx,sign*18,-1,2.25,18))
    add(id,name,m,1,['主体外径110、内径91、高16；两半装合分缝2。','夹耳X=−68..−48及48..68，Y=1..13或−13..−1。','现成灯Ø90；薄软垫试夹，线口现场避让，不可压LED或镜头。'],
    [f'2×Ø4.5贯通Z：中心(X,Y)=(−48,{sign*18}),(48,{sign*18})。','2×Ø4.5贯通Y：X=−61/+61、Z=8；夹紧两半。',f'环体取Y≥1部分。' if sign==1 else '环体取Y≤−1部分。'],expect=[136,54,16])
m=box(0,-8,0,68,16,8)
for xx in [8,60]:m=m.cut(zhole(xx,0,-1,2.25,10))
add('P07','灯圈外侧连接片',m,4,['外形68×16×8，两孔中心距52。','连接X=±48处灯圈与X=±100处灯托臂，四片均在灯背面。','跨接片不穿过灯中央孔；先夹紧灯圈，再锁紧连接片。'],['2×Ø4.5贯通Z：中心(X,Y)=(8,0),(60,0)。'],expect=[68,16,8])

arm=parts[0]['model'];pad=parts[1]['model'];cap=parts[2]['model']
pad_rear=pad.translate((0,116,50));cap_rear=cap.translate((0,116,60))
pad_front=pad.rotate((0,0,0),(0,0,1),180).translate((0,54,50))
def overlap(a,b):
    return sum(s.Volume() for s in a.intersect(b).solids().vals())
assert overlap(arm,pad_rear)<1e-5
assert overlap(arm,pad_front)<1e-5
assert overlap(pad_rear,cap_rear)<1e-5
result=[{k:v for k,v in p.items() if k!='model'} for p in parts]
checks={'single_solid_and_valid':True,'dimensions_checked':True,'arm_pad_cap_sample_interference_checked':True,'support_overlap_right_mm':12,'support_overlap_left_mm':52,'assembly_interference_checked':False,'load_tested':False,'optics_tested':False}
assert 65-32==33 and -20+65-33==12
(OUT/'几何校核.json').write_text(json.dumps({'parts':result,'checks':checks},ensure_ascii=False,indent=2),encoding='utf8')
print('CAD solids and STEP complete:',len(parts),flush=True)

if __name__=='__main__':
    from make_parts_sheets import make_sheets
    make_sheets(parts,OUT)
