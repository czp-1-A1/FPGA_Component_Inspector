"""Independent PTRACE math from captured post-ISP pixels and public objects.

No simulator hierarchy, internal RAM image or DUT formatter is evaluated.
Object geometry/population is first matched to a separate 4-connected CCL.
"""
from collections import deque
import numpy as np
GX=np.array([[-1,0,1],[-2,0,2],[-1,0,1]],dtype=np.int64)
GY=GX.T

def components(a,threshold):
    remaining=set(zip(*np.where(a>=threshold)[::-1]));result=[]
    while remaining:
        seed=remaining.pop();todo=deque([seed]);group=[seed]
        while todo:
            x,y=todo.popleft()
            for other in ((x-1,y),(x+1,y),(x,y-1),(x,y+1)):
                if other in remaining:
                    remaining.remove(other);todo.append(other);group.append(other)
        result.append((min(x for x,y in group),max(x for x,y in group),
                       min(y for x,y in group),max(y for x,y in group),len(group)))
    return result

def verify(image,word,objects):
    assert image.shape==(720,1280)
    if not word:
        assert not any((objects>>(76*i+75))&1 and ((objects>>(76*i+73))&3)==2 for i in range(4))
        return {'selected':False}
    assert word>>124==1 and (word>>123)&1
    region=(word>>122)&1;slot=(word>>120)&3;weak=bool((word>>119)&1)
    assert slot<2
    ob=(objects>>(76*(2*region+slot)))&((1<<76)-1)
    assert (ob>>75)&1 and ((ob>>73)&3)==2
    reason=(ob>>69)&15;assert reason==(word>>14)&15
    x0=(((ob>>31)&2047)+2)//2;y0=(((ob>>10)&1023)+2)//2
    width=((ob>>49)&127)//2;height=((ob>>42)&127)//2
    x1=x0+width-1;y1=y0+height-1;cx=x0+width//2;cy=y0+height//2
    assert (word>>12)&3==((y0&1)*2+(x0&1))
    avg=image.astype(np.int64).reshape(360,2,640,2).sum((1,3))//4
    fg=(ob>>56)&8191
    assert (x0,x1,y0,y1,fg//4) in components(avg,80 if weak else 100)
    in_cache=x0>=193 and x1+1<448 and y0>=113 and y1+1<308
    body=width>=16 and height>=16 and cx>=200 and cx+8<=448 and cy>=120 and cy+8<=308
    eligible=in_cache and body
    if weak:
        assert not ((word>>118)&1) and ((word>>110)&255)==128
        assert ((word>>18)&((1<<92)-1))==0
        return {'selected':True,'region':region,'slot':slot,'weak':True,'reason':reason,'measured':False}
    if not eligible:
        assert not ((word>>118)&1)
        assert ((word>>110)&255)==int(not in_cache)*16+int(not body)*64
        assert ((word>>18)&((1<<92)-1))==0
        return {'selected':True,'region':region,'slot':slot,'weak':False,'reason':reason,'measured':False}
    q=avg>>3
    blocks=(q[cy-4:cy+4,cx-4:cx+4],q[cy-4:cy+4,cx-8:cx-4],
            q[cy-4:cy+4,cx+4:cx+8],q[cy-8:cy-4,cx-4:cx+4],q[cy+4:cy+8,cx-4:cx+4])
    sums=[int(b.sum()) for b in blocks]
    gradients=[]
    for side,(x,y) in enumerate(((x0,cy),(x1,cy),(cx,y0),(cx,y1))):
        patch=q[y-1:y+2,x-1:x+2]
        gx=int((patch*GX).sum());gy=int((patch*GY).sum())
        gradients.append((gx,-gx,gy,-gy)[side])
    cm=sums[0]//64;edge_min=min(n//32 for n in sums[1:]);good=sum(g>=8 for g in gradients)
    fail=int(cm<13)|(int(edge_min*5<cm*4)<<1)|(int(max(sums[1:])*2>sums[0]+16)<<2)|(int(good<3)<<3)
    expected=0
    for value,bits in ((sums[0],11),*((n,10) for n in sums[1:]),
                       *((g&511,9) for g in gradients),(good,3),(int((fail&7)==0),1),
                       (int(fail==0),1),(1,1),(fail,8)):
        expected=(expected<<bits)|value
    actual=(((word>>99)&2047)<<90)|(((word>>59)&((1<<40)-1))<<50)|(((word>>23)&((1<<36)-1))<<14)|(((word>>20)&7)<<11)|(((word>>19)&1)<<10)|(((word>>18)&1)<<9)|(((word>>118)&1)<<8)|((word>>110)&255)
    assert actual==expected,(f'actual={actual:026x}',f'expected={expected:026x}')
    assert bool(reason&8)==bool(fail)
    return {'selected':True,'region':region,'slot':slot,'weak':False,'reason':reason,
            'measured':True,'sums':sums,'signed_gradients':gradients,'failure_mask':fail}
