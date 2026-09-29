import adsk.core, adsk.fusion, json, math

APP=adsk.core.Application.get()
D=adsk.fusion.Design.cast(APP.activeProduct)
V=adsk.core.ValueInput
P=adsk.core.Point3D
OP=adsk.fusion.FeatureOperations
HOR=adsk.fusion.DimensionOrientations.HorizontalDimensionOrientation
VER=adsk.fusion.DimensionOrientations.VerticalDimensionOrientation

def E(x):return str(x)+' mm' if isinstance(x,(int,float)) else x
def F(x):return D.unitsManager.evaluateExpression(E(x),'mm')
def plus(a,b):return '('+E(a)+')+('+E(b)+')'
def minus(a,b):return '('+E(a)+')-('+E(b)+')'
def neg(a):return '-('+E(a)+')'

def component(name,x=0,y=0,z=0,rotation=0):
    m=adsk.core.Matrix3D.create()
    if rotation:m.setToRotation(rotation,adsk.core.Vector3D.create(0,0,1),P.create())
    m.translation=adsk.core.Vector3D.create(x/10,y/10,z/10)
    occ=globals().get('PARENT',D.rootComponent).occurrences.addNewComponent(m)
    c=occ.component;c.name=name
    c.attributes.add('R2','status','PROTOTYPE_UNTESTED')
    c.attributes.add('R2','material','PETG' if name.startswith('P') else 'REFERENCE' if name.startswith('E') else 'PLYWOOD_12')
    return c,occ

def instance(c,x=0,y=0,z=0,rotation=0):
    m=adsk.core.Matrix3D.create()
    if rotation:m.setToRotation(rotation,adsk.core.Vector3D.create(0,0,1),P.create())
    m.translation=adsk.core.Vector3D.create(x/10,y/10,z/10)
    return globals().get('PARENT',D.rootComponent).occurrences.addExistingComponent(c,m)

def sketch(c,axis,start,name):
    datum={'z':c.xYConstructionPlane,'y':c.xZConstructionPlane,'x':c.yZConstructionPlane}[axis]
    normal=datum.geometry.normal
    sign={'z':normal.z,'y':normal.y,'x':normal.x}[axis]
    ci=c.constructionPlanes.createInput();ci.setByOffset(datum,V.createByString(E(start) if sign>0 else neg(start)))
    pl=c.constructionPlanes.add(ci);pl.name=name+'_datum';pl.isLightBulbOn=False
    sk=c.sketches.add(pl);sk.name=name
    # A global in-plane (u,v) pair is converted into the actual Fusion sketch basis.
    def point(u,v):
        w=F(start)
        xyz={'z':(F(u),F(v),w),'y':(F(u),w,F(v)),'x':(w,F(u),F(v))}[axis]
        return sk.modelToSketchSpace(P.create(*xyz))
    o=point(0,0);a=point(10,0);b=point(0,10)
    mapping=((round(a.x-o.x),round(b.x-o.x)),(round(a.y-o.y),round(b.y-o.y)))
    def coord_expr(u,v,i):
        q=mapping[i]
        e=E(u) if q[0] else E(v)
        return e if (q[0] or q[1])>0 else neg(e)
    return sk,point,coord_expr,sign

def anchor(sk,pt,ex,ey):
    g=pt.geometry
    ref=sk.sketchPoints.add(P.create(-100,-100,0));ref.isFixed=True
    sk.sketchDimensions.addDistanceDimension(ref,pt,HOR,P.create(g.x/2,g.y-.4,0)).parameter.expression='1000 mm+('+ex+')'
    sk.sketchDimensions.addDistanceDimension(ref,pt,VER,P.create(g.x-.4,g.y/2,0)).parameter.expression='1000 mm+('+ey+')'

def rectangle(sk,point,ce,u,v,du,dv):
    pts=[point(u,v),point(plus(u,du),v),point(plus(u,du),plus(v,dv)),point(u,plus(v,dv))]
    lines=sk.sketchCurves.sketchLines
    ls=[lines.addByTwoPoints(pts[0],pts[1])]
    for k in [1,2]:ls.append(lines.addByTwoPoints(ls[-1].endSketchPoint,pts[k+1]))
    ls.append(lines.addByTwoPoints(ls[-1].endSketchPoint,ls[0].startSketchPoint))
    for l in ls:
        a=l.startSketchPoint.geometry;b=l.endSketchPoint.geometry
        (sk.geometricConstraints.addHorizontal if abs(a.y-b.y)<1e-7 else sk.geometricConstraints.addVertical)(l)
    anchor(sk,ls[0].startSketchPoint,ce(u,v,0),ce(u,v,1))
    for k,expr in [(0,du),(1,dv)]:
        l=ls[k];a=l.startSketchPoint.geometry;b=l.endSketchPoint.geometry
        orient=HOR if abs(a.y-b.y)<1e-7 else VER
        sk.sketchDimensions.addDistanceDimension(l.startSketchPoint,l.endSketchPoint,orient,P.create((a.x+b.x)/2-.3,(a.y+b.y)/2-.3,0)).parameter.expression=E(expr)

def circle(sk,point,ce,u,v,diam):
    p=point(u,v)
    c=sk.sketchCurves.sketchCircles.addByCenterRadius(p,F(diam)/2)
    anchor(sk,c.centerSketchPoint,ce(u,v,0),ce(u,v,1))
    sk.sketchDimensions.addDiameterDimension(c,P.create(p.x+.4,p.y+.4,0)).parameter.expression=E(diam)

def extrude(c,sk,sign,depth,op,name):
    sk.isComputeDeferred=False
    profiles=adsk.core.ObjectCollection.create()
    for pr in sk.profiles:profiles.add(pr)
    assert profiles.count>0,name+' no profiles'
    ei=c.features.extrudeFeatures.createInput(profiles,op)
    if op==OP.CutFeatureOperation:ei.participantBodies=[b for b in c.bRepBodies]
    ei.setDistanceExtent(False,V.createByString(E(depth) if sign>0 else neg(depth)))
    ft=c.features.extrudeFeatures.add(ei);ft.name=name
    sk.isLightBulbOn=False
    return ft

def box(c,name,x,y,z,dx,dy,dz,op=OP.NewBodyFeatureOperation):
    sk,p,ce,sign=sketch(c,'z',z,name+'_sketch')
    rectangle(sk,p,ce,x,y,dx,dy)
    return extrude(c,sk,sign,dz,op,name)

def holes(c,name,axis,start,depth,centers,diam='slot_d'):
    for i,(u,v) in enumerate(centers):
        sk,p,ce,sign=sketch(c,axis,start,name+'_'+str(i+1)+'_sketch')
        circle(sk,p,ce,u,v,diam)
        ft=extrude(c,sk,sign,depth,OP.CutFeatureOperation,name+'_'+str(i+1))
    return ft

def cylinder(c,name,axis,start,depth,u,v,diam,op=OP.NewBodyFeatureOperation,inner=None):
    if inner:
        ft=cylinder(c,name,axis,start,depth,u,v,diam,op)
        holes(c,name+'_bore',axis,start,depth,[(u,v)],inner)
        return ft
    sk,p,ce,sign=sketch(c,axis,start,name+'_sketch');circle(sk,p,ce,u,v,diam)
    return extrude(c,sk,sign,depth,op,name)

def slots(c,name,axis,start,depth,centers,length,width='slot_d',direction='v'):
    for i,(u,v) in enumerate(centers):
        sk,p,ce,sign=sketch(c,axis,start,name+'_'+str(i)+'_sketch')
        h='('+E(length)+'-'+E(width)+')/2'
        if direction=='v':
            rectangle(sk,p,ce,minus(u,'('+E(width)+')/2'),minus(v,h),width,'2*('+h+')')
            ends=[(u,minus(v,h)),(u,plus(v,h))]
        else:
            rectangle(sk,p,ce,minus(u,h),minus(v,'('+E(width)+')/2'),'2*('+h+')',width)
            ends=[(minus(u,h),v),(plus(u,h),v)]
        extrude(c,sk,sign,depth,OP.CutFeatureOperation,name+'_'+str(i)+'_middle')
        ft=holes(c,name+'_'+str(i)+'_ends',axis,start,depth,ends,width)
    return ft

def triangle(c,name,axis,start,depth,u,v,du,dv,op=OP.NewBodyFeatureOperation):
    sk,p,ce,sign=sketch(c,axis,start,name+'_sketch')
    pts=[p(u,v),p(plus(u,du),v),p(u,plus(v,dv))]
    lines=sk.sketchCurves.sketchLines
    a=lines.addByTwoPoints(pts[0],pts[1]);b=lines.addByTwoPoints(a.endSketchPoint,pts[2]);q=lines.addByTwoPoints(b.endSketchPoint,a.startSketchPoint)
    for l in [a,q]:
        x=l.startSketchPoint.geometry;y=l.endSketchPoint.geometry
        (sk.geometricConstraints.addHorizontal if abs(x.y-y.y)<1e-7 else sk.geometricConstraints.addVertical)(l)
    anchor(sk,a.startSketchPoint,ce(u,v,0),ce(u,v,1))
    for l,expr in [(a,du),(q,dv)]:
        x=l.startSketchPoint.geometry;y=l.endSketchPoint.geometry
        sk.sketchDimensions.addDistanceDimension(l.startSketchPoint,l.endSketchPoint,HOR if abs(x.y-y.y)<1e-7 else VER,P.create(x.x-.4,x.y-.4,0)).parameter.expression='abs('+E(expr)+')'
    return extrude(c,sk,sign,depth,op,name)

def report(label):
    D.computeAll()
    items=[]
    for o in D.rootComponent.occurrences:
        b=o.boundingBox
        items.append({'name':o.name,'bodies':o.component.bRepBodies.count,'bbox_mm':[round(v*10,3) for v in [b.minPoint.x,b.minPoint.y,b.minPoint.z,b.maxPoint.x,b.maxPoint.y,b.maxPoint.z]]})
    errs=[{'name':D.timeline.item(i).name,'message':getattr(D.timeline.item(i).entity,'errorOrWarningMessage','')} for i in range(D.timeline.count) if getattr(D.timeline.item(i).entity,'healthState',0)!=0]
    print(json.dumps({'stage':label,'occurrences':items,'timeline_count':D.timeline.count,'unhealthy':errs},ensure_ascii=False))
    APP.activeViewport.fit();APP.activeViewport.refresh()
