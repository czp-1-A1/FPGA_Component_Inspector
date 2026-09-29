def hex_prism(c,name,axis,start,depth,u,v,af,op=OP.NewBodyFeatureOperation):
    sk,p,ce,sign=sketch(c,axis,start,name+'_sketch')
    coords=[]
    for i in range(6):
        a=math.pi*i/3
        ca=round(math.cos(a)/math.sqrt(3),12);sa=round(math.sin(a)/math.sqrt(3),12)
        coords.append((plus(u,str(ca)+'*('+E(af)+')'),plus(v,str(sa)+'*('+E(af)+')')))
    pts=[p(u,v) for u,v in coords];ls=[]
    for i in range(6):
        startpt=pts[0] if i==0 else ls[-1].endSketchPoint
        endpt=pts[i+1] if i<5 else ls[0].startSketchPoint
        ls.append(sk.sketchCurves.sketchLines.addByTwoPoints(startpt,endpt))
    for l,(u,v) in zip(ls,coords):anchor(sk,l.startSketchPoint,ce(u,v,0),ce(u,v,1))
    return extrude(c,sk,sign,depth,op,name)

def fastener_group(code,axis,u,v,low,high,length,copies,head='high',washerod=9):
    shaft=minus(plus(high,.8),length) if head=='high' else minus(low,.8)
    headstart=plus(high,.8) if head=='high' else minus(low,4.8)
    nutstart=minus(low,4) if head=='high' else plus(high,.8)
    specs=[('Bolt_M4x'+str(length),'bolt',shaft),('Nut_M4','nut',nutstart),('Washer_head_M4','washer',high if head=='high' else minus(low,.8)),('Washer_nut_M4','washer',minus(low,.8) if head=='high' else high)]
    for label,kind,z in specs:
        x,y,zz,rot=copies[0]
        c,o=component('H_'+code+'_'+label,x,y,zz,rot)
        c.attributes.add('R2','material','STEEL_PURCHASED_NOMINAL_ENVELOPE')
        if kind=='bolt':
            cylinder(c,'Shank_threads_simplified',axis,z,length,u,v,4)
            cylinder(c,'Socket_head',axis,headstart,4,u,v,7,OP.JoinFeatureOperation)
            c.attributes.add('R2','geometry_note','Purchased screw envelope; thread and hex socket omitted')
        elif kind=='nut':
            cylinder(c,'Hex_nut_conservative_circumscribed_envelope',axis,z,3.2,u,v,8.1,inner=4)
            c.attributes.add('R2','geometry_note','M4 AF7 nut represented by conservative OD8.1 envelope')
        else:cylinder(c,'Flat_washer',axis,z,.8,u,v,washerod,inner=4.5)
        for x,y,zz,rot in copies[1:]:instance(c,x,y,zz,rot)
