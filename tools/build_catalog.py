#!/usr/bin/env python3
"""Generate low-poly, smoothly contoured mannequin parts with rigid bone bindings.

    python3 tools/build_catalog.py            # data/piezas/ (all profiles; colliders of every profile)
    python3 tools/build_catalog.py --lod hd   # data/piezas_hd/ (Ultra's visible meshes, docs/futuro/17)

The hd level only multiplies the sides of every cross-section (8 -> 18); shapes, bones and colour
zones are identical, and catalogo.json keeps pointing at the base pieces."""
import json
import math
import sys
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
CATALOG = ROOT / 'data/catalogo.json'
cat = json.loads(CATALOG.read_text())
HD = '--lod' in sys.argv and sys.argv[sys.argv.index('--lod')+1] == 'hd'
if HD:
    # data/piezas_hd/ now comes from Blender (tools/blender/build_characters.py, docs/futuro/18):
    # regenerating it here would overwrite the Blender mannequins, clothes and wigs.
    sys.exit('data/piezas_hd/ se genera con Blender: blender -b --factory-startup -P tools/blender/build_characters.py')
PIECES = 'data/piezas_hd' if HD else 'data/piezas'
(ROOT/PIECES).mkdir(exist_ok=True)

def S(n):
    """Sides of a cross-section at this level of detail."""
    return round(n*2.25) if HD else n

def loft_mesh(rings, segments=8):
    """Elliptical cross sections (y, half-width, half-depth, z-offset), smooth normals."""
    vertices, normals, indices = [], [], []
    for k,(y,rx,rz,cz) in enumerate(rings):
        lo,hi=rings[max(0,k-1)],rings[min(len(rings)-1,k+1)]
        dy=max(.00001,hi[0]-lo[0])
        for i in range(segments):
            a=math.tau*i/segments
            sn,cs=math.sin(a),math.cos(a)
            vertices.append([rx*sn,y,cz-rz*cs])
            tx,tz=rx*cs,rz*sn
            vy=(hi[1]-lo[1])*sn/dy
            vz=(hi[3]-lo[3]-(hi[2]-lo[2])*cs)/dy
            normal=[tz,tx*vz-tz*vy,-tx]
            length=math.sqrt(sum(v*v for v in normal))
            normals.append([v/length for v in normal])
    for k in range(len(rings)-1):
        for i in range(segments):
            a=k*segments+i; b=k*segments+(i+1)%segments
            indices.extend([a,a+segments,b+segments,a,b+segments,b])
    for k,sign in [(0,-1),(len(rings)-1,1)]:
        center=len(vertices)
        y,rx,rz,cz=rings[k]
        vertices.append([0,y,cz]);normals.append([0,sign,0])
        for i in range(segments):
            a=k*segments+i;b=k*segments+(i+1)%segments
            indices.extend([center,a,b] if sign<0 else [center,b,a])
    indices=sum(([indices[i],indices[i+2],indices[i+1]] for i in range(0,len(indices),3)),[])
    return dict(vertices=vertices,normals=normals,indices=indices)

def strip_mesh(rings, a0, a1, steps=2, lift=1.03, double=True):
    """A band of a loft between two angles (0 = front, towards -z): straps over the shoulders, the
    open tails of a coat. Slightly outside the surface it follows; both faces if `double`."""
    vertices,normals,tris=[],[],[]
    for r,(y,rx,rz,cz) in enumerate(rings):
        # (a0 may be a list, one half-opening per ring: a coat that closes at the belt and opens below.)
        lo=a0[r] if isinstance(a0,(list,tuple)) else a0
        hi=math.tau-lo if isinstance(a0,(list,tuple)) else a1
        for i in range(steps+1):
            a=lo+(hi-lo)*i/steps
            sn,cs=math.sin(a),math.cos(a)
            vertices.append([rx*sn*lift,y,cz-rz*cs*lift])
            length=max(.0001,math.hypot(rz*sn,rx*cs))
            normals.append([rz*sn/length,0,-rx*cs/length])
    w=steps+1
    for k in range(len(rings)-1):
        for i in range(steps):
            a,b,c,d=k*w+i,k*w+i+1,(k+1)*w+i,(k+1)*w+i+1
            tris+=[(a,b,d),(a,d,c)]
    indices=oriented(vertices,normals,tris)
    if double: indices+=sum(([indices[i],indices[i+2],indices[i+1]] for i in range(0,len(indices),3)),[])
    return dict(vertices=vertices,normals=normals,indices=indices)

def oriented(vertices, normals, triangles):
    """Orders each triangle the way loft_mesh does (Godot front faces: cross product against the normal)."""
    indices=[]
    for a,b,c in triangles:
        p,q,r=vertices[a],vertices[b],vertices[c]
        u=[q[k]-p[k] for k in range(3)];v=[r[k]-p[k] for k in range(3)]
        cross=[u[1]*v[2]-u[2]*v[1],u[2]*v[0]-u[0]*v[2],u[0]*v[1]-u[1]*v[0]]
        n=[normals[a][k]+normals[b][k]+normals[c][k] for k in range(3)]
        indices.extend([a,b,c] if sum(cross[k]*n[k] for k in range(3))<0 else [a,c,b])
    return indices

def visor_mesh(head, cz, steps=None, spread=math.radians(78)):
    """Curved cap peak: starts on the scalp over the forehead and only projects forwards,
    dipping slightly at the tip, with a thin rim so it reads from the side."""
    steps=steps or S(6)
    rows=[]
    for i in range(steps+1):
        a=-spread+2*spread*i/steps
        sn,cs=math.sin(a),math.cos(a)
        inner=[head*.385*sn,head*.735,cz-head*.405*cs]
        reach=head*(.06+.23*cs**1.5)
        outer=[inner[0]*1.05,head*(.735-.09*cs),inner[2]-reach]
        rows.append((inner,outer))
    t=head*.022
    vertices,normals,tris=[],[],[]
    for sign in (1,-1):
        base=len(vertices)
        for inner,outer in rows:
            for p in (inner,outer):
                vertices.append([p[0],p[1]+(t*.5 if sign>0 else -t*.5),p[2]]);normals.append([0,sign,0])
        for i in range(steps):
            a,b,c,d=base+2*i,base+2*i+1,base+2*i+2,base+2*i+3
            tris+=[(a,b,d),(a,d,c)]
    base=len(vertices)
    for inner,outer in rows:
        dx,dz=outer[0]-inner[0],outer[2]-inner[2]
        length=max(.0001,math.hypot(dx,dz))
        for dy in (t*.5,-t*.5):
            vertices.append([outer[0],outer[1]+dy,outer[2]]);normals.append([dx/length,0,dz/length])
    for i in range(steps):
        a,b,c,d=base+2*i,base+2*i+1,base+2*i+2,base+2*i+3
        tris+=[(a,b,d),(a,d,c)]
    return dict(vertices=vertices,normals=normals,indices=oriented(vertices,normals,tris))

# Wooden mannequin finishes (docs/futuro/02_ESTILO_VISUAL_Y_POLIGONOS.md, 3.1). The trait keeps its
# 'skin' keys so casting draws stay identical; person.gd paints the body with the mapped wood.
cat['tonos_madera']={'arce':'d8b27f','haya':'c79463','roble':'a8744a','nogal':'76492e'}
cat.setdefault('madera_por_tono',{'clara':'arce','media':'haya','morena':'roble','oscura':'nogal'})
# Street-shoe palette; picked per person from its traits (scripts/person.gd), not a predicate.
cat.setdefault('tonos_calzado',{'negro':'26282b','marrón':'5b3a26','blanco':'e3dfd4','gris':'62676d'})
JOINT=.22
for profile in cat['perfiles']:
    h,w,ratio,j=(profile[k] for k in ('altura','hombros','relacion_cabeza','radio'))
    nz,head=h-h/ratio,h/ratio
    shoulder=w/2-j
    all_pieces=[]
    for slot,entries in [('cuerpo',[dict(id='cuerpo',etiqueta=profile['etiqueta'],genero='m',zona_color='piel',zonas=['piel'])]),*cat['piezas'].items()]:
        for index,piece in enumerate(entries):
            geometry=[]
            def shape(kind,bone,color,**kwargs): geometry.append(dict(type=kind,bone=bone,color=color,**kwargs))
            def ball(bone,pos,size,color,**kwargs): shape('ellipsoid',bone,color,position=pos,size=size,**kwargs)
            def seg(bone,a,b,ra,rb,color,**kwargs): shape('segment',bone,color,a=a,b=b,radius_a=ra,radius_b=rb,**kwargs)
            def loft(bone,rings,color,segments=8,**kwargs):
                segments=S(segments)
                mesh=loft_mesh(rings,segments)
                if bone not in ('cabeza','mano.I','mano.D','pie.I','pie.D'):
                    mesh['indices']=mesh['indices'][:-segments*6]
                shape('mesh',bone,color,**mesh,**kwargs)
            def patch(bone,points,color,**kwargs):
                # Small cloth panels sit over the curved body, without thick floating boxes.
                points=[[x,y,z-nz*.004] for x,y,z in points]
                a,b,c=points[:3]
                u=[b[k]-a[k] for k in range(3)];v=[c[k]-a[k] for k in range(3)]
                n=[u[1]*v[2]-u[2]*v[1],u[2]*v[0]-u[0]*v[2],u[0]*v[1]-u[1]*v[0]]
                length=max(.0001,math.sqrt(sum(t*t for t in n)))
                n=[t/length for t in n]
                # Point the normal away from the bone axis: mirrored panels came out facing inwards,
                # which the toon bands render as solid shadow.
                centre=[sum(p[k] for p in points)/len(points) for k in range(3)]
                if n[0]*centre[0]+n[2]*centre[2]<0: n=[-t for t in n]
                ids=[]
                for i in range(1,len(points)-1): ids.extend([0,i,i+1])
                # Front/back avoid disappearance of seams from grazing angles.
                ids+=sum(([ids[i],ids[i+2],ids[i+1]] for i in range(0,len(ids),3)),[])
                # Double-sided panels are left out of the ink outline: its hull pass would cover them.
                shape('mesh',bone,color,vertices=points,normals=[n]*len(points),indices=ids,collision=False,outline=False,**kwargs)
            if slot=='cuerpo':
                loft('cabeza',[(head*y,head*x,head*z,head*offset) for y,x,z,offset in [
                    (0,.17,.20,-.025),(.12,.28,.30,-.03),(.34,.36,.365,-.015),
                    (.64,.375,.395,.015),(.84,.31,.34,.025),(.96,.19,.23,.025),(1,.045,.06,.025)]],'piel',10)
                seg('cuello',[0,-nz*.025,0],[0,nz*.045,0],j*.82,j*.73,'piel')
                # Visible ball joints of the drawing mannequin, a shade darker than the wood.
                ball('cuello',[0,nz*.035,0],[j*1.9,j*1.3,j*1.9],'piel',darken=JOINT)
                for side in ['I','D']:
                    length=nz*.085
                    loft('mano.'+side,[(-length,j*.25,j*.23,-.004),(-length*.82,j*.57,j*.35,-.008),(-length*.32,j*.65,j*.40,0),(0,j*.50,j*.43,0)],'piel',6)
                    sign=-1 if side=='I' else 1
                    ball('mano.'+side,[sign*j*.59,-length*.32,-j*.08],[j*.6,length*.55,j*.57],'piel')
                    ball('mano.'+side,[0,0,0],[j*1.55]*3,'piel',darken=JOINT)
            elif slot=='torso':
                casual=piece['style'] in ('plain','hood')
                bulk=1.08 if piece['style']=='hood' else (1.07 if piece['style']=='coat' else 1.0)
                tank=piece['style']=='tank'
                # Waist, ribs, chest, rounded shoulders and a close-fitting neckline.
                trunk=[(nz*y,shoulder*x*bulk,shoulder*z*bulk,0) for y,x,z in [
                    (-.08,.72,.50),(-.015,.76,.53),(.10,.77,.56),(.19,.94,.59),
                    (.235,.92,.53),(.273,.47,.36),(.284,.30,.29)]]
                if tank:
                    # Tank top: the cloth stops under the arms; shoulders and upper chest are bare
                    # wood, with two straps over them.
                    cut=(nz*.205,shoulder*.935,shoulder*.565,0)
                    loft('lumbar',trunk[:4]+[cut],'tela_a')
                    loft('lumbar',[(nz*.200,shoulder*.925,shoulder*.555,0)]+trunk[4:],'piel')
                    loft('lumbar',[(nz*.197,shoulder*.945,shoulder*.575,0),(nz*.208,shoulder*.94,shoulder*.57,0)],'tela_a',8,darken=.18)
                    # Each strap keeps its distance from the neck: up the chest, over the slope of the
                    # shoulder (where the body is as wide as the strap is far out) and down the back.
                    lower,mid,high=cut,trunk[4],trunk[5]
                    for sx in (-1,1):
                        xt,half=shoulder*.42,shoulder*.10
                        left,right=[],[]
                        for x,row in ((xt-half,left),(xt+half,right)):
                            pts=[]
                            for (y,rx,rz,cz) in (lower,mid):
                                k=math.sqrt(max(0.0,1-min(1.0,(x/(rx*1.07))**2)))
                                pts.append((y,rz*1.07*k+.004))
                            t=min(1.0,max(0.0,(mid[1]-x)/(mid[1]-high[1])))
                            top=mid[0]+(high[0]-mid[0])*t+.006
                            # Two more samples on the slope, which bulges: a straight strap cut through it.
                            for u in (.45,.8):
                                rx=mid[1]+(high[1]-mid[1])*t*u;rz=mid[2]+(high[2]-mid[2])*t*u
                                k=math.sqrt(max(0.0,1-min(1.0,(x/(rx*1.07))**2)))
                                pts.append((mid[0]+(high[0]-mid[0])*t*u,rz*1.07*k+.004))
                            for y,z in pts: row.append([sx*x,y+.003,-z])
                            row.append([sx*x,top,0])
                            for y,z in reversed(pts): row.append([sx*x,y+.003,z])
                        vertices=left+right
                        m=len(left)
                        tris=[]
                        for i in range(m-1): tris+=[(i,i+1,m+i+1),(i,m+i+1,m+i)]
                        normals=[[0,.3,-1] if i%m<4 else ([0,1,0] if i%m==4 else [0,.3,1]) for i in range(2*m)]
                        ids=oriented(vertices,normals,tris)
                        ids+=sum(([ids[i],ids[i+2],ids[i+1]] for i in range(0,len(ids),3)),[])
                        shape('mesh','lumbar','tela_a',vertices=vertices,normals=normals,indices=ids,collision=False,outline=False)
                else:
                    loft('lumbar',trunk,'tela_a')
                # Hem and a narrow collar add the ink-like edges visible in the mockup.
                loft('lumbar',[(nz*-.081,shoulder*.726*bulk,shoulder*.51*bulk,0),(nz*-.07,shoulder*.74*bulk,shoulder*.52*bulk,0)],'tela_a',8,darken=.18)
                if not tank: loft('cuello',[(nz*.001,j*.99,j*.9,0),(nz*.013,j*.97,j*.88,0)],'tela_a',8,darken=.18)
                if piece['style']=='hood':
                    ball('cuello',[0,-nz*.034,nz*.06],[w*.48,nz*.13,nz*.13],'tela_a',darken=.12)
                if piece['style']=='coat':
                    # Trench coat: belt, and tails down to mid-thigh that hang from the hips, open
                    # in front so the legs walk through the gap instead of through the cloth.
                    loft('lumbar',[(nz*-.02,shoulder*.80*bulk,shoulder*.555*bulk,0),(nz*.012,shoulder*.80*bulk,shoulder*.56*bulk,0)],'tela_a',8,darken=.32)
                    # Wider than the trousers' seat and thighs at every height, with enough sides not to
                    # cut inside them (a seven-sided tail let the hips show through its flat faces),
                    # and open wide enough at the hem for a thigh to swing forward through the gap.
                    # They start above the trousers' waistband (which is wider than the coat's body) and
                    # only the lowest band, the one seen from inside through the gap, has two faces.
                    tails=[(nz*y,shoulder*x,shoulder*z,0) for y,x,z in [(.122,.90,.70),(.085,1.05,.98),(.03,1.16,1.04),(-.15,1.18,1.14)]]
                    shape('mesh','caderas','tela_a',**strip_mesh(tails[:3],[.06,.10,.50],None,S(12),1.0,False),collision=False,outline=False)
                    shape('mesh','caderas','tela_a',**strip_mesh(tails[2:],[.50,1.36],None,S(12),1.0),collision=False,outline=False)
                if piece['style'] in ('collar','lapel','coat'):
                    for sign in [-1,1]:
                        x=lambda value: sign*shoulder*value
                        # Lapels follow the chest contour into the centre of the garment.
                        patch('lumbar',[[x(.21),nz*.278,-shoulder*.29],[x(.54),nz*.244,-shoulder*.43],[x(.25),nz*(.12 if piece['style'] in ('lapel','coat') else .215),-shoulder*.585],[x(.04),nz*.233,-shoulder*.53]],'tela_a',lighten=.22)
                    patch('lumbar',[[-.006,nz*-.065,-shoulder*.535],[.006,nz*-.065,-shoulder*.535],[.006,nz*.22,-shoulder*.58],[-.006,nz*.22,-shoulder*.58]],'tela_a',darken=.28)
                    for sign in [-1,1]:
                        patch('lumbar',[[sign*shoulder*.3,nz*.025,-shoulder*.54],[sign*shoulder*.64,nz*.035,-shoulder*.47],[sign*shoulder*.64,nz*.05,-shoulder*.47],[sign*shoulder*.3,nz*.04,-shoulder*.54]],'tela_a',darken=.17)
                for side in ['I','D']:
                    arm,fore,sleeve=nz*.215,nz*.169,piece['sleeve']
                    if tank:
                        # Bare arm from the shoulder: ball joint and the whole upper arm in wood.
                        ball('brazo.'+side,[0,-j*.2,0],[j*2.3]*3,'piel',darken=JOINT)
                        loft('brazo.'+side,[(-arm,j*.84,j*.86,0),(-arm*.5,j*.98,j*1.0,0),(-j*.3,j*.94,j*.96,0)],'piel',6)
                        ball('antebrazo.'+side,[0,0,0],[j*2.4]*3,'piel',darken=JOINT)
                        loft('antebrazo.'+side,[(-fore,j*.66,j*.67,0),(-fore*.60,j*.90,j*.90,0),(-fore*.15,j*.96,j*.98,0),(0,j*.88,j*.91,0)],'piel',6)
                        continue
                    ball('brazo.'+side,[0,-j*.25,0],[j*1.95,j*1.7,j*2.0],'tela_a')
                    end=-arm*sleeve
                    loft('brazo.'+side,[(end,j*.95,j*.97,0),(end*.64,j*1.16,j*1.12,0),(-j*.1,j*1.10,j*1.10,0)],'tela_a',6)
                    if sleeve<1:
                        seg('brazo.'+side,[0,end+.004,0],[0,-arm,0],j*.9,j*.84,'piel')
                        loft('brazo.'+side,[(end-.004,j*.98,j*1.00,0),(end+.007,j*1.02,j*1.04,0)],'tela_a',6,darken=.16)
                    fc='tela_a' if sleeve==1 else 'piel'
                    ball('antebrazo.'+side,[0,0,0],[j*(2.4 if fc=='piel' else 1.90)]*3,fc,darken=JOINT if fc=='piel' else 0)
                    loft('antebrazo.'+side,[(-fore,j*.66,j*.67,0),(-fore*.60,j*.90,j*.90,0),(-fore*.15,j*.96,j*.98,0),(0,j*.88,j*.91,0)],fc,6)
                    if sleeve==1: loft('antebrazo.'+side,[(-fore,j*.70,j*.72,0),(-fore+.014,j*.73,j*.75,0)],'tela_a',6,darken=.17)
                if piece['style']=='sport':
                    for sign in [-1,1]:
                        patch('lumbar',[[sign*shoulder*.60,nz*.02,-shoulder*.55],[sign*shoulder*.70,nz*.02,-shoulder*.53],[sign*shoulder*.70,nz*.20,-shoulder*.55],[sign*shoulder*.60,nz*.20,-shoulder*.57]],'acento')
            elif slot=='piernas':
                short=piece['length']<1
                skirt=piece['style']=='skirt'
                n=S(8)
                pelvis=loft_mesh([(nz*y,shoulder*x,shoulder*z,0) for y,x,z in [(-.012,.93,.38),(.055,.96,.53),(.105,.80,.54)]],n)
                for i in range(n):
                    pelvis['vertices'][i][1]+=nz*.074*abs(math.sin(math.tau*i/n))
                pelvis['indices']=pelvis['indices'][:-n*6]
                shape('mesh','caderas','tela_b',**pelvis)
                for side in ['I','D']:
                    thigh=nz*(.542-.323);calf=nz*(.323-.03)
                    tc='piel' if skirt else 'tela_b'
                    # The concealed hip joint is inside the pelvis. Rounded ends overlap at the knee.
                    # Trouser thighs continue above the joint into the pelvis, filling the raised
                    # leg openings at the hips; under a skirt they would poke through its waist.
                    top=[] if skirt else [(nz*.075,j*1.40,j*1.44,0)]
                    loft('muslo.'+side,[(-thigh,j*1.26,j*1.32,0),(-thigh*.55,j*1.55,j*1.54,0),(0,j*1.45,j*1.50,0)]+top,tc,6)
                    kc='piel' if short else 'tela_b'
                    ball('pierna.'+side,[0,0,0],[j*(2.8 if kc=='piel' else 2.5)]*3,kc,darken=JOINT if kc=='piel' else 0)
                    loft('pierna.'+side,[(-calf,j*.84,j*.90,0),(-calf*.65,j*1.10,j*1.24,.006),(-calf*.25,j*1.32,j*1.43,.008),(0,j*1.19,j*1.25,0)],kc,6)
                    if not skirt and short:
                        loft('muslo.'+side,[(-thigh,j*1.30,j*1.37,0),(-thigh+.012,j*1.33,j*1.39,0)],'tela_b',6,darken=.18)
                    ankle=nz*.03
                    # Footwear has its own colour zone: trainers stay light, street shoes use 'calzado'.
                    shoe='acento' if piece.get('sport') else 'calzado'
                    loft('pie.'+side,[(-ankle,j*.82,j*2.1,-j*.48),(-ankle+.012,j*.97,j*2.32,-j*.5),(ankle*.24,j*.84,j*2.06,-j*.35),(ankle*.70,j*.63,j*1.20,.005)],shoe,8,darken=.05)
                    loft('pie.'+side,[(-ankle,j*.83,j*2.12,-j*.48),(-ankle+.010,j*.97,j*2.34,-j*.5)],shoe,6,darken=.45)
                if skirt:
                    loft('caderas',[(nz*y,shoulder*x,shoulder*z,0) for y,x,z in [(-.295,1.08,.77),(-.28,1.11,.79),(-.04,1.07,.68),(.10,.95,.59)]],'tela_b',8)
                    loft('caderas',[(-nz*.297,shoulder*1.085,shoulder*.777,0),(-nz*.286,shoulder*1.105,shoulder*.790,0)],'tela_b',8,darken=.22)
            elif slot=='cabeza':
                hair=piece['style'];color='tela_b' if hair in ('cap','cap_back','hat','beanie','beret') else 'pelo'
                if hair in ('cap','cap_back'):
                    # Smooth crown ending in a clean band at peak height, closed on top.
                    n=S(10)
                    crown=loft_mesh([(head*y,head*x,head*z,head*.03) for y,x,z in [(.60,.405,.425),(.80,.375,.405),(.95,.255,.295),(1.04,.04,.07)]],n)
                    crown['indices']=crown['indices'][:-n*6]+crown['indices'][-n*3:]
                    shape('mesh','cabeza',color,**crown)
                elif hair=='beret':
                    # Beret: a band round the head and a flat, wide crown pushed back, with its stalk.
                    n=S(10)
                    crown=loft_mesh([(head*y,head*x,head*z,head*cz) for y,x,z,cz in [(.62,.40,.42,.03),(.72,.41,.43,.035),(.80,.56,.58,.07),(.93,.54,.56,.09),(1.03,.30,.32,.09),(1.055,.03,.04,.09)]],n)
                    crown['indices']=crown['indices'][:-n*6]+crown['indices'][-n*3:]
                    shape('mesh','cabeza',color,**crown)
                    loft('cabeza',[(head*.615,head*.405,head*.425,head*.03),(head*.665,head*.41,head*.43,head*.032)],color,8,darken=.3)
                    ball('cabeza',[0,head*1.07,head*.09],[head*.07,head*.09,head*.07],color,darken=.2)
                elif hair not in ('bald','curly'):
                    # Scalp follows the skull, with a high forehead and a lower nape.
                    rings=[(.39,.325,.34),(.66,.392,.414),(.85,.33,.365),(.98,.195,.245),(1.025,.035,.065)]
                    n=S(10)
                    m=loft_mesh([(head*y,head*x,head*z,head*.035) for y,x,z in rings],n)
                    # Raise the front hairline without covering the faceless oval.
                    for i in range(n):
                        front=max(0,math.cos(math.tau*i/n))
                        m['vertices'][i][1]+=head*((.23+.06*math.sin(math.tau*i/n)) if hair=='fringe' else .33)*front
                    # Open underside: only the side/top cap, avoiding a disc across the face.
                    m['indices']=m['indices'][:(len(rings)-1)*n*6]+m['indices'][-n*3:]
                    shape('mesh','cabeza',color,**m)
                if hair=='long':
                    # Rounded mass behind the ears, widening slightly at shoulder length.
                    loft('cabeza',[(head*y,head*x,head*z,head*cz) for y,x,z,cz in [(-.19,.31,.16,.25),(-.10,.39,.19,.27),(.40,.38,.19,.29),(.72,.31,.19,.24)]],color,8)
                if hair=='short':
                    ball('cabeza',[-head*.065,head*.88,-head*.11],[head*.66,head*.26,head*.52],color,lighten=.045)
                if hair=='tail':
                    loft('cabeza',[(head*y,head*x,head*z,head*cz) for y,x,z,cz in [(-.11,.07,.065,.51),(.07,.16,.12,.55),(.36,.17,.14,.56),(.58,.10,.09,.43)]],color,6)
                    ball('cabeza',[0,head*.55,head*.41],[head*.21,head*.18,head*.19],color,darken=.28)
                if hair=='bun':
                    # Hair pulled back into a round bun high on the back of the head.
                    ball('cabeza',[0,head*.86,head*.37],[head*.36,head*.34,head*.36],color,lighten=.04)
                    ball('cabeza',[0,head*.80,head*.27],[head*.27,head*.2,head*.2],color,darken=.3)
                if hair=='curly':
                    # A round mass of curls, wider than the head: top, sides and back; the face stays clear.
                    n=S(10)
                    mass=loft_mesh([(head*y,head*x,head*z,head*cz) for y,x,z,cz in [(.40,.45,.40,.10),(.66,.51,.51,.05),(.86,.47,.48,.04),(1.01,.31,.33,.04),(1.09,.06,.08,.04)]],n)
                    for i in range(n):
                        mass['vertices'][i][1]+=head*.25*max(0,math.cos(math.tau*i/n))
                    mass['indices']=mass['indices'][:4*n*6]+mass['indices'][-n*3:]
                    shape('mesh','cabeza',color,**mass)
                    # A few lumps break the smooth outline: curls, seen from afar.
                    for a in (1.2,2.1,math.pi,-2.1,-1.2):
                        ball('cabeza',[math.sin(a)*head*.47,head*.56,head*.06-math.cos(a)*head*.46],[head*.3,head*.3,head*.3],color,darken=.1,collision=False)
                if hair=='cap':
                    # Peak only in front of the forehead; a full ring read as a halo from the front.
                    shape('mesh','cabeza',color,**visor_mesh(head,head*.035),darken=.12)
                if hair=='cap_back':
                    # The same cap worn backwards: the peak over the nape, mirrored front to back.
                    peak=visor_mesh(head,head*.035)
                    axis=head*.035
                    peak['vertices']=[[x,y,2*axis-z] for x,y,z in peak['vertices']]
                    peak['normals']=[[x,y,-z] for x,y,z in peak['normals']]
                    ids=peak['indices']
                    peak['indices']=sum(([ids[i],ids[i+2],ids[i+1]] for i in range(0,len(ids),3)),[])
                    shape('mesh','cabeza',color,**peak,darken=.12)
                if hair=='hat':
                    loft('cabeza',[(head*.82,head*.66,head*.63,0),(head*.86,head*.66,head*.63,0)],color,10)
                    loft('cabeza',[(head*.86,head*.36,head*.37,0),(head*1.28,head*.32,head*.33,0)],color,8)
                    loft('cabeza',[(head*.88,head*.365,head*.375,0),(head*.96,head*.36,head*.37,0)],color,8,darken=.5)
                if hair=='beanie':
                    loft('cabeza',[(head*.60,head*.405,head*.425,0),(head*.76,head*.42,head*.44,0)],color,8,lighten=.2)
                    ball('cabeza',[0,head*1.06,0],[head*.23,head*.25,head*.23],color)
            elif slot=='accesorio':
                if piece['style']=='scarf':
                    loft('cuello',[(-nz*.018,j*1.55,j*1.5,0),(nz*.04,j*1.55,j*1.5,0)],'accesorio',8)
                    shape('box','torax','accesorio',position=[j*.65,-nz*.018,-shoulder*.65],size=[j*1.4,nz*.25,.025])
                if piece['style']=='bag':
                    shape('box','caderas','accesorio',position=[shoulder*.95,nz*.10,0],size=[shoulder*.7,nz*.18,shoulder*.7])
                    patch('lumbar',[[-shoulder*.8,nz*.23,-shoulder*.59],[-shoulder*.6,nz*.23,-shoulder*.60],[shoulder*.85,-nz*.06,-shoulder*.55],[shoulder*.65,-nz*.06,-shoulder*.56]],'accesorio')
                if piece['style']=='backpack':
                    # Backpack: a rounded bag on the back, a darker pocket and a strap over each shoulder.
                    bag=loft_mesh([(nz*y,shoulder*x,shoulder*z,shoulder*cz) for y,x,z,cz in [(-.035,.50,.20,.80),(.03,.64,.29,.87),(.19,.60,.28,.86),(.245,.34,.14,.76)]],S(6))
                    shape('mesh','lumbar','accesorio',**bag)
                    pocket=loft_mesh([(nz*y,shoulder*x,shoulder*z,shoulder*cz) for y,x,z,cz in [(-.01,.36,.10,1.06),(.10,.38,.10,1.06)]],S(5))
                    shape('mesh','lumbar','accesorio',**pocket,darken=.22,collision=False)
                    over=[(nz*y,shoulder*x*1.01,shoulder*z*1.03,0) for y,x,z in [(.10,.77,.56),(.235,.92,.53),(.284,.30,.29)]]
                    for centre in (.5,-.5,math.pi-.5,math.pi+.5):
                        shape('mesh','lumbar','accesorio',**strip_mesh(over,centre-.1,centre+.1,1,1.06),collision=False,outline=False,darken=.15)
                if piece['style']=='umbrella':
                    # Closed umbrella carried by its handle in the left hand, pointing down like a cane.
                    top=-nz*.035
                    L=nz*.50
                    seg('mano.I',[0,top-L*.12,-j*.5],[0,top-L,-j*.5],j*.78,j*.16,'accesorio',collision=False)
                    seg('mano.I',[0,top+j*.4,-j*.5],[0,top-L*.12,-j*.5],j*.13,j*.13,'calzado',collision=False)
                    ball('mano.I',[0,top+j*.55,-j*.1],[j*.36,j*.36,j*1.0],'calzado',collision=False)
            elif slot=='gafas':
                # Glasses: flat frames just in front of the faceless oval, at eye height. Plain glasses
                # are only the rims (the wood shows through: clear lenses); sunglasses fill them dark.
                style=piece['style']
                if style!='none':
                    ey,z=head*.50,-head*.405
                    cx,hw,hh=head*.16,head*.115,head*.075
                    t=head*.022
                    def quad(x0,y0,x1,y1,color,zz=z,**kw):
                        geometry.append(dict(type='mesh',bone='cabeza',color=color,collision=False,outline=False,
                            vertices=[[x0,y0,zz],[x1,y0,zz],[x1,y1,zz],[x0,y1,zz]],normals=[[0,0,-1]]*4,indices=[0,1,2,0,2,3,0,2,1,0,3,2],**kw))
                    for sx in (-1,1):
                        x0,x1=sx*cx-hw,sx*cx+hw
                        if style=='sunglasses': quad(x0,ey-hh,x1,ey+hh,'cristal',z+head*.004)
                        quad(x0,ey+hh-t,x1,ey+hh,'montura')
                        quad(x0,ey-hh,x1,ey-hh+t,'montura')
                        quad(x0,ey-hh,x0+t,ey+hh,'montura')
                        quad(x1-t,ey-hh,x1,ey+hh,'montura')
                        # Temple arm along the side of the head, back to the ear.
                        xa,xb=sx*(cx+hw),sx*head*.385
                        geometry.append(dict(type='mesh',bone='cabeza',color='montura',collision=False,outline=False,
                            vertices=[[xa,ey+hh*.2,z],[xb,ey+hh*.1,head*.02],[xb,ey+hh*.1+t,head*.02],[xa,ey+hh*.2+t,z]],normals=[[sx,0,0]]*4,indices=[0,1,2,0,2,3,0,2,1,0,3,2]))
                    quad(-cx+hw,ey+hh*.25,cx-hw,ey+hh*.25+t,'montura')
            relative=f'{PIECES}/{profile["id"]}_{slot}_{index}.json'
            (ROOT/relative).write_text(json.dumps(dict(geometry=geometry),ensure_ascii=False,separators=(',',':'))+'\n')
            all_pieces.append(dict(piece,ranura=slot,indice=index,recurso='res://'+relative))
    profile['piezas']=all_pieces
if not HD:
    CATALOG.write_text(json.dumps(cat,ensure_ascii=False,indent=2)+'\n')
print('Generated',sum(len(p['piezas']) for p in cat['perfiles']),'contoured mannequin parts in',PIECES)
