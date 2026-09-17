#!/usr/bin/env python3
"""Generate low-poly, smoothly contoured mannequin parts with rigid bone bindings."""
import json
import math
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
CATALOG = ROOT / 'data/catalogo.json'
cat = json.loads(CATALOG.read_text())

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
                ids=[]
                for i in range(1,len(points)-1): ids.extend([0,i,i+1])
                # Front/back avoid disappearance of seams from grazing angles.
                ids+=sum(([ids[i],ids[i+2],ids[i+1]] for i in range(0,len(ids),3)),[])
                shape('mesh',bone,color,vertices=points,normals=[n]*len(points),indices=ids,collision=False,**kwargs)
            if slot=='cuerpo':
                loft('cabeza',[(head*y,head*x,head*z,head*offset) for y,x,z,offset in [
                    (0,.17,.20,-.025),(.12,.28,.30,-.03),(.34,.36,.365,-.015),
                    (.64,.375,.395,.015),(.84,.31,.34,.025),(.96,.19,.23,.025),(1,.045,.06,.025)]],'piel',10)
                seg('cuello',[0,-nz*.025,0],[0,nz*.045,0],j*.82,j*.73,'piel')
                for side in ['I','D']:
                    length=nz*.085
                    loft('mano.'+side,[(-length,j*.25,j*.23,-.004),(-length*.82,j*.57,j*.35,-.008),(-length*.32,j*.65,j*.40,0),(0,j*.50,j*.43,0)],'piel',6)
                    sign=-1 if side=='I' else 1
                    ball('mano.'+side,[sign*j*.59,-length*.32,-j*.08],[j*.6,length*.55,j*.57],'piel')
            elif slot=='torso':
                casual=piece['style'] in ('plain','hood')
                bulk=1.08 if piece['style']=='hood' else 1.0
                # Waist, ribs, chest, rounded shoulders and a close-fitting neckline.
                loft('lumbar',[(nz*y,shoulder*x*bulk,shoulder*z*bulk,0) for y,x,z in [
                    (-.08,.72,.50),(-.015,.76,.53),(.10,.77,.56),(.19,.94,.59),
                    (.235,.92,.53),(.273,.47,.36),(.284,.30,.29)]],'tela_a')
                # Hem and a narrow collar add the ink-like edges visible in the mockup.
                loft('lumbar',[(nz*-.081,shoulder*.726*bulk,shoulder*.51*bulk,0),(nz*-.07,shoulder*.74*bulk,shoulder*.52*bulk,0)],'tela_a',8,darken=.18)
                loft('cuello',[(nz*.001,j*.99,j*.9,0),(nz*.013,j*.97,j*.88,0)],'tela_a',8,darken=.18)
                if piece['style']=='hood':
                    ball('cuello',[0,-nz*.034,nz*.06],[w*.48,nz*.13,nz*.13],'tela_a',darken=.12)
                if piece['style'] in ('collar','lapel'):
                    for sign in [-1,1]:
                        x=lambda value: sign*shoulder*value
                        # Lapels follow the chest contour into the centre of the garment.
                        patch('lumbar',[[x(.21),nz*.278,-shoulder*.29],[x(.54),nz*.244,-shoulder*.43],[x(.25),nz*(.12 if piece['style']=='lapel' else .215),-shoulder*.585],[x(.04),nz*.233,-shoulder*.53]],'tela_a',lighten=.22)
                    patch('lumbar',[[-.006,nz*-.065,-shoulder*.535],[.006,nz*-.065,-shoulder*.535],[.006,nz*.22,-shoulder*.58],[-.006,nz*.22,-shoulder*.58]],'tela_a',darken=.28)
                    for sign in [-1,1]:
                        patch('lumbar',[[sign*shoulder*.3,nz*.025,-shoulder*.54],[sign*shoulder*.64,nz*.035,-shoulder*.47],[sign*shoulder*.64,nz*.05,-shoulder*.47],[sign*shoulder*.3,nz*.04,-shoulder*.54]],'tela_a',darken=.17)
                for side in ['I','D']:
                    arm,fore,sleeve=nz*.215,nz*.169,piece['sleeve']
                    ball('brazo.'+side,[0,-j*.13,0],[j*2.18,j*2.0,j*2.22],'tela_a')
                    end=-arm*sleeve
                    loft('brazo.'+side,[(end,j*.85,j*.87,0),(end*.64,j*1.08,j*1.04,0),(-j*.1,j*1.07,j*1.07,0)],'tela_a',6)
                    if sleeve<1:
                        seg('brazo.'+side,[0,end+.004,0],[0,-arm,0],j*.8,j*.75,'piel')
                        loft('brazo.'+side,[(end-.004,j*.88,j*.90,0),(end+.007,j*.92,j*.94,0)],'tela_a',6,darken=.16)
                    fc='tela_a' if sleeve==1 else 'piel'
                    ball('antebrazo.'+side,[0,0,0],[j*1.70]*3,fc)
                    loft('antebrazo.'+side,[(-fore,j*.59,j*.60,0),(-fore*.60,j*.80,j*.80,0),(-fore*.15,j*.86,j*.88,0),(0,j*.78,j*.81,0)],fc,6)
                    if sleeve==1: loft('antebrazo.'+side,[(-fore,j*.63,j*.65,0),(-fore+.014,j*.66,j*.68,0)],'tela_a',6,darken=.17)
                if piece['style']=='sport':
                    for sign in [-1,1]:
                        patch('lumbar',[[sign*shoulder*.60,nz*.02,-shoulder*.55],[sign*shoulder*.70,nz*.02,-shoulder*.53],[sign*shoulder*.70,nz*.20,-shoulder*.55],[sign*shoulder*.60,nz*.20,-shoulder*.57]],'acento')
            elif slot=='piernas':
                short=piece['length']<1
                skirt=piece['style']=='skirt'
                pelvis=loft_mesh([(nz*y,shoulder*x,shoulder*z,0) for y,x,z in [(-.012,.93,.38),(.055,.96,.53),(.105,.80,.54)]],8)
                for i in range(8):
                    pelvis['vertices'][i][1]+=nz*.074*abs(math.sin(math.tau*i/8))
                pelvis['indices']=pelvis['indices'][:-48]
                shape('mesh','caderas','tela_b',**pelvis)
                for side in ['I','D']:
                    thigh=nz*(.542-.323);calf=nz*(.323-.03)
                    tc='piel' if skirt else 'tela_b'
                    # The concealed hip joint is inside the pelvis. Rounded ends overlap at the knee.
                    loft('muslo.'+side,[(-thigh,j*.96,j*1.02,0),(-thigh*.55,j*1.27,j*1.26,0),(0,j*1.42,j*1.48,0)],tc,6)
                    kc='piel' if short else 'tela_b'
                    ball('pierna.'+side,[0,0,0],[j*1.91]*3,kc)
                    loft('pierna.'+side,[(-calf,j*.65,j*.70,0),(-calf*.65,j*.84,j*.95,.006),(-calf*.25,j*1.01,j*1.10,.008),(0,j*.91,j*.96,0)],kc,6)
                    if not skirt and short:
                        loft('muslo.'+side,[(-thigh,j*1.0,j*1.07,0),(-thigh+.012,j*1.03,j*1.09,0)],'tela_b',6,darken=.18)
                    ankle=nz*.03
                    loft('pie.'+side,[(-ankle,j*.82,j*2.1,-j*.48),(-ankle+.012,j*.97,j*2.32,-j*.5),(ankle*.24,j*.84,j*2.06,-j*.35),(ankle*.70,j*.63,j*1.20,.005)],'acento' if piece.get('sport') else 'tela_b',8,darken=.05 if piece.get('sport') else .25)
                    loft('pie.'+side,[(-ankle,j*.83,j*2.12,-j*.48),(-ankle+.010,j*.97,j*2.34,-j*.5)],'tela_b',6,darken=.55)
                if skirt:
                    loft('caderas',[(nz*y,shoulder*x,shoulder*z,0) for y,x,z in [(-.295,1.08,.77),(-.28,1.11,.79),(-.04,.83,.60),(.10,.76,.55)]],'tela_b',8)
                    loft('caderas',[(-nz*.297,shoulder*1.085,shoulder*.777,0),(-nz*.286,shoulder*1.105,shoulder*.790,0)],'tela_b',8,darken=.22)
            elif slot=='cabeza':
                hair=piece['style'];color='tela_b' if hair in ('cap','hat','beanie') else 'pelo'
                if hair!='bald':
                    # Scalp follows the skull, with a high forehead and a lower nape.
                    rings=[(.39,.325,.34),(.66,.392,.414),(.85,.33,.365),(.98,.195,.245),(1.025,.035,.065)]
                    m=loft_mesh([(head*y,head*x,head*z,head*.035) for y,x,z in rings],8)
                    # Raise the front hairline without covering the faceless oval.
                    for i in range(10):
                        front=max(0,math.cos(math.tau*i/10))
                        m['vertices'][i][1]+=head*((.23+.06*math.sin(math.tau*i/10)) if hair=='fringe' else .33)*front
                    # Open underside: only the side/top cap, avoiding a disc across the face.
                    m['indices']=m['indices'][:(len(rings)-1)*10*6]+m['indices'][-30:]
                    shape('mesh','cabeza',color,**m)
                if hair=='long':
                    # Rounded mass behind the ears, widening slightly at shoulder length.
                    loft('cabeza',[(head*y,head*x,head*z,head*cz) for y,x,z,cz in [(-.19,.31,.16,.25),(-.10,.39,.19,.27),(.40,.38,.19,.29),(.72,.31,.19,.24)]],color,8)
                if hair=='short':
                    ball('cabeza',[-head*.065,head*.88,-head*.11],[head*.66,head*.26,head*.52],color,lighten=.045)
                if hair=='tail':
                    loft('cabeza',[(head*y,head*x,head*z,head*cz) for y,x,z,cz in [(-.11,.07,.065,.51),(.07,.16,.12,.55),(.36,.17,.14,.56),(.58,.10,.09,.43)]],color,6)
                    ball('cabeza',[0,head*.55,head*.41],[head*.21,head*.18,head*.19],color,darken=.28)
                if hair=='cap':
                    # Curved visor, shallow enough to read as fabric instead of a box.
                    loft('cabeza',[(head*.727,head*.40,head*.37,-head*.31),(head*.758,head*.42,head*.41,-head*.30)],color,8,darken=.12)
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
            relative=f'data/piezas/{profile["id"]}_{slot}_{index}.json'
            (ROOT/relative).write_text(json.dumps(dict(geometry=geometry),ensure_ascii=False,separators=(',',':'))+'\n')
            all_pieces.append(dict(piece,ranura=slot,indice=index,recurso='res://'+relative))
    profile['piezas']=all_pieces
CATALOG.write_text(json.dumps(cat,ensure_ascii=False,indent=2)+'\n')
print('Generated',sum(len(p['piezas']) for p in cat['perfiles']),'contoured mannequin parts.')
