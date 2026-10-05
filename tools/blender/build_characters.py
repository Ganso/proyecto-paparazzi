"""Generador de maniquíes y ropa (docs/futuro/18).

    blender -b --factory-startup -P tools/blender/build_characters.py -- [--only estandar] [--slots torso,piernas]

Escribe data/piezas_hd/<perfil>_<ranura>_<índice>.json con formas "skinned": vértices en espacio de
modelo en reposo (coordenadas de Godot: y arriba, -z delante), normales suaves, índices con el
sentido de Godot y hasta cuatro huesos por vértice. La madera del maniquí es rígida (un hueso por
pieza); ropa, pelo y accesorios reparten el peso entre los huesos más cercanos, así que se doblan
en codos, rodillas y caderas en vez de cortarse. Las prendas declaran en "hides" qué partes del
cuerpo tapan: person.gd no las dibuja, de modo que la madera nunca asoma por la tela.

El esqueleto es el de person.gd::make_rig() (20 huesos, mismas posiciones): la marcha y la
puntuación no cambian. Las piezas base (data/piezas/, tools/build_catalog.py) siguen dando los
colisionadores.
"""
import bpy
import bmesh
import json
import math
import os
import sys
from mathutils import Vector, noise

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
CATALOG = json.load(open(os.path.join(ROOT, "data", "catalogo.json")))
OUT = os.path.join(ROOT, "data", "piezas_hd")


# ---------------------------------------------------------------- proporciones y esqueleto

class Body:
    def __init__(self, profile):
        self.id = profile["id"]
        self.h = profile["altura"]
        self.head = self.h / profile["relacion_cabeza"]
        self.nz = self.h - self.head
        self.j = profile["radio"]
        self.shoulders = profile["hombros"]
        self.W = self.shoulders / 0.42          # anchura del tronco
        self.S = self.j / 0.045                 # grosor de los miembros
        nz = self.nz
        self.hip_y = nz * .542
        self.knee_y = nz * .323
        self.ankle_y = nz * .03
        self.lumbar_y = nz * .692
        self.torax_y = nz * .808
        self.neck_y = nz * .965
        self.sh_y = nz * .929
        self.sh_x = self.shoulders * .5 - self.j
        self.el_y = nz * (.929 - .215)
        self.wr_y = nz * (.929 - .215 - .169)
        self.leg_x = self.shoulders * .22
        # Segmentos de cada hueso (cabeza → cola) para repartir pesos por distancia.
        self.segments = {
            "caderas": ((0, nz * .50, 0), (0, nz * .655, 0)),
            "lumbar": ((0, nz * .655, 0), (0, nz * .78, 0)),
            "torax": ((0, nz * .78, 0), (0, nz * .94, 0)),
            "cuello": ((0, nz * .94, 0), (0, nz + .02, 0)),
            "cabeza": ((0, nz + .02, 0), (0, nz + self.head * .9, 0)),
        }
        for side, sign in (("I", -1), ("D", 1)):
            x, lx = self.sh_x * sign, self.leg_x * sign
            self.segments.update({
                "clavicula." + side: ((x * .35, self.sh_y, 0), (x, self.sh_y, 0)),
                "brazo." + side: ((x, self.sh_y, 0), (x, self.el_y, 0)),
                "antebrazo." + side: ((x, self.el_y, 0), (x, self.wr_y, 0)),
                "mano." + side: ((x, self.wr_y, 0), (x, self.wr_y - nz * .08, 0)),
                "muslo." + side: ((lx, self.hip_y, 0), (lx, self.knee_y, 0)),
                "pierna." + side: ((lx, self.knee_y, 0), (lx, self.ankle_y, 0)),
                "pie." + side: ((lx, self.ankle_y, 0), (lx, 0.02, -.14 * self.S)),
            })


def seg_distance(p, a, b):
    a, b = Vector(a), Vector(b)
    ab = b - a
    t = max(0.0, min(1.0, (p - a).dot(ab) / max(ab.dot(ab), 1e-9)))
    return (p - (a + ab * t)).length


def smooth_weights(body, p, candidates, power=6.0):
    """Hasta 4 huesos por vértice, por distancia inversa a sus segmentos: en mitad de un miembro
    domina su hueso y cerca de la articulación se reparte con el vecino."""
    scored = []
    for name in candidates:
        d = seg_distance(p, *body.segments[name])
        scored.append((1.0 / max(d, 0.004) ** power, name))
    scored.sort(reverse=True)
    scored = scored[:4]
    total = sum(w for w, _ in scored)
    out = [(n, w / total) for w, n in scored if w / total > 0.01]
    total = sum(w for _, w in out)
    return [(n, w / total) for n, w in out]


# ---------------------------------------------------------------- cadenas secundarias (muelles)

class Chains:
    """Cadenas de huesos secundarios que Godot hace oscilar (SpringBoneSimulator3D). Cada cadena
    es una polilínea de puntos (cabezas de hueso; el último es la punta). weight(p) reparte el peso
    de un vértice entre las dos cadenas más próximas en ángulo y, a lo largo de cada una, entre los
    dos huesos que abarcan su altura; por encima de `top` el vértice sigue al hueso padre."""

    def __init__(self, name, parent, centre, top, blend=.06, stiffness=1.0, drag=.4, gravity=0.0, radius=.02, along=None):
        self.name, self.parent, self.centre = name, parent, Vector(centre)
        self.top, self.blend = top, blend
        self.props = {"stiffness": stiffness, "drag": drag, "gravity": gravity, "radius": radius}
        self.list = []
        self.parents = []
        self.along = along

    def add(self, points, parent=None):
        self.list.append([Vector(p) for p in points])
        self.parents.append(parent or self.parent)

    def angle(self, p):
        d = Vector(p) - self.centre
        return math.atan2(d.x, -d.z)

    def export(self):
        out = []
        for i, pts in enumerate(self.list):
            c = {"name": "%s%d" % (self.name, i), "parent": self.parents[i], "points": [[round(v, 5) for v in pt] for pt in pts]}
            c.update(self.props)
            out.append(c)
        return out

    def along_chain(self, i, p):
        """(índice de segmento, fracción) del punto p proyectado sobre la cadena i."""
        pts = self.list[i]
        best = (1e9, 0, 0.0)
        for k in range(len(pts) - 1):
            a, b = pts[k], pts[k + 1]
            ab = b - a
            t = max(0.0, min(1.0, (p - a).dot(ab) / max(ab.dot(ab), 1e-9)))
            d = (p - (a + ab * t)).length
            if d < best[0]:
                best = (d, k, t)
        return best[1], best[2]

    def weight(self, p):
        p = Vector(p)
        if len(self.list) == 1:
            k, t = self.along_chain(0, p)
            parts = [(0, 1.0)]
        else:
            ang = self.angle(p)
            roots = [(abs(math.atan2(math.sin(ang - self.angle(c[0])), math.cos(ang - self.angle(c[0])))), i) for i, c in enumerate(self.list)]
            roots.sort()
            (d0, i0), (d1, i1) = roots[0], roots[1]
            w0 = d1 / max(d0 + d1, 1e-6)
            parts = [(i0, w0), (i1, 1 - w0)]
        out = {}
        follow = max(0.0, min(1.0, (self.top - p.y) / self.blend)) if self.along is None else None
        for i, w in parts:
            k, t = self.along_chain(i, p)
            if self.along is not None:
                follow = max(0.0, min(1.0, (k + t) / self.along))
            # El hueso k controla su segmento: el vértice va con el hueso k (y algo del siguiente).
            a = "%s%d.%d" % (self.name, i, k)
            b2 = "%s%d.%d" % (self.name, i, min(k + 1, len(self.list[i]) - 2))
            out[a] = out.get(a, 0) + w * follow * (1 - t * .5)
            out[b2] = out.get(b2, 0) + w * follow * t * .5
        out[self.parent] = out.get(self.parent, 0) + (1 - follow)
        items = sorted(out.items(), key=lambda x: -x[1])[:4]
        total = sum(v for _, v in items)
        return [(n, v / total) for n, v in items if v / total > .005]


# ---------------------------------------------------------------- construcción de mallas

class Piece:
    """Malla de control en coordenadas de Godot, con su zona de color y su regla de pesos."""

    def __init__(self, zone, bone=None, candidates=None, subdivide=1, part=None, darken=0.0, lighten=0.0, weight_fn=None):
        self.bm = bmesh.new()
        self.zone = zone
        self.bone = bone
        self.candidates = candidates
        self.subdivide = subdivide
        self.part = part
        self.darken = darken
        self.lighten = lighten
        self.weight_fn = weight_fn
        # Caída de tela (drape): {"pin": f(p) -> 0..1, "frames": n}. Blender simula la prenda sobre
        # el cuerpo en reposo con el modificador Cloth y guarda la forma asentada (pliegues, caída).
        self.drape = None

    def verts(self, points):
        return [self.bm.verts.new(Vector(p)) for p in points]

    def face(self, vs):
        unique = []
        for v in vs:
            if v not in unique:
                unique.append(v)
        if len(unique) >= 3:
            try:
                self.bm.faces.new(unique)
            except ValueError:
                pass


def ring_points(y, cx, cz, rx, rz, n, shape=None, phase=0.0):
    pts = []
    for i in range(n):
        a = phase + i * math.tau / n
        k = shape(a, y) if shape else 1.0
        pts.append((cx + math.sin(a) * rx * k, y, cz - math.cos(a) * rz * k))
    return pts


def loft(piece, rings, n, cap_bottom=True, cap_top=True, shape=None):
    """Tubo a lo largo de y. rings = [(y, cx, cz, rx, rz), ...] de abajo arriba (o de arriba abajo)."""
    rows = [piece.verts(ring_points(y, cx, cz, rx, rz, n, shape)) for (y, cx, cz, rx, rz) in rings]
    for a, b in zip(rows, rows[1:]):
        for i in range(n):
            j = (i + 1) % n
            piece.face([a[i], a[j], b[j], b[i]])
    for cap, row, ring in ((cap_bottom, rows[0], rings[0]), (cap_top, rows[-1], rings[-1])):
        if cap:
            centre = piece.bm.verts.new(Vector((ring[1], ring[0], ring[2])))
            for i in range(n):
                piece.face([row[i], row[(i + 1) % n], centre])
    return rows


def tube(piece, path, radii, n, caps=True):
    """Barrido de un círculo a lo largo de una polilínea (dedos, cordones, coleta, correas)."""
    path = [Vector(p) for p in path]
    rows, normal = [], None
    for i, p in enumerate(path):
        t = (path[min(i + 1, len(path) - 1)] - path[max(i - 1, 0)]).normalized()
        if normal is None:
            ref = Vector((0, 1, 0)) if abs(t.y) < .9 else Vector((1, 0, 0))
            normal = t.cross(ref).normalized()
        else:
            normal = (normal - t * normal.dot(t)).normalized()
        bi = t.cross(normal)
        r = radii[i] if isinstance(radii, (list, tuple)) else radii
        rows.append(piece.verts([tuple(p + (normal * math.cos(a) + bi * math.sin(a)) * r) for a in [k * math.tau / n for k in range(n)]]))
    for a, b in zip(rows, rows[1:]):
        for i in range(n):
            piece.face([a[i], a[(i + 1) % n], b[(i + 1) % n], b[i]])
    if caps:
        for row, p in ((rows[0], path[0]), (rows[-1], path[-1])):
            c = piece.bm.verts.new(p)
            for i in range(n):
                piece.face([row[i], row[(i + 1) % n], c])


def ball(piece, centre, radius, subdivisions=2, squash=(1, 1, 1)):
    m = bmesh.new()
    bmesh.ops.create_icosphere(m, subdivisions=subdivisions, radius=radius)
    offset = {}
    for v in m.verts:
        offset[v] = piece.bm.verts.new(Vector(centre) + Vector((v.co.x * squash[0], v.co.y * squash[1], v.co.z * squash[2])))
    for f in m.faces:
        piece.face([offset[v] for v in f.verts])
    m.free()


def slab(piece, outline, normal_offset, thickness):
    """Placa con grosor (solapas, visera, ala): outline = lista de puntos (polígono convexo o casi)."""
    outline = [Vector(p) for p in outline]
    off = Vector(normal_offset).normalized() * thickness
    top = piece.verts([tuple(p + off) for p in outline])
    bottom = piece.verts([tuple(p) for p in outline])
    piece.face(top)
    piece.face(list(reversed(bottom)))
    n = len(outline)
    for i in range(n):
        j = (i + 1) % n
        piece.face([bottom[i], bottom[j], top[j], top[i]])


def patch(piece, rings, rows, lift, thickness=.004, n=4):
    """Placa con grosor que sigue la superficie delantera de la prenda: rows = [(y, x0, x1), ...]."""
    top, bottom = [], []
    for (y, x0, x1) in rows:
        pts = [front_of(rings, y, x0 + (x1 - x0) * i / n, lift) for i in range(n + 1)]
        bottom.append(piece.verts(pts))
        top.append(piece.verts([(x, py, z - thickness) for (x, py, z) in pts]))
    last = len(rows) - 1
    for r in range(last):
        for i in range(n):
            piece.face([top[r][i], top[r][i + 1], top[r + 1][i + 1], top[r + 1][i]])
            piece.face([bottom[r + 1][i], bottom[r + 1][i + 1], bottom[r][i + 1], bottom[r][i]])
        for i in (0, n):
            piece.face([bottom[r][i], bottom[r + 1][i], top[r + 1][i], top[r][i]])
    for r in (0, last):
        for i in range(n):
            piece.face([bottom[r][i], bottom[r][i + 1], top[r][i + 1], top[r][i]])


# ---------------------------------------------------------------- maniquí de madera

JOINT_DARKEN = .22


def build_body(b):
    S, W, nz = b.S, b.W, b.nz
    parts = []

    def rigid(bone, part, darken=0.0, subdivide=1):
        p = Piece("piel", bone=bone, part=part, darken=darken, subdivide=subdivide)
        parts.append(p)
        return p

    # Pelvis, abdomen y pecho: tres bloques torneados con la cintura articulada.
    loft(rigid("caderas", "pelvis"), [(nz * .495, 0, 0, .10 * W, .07 * W), (nz * .525, 0, 0, .152 * W, .10 * W),
         (nz * .58, 0, -.004, .162 * W, .108 * W), (nz * .63, 0, 0, .145 * W, .096 * W), (nz * .665, 0, 0, .118 * W, .082 * W)], 8)
    loft(rigid("lumbar", "abdomen"), [(nz * .655, 0, 0, .112 * W, .08 * W), (nz * .70, 0, -.006, .126 * W, .09 * W),
         (nz * .75, 0, -.006, .132 * W, .092 * W), (nz * .785, 0, 0, .128 * W, .088 * W)], 8)
    ball(rigid("lumbar", "cintura", JOINT_DARKEN, 0), (0, nz * .66, 0), .095 * W, 2, (1.25, .5, .9))
    chest = lambda a, y: 1.0 - .08 * max(0.0, math.cos(a)) ** 2 * (1.0 if y > nz * .9 else 0.0)
    loft(rigid("torax", "pecho"), [(nz * .775, 0, 0, .13 * W, .09 * W), (nz * .82, 0, -.008, .152 * W, .104 * W),
         (nz * .87, 0, -.012, .17 * W, .112 * W), (nz * .905, 0, -.006, .172 * W, .104 * W),
         (nz * .935, 0, 0, .148 * W, .086 * W), (nz * .958, 0, .004, .09 * W, .062 * W)], 10, shape=chest)
    # Cuello y cabeza ovoide sin rasgos.
    loft(rigid("cuello", "cuello"), [(nz * .945, 0, .004, .058 * S, .055 * S), (nz * .975, 0, .008, .051 * S, .05 * S),
         (nz + .012, 0, .012, .047 * S, .046 * S)], 8, cap_bottom=False, cap_top=False)
    hh = b.head
    egg = [(0, .17, .20, -.025), (.12, .28, .30, -.03), (.34, .36, .365, -.015), (.64, .375, .395, .015),
           (.84, .31, .34, .025), (.96, .19, .23, .025), (1, .045, .06, .025)]
    # La barbilla baja por delante del cuello, como en una cabeza real (el cuello no parece tan largo).
    loft(rigid("cabeza", "cabeza"), [(nz + hh * (y * 1.08 - .1), 0, hh * cz - (.03 * hh if y < .3 else 0), hh * x * 1.04, hh * z) for y, x, z, cz in egg], 12, cap_top=False)
    for side, sign in (("I", -1), ("D", 1)):
        x, lx = b.sh_x * sign, b.leg_x * sign
        # Brazo: hombro, húmero con bíceps, codo, antebrazo, muñeca y mano con pulgar.
        ball(rigid("brazo." + side, "hombro." + side, JOINT_DARKEN, 0), (x, b.sh_y, 0), .052 * S)
        loft(rigid("brazo." + side, "brazo." + side), [(b.sh_y - .02, x, 0, .044 * S, .046 * S), (b.sh_y - .07, x, -.003, .046 * S, .05 * S),
             ((b.sh_y + b.el_y) * .5, x, -.004, .042 * S, .045 * S), (b.el_y + .03, x, 0, .034 * S, .035 * S), (b.el_y + .012, x, 0, .03 * S, .031 * S)], 8)
        ball(rigid("antebrazo." + side, "codo." + side, JOINT_DARKEN, 0), (x, b.el_y, 0), .037 * S, 1)
        loft(rigid("antebrazo." + side, "antebrazo." + side), [(b.el_y - .012, x, 0, .031 * S, .032 * S), (b.el_y - .05, x, 0, .037 * S, .04 * S),
             ((b.el_y + b.wr_y) * .5, x, 0, .033 * S, .036 * S), (b.wr_y + .02, x, 0, .025 * S, .03 * S), (b.wr_y + .008, x, 0, .023 * S, .027 * S)], 8)
        ball(rigid("mano." + side, "muneca." + side, JOINT_DARKEN, 0), (x, b.wr_y, 0), .026 * S, 1)
        hand = rigid("mano." + side, "mano." + side)
        hl = nz * .082
        loft(hand, [(b.wr_y - .008, x, 0, .016 * S, .026 * S), (b.wr_y - hl * .3, x, -.004, .019 * S, .042 * S),
             (b.wr_y - hl * .72, x, -.004, .017 * S, .043 * S), (b.wr_y - hl * .92, x, -.002, .011 * S, .032 * S),
             (b.wr_y - hl, x, 0, .005 * S, .014 * S)], 8)
        tube(hand, [(x - sign * .004, b.wr_y - hl * .22, -.03 * S), (x - sign * .008, b.wr_y - hl * .42, -.046 * S),
             (x - sign * .006, b.wr_y - hl * .6, -.05 * S)], [.011 * S, .01 * S, .007 * S], 6)
        # Pierna: cadera, muslo, rodilla, gemelo y tobillo (el pie lo pone el calzado).
        ball(rigid("muslo." + side, "cadera." + side, JOINT_DARKEN, 0), (lx, b.hip_y, 0), .07 * S)
        loft(rigid("muslo." + side, "muslo." + side), [(b.hip_y - .01, lx, 0, .074 * S, .076 * S), (b.hip_y - .08, lx, -.004, .072 * S, .075 * S),
             ((b.hip_y + b.knee_y) * .5, lx, -.002, .062 * S, .064 * S), (b.knee_y + .045, lx, 0, .05 * S, .05 * S), (b.knee_y + .018, lx, 0, .044 * S, .044 * S)], 8)
        ball(rigid("pierna." + side, "rodilla." + side, JOINT_DARKEN, 0), (lx, b.knee_y, -.004), .05 * S)
        calf = b.knee_y - b.ankle_y
        loft(rigid("pierna." + side, "pierna." + side), [(b.knee_y - .016, lx, 0, .043 * S, .043 * S), (b.knee_y - calf * .25, lx, .006, .048 * S, .056 * S),
             (b.knee_y - calf * .55, lx, .004, .04 * S, .044 * S), (b.ankle_y + .04, lx, 0, .03 * S, .031 * S), (b.ankle_y + .018, lx, 0, .027 * S, .028 * S)], 8)
        ball(rigid("pie." + side, "tobillo." + side, JOINT_DARKEN, 0), (lx, b.ankle_y, 0), .03 * S, 1)
    return parts


# ---------------------------------------------------------------- ropa

# El tronco de las prendas nunca toma peso de los brazos: con los brazos colgando junto a la cadera,
# el bajo quedaba más cerca del antebrazo que del tronco y se estiraba al balancearlos.
TOP_BONES = ["lumbar", "torax", "cuello", "clavicula.I", "clavicula.D", "caderas"]
ARM_BONES = {"I": ["torax", "clavicula.I", "brazo.I", "antebrazo.I"], "D": ["torax", "clavicula.D", "brazo.D", "antebrazo.D"]}
LEG_BONES = ["caderas", "lumbar", "muslo.I", "muslo.D", "pierna.I", "pierna.D"]


def cloth(zone="tela_a", candidates=None, part=None, **kw):
    return Piece(zone, candidates=candidates or TOP_BONES, part=part, **kw)


def torso_rings(b, ease, hem_y):
    """Secciones del tronco de una prenda: el cuerpo más holgura, sin estrecharse en la cintura."""
    W, nz = b.W, b.nz
    # Hombros y pecho más anchos que la cintura (silueta en V suave) y el bajo algo suelto.
    table = [(.50, .158, .106), (.56, .162, .11), (.62, .152, .104), (.68, .138, .097), (.74, .145, .102),
             (.80, .16, .112), (.85, .176, .118), (.885, .18, .112), (.915, .158, .094), (.945, .114, .074), (.962, .085, .064)]
    rings = []
    for f, rx, rz in table:
        y = nz * f
        if y < hem_y - 1e-6:
            continue
        # Por debajo de la cintura la prenda de arriba pasa por fuera del pantalón o la falda.
        over = .006 * max(0.0, min(1.0, (.68 - f) / .06))
        rings.append((y, 0, -.006 if .8 < f < .92 else 0, rx * W + ease + over, rz * W + ease + over))
    if rings[0][0] > hem_y + 1e-6:
        y0, _, _, rx0, rz0 = rings[0]
        rings.insert(0, (hem_y, 0, 0, rx0 * 1.02, rz0 * 1.02))
    return rings


def ring_at(rings, y):
    """Sección interpolada (cx, cz, rx, rz) de una lista de anillos a la altura y."""
    rs = sorted(rings, key=lambda r: r[0])
    if y <= rs[0][0]:
        return rs[0][1:]
    for r0, r1 in zip(rs, rs[1:]):
        if r0[0] <= y <= r1[0]:
            t = (y - r0[0]) / max(r1[0] - r0[0], 1e-6)
            return tuple(a + (c - a) * t for a, c in zip(r0[1:], r1[1:]))
    return rs[-1][1:]


def front_of(rings, y, x=0.0, lift=.002):
    """Punto de la superficie delantera de la prenda en (x, y), un poco por fuera."""
    cx, cz, rx, rz = ring_at(rings, y)
    k = math.sqrt(max(0.0, 1 - min(1.0, ((x - cx) / rx) ** 2)))
    return (x, y, cz - rz * k - lift)


def densify(rings, step=.015):
    """Interpola anillos cada `step` metros de altura para que las arrugas tengan geometría."""
    out = [rings[0]]
    for r0, r1 in zip(rings, rings[1:]):
        count = max(1, int(abs(r1[0] - r0[0]) / step))
        for k in range(1, count + 1):
            t = k / count
            out.append(tuple(a + (c - a) * t for a, c in zip(r0, r1)))
    return out


def wrinkles(zones, seed=0.0):
    """Arrugas de tela: zones = [(y_centro, semialto, amplitud, frecuencia, lado)], lado = +1 delante,
    -1 detrás, 0 alrededor. Pliegues horizontales ondulados que se desvanecen fuera de la zona."""
    def shape(a, y):
        k = 1.0
        for yc, half, amp, freq, side in zones:
            d = (y - yc) / half
            if abs(d) >= 1:
                continue
            fall = (1 - d * d) ** 2
            facing = 1.0 if side == 0 else max(0.0, side * math.cos(a)) ** .7
            wobble = math.sin(a * 3 + seed) * .8
            k += amp * fall * facing * math.sin((y - yc) * freq + wobble) ** 2
        return k
    return shape


def add_hem(piece, ring, n, inward=.006, depth=.02, up=True):
    """Dobladillo: el borde abierto se vuelve hacia dentro, así la tela tiene grosor visible."""
    y, cx, cz, rx, rz = ring
    d = depth if up else -depth
    loft(piece, [(y, cx, cz, rx, rz), (y, cx, cz, rx - inward, rz - inward), (y + d, cx, cz, rx - inward * 1.2, rz - inward * 1.2)], n, False, False)


def sleeve(piece, b, sign, ease, length, cuff=False, puff=1.0):
    """Manga desde la copa del hombro hasta `length` (fracción del brazo completo hasta la muñeca)."""
    S = b.S
    x = b.sh_x * sign
    arm = b.sh_y - b.wr_y
    end_y = b.sh_y - arm * length
    rings = [(b.sh_y + .052 * S, x * .86, 0, .02 * S, .026 * S), (b.sh_y + .04 * S, x * .92, 0, .044 * S * puff, .048 * S * puff),
             (b.sh_y + .01, x * .98, 0, .056 * S * puff + ease, .058 * S * puff + ease), (b.sh_y - .05, x, -.003, .05 * S + ease, .053 * S + ease)]
    ys = [b.sh_y - .1, (b.sh_y + b.el_y) * .5, b.el_y + .02, b.el_y - .03, (b.el_y + b.wr_y) * .5, b.wr_y + .03]
    radius = {ys[0]: .047, ys[1]: .044, ys[2]: .039, ys[3]: .039, ys[4]: .036, ys[5]: .031}
    for y in ys:
        if y > end_y + .015:
            rings.append((y, x, -.002, radius[y] * S + ease, radius[y] * S * 1.05 + ease))
    last = rings[-1]
    flare = .004 if length < .6 else 0
    rings.append((end_y, x, 0, last[3] + flare, last[4] + flare))
    folds = []
    if length > .6:
        # Pliegues del codo por delante y algo de tela acumulada sobre el puño.
        folds = [(b.el_y + .01, .07, .22, 150.0, 1), (end_y + .05, .05, .15, 200.0, 0)]
    head = [r for r in rings if r[0] > b.sh_y - .06]
    tail = [r for r in rings if r[0] <= b.sh_y - .06]
    loft(piece, head + densify(tail, .012)[1:] if tail else head, 14, cap_bottom=False, cap_top=True, shape=wrinkles(folds, sign))
    if cuff:
        y = end_y
        loft(piece, [(y - .004, x, 0, last[3] + .004, last[4] + .004), (y + .045, x, 0, last[3] + .004, last[4] + .004)], 10, False, False)
    add_hem(piece, (end_y, x, 0, last[3] + flare, last[4] + flare), 10)
    return end_y


def neckline(piece, b, ease, height=.0, z_front=0.0):
    nz, S = b.nz, b.S
    y = nz * .968 + height
    loft(piece, [(nz * .955, 0, .004, .098 * b.W + ease, .068 * b.W + ease), (y, 0, .006 + z_front, .06 * S + ease * .6, .058 * S + ease * .6),
         (y - .012, 0, .006 + z_front, .052 * S, .05 * S)], 10, False, False)


def top_hides(length):
    hides = ["pecho", "abdomen", "cintura", "hombro.I", "hombro.D"]
    # El brazo solo se oculta si la manga lo cubre entero (hasta el codo, 0,56 del brazo); con manga
    # corta quedaba un hueco de madera entre la manga y el codo.
    if length > .56:
        hides += ["brazo.I", "brazo.D", "codo.I", "codo.D"]
    if length > .9:
        hides += ["antebrazo.I", "antebrazo.D"]
    return hides


def build_torso(b, piece_def):
    style, sleeve_len = piece_def["style"], piece_def.get("sleeve", 1)
    W, S, nz = b.W, b.S, b.nz
    parts, hides = [], []
    ease = {"plain": .012, "collar": .014, "lapel": .024, "hood": .03, "sport": .006, "tank": .008, "coat": .028}[style]
    # Bajos a la altura natural: camiseta y sudadera justo bajo el cinturón, americana tapando la cadera.
    hem_y = {"plain": nz * .605, "collar": nz * .59, "lapel": nz * .53, "hood": nz * .6, "sport": nz * .61, "tank": nz * .6, "coat": nz * .53}[style]
    if style == "tank":
        return build_tank(b, ease, hem_y)
    tailored = style in ("lapel", "coat")
    body = cloth()
    parts.append(body)
    rings = torso_rings(b, ease, hem_y)
    if tailored:
        # Americana: hombros con hombrera y el cuerpo recto.
        rings = [(y, cx, cz, rx * (1.03 if y > nz * .9 else 1.0), rz) for (y, cx, cz, rx, rz) in rings]
    # Tela ahuecada sobre el cinturón y algo de arruga bajo el pecho.
    body_folds = [(hem_y + .07, .05, .025 if style != "sport" else .01, 110.0, 0), (nz * .76, .06, .03, 90.0, 1)]
    loft(body, densify(rings, .015), 16, cap_bottom=False, cap_top=False, shape=wrinkles(body_folds, 1.7))
    add_hem(body, rings[0], 16)
    neckline(body, b, ease, .004 if style == "hood" else 0.0)
    for side, sign in (("I", -1), ("D", 1)):
        arm_piece = cloth(candidates=ARM_BONES[side])
        parts.append(arm_piece)
        sleeve(arm_piece, b, sign, ease * (.8 if style != "hood" else 1.0), sleeve_len if not tailored else .98,
               cuff=style in ("collar", "hood"), puff=1.08 if tailored else 1.0)
    hides += top_hides(sleeve_len)
    front_z = lambda y: front_of(rings, y)[2]
    if style == "collar":
        # Camisa: cuello de pajarita con puntas, tapeta con botones y bolsillo de pecho.
        collar = cloth(darken=.06)
        parts.append(collar)
        cy = nz * .958
        loft(collar, [(cy - .006, 0, .006, .064 * S + .004, .062 * S + .004), (cy + .024, 0, .01, .058 * S + .004, .056 * S + .004),
             (cy + .03, 0, .01, .054 * S, .052 * S)], 12, False, False)
        for sign in (-1, 1):
            slab(collar, [(sign * .012, cy + .02, -.064 * S), (sign * .05 * S, cy + .01, -.05 * S), (sign * .046 * S, cy - .03, -.07 * S), (sign * .01, cy - .014, -.07 * S)], (0, .2, -1), .004)
        placket = cloth(darken=.08, subdivide=0)
        parts.append(placket)
        z = front_z(nz * .7) - .003
        slab(placket, [front_of(rings, hem_y + .01, -.012), front_of(rings, hem_y + .01, .012), front_of(rings, cy - .03, .012), front_of(rings, cy - .03, -.012)], (0, 0, -1), .003)
        buttons = Piece("acento", candidates=TOP_BONES, subdivide=0)
        parts.append(buttons)
        for k in range(5):
            y = hem_y + .04 + k * (cy - hem_y - .08) / 4
            ball(buttons, (0, y, front_z(y) - .007), .0045, 1, (1, 1, .5))
        pocket = cloth(darken=.05, subdivide=0)
        parts.append(pocket)
        py = nz * .86
        slab(pocket, [front_of(rings, py - .05, .045 * W), front_of(rings, py - .05, .105 * W), front_of(rings, py + .01, .105 * W), front_of(rings, py + .01, .045 * W)], (0, 0, -1), .003)
    elif tailored:
        # Americana: abierta en V hasta el botón, con la camisa blanca a la vista, solapas de muesca
        # más oscuras que el paño, el canto del delantero, dos botones grandes, pañuelo en el
        # bolsillo del pecho y carteras. Todo en placas que siguen la curva del pecho (patch), no en
        # triángulos planos que se hundían en él: de lejos se leía como un jersey.
        cy = nz * .958
        v_bottom = nz * (.715 if style == "lapel" else .76)
        steps = 8
        shirt = Piece("acento", candidates=TOP_BONES, subdivide=0)
        parts.append(shirt)
        rows = []
        for k in range(steps + 1):
            t = k / steps
            half = max(.004, (.064 * S) * (1 - t) + .004 * t)
            rows.append((cy - .004 + (v_bottom - cy + .004) * t, -half, half))
        patch(shirt, rings, rows, .005, .002, 6)
        # Cuello de la camisa: dos puntas blancas sobre la solapa.
        for sign in (-1, 1):
            patch(shirt, rings, [(cy + .006, sign * .012, sign * .05 * S), (cy - .03, sign * .02, sign * .04 * S)], .012, .003, 2)
        lapels = cloth(darken=.2)
        parts.append(lapels)
        for sign in (-1, 1):
            rows = []
            for k in range(steps + 1):
                t = k / steps
                inner = max(.004, (.064 * S) * (1 - t) + .004 * t)
                # Cuello hasta la muesca (t = 0,3) y de ahí la solapa, que se estrecha hacia el botón.
                width = (.03 + .03 * t / .3) * W if t < .3 else max(.006, .078 * W * (1 - (t - .3) / .7))
                rows.append((cy + .004 + (v_bottom - .006 - cy) * t, sign * inner, sign * (inner + width)))
            patch(lapels, rings, rows, .008, .005, 3)
        # Canto del delantero, del botón al bajo.
        edge = cloth(darken=.28, subdivide=0)
        parts.append(edge)
        patch(edge, rings, [(v_bottom, .002, .012), ((v_bottom + hem_y) * .5, .002, .012), (hem_y + .004, .002, .012)], .004, .004, 1)
        buttons = Piece("calzado", candidates=TOP_BONES, subdivide=0)
        parts.append(buttons)
        for y in (nz * .695, nz * .64):
            ball(buttons, (-.012, y, front_z(y) - .009), .013, 1, (1, 1, .45))
        if style == "lapel":
            # Pañuelo en el bolsillo del pecho.
            hanky = Piece("acento", candidates=TOP_BONES, subdivide=0)
            parts.append(hanky)
            patch(hanky, rings, [(nz * .862, .075 * W, .125 * W), (nz * .845, .07 * W, .13 * W)], .006, .004, 2)
        else:
            coat_extras(parts, b, rings, ease)
        flaps = cloth(darken=.16, subdivide=0)
        parts.append(flaps)
        for sign in (-1, 1):
            py = nz * .6
            patch(flaps, rings, [(py, sign * .06 * W, sign * .14 * W), (py - .03, sign * .06 * W, sign * .14 * W)], .004, .005, 2)
    elif style == "hood":
        # Sudadera: capucha real caída sobre la espalda, cordones, bolsillo canguro y puños elásticos.
        hood = cloth(darken=.05)
        parts.append(hood)
        cy = nz * .96
        hood_rings = []
        for k, (dy, rx, rz, cz) in enumerate([(.03, .075, .07, .02), (0.0, .11, .1, .045), (-.05, .12, .11, .07), (-.11, .105, .09, .085), (-.16, .06, .05, .085)]):
            hood_rings.append((cy + dy * S, 0, cz * W, rx * W, rz * W))
        # Media capucha: solo la mitad trasera de cada sección (la delantera queda abierta sobre el cuello).
        rows = []
        n = 12
        for (y, cx, cz, rx, rz) in hood_rings:
            pts = []
            for i in range(n + 1):
                a = math.pi * .35 + i * math.pi * 1.3 / n
                pts.append((cx + math.sin(a) * rx, y, cz - math.cos(a) * rz))
            rows.append(hood.verts(pts))
        for r0, r1 in zip(rows, rows[1:]):
            for i in range(n):
                hood.face([r0[i], r0[i + 1], r1[i + 1], r1[i]])
        strings = Piece("acento", candidates=TOP_BONES, subdivide=0)
        parts.append(strings)
        for sign in (-1, 1):
            x = sign * .03
            tube(strings, [(x, cy - .005, -.07 * S), (x, cy - .07, front_z(cy - .07) - .006), (x * 1.1, cy - .14, front_z(cy - .14) - .008)], .0035, 5)
        pocket = cloth(darken=.07)
        parts.append(pocket)
        py0, py1 = hem_y + .03, nz * .69
        slab(pocket, [front_of(rings, py0, -.1 * W), front_of(rings, py0, .1 * W), front_of(rings, py1, .075 * W), front_of(rings, py1, -.075 * W)], (0, 0, -1), .006)
        rib = cloth(darken=.1)
        parts.append(rib)
        r0 = rings[0]
        loft(rib, [(hem_y - .002, 0, 0, r0[3] - .004, r0[4] - .004), (hem_y + .05, 0, 0, r0[3] - .008, r0[4] - .008)], 12, False, False)
    elif style == "sport":
        stripes = Piece("acento", candidates=TOP_BONES, subdivide=0)
        parts.append(stripes)
        for sign in (-1, 1):
            for k in range(2):
                y0, y1 = hem_y + .03, nz * .93
                x0 = sign * (.155 * W + ease + .001)
                slab(stripes, [(x0, y0, -.02 + k * .018), (x0, y0, -.01 + k * .018), (sign * (.17 * W + ease), y1, -.01 + k * .018), (sign * (.17 * W + ease), y1, -.02 + k * .018)], (sign, 0, 0), .002)
    return parts, hides


def build_tank(b, ease, hem_y):
    """Camiseta de tirantes: el paño acaba bajo los brazos; hombros, brazos y lo alto del pecho son
    madera a la vista, con un tirante sobre cada hombro. No oculta el pecho ni los brazos."""
    W, S, nz = b.W, b.S, b.nz
    parts = []
    body = cloth()
    parts.append(body)
    full = torso_rings(b, ease, hem_y)
    top_y = nz * .885
    rings = [r for r in full if r[0] <= top_y + 1e-6]
    folds = [(hem_y + .07, .05, .02, 110.0, 0), (nz * .76, .06, .025, 90.0, 1)]
    loft(body, densify(rings, .015), 16, cap_bottom=False, cap_top=False, shape=wrinkles(folds, 2.3))
    add_hem(body, rings[0], 16)
    add_hem(body, rings[-1], 16, up=False)
    straps = cloth(darken=.06, subdivide=0)
    parts.append(straps)
    for sign in (-1, 1):
        x = sign * .088 * W
        path, outs = [], []
        for side in (-1, 1):                      # -1: por delante (subiendo); 1: por detrás (bajando)
            ys = [.87, .90, .925, .945, .957]
            for f in (ys if side < 0 else reversed(ys)):
                cx, cz, rx, rz = ring_at(full, nz * f)
                k = math.sqrt(max(0.0, 1 - min(1.0, (x / rx) ** 2)))
                p = Vector((x, nz * f, cz + side * (rz * k + .003)))
                path.append(p)
                outs.append((p - Vector((x * .5, nz * .9, 0))).normalized())
        ribbon(straps, path, outs, [.017 * S] * len(path), .003, 6)
    return parts, ["abdomen", "cintura"]


def open_shell(piece, rows, thickness=.005):
    """Tela abierta (faldón de abrigo): rows = filas de puntos, de arriba abajo. Cara de fuera, cara
    de dentro (desplazada hacia el eje) y los cantos, para que se vea por los dos lados."""
    outer = [piece.verts(r) for r in rows]
    inner = []
    for r in rows:
        pts = []
        for (x, y, z) in r:
            d = Vector((x, 0, z))
            d = d.normalized() * thickness if d.length > 1e-6 else Vector()
            pts.append((x - d.x, y, z - d.z))
        inner.append(piece.verts(pts))
    n = len(rows[0])
    for r in range(len(rows) - 1):
        for i in range(n - 1):
            piece.face([outer[r][i], outer[r][i + 1], outer[r + 1][i + 1], outer[r + 1][i]])
            piece.face([inner[r + 1][i], inner[r + 1][i + 1], inner[r][i + 1], inner[r][i]])
        for i in (0, n - 1):
            piece.face([outer[r][i], outer[r + 1][i], inner[r + 1][i], inner[r][i]])
    for r in (0, len(rows) - 1):
        for i in range(n - 1):
            piece.face([outer[r][i], inner[r][i], inner[r][i + 1], outer[r][i + 1]])


def coat_extras(parts, b, rings, ease):
    """Gabardina: cinturón con hebilla y faldones hasta medio muslo, abiertos por delante en A para
    que las piernas pasen por el hueco al andar en vez de atravesar la tela."""
    W, S, nz = b.W, b.S, b.nz
    belt = cloth(darken=.3, subdivide=0)
    parts.append(belt)
    by = nz * .655
    cx, cz, rx, rz = ring_at(rings, by)
    loft(belt, [(by - .022, 0, cz, rx + .005, rz + .005), (by + .022, 0, cz, rx + .005, rz + .005)], 20, False, False)
    buckle = Piece("calzado", candidates=TOP_BONES, subdivide=0)
    parts.append(buckle)
    slab(buckle, [(-.022, by - .018, cz - rz - .008), (.022, by - .018, cz - rz - .008), (.022, by + .018, cz - rz - .008), (-.022, by + .018, cz - rz - .008)], (0, 0, -1), .004)
    tails = cloth(candidates=["caderas", "lumbar"])
    parts.append(tails)
    top_y, hem = nz * .56, nz * .405
    _, _, rx0, rz0 = ring_at(rings, nz * .56)
    rows = []
    steps, n = 6, 22
    for k in range(steps + 1):
        t = k / steps
        y = top_y + (hem - top_y) * t
        gap = .16 + 1.06 * t ** .55               # semiángulo de la abertura: casi cerrado arriba, 70° abajo
        rx = rx0 - .004 + (.03 * W + .012) * t
        rz = rz0 - .004 + (.05 * W + .016) * t
        row = []
        for i in range(n + 1):
            a = gap + (math.tau - 2 * gap) * i / n
            wave = 1.0 + .018 * t * math.sin(a * 7 + 1.3)
            row.append((math.sin(a) * rx * wave, y, -math.cos(a) * rz * wave))
        rows.append(row)
    open_shell(tails, rows)
    # Charreteras: la trabilla de los hombros de una gabardina.
    tabs = cloth(darken=.14, subdivide=0)
    parts.append(tabs)
    for sign in (-1, 1):
        y = b.sh_y + .05 * S
        slab(tabs, [(sign * .07 * W, y + .012, -.02), (sign * .15 * W, y - .004, -.022), (sign * .15 * W, y - .004, .022), (sign * .07 * W, y + .012, .02)], (0, 1, 0), .005)


def shoe(parts, b, sign, sport, formal):
    S = b.S
    lx = b.leg_x * sign
    zone = "acento" if sport else "calzado"
    upper = Piece(zone, bone="pie." + ("I" if sign < 0 else "D"), part="zapato")
    parts.append(upper)
    length = .26 * S * (1.08 if formal else 1.0)
    heel_z, toe_z = .05 * S, .05 * S - length
    rings = []
    for k in range(8):
        t = k / 7
        z = heel_z + (toe_z - heel_z) * t
        width = (.04 + .012 * math.sin(math.pi * min(1, t * 1.25))) * S * (0.9 if formal and t > .8 else 1.0)
        top = (b.ankle_y + .035 * S) * (1 - t) ** 1.4 + .03 * S * (1 - (1 - t) ** 1.4) if t < .95 else .018 * S
        rings.append((z, width, top))
    # Loft a lo largo de z: secciones redondeadas por arriba y planas por abajo.
    rows = []
    n = 10
    for z, w, top in rings:
        pts = []
        for i in range(n):
            a = i * math.tau / n
            y = .012 + (top - .012) * (.5 + .5 * math.cos(a)) if math.cos(a) > -.3 else .006
            pts.append((lx + math.sin(a) * w, max(.006, y), z))
        rows.append(upper.verts(pts))
    for r0, r1 in zip(rows, rows[1:]):
        for i in range(n):
            upper.face([r0[i], r0[(i + 1) % n], r1[(i + 1) % n], r1[i]])
    for row in (rows[0], rows[-1]):
        c = upper.bm.verts.new(sum((v.co for v in row), Vector()) / n)
        for i in range(n):
            upper.face([row[i], row[(i + 1) % n], c])
    sole = Piece("calzado" if sport else "calzado", bone="pie." + ("I" if sign < 0 else "D"), part="zapato", darken=.35 if not sport else 0.0, lighten=.3 if sport else 0.0, subdivide=0)
    parts.append(sole)
    h = .022 * S if sport else .012 * S
    loop = [(lx + math.sin(a) * (.046 * S + .004), 0, (heel_z + toe_z) * .5 + math.cos(a) * (length * .5 + .006)) for a in [k * math.tau / 14 for k in range(14)]]
    slab(sole, loop, (0, 1, 0), h)


def leg_rings(b, lx, ease, end_y, fit):
    """Pernera: recta (fit=0) o ceñida al gemelo (fit=1)."""
    S = b.S
    calf = b.knee_y - b.ankle_y
    table = [(b.hip_y + .02, .082, .084, 0), (b.hip_y - .09, .077, .079, -.003), ((b.hip_y + b.knee_y) * .5, .068, .07, -.002),
             (b.knee_y + .03, .058, .06, 0), (b.knee_y - .03, .055, .058, .002), (b.knee_y - calf * .3, .054, .06, .005),
             (b.knee_y - calf * .6, .05, .052, .003), (b.ankle_y + .05, .048, .05, 0), (b.ankle_y + .02, .049, .051, 0)]
    tight = [(y, r * .88 if y > b.knee_y else r * .85, rz * .88 if y > b.knee_y else rz * .85, cz) for (y, r, rz, cz) in table]
    body_calf = {table[5][0]: (.048, .056), table[6][0]: (.04, .044), table[7][0]: (.03, .031), table[8][0]: (.028, .029)}
    rings = []
    for (y, r, rz, cz), (_, tr, trz, _) in zip(table, tight):
        if y < end_y - 1e-6:
            continue
        if fit:
            br, brz = body_calf.get(y, (tr, trz))
            r, rz = br, brz
        rings.append((y, lx, cz, r * S + ease, rz * S + ease))
    last = rings[-1]
    if last[0] > end_y + .005:
        rings.append((end_y, lx, last[2], last[3], last[4]))
    return rings


def skirt_weights(b):
    def fn(p):
        # La falda sigue a la cadera arriba y, hacia el bajo, medio muslo de cada lado: se abre al
        # andar y cubre los muslos al sentarse, sin partirse entre las piernas.
        t = max(0.0, min(1.0, (b.hip_y + .02 - p.y) / (b.hip_y - b.knee_y)))
        # Delante la falda sigue al muslo casi del todo (al sentarse cubre el regazo); detrás, menos.
        front = max(0.0, min(1.0, .5 - p.z / (.25 * b.W)))
        follow = (.85 + .12 * front) * t
        side = max(0.0, min(1.0, .5 + p.x / (b.leg_x * 2.2)))
        w = [("caderas", 1 - follow), ("muslo.D", follow * side), ("muslo.I", follow * (1 - side))]
        return [(n, v) for n, v in w if v > .005]
    return fn


def pants_weights(b):
    """Cada pernera va con su pierna (muslo arriba, pierna bajo la rodilla, fundidos en la rodilla) y
    solo cerca de la cadera se funde con la pelvis: al andar la pernera no se separa de la pierna."""
    def smooth(e0, e1, x):
        t = max(0.0, min(1.0, (x - e0) / (e1 - e0)))
        return t * t * (3 - 2 * t)

    def fn(p):
        side = "D" if p.x > 0 else "I"
        leg = smooth(b.hip_y + .06, b.hip_y - .07, p.y)
        # En la entrepierna y el centro de la culera, más pelvis: no se estira entre las dos piernas.
        centre = max(0.0, 1 - abs(p.x) / (b.leg_x * .9))
        leg *= 1 - .6 * centre * smooth(b.hip_y - .12, b.hip_y + .02, p.y)
        calf = smooth(b.knee_y + .05, b.knee_y - .05, p.y)
        w = [("caderas", 1 - leg), ("muslo." + side, leg * (1 - calf)), ("pierna." + side, leg * calf)]
        return [(n, v) for n, v in w if v > .005]
    return fn


def build_legs(b, piece_def):
    style, length = piece_def["style"], piece_def.get("length", 1)
    sport = piece_def.get("sport", False)
    formal = style == "formal"
    W, S, nz = b.W, b.S, b.nz
    parts, hides = [], ["pelvis"]
    waist_y = nz * .655
    if style == "skirt":
        # Ocho cadenas alrededor de la cadera: la falda se balancea al andar y los muslos la empujan.
        hem0 = b.hip_y - .295 * nz
        skirt_chains = Chains("falda", "caderas", (0, 0, .005), top=b.hip_y + .03, blend=.07, stiffness=2.6, drag=.5, gravity=.15, radius=.008)
        for k in range(8):
            a = (k + .5) * math.tau / 8
            # Las cadenas delanteras cuelgan del muslo: al andar lo siguen y al sentarse cubren el regazo.
            # (también las traseras: al sentarse, la falda queda bajo los muslos, sobre el asiento).
            front_parent = "muslo.D" if math.sin(a) > 0 else "muslo.I"
            pts = []
            for u in (0.0, .34, .68, 1.0, 1.12):
                y = b.hip_y + .02 - (b.hip_y + .02 - hem0) * u
                rx = (.19 + .045 * min(u, 1)) * W
                rz = (.14 + .045 * min(u, 1)) * W
                pts.append((math.sin(a) * rx, y, .005 - math.cos(a) * rz))
            skirt_chains.add(pts, front_parent)
        skirt = Piece("tela_b", candidates=LEG_BONES, weight_fn=skirt_chains.weight)
        skirt.drape = {"pin": lambda p: 1.0 if p.y > b.hip_y - .02 else 0.0, "frames": 70, "bending": .6}
        parts.append(skirt)
        hem = b.hip_y - .295 * nz
        pleats = lambda a, y: 1.0 + .025 * math.cos(a * 14) * max(0.0, (waist_y - y) / (waist_y - hem))
        rings = [(waist_y, 0, 0, .135 * W, .095 * W), (nz * .6, 0, 0, .168 * W, .118 * W), (b.hip_y, 0, 0, .19 * W, .14 * W),
                 (b.hip_y - .1, 0, .005, .235 * W, .185 * W), ((b.hip_y + hem) * .5, 0, .008, .27 * W, .22 * W),
                 (hem + .04, 0, .01, .305 * W, .255 * W), (hem, 0, .01, .315 * W, .265 * W)]
        # Falda evasé: el bajo es más ancho que la cadera y la simulación lo recoge en pliegues.
        # Godets: ondas que nacen bajo la cadera y se abren hacia el bajo; la simulación las asienta.
        godets = lambda a, y: 1.0 + .07 * math.sin(a * 9 + .6 * math.sin(a * 3)) * max(0.0, min(1.0, (b.hip_y - .05 - y) / (b.hip_y - .05 - hem))) ** 1.3
        loft(skirt, list(reversed(rings)), 36, cap_bottom=False, cap_top=False, shape=godets)
        # Sin dobladillo vuelto: la simulación de tela lo descolgaba en tiras.
        band = Piece("tela_b", bone="caderas", darken=.12)
        parts.append(band)
        loft(band, [(waist_y - .03, 0, 0, .14 * W, .1 * W), (waist_y + .006, 0, 0, .137 * W, .097 * W)], 16, False, False)
        hides += ["cadera.I", "cadera.D"]
        band.weight_fn = None
        for sign in (-1, 1):
            shoe(parts, b, sign, sport, formal)
        return parts, hides, [skirt_chains]
    ease = {"plain": .012, "formal": .01, "sport": .004 if length > .9 else .016}[style]
    fit = 1 if (sport and length > .9) else 0
    end_y = b.ankle_y + .02 if length > .9 else b.knee_y + (.06 if style == "plain" else .14) * nz
    pants = Piece("tela_b", weight_fn=pants_weights(b))
    parts.append(pants)
    # Cintura y culera: un tubo desde la cintura hasta la entrepierna; las perneras nacen dentro.
    seat_ease = .006
    seat = [(nz * .515, 0, 0, .145 * W + seat_ease, .098 * W + seat_ease), (nz * .56, 0, 0, .164 * W + seat_ease, .11 * W + seat_ease),
            (nz * .62, 0, 0, .156 * W + seat_ease, .105 * W + seat_ease), (waist_y, 0, 0, .138 * W + seat_ease, .095 * W + seat_ease)]
    loft(pants, seat, 12, cap_bottom=True, cap_top=False)
    for side, sign in (("I", -1), ("D", 1)):
        lx = b.leg_x * sign
        rings = leg_rings(b, lx, ease, end_y, fit)
        folds = [] if fit else [(b.knee_y - .01, .08, .18, 140.0, -1), (b.hip_y - .05, .06, .1, 120.0, 1)]
        if length > .9 and not fit:
            # Quiebre del bajo sobre el zapato.
            folds.append((end_y + .05, .06, .16, 170.0, 0))
        loft(pants, densify(rings, .012), 12, cap_bottom=False, cap_top=False, shape=wrinkles(folds, sign))
        add_hem(pants, rings[-1], 10, up=True)
        hides += ["cadera." + side]
        if length > .9:
            hides += ["muslo." + side, "rodilla." + side, "pierna." + side]
        if sport:
            # Franja lateral que sigue la pernera por fuera.
            stripe = Piece("acento", weight_fn=pants_weights(b), subdivide=0)
            parts.append(stripe)
            # Anillos densos: la franja se dobla en la rodilla sin abrirse.
            dense = []
            for r0, r1 in zip(rings, rings[1:]):
                for k in range(4):
                    t = k / 4
                    dense.append(tuple(a + (c - a) * t for a, c in zip(r0, r1)))
            dense.append(rings[-1])
            pts_a = [(r[1] + sign * (r[3] + .0015), r[0], r[2] - .006) for r in dense]
            pts_b = [(r[1] + sign * (r[3] + .0015), r[0], r[2] + .006) for r in reversed(dense)]
            slab(stripe, pts_a + pts_b, (sign, 0, 0), .0015)
    if not sport:
        belt = Piece("calzado", bone="caderas", darken=.1)
        parts.append(belt)
        loft(belt, [(waist_y - .026, 0, 0, .141 * W + seat_ease + .002, .097 * W + seat_ease + .002), (waist_y + .002, 0, 0, .139 * W + seat_ease + .002, .096 * W + seat_ease + .002)], 16, False, False)
    if formal:
        crease = Piece("tela_b", weight_fn=pants_weights(b), darken=.1, subdivide=0)
        parts.append(crease)
        for sign in (-1, 1):
            lx = b.leg_x * sign
            tube(crease, [(lx, b.hip_y - .05, -(.082 * S + ease)), (lx, b.knee_y, -(.061 * S + ease)), (lx, end_y + .01, -(.052 * S + ease))], .0025, 4, caps=False)
    for sign in (-1, 1):
        shoe(parts, b, sign, sport, formal)
    return parts, hides


# ---------------------------------------------------------------- pelo y tocados

def skull(b):
    hh = b.head
    return [(0, .17, .20, -.025), (.12, .28, .30, -.03), (.34, .36, .365, -.015), (.64, .375, .395, .015),
            (.84, .31, .34, .025), (.96, .19, .23, .025), (1, .045, .06, .025)]


def skull_radius(b, f):
    """Semiejes (x, z, desplazamiento z) del cráneo a la altura f (fracción de la cabeza)."""
    table = skull(b)
    # La cabeza de madera se estira hacia la barbilla (build_body): y_madera = y_tabla * 1.08 - .1.
    f = max(0.0, min(1.0, (f + .1) / 1.08))
    for (y0, x0, z0, c0), (y1, x1, z1, c1) in zip(table, table[1:]):
        if y0 <= f <= y1:
            t = (f - y0) / max(y1 - y0, 1e-6)
            return (x0 + (x1 - x0) * t) * 1.04, z0 + (z1 - z0) * t, c0 + (c1 - c0) * t
    return table[-1][1] * 1.04, table[-1][2], table[-1][3]


def hair_shell(piece, b, edge, offset, clump=.012, seed=0.0, n=20, rows=8, below=None, lip=True, volume=.6, strands=0):
    """Casquete de pelo sobre el cráneo. edge(a) = altura del borde (fracción de la cabeza) en el
    ángulo a (0 = frente): la línea del pelo es una curva continua, sin escalones. Por debajo de la
    parte más ancha del cráneo (bordes negativos) el pelo cae en vertical con esa anchura (melenas).
    volume abomba la coronilla; strands > 0 marca mechones peinados (surcos a lo largo del pelo)."""
    hh, nz = b.head, b.nz
    grid = []
    for r in range(rows + 1):
        t = r / rows
        row = []
        for i in range(n):
            a = i * math.tau / n
            e = edge(a)
            f = e + (.97 - e) * (1 - (1 - t) ** 1.5)
            if f >= .64:
                x, z, cz = skull_radius(b, f)
            else:
                x, z, cz = skull_radius(b, max(f, .64))
                if f < .64:
                    drop = (.64 - f)
                    x *= 1 + drop * .12
                    z *= 1 + drop * .08
            # Grosor: más volumen en la coronilla que en el borde; mechones y algo de desorden.
            thick = offset * (1 + volume * max(0.0, (f - .6) / .4))
            if strands:
                wave = noise.noise(Vector((a * 1.3 + seed, f * 2.0, seed * .7)))
                thick += offset * .55 * abs(math.sin(a * strands + wave * 2.2)) ** .7
            thick += noise.noise(Vector((math.cos(a) * 2.5, f * 3.0, math.sin(a) * 2.5 + seed))) * clump
            k = 1.0 + (thick / hh) / max(x, .05)
            y = nz + hh * min(f, 1.0) + (thick * .6 if f > .9 else 0.0)
            row.append(piece.bm.verts.new(Vector((math.sin(a) * x * hh * k, y, hh * cz - math.cos(a) * z * hh * k))))
        grid.append(row)
    for r0, r1 in zip(grid, grid[1:]):
        for i in range(n):
            piece.face([r0[i], r0[(i + 1) % n], r1[(i + 1) % n], r1[i]])
    # Coronilla redonda: el polo queda a la altura media del último anillo, no en punta.
    top_y = sum(v.co.y for v in grid[-1]) / n + offset * .6
    top = piece.bm.verts.new(Vector((0, top_y, hh * .02)))
    for i in range(n):
        piece.face([grid[-1][i], grid[-1][(i + 1) % n], top])
    if lip:
        inner = []
        for v in grid[0]:
            c = Vector((0, v.co.y, hh * .01))
            inner.append(piece.bm.verts.new(v.co + (c - v.co).normalized() * offset * .9 + Vector((0, .004, 0))))
        for i in range(n):
            piece.face([grid[0][(i + 1) % n], grid[0][i], inner[i], inner[(i + 1) % n]])


def scalp(b, a, f, lift=0.0):
    """Punto del cuero cabelludo en el ángulo a y la altura f, levantado `lift` metros."""
    hh, nz = b.head, b.nz
    x, z, cz = skull_radius(b, f)
    k = 1 + lift / hh / max(x, .05)
    return Vector((math.sin(a) * x * hh * k, nz + hh * f, hh * cz - math.cos(a) * z * hh * k))


def clump(piece, centre, flow, normal, length, width, thick, bend=0.0):
    """Mechón esculpido: elipsoide alargado según el peinado (flow), achatado contra la cabeza."""
    flow = flow.normalized()
    normal = (normal - flow * normal.dot(flow)).normalized()
    side = flow.cross(normal)
    m = bmesh.new()
    bmesh.ops.create_icosphere(m, subdivisions=1, radius=1.0)
    lookup = {}
    for v in m.verts:
        u = v.co
        # Punta afilada en el extremo del mechón y curvatura hacia la cabeza.
        # Raíz en u.z = -1 y punta en u.z = 1: el mechón solo crece hacia la punta.
        taper = 1.0 - .28 * max(0.0, u.z) ** 2
        p = Vector(centre) + flow * ((u.z + 1) * .5 * length) + side * (u.x * width * taper) + normal * (u.y * thick * taper - bend * max(0.0, u.z) ** 2)
        lookup[v] = piece.bm.verts.new(p)
    for f in m.faces:
        piece.face([lookup[v] for v in f.verts])
    m.free()


def sculpted_hair(piece, b, edge, seed, rows, per_row, length, width, thick, hang=None, forward=0.0):
    """Pelo tallado: filas de mechones desde el borde hasta la coronilla. Cada mechón sigue el
    meridiano hacia abajo (o se peina hacia delante con `forward`). hang(a) alarga los mechones que
    caen por debajo del cráneo (melena)."""
    head_centre = Vector((0, b.nz + b.head * .5, 0))
    for r in range(rows):
        t = (r + .5) / rows
        count = max(3, int(per_row * (1.0 - .55 * t)))
        for k in range(count):
            a = (k + .5 + (.5 if r % 2 else 0)) * math.tau / count + noise.noise(Vector((r * 1.3, k * .7, seed))) * .15
            e = edge(a)
            f = e + .04 + (.92 - e) * t
            f = min(f, .93)
            root = scalp(b, a, f, thick * .55)
            below = scalp(b, a, max(f - .05, -.2), thick * .55)
            flow = below - root
            if forward:
                flow = flow + Vector((0, 0, -forward * (1 if math.cos(a) > -.3 else 0)))
            normal = root - head_centre
            L = length * (1.2 - .4 * t) * (1 + noise.noise(Vector((k, r, seed + 3))) * .2)
            extra = hang(a) * (1 - t) if hang else 0.0
            # Empieza un poco por encima de la raíz para solaparse con la fila anterior.
            start = root - flow.normalized() * (L * .25)
            clump(piece, start, flow, normal, L + extra, width * (1.15 - .3 * t), thick, bend=thick * .5)


def scalp_point(b, a, f, lift):
    """Como scalp(), pero por debajo de la parte más ancha del cráneo la melena cae recta con esa
    anchura en vez de cerrarse hacia la barbilla."""
    hh, nz = b.head, b.nz
    x, z, cz = skull_radius(b, max(f, .62))
    k = 1 + lift / hh / max(x, .05)
    return Vector((math.sin(a) * x * hh * k, nz + hh * f, hh * cz - math.cos(a) * z * hh * k))


def ribbon(piece, path, outs, widths, thick, n=8):
    """Mechón de peluca: cinta de sección aplanada que sigue la cabeza (outs = dirección hacia fuera)."""
    rows = []
    for i, p in enumerate(path):
        t = (path[min(i + 1, len(path) - 1)] - path[max(i - 1, 0)]).normalized()
        out = (outs[i] - t * outs[i].dot(t)).normalized()
        side = t.cross(out)
        w = widths[i]
        th = thick * (widths[i] / max(widths[0], 1e-6)) ** .5
        rows.append(piece.verts([tuple(p + side * math.cos(q) * w + out * (math.sin(q) * th + th * .6))
                                 for q in [k * math.tau / n for k in range(n)]]))
    for r0, r1 in zip(rows, rows[1:]):
        for k in range(n):
            piece.face([r0[k], r0[(k + 1) % n], r1[(k + 1) % n], r1[k]])
    for row, p in ((rows[0], path[0]), (rows[-1], path[-1])):
        c = piece.bm.verts.new(sum((v.co for v in row), Vector()) / n)
        for k in range(n):
            piece.face([row[k], row[(k + 1) % n], c])


def wig(piece, b, edge, seed, rows, per_row, width, thick, tip=None, part=0.0, sweep=0.0):
    """Peluca de mechones suaves. Cada mechón nace en una fila (desde la coronilla hacia el borde),
    sigue el cráneo hacia abajo y acaba en tip(a) (altura de la punta, por defecto el borde). part
    desplaza la raya; sweep peina los mechones de delante hacia un lado."""
    head_centre = Vector((0, b.nz + b.head * .45, 0))
    for r in range(rows):
        t = r / max(rows - 1, 1)
        count = max(4, int(per_row * (.45 + .55 * t)))
        for k in range(count):
            a0 = (k + (.5 if r % 2 else 0.0)) * math.tau / count + noise.noise(Vector((r * 1.7, k * .9, seed))) * .12
            end_f = tip(a0) if tip else edge(a0)
            root_f = .98 - (.98 - max(end_f, edge(a0)) - .02) * (.15 + .6 * t)
            steps = 7
            path, outs, widths = [], [], []
            for i in range(steps):
                u = i / (steps - 1)
                f = root_f + (end_f - root_f) * u
                a = a0 + sweep * math.cos(a0) * u + part * (1 - u) * .2
                lift = thick * (1.2 + (1 - t) * 1.2) * (1 - .25 * u)
                p = scalp_point(b, a, f, lift)
                path.append(p)
                outs.append((p - head_centre).normalized())
                widths.append(width * (1.0 - .55 * u ** 2) * (1 + .2 * noise.noise(Vector((k, r, seed + 5)))))
            ribbon(piece, path, outs, widths, thick)


def locks(piece, b, count, span, top_f, bottom_f, width, seed):
    """Mechones sueltos que caen sobre la frente (flequillo): cintas curvadas con punta."""
    hh, nz = b.head, b.nz
    for k in range(count):
        a = -span / 2 + span * (k + .5) / count + (noise.noise(Vector((k * 1.7, seed, 0))) * .08)
        pts = []
        for f in (top_f, (top_f + bottom_f) * .5, bottom_f):
            x, z, cz = skull_radius(b, f)
            out = .016 + (.004 if f == top_f else 0)
            k2 = 1 + out / hh / max(x, .05)
            pts.append(Vector((math.sin(a) * x * hh * k2, nz + hh * f, hh * cz - math.cos(a) * z * hh * k2)))
        radii = [width, width * .8, width * .15]
        tube(piece, pts, radii, 6)


def build_head(b, piece_def):
    style = piece_def["style"]
    hh, nz, S = b.head, b.nz, b.S
    parts = []
    if style == "bald":
        return parts, []

    head_chains = []

    def hair(**kw):
        kw.setdefault("bone", "cabeza")
        p = Piece("pelo", **kw)
        parts.append(p)
        return p

    def fabric(**kw):
        p = Piece("tela_b", bone="cabeza", **kw)
        parts.append(p)
        return p

    front = lambda a: max(0.0, math.cos(a))
    back = lambda a: max(0.0, -math.cos(a))
    if style == "short":
        edge = lambda a: .72 * front(a) ** 2 + .44 * (1 - front(a) ** 2) - .1 * back(a)
        base = hair()
        hair_shell(base, b, edge, .007, 0.0, 1.3, n=24, volume=.3)
        wig(hair(subdivide=0), b, edge, 1.3, 5, 22, .026 * S, .006 * S, sweep=.25)
    elif style == "fringe":
        edge = lambda a: .72 * front(a) ** 2 + .44 * (1 - front(a) ** 2) - .1 * back(a)
        base = hair()
        hair_shell(base, b, edge, .007, 0.0, 2.1, n=24, volume=.3)
        fringe_tip = lambda a: edge(a) - (.12 * front(a) ** 3)
        wig(hair(subdivide=0), b, edge, 2.1, 5, 22, .026 * S, .006 * S, tip=fringe_tip, sweep=.15)
    elif style == "long":
        edge = lambda a: (.7 * front(a) ** 3 + (-.55) * (1 - front(a) ** 3)) if abs(math.sin(a)) > .2 or math.cos(a) < 0 else .7
        edge = lambda a: .72 if math.cos(a) > .55 else (-.5 if math.cos(a) < .2 else .72 - (.55 - math.cos(a)) / .35 * 1.22)
        # La melena cae desde la altura de las orejas en siete cadenas que se mecen con la cabeza.
        top = nz + hh * .5
        long_chains = Chains("melena", "cabeza", (0, 0, hh * .02), top=top, blend=hh * .25, stiffness=1.2, drag=.5, gravity=.6, radius=.025)
        for k in range(7):
            a = math.pi * .45 + k * (math.pi * 1.1) / 6
            long_chains.add([scalp_point(b, a, f, .02 * S) for f in (.5, .15, -.2, -.5, -.62)])
        head_chains.append(long_chains)
        base = hair(bone=None, weight_fn=long_chains.weight)
        hair_shell(base, b, edge, .012, 0.0, 3.4, n=28, rows=10, below=True, volume=.3)
        wig(hair(subdivide=0, bone=None, weight_fn=long_chains.weight), b, edge, 3.4, 5, 26, .03 * S, .007 * S, part=.4)
    elif style == "tail":
        edge = lambda a: .72 * front(a) ** 2 + .42 * (1 - front(a) ** 2) - .08 * back(a)
        hair_shell(hair(), b, edge, .008, 0.0, 4.2, n=24, volume=.2)
        # Pelo recogido: mechones tirantes hacia la nuca.
        wig(hair(subdivide=0), b, edge, 4.2, 4, 22, .026 * S, .005 * S)
        z0 = hh * (.395 + .03)
        path = [(0, nz + hh * .55, z0), (0, nz + hh * .45, z0 + .05), (0, nz + hh * .2, z0 + .065), (0, nz - hh * .08, z0 + .04)]
        tail_chain = Chains("coleta", "cabeza", (0, 0, 0), top=0, stiffness=.9, drag=.35, gravity=.8, radius=.02, along=1.0)
        tail_chain.add(path + [(0, nz - hh * .2, z0 + .03)])
        head_chains.append(tail_chain)
        tail = hair(subdivide=1, bone=None, weight_fn=tail_chain.weight)
        tube(tail, path, [.024 * S, .028 * S, .022 * S, .01 * S], 10)
        tie = fabric(darken=.3, subdivide=0)
        tube(tie, [(0, nz + hh * .57, z0 - .005), (0, nz + hh * .53, z0 + .012)], .02 * S, 10)
    elif style == "bun":
        # Moño: el pelo tirante hacia atrás y recogido en una bola alta, con su goma.
        edge = lambda a: .72 * front(a) ** 2 + .42 * (1 - front(a) ** 2) - .08 * back(a)
        hair_shell(hair(), b, edge, .008, 0.0, 5.1, n=24, volume=.2)
        wig(hair(subdivide=0), b, edge, 5.1, 4, 22, .026 * S, .005 * S)
        x8, z8, c8 = skull_radius(b, .84)
        centre = (0, nz + hh * .90, hh * c8 + z8 * hh + .03)
        bun = hair(lighten=.03)
        lumps = lambda p: 1.0 + .1 * noise.noise(Vector((p[0] * 40, p[1] * 40, p[2] * 40)))
        m = bmesh.new()
        bmesh.ops.create_icosphere(m, subdivisions=2, radius=hh * .215)
        lookup = {}
        for v in m.verts:
            k = lumps(v.co)
            lookup[v] = bun.bm.verts.new(Vector(centre) + Vector((v.co.x * 1.05 * k, v.co.y * .95 * k, v.co.z * k)))
        for f in m.faces:
            bun.face([lookup[v] for v in f.verts])
        m.free()
        tie = fabric(darken=.3, subdivide=0)
        tube(tie, [(0, centre[1] - hh * .1, centre[2] - hh * .13), (0, centre[1] - hh * .05, centre[2] - hh * .07)], hh * .1, 10)
    elif style == "curly":
        # Pelo rizado: un casquete con mucho volumen y una capa de rizos (bolas) por toda la cabeza.
        edge = lambda a: .70 * front(a) ** 2 + .34 * (1 - front(a) ** 2) - .12 * back(a)
        hair_shell(hair(), b, edge, .026, .006, 6.3, n=24, rows=8, volume=.1)
        curls = hair(subdivide=1, lighten=.03)
        # Los rizos se reparten por anillos, de la coronilla al borde, sobre el casquete (que
        # abulta más arriba: de ahí el levante según la altura).
        centre = Vector((0, nz + hh * .5, hh * .02))
        ball(curls, (0, nz + hh * 1.0, hh * .02), .05 * S, 1, (1, .6, 1))
        for r in range(1, 9):
            f = 1.0 - r * .085
            count = int(5 + r * 3.2)
            for k in range(count):
                a = (k + (.5 if r % 2 else 0.0)) * math.tau / count
                a = math.atan2(math.sin(a), math.cos(a))
                if f < edge(a) + .015:
                    continue
                jitter = noise.noise(Vector((k * .37 + r, 6.3, r * .7)))
                lift = .026 * (1 + .35 * max(0.0, (f - .6) / .4)) + .014 + .006 * jitter
                p = scalp(b, a, min(f, .96), lift)
                ball(curls, tuple(p), (.03 + .006 * jitter) * S, 1, (1, .95, 1))
    elif style == "beret":
        # Boina: banda ceñida, plato ancho y plano caído hacia un lado y hacia atrás, y el rabillo.
        x6, z6, c6 = skull_radius(b, .62)
        cz0 = hh * c6
        # (El plato cubre la coronilla del maniquí, que llega a 0,98 de la cabeza: más bajo, asomaba.)
        rings = [(nz + hh * .58, 0, cz0, x6 * hh * 1.07, z6 * hh * 1.07), (nz + hh * .65, 0, cz0 + .004, x6 * hh * 1.09, z6 * hh * 1.09),
                 (nz + hh * .72, .018, cz0 + .014, x6 * hh * 1.54, z6 * hh * 1.48), (nz + hh * .82, .03, cz0 + .024, x6 * hh * 1.52, z6 * hh * 1.46),
                 (nz + hh * .94, .034, cz0 + .028, x6 * hh * 1.12, z6 * hh * 1.08), (nz + hh * 1.01, .036, cz0 + .03, x6 * hh * .6, z6 * hh * .58),
                 (nz + hh * 1.025, .036, cz0 + .03, x6 * hh * .15, z6 * hh * .15)]
        plate = fabric()
        loft(plate, rings, 20, cap_bottom=False, cap_top=True)
        band = fabric(darken=.3, subdivide=0)
        loft(band, [(nz + hh * .575, 0, cz0, x6 * hh * 1.085, z6 * hh * 1.085), (nz + hh * .635, 0, cz0 + .003, x6 * hh * 1.1, z6 * hh * 1.1)], 20, False, False)
        stalk = fabric(darken=.2, subdivide=0)
        tube(stalk, [(.036, nz + hh * 1.02, cz0 + .03), (.039, nz + hh * 1.07, cz0 + .033)], .006, 6)
    elif style in ("cap", "cap_back"):
        crown = fabric()
        hair_shell(crown, b, lambda a: .6, .02, 0.0, 0, n=16, rows=6, volume=.3)
        button = fabric(subdivide=0)
        ball(button, (0, nz + hh * 1.03, hh * .025), .012, 1, (1, .5, 1))
        visor = fabric(darken=.12)
        pts = []
        # La gorra hacia atrás es la misma con la visera girada media vuelta, sobre la nuca.
        turn = -1 if style == "cap_back" else 1
        for k in range(9):
            a = -1.2 + k * 2.4 / 8
            x, z, cz = skull_radius(b, .6)
            inner = (turn * math.sin(a) * x * hh * 1.05, nz + hh * .6, hh * cz - turn * math.cos(a) * z * hh * 1.05)
            pts.append(inner)
        for k in range(8, -1, -1):
            a = -1.2 + k * 2.4 / 8
            x, z, cz = skull_radius(b, .6)
            reach = hh * (.08 + .2 * math.cos(a) ** 1.5)
            pts.append((turn * math.sin(a) * x * hh * 1.08, nz + hh * .58 - reach * .15, hh * cz - turn * (math.cos(a) * z * hh * 1.05 + reach)))
        slab(visor, pts, (0, 1, 0), .006)
    elif style == "hat":
        # Sombrero de ala (fedora): copa con hendidura, cinta y ala curvada.
        crown = fabric()
        x6, z6, c6 = skull_radius(b, .64)
        dent = lambda a, y: 1.0
        rings = [(nz + hh * .62, 0, hh * c6, x6 * hh * 1.08, z6 * hh * 1.08), (nz + hh * .9, 0, hh * c6, x6 * hh * 1.02, z6 * hh * 1.0),
                 (nz + hh * 1.04, 0, hh * c6, x6 * hh * .95, z6 * hh * .9), (nz + hh * 1.08, 0, hh * c6, x6 * hh * .7, z6 * hh * .55)]
        loft(crown, rings, 16, cap_bottom=False, cap_top=True, shape=lambda a, y: 1.0 - (.12 * max(0.0, math.cos(a)) ** 2 if y > nz + hh * .95 else 0.0))
        band = fabric(darken=.45, subdivide=0)
        loft(band, [(nz + hh * .64, 0, hh * c6, x6 * hh * 1.09, z6 * hh * 1.09), (nz + hh * .76, 0, hh * c6, x6 * hh * 1.07, z6 * hh * 1.06)], 16, False, False)
        brim = fabric()
        n = 24
        inner = [(math.sin(a) * x6 * hh * 1.07, nz + hh * .62, hh * c6 - math.cos(a) * z6 * hh * 1.07) for a in [k * math.tau / n for k in range(n)]]
        outer = []
        for k in range(n):
            a = k * math.tau / n
            lift = .025 * abs(math.sin(a)) - .012 * max(0.0, math.cos(a))
            outer.append((math.sin(a) * (x6 * hh * 1.07 + .075 * S), nz + hh * .62 + lift, hh * c6 - math.cos(a) * (z6 * hh * 1.07 + .085 * S)))
        ti = brim.verts(inner)
        to = brim.verts(outer)
        bi = brim.verts([(p[0], p[1] - .006, p[2]) for p in inner])
        bo = brim.verts([(p[0], p[1] - .006, p[2]) for p in outer])
        for k in range(n):
            m = (k + 1) % n
            brim.face([ti[k], to[k], to[m], ti[m]])
            brim.face([bi[m], bo[m], bo[k], bi[k]])
            brim.face([to[k], bo[k], bo[m], to[m]])
    elif style == "beanie":
        knit = fabric()
        hair_shell(knit, b, lambda a: .52, .02, 0.0, 0, n=24, rows=7, volume=.5)
        cuff = fabric(lighten=.12)
        x5, z5, c5 = skull_radius(b, .56)
        ribs = lambda a, y: 1.0 + .03 * math.cos(a * 24)
        loft(cuff, [(nz + hh * .5, 0, hh * c5, x5 * hh + .026, z5 * hh + .026), (nz + hh * .7, 0, hh * c5, x5 * hh * .98 + .026, z5 * hh * .98 + .026)], 24, False, False, shape=ribs)
        pom = fabric(lighten=.05, subdivide=0)
        m = bmesh.new()
        ball(pom, (0, nz + hh * 1.1, hh * .025), .035 * S, 2)
    return parts, [], head_chains


# ---------------------------------------------------------------- accesorios

def build_accessory(b, piece_def, high=False):
    """high: variante para faldas (bandolera corta, el bolso a la altura de la cintura, por encima
    del vuelo de la falda). person.gd la elige con el sufijo _falda."""
    style = piece_def["style"]
    W, S, nz = b.W, b.S, b.nz
    parts = []
    chains_out = []
    if style == "scarf":
        scarf = Piece("accesorio", candidates=["cuello", "torax", "clavicula.I", "clavicula.D"])
        parts.append(scarf)
        y = nz * .952
        loft(scarf, [(y - .03, 0, .008, .085 * S + .01, .082 * S + .01), (y, 0, .008, .09 * S + .014, .088 * S + .014), (y + .03, 0, .008, .078 * S + .008, .075 * S + .008)], 16,
             False, False, shape=lambda a, yy: 1.0 + .04 * noise.noise(Vector((math.cos(a) * 2, yy * 20, math.sin(a) * 2))))
        # Las colas cuelgan de dos cadenas que se balancean sobre el pecho.
        scarf_chains = Chains("bufanda", "torax", (0, 0, 0), top=y - .03, blend=.05, stiffness=1.4, drag=.5, gravity=.5, radius=.012)
        for dx in (.025, -.01):
            scarf_chains.add([(dx, y - .03, -(.085 * S + .025)), (dx + .01, y - .12, -(.112 * W + .035)), (dx + .015, nz * .78, -(.106 * W + .035)), (dx + .015, nz * .74, -(.106 * W + .035))])
        chains_out.append(scarf_chains)
        tails = Piece("accesorio", darken=.05, weight_fn=scarf_chains.weight)
        parts.append(tails)
        for k, dx in enumerate((.025, -.01)):
            top = (dx, y - .02, -.085 * S - .02)
            path = [top, (dx + .01, y - .12, -(.112 * W + .03)), (dx + .015, nz * .78, -(.106 * W + .03))]
            p0 = [Vector(p) for p in path]
            # Cola plana: placa que baja por el pecho.
            pts = [(p.x - .03, p.y, p.z) for p in p0] + [(p.x + .03, p.y, p.z) for p in reversed(p0)]
            slab(tails, pts, (0, 0, -1), .01)
        fringe = Piece("accesorio", lighten=.08, subdivide=0, weight_fn=scarf_chains.weight)
        parts.append(fringe)
        for k in range(6):
            x = -.02 + k * .01
            tube(fringe, [(x + .015, nz * .78, -(.106 * W + .036)), (x + .016, nz * .765, -(.106 * W + .037))], .0025, 4)
    elif style == "bag":
        strap = Piece("accesorio", candidates=["torax", "lumbar", "caderas", "clavicula.I"], darken=.1, subdivide=0)
        parts.append(strap)
        # Correa del hombro izquierdo a la cadera derecha, pegada al pecho y a la espalda.
        for zsign in (-1, 1):
            path = []
            for k in range(9):
                t = k / 8
                y = b.sh_y + .03 - t * (b.sh_y - b.hip_y - (.2 if high else .05))
                x = -b.sh_x * .6 + t * (b.sh_x * .6 + .166 * W + (.012 if high else 0.0))
                # Sobre la superficie de una prenda holgada a esa altura (no flota lejos del pecho).
                # Pegada a una camiseta normal: con la holgura de la sudadera la correa flotaba alrededor
                # del cuerpo; se prefiere que roce algo las prendas más holgadas.
                cx0, cz0, rx, rz = ring_at(torso_rings(b, .03, nz * .5), y)
                z = cz0 + zsign * rz * math.sqrt(max(0.0, 1 - min(1.0, (x / rx) ** 2))) + zsign * .004
                path.append(Vector((x, y, z)))
            pts = [(p.x - .02, p.y + .01, p.z) for p in path] + [(p.x + .02, p.y - .01, p.z) for p in reversed(path)]
            slab(strap, pts, (0, 0, zsign), .004)
        # Bolso fino tipo tote colgado en el costado derecho, plano contra la cadera. El brazo de ese
        # lado se separa un poco del cuerpo (person.gd::arm_out) para no atravesarlo al balancearse.
        cx, cy, cz = .166 * W + .018, b.hip_y + .01, 0.0
        if high:
            cx, cy = .168 * W + .03, b.hip_y + .16
        bag_chain = Chains("bolso", "caderas", (0, 0, 0), top=0, stiffness=2.4, drag=.6, gravity=.5, radius=.02, along=.6)
        bag_chain.add([(cx, cy + .12, cz), (cx + .004, cy - .02, cz), (cx + .006, cy - .12, cz)])
        chains_out.append(bag_chain)
        bag = Piece("accesorio", weight_fn=bag_chain.weight)
        parts.append(bag)
        half_w = .09
        outline = []
        for k in range(16):
            a = k * math.tau / 16
            ez, ey = math.cos(a), math.sin(a)
            outline.append((cx - .012, cy - .02 + math.copysign(abs(ey) ** .35, ey) * .1, cz + math.copysign(abs(ez) ** .35, ez) * half_w))
        slab(bag, outline, (1, 0, 0), .026)
        handle = Piece("accesorio", darken=.12, subdivide=0, weight_fn=bag_chain.weight)
        parts.append(handle)
        for sz in (-1, 1):
            tube(handle, [(cx + .016, cy + .08, cz + sz * half_w * .55), (cx + .018, cy + .13, cz + sz * half_w * .4), (cx + .018, cy + .15, cz)], .004, 5, caps=False)
    elif style == "backpack":
        # Mochila: saco redondeado a la espalda, bolsillo delantero, asa y un tirante por hombro que
        # baja por el pecho y vuelve por debajo del brazo.
        guide = torso_rings(b, .03, nz * .5)
        back_z = lambda y: (lambda r: r[1] + r[3])(ring_at(guide, y))
        y0, y1 = nz * .665, nz * .915
        depth, half_w = .062 * W + .045, .118 * W
        boxy = lambda a, yy: (abs(math.cos(a)) ** 4 + abs(math.sin(a)) ** 4) ** -.25
        sack = Piece("accesorio", candidates=["torax", "lumbar"])
        parts.append(sack)
        zc = lambda y: back_z(y) + depth * .5 + .004
        rings = []
        for t, kx, kz in ((0, .7, .55), (.07, .95, .9), (.3, 1.0, 1.0), (.75, .97, .95), (.93, .85, .75), (1, .5, .4)):
            y = y0 + (y1 - y0) * t
            rings.append((y, 0, zc(y), half_w * kx, depth * .5 * kz))
        loft(sack, rings, 16, True, True, shape=boxy)
        pocket = Piece("accesorio", candidates=["torax", "lumbar"], darken=.2)
        parts.append(pocket)
        py0, py1 = y0 + .02, y0 + (y1 - y0) * .55
        loft(pocket, [(py0, 0, zc(py0) + depth * .5, half_w * .6, .012), (py0 + .02, 0, zc(py0) + depth * .5 + .008, half_w * .74, .022),
             (py1 - .02, 0, zc(py1) + depth * .5 + .006, half_w * .72, .02), (py1, 0, zc(py1) + depth * .5, half_w * .55, .01)], 12, True, True, shape=boxy)
        handle = Piece("accesorio", candidates=["torax"], darken=.25, subdivide=0)
        parts.append(handle)
        tube(handle, [(-.03, y1 - .01, zc(y1) - .01), (-.02, y1 + .03, zc(y1) - .005), (.02, y1 + .03, zc(y1) - .005), (.03, y1 - .01, zc(y1) - .01)], .006, 6, caps=False)
        straps = Piece("accesorio", candidates=["torax", "lumbar", "clavicula.I", "clavicula.D"], darken=.14, subdivide=0)
        parts.append(straps)
        for sign in (-1, 1):
            x = sign * .092 * W
            path = []
            # Por detrás, de la mochila al hombro; por delante, del hombro a la axila; y de vuelta
            # a la base de la mochila por el costado.
            for f in (.90, .93, .952):
                cx, cz, rx, rz = ring_at(guide, nz * f)
                path.append(Vector((x, nz * f, cz + rz * math.sqrt(max(0.0, 1 - min(1.0, (x / rx) ** 2))) + .004)))
            for f in (.957, .94, .91, .87, .83, .79):
                cx, cz, rx, rz = ring_at(guide, nz * f)
                path.append(Vector((x, nz * f, cz - rz * math.sqrt(max(0.0, 1 - min(1.0, (x / rx) ** 2))) - .004)))
            for f, ang in ((.755, .9), (.725, 1.5), (.70, 2.2), (.685, 2.7)):
                cx, cz, rx, rz = ring_at(guide, nz * f)
                path.append(Vector((sign * math.sin(ang) * (rx + .004), nz * f, cz - math.cos(ang) * (rz + .004))))
            outs = [Vector((p.x * .6, 0, p.z)).normalized() if abs(p.z) > .02 else Vector((sign, 0, 0)) for p in path]
            outs[3] = Vector((0, 1, 0))
            ribbon(straps, path, outs, [.02 * S] * len(path), .0035, 6)
    elif style == "umbrella":
        # Paraguas cerrado, llevado por el mango en la mano izquierda con la punta hacia abajo.
        hl = nz * .082
        x, z = -b.sh_x - .004, -.036 * S
        top = b.wr_y - hl * .35
        tip = max(.05, top - nz * .5)
        wood = Piece("calzado", bone="mano.I")
        parts.append(wood)
        # Mango curvo (cayado) por encima del puño y varilla hasta la punta.
        tube(wood, [(x, top + .035, z + .05), (x, top + .062, z + .04), (x, top + .07, z + .018), (x, top + .055, z), (x, top, z), (x, top - .09, z)],
             [.011, .012, .012, .011, .01, .008], 8)
        tube(wood, [(x, tip + .05, z), (x, tip, z)], [.006, .003], 6)
        canopy = Piece("accesorio", bone="mano.I")
        parts.append(canopy)
        pleats = lambda a, yy: 1.0 + .16 * math.cos(a * 8)
        c0, c1 = top - .085, tip + .045
        loft(canopy, [(c1, x, z, .011, .011), (c1 + (c0 - c1) * .25, x, z, .027, .027), (c1 + (c0 - c1) * .7, x, z, .037, .037),
             (c0 - .012, x, z, .034, .034), (c0, x, z, .014, .014)], 16, True, True, shape=pleats)
        band = Piece("accesorio", bone="mano.I", darken=.3, subdivide=0)
        parts.append(band)
        cy = c1 + (c0 - c1) * .62
        loft(band, [(cy - .01, x, z, .041, .041), (cy + .01, x, z, .041, .041)], 12, False, False)
    return parts, [], chains_out


def build_glasses(b, piece_def):
    """Gafas (ranura propia, se combinan con cualquier accesorio): montura redonda delante de la
    cara lisa del maniquí, puente y patillas hasta las orejas. Las «gafas» son solo la montura (se
    ve la madera: cristal transparente); las «gafas de sol» llevan además los cristales oscuros."""
    style = piece_def["style"]
    parts = []
    if style == "none":
        return parts, []
    hh, nz = b.head, b.nz
    f = .46
    xr, zr, cz = skull_radius(b, f)
    y = nz + hh * f
    frame = Piece("montura", bone="cabeza", subdivide=0)
    parts.append(frame)
    lens_r = hh * .105
    for sign in (-1, 1):
        a = sign * .40                                   # el cristal mira un poco hacia fuera, siguiendo la cara
        out = Vector((math.sin(a), 0, -math.cos(a)))
        centre = Vector((math.sin(a) * xr * hh, y, hh * cz - math.cos(a) * zr * hh)) + out * .014
        side = Vector((math.cos(a), 0, math.sin(a)))
        up = Vector((0, 1, 0))
        ring = [centre + (side * math.cos(q) + up * math.sin(q) * .88) * lens_r for q in [k * math.tau / 16 for k in range(17)]]
        tube(frame, ring, .0032, 6, caps=False)
        if style == "sunglasses":
            lens = Piece("cristal", bone="cabeza", subdivide=0)
            parts.append(lens)
            slab(lens, [tuple(p - out * .001) for p in ring[:-1]], tuple(out), .002)
        # Patilla: del borde exterior de la montura a la oreja, pegada a la sien.
        hinge = centre + side * sign * lens_r
        ear = Vector((sign * xr * hh * 1.03, y + .004, hh * cz + .012))
        mid = Vector((sign * xr * hh * 1.06, y + .003, (hinge.z + ear.z) * .5))
        tube(frame, [hinge, mid, ear, ear + Vector((0, -.012, .012))], .0026, 5)
        if sign < 0:
            inner_l = centre + side * lens_r
        else:
            inner_r = centre - side * lens_r
    bridge_mid = (inner_l + inner_r) * .5 + Vector((0, .006, -.004))
    tube(frame, [inner_l, bridge_mid, inner_r], .0028, 5)
    return parts, []


# ---------------------------------------------------------------- exportación

def piece_to_shape(body, piece):
    if not piece.bm.faces:
        piece.bm.free()
        return None
    mesh = bpy.data.meshes.new("pieza")
    bmesh.ops.remove_doubles(piece.bm, verts=piece.bm.verts, dist=1e-5)
    bmesh.ops.recalc_face_normals(piece.bm, faces=piece.bm.faces)
    piece.bm.to_mesh(mesh)
    piece.bm.free()
    obj = bpy.data.objects.new("pieza", mesh)
    bpy.context.scene.collection.objects.link(obj)
    for poly in mesh.polygons:
        poly.use_smooth = True
    if piece.drape and DRAPE["body"] is not None:
        group = obj.vertex_groups.new(name="pin")
        for v in mesh.vertices:
            group.add([v.index], max(0.0, min(1.0, piece.drape["pin"](v.co))), "REPLACE")
        pre = obj.modifiers.new("pre", "SUBSURF")
        pre.levels = 1
        pre.render_levels = 1
        cloth = obj.modifiers.new("tela", "CLOTH")
        st = cloth.settings
        st.quality = 12
        st.mass = .15
        st.tension_stiffness = 60
        st.compression_stiffness = 60
        st.shear_stiffness = 20
        st.bending_stiffness = piece.drape.get("bending", .3)
        st.air_damping = 2.0
        st.vertex_group_mass = "pin"
        st.pin_stiffness = 1.0
        st.shrink_min = piece.drape.get("shrink", 0.0)
        cloth.collision_settings.use_collision = True
        cloth.collision_settings.distance_min = .006
        cloth.collision_settings.collision_quality = 4
        cloth.collision_settings.use_self_collision = False
        frames = piece.drape.get("frames", 30)
        cloth.point_cache.frame_start = 1
        cloth.point_cache.frame_end = frames
        scene = bpy.context.scene
        for f in range(1, frames + 1):
            scene.frame_set(f)
    if piece.subdivide:
        mod = obj.modifiers.new("sub", "SUBSURF")
        mod.levels = piece.subdivide
        mod.render_levels = piece.subdivide
    deps = bpy.context.evaluated_depsgraph_get()
    evaluated = obj.evaluated_get(deps)
    em = evaluated.to_mesh()
    em.calc_loop_triangles()
    vertices = [v.co.copy() for v in em.vertices]
    normals = [v.normal.copy() for v in em.vertices]
    indices = []
    for tri in em.loop_triangles:
        a, b2, c = tri.vertices
        cross = (vertices[b2] - vertices[a]).cross(vertices[c] - vertices[a])
        n = normals[a] + normals[b2] + normals[c]
        # Godot: caras frontales en sentido horario visto desde fuera.
        indices += [a, b2, c] if cross.dot(n) < 0 else [a, c, b2]
    names, joints, weights = [], [], []
    for v in vertices:
        if piece.bone:
            w = [(piece.bone, 1.0)]
        elif piece.weight_fn:
            w = piece.weight_fn(v)
        else:
            w = smooth_weights(body, v, piece.candidates)
        w = sorted(w, key=lambda item: -item[1])[:4]
        for name, _ in w:
            if name not in names:
                names.append(name)
        pad = w + [(w[0][0], 0.0)] * (4 - len(w))
        joints += [names.index(n) for n, _ in pad]
        weights += [round(x, 5) for _, x in pad]
    evaluated.to_mesh_clear()
    bpy.context.scene.frame_set(1)
    bpy.data.objects.remove(obj)
    bpy.data.meshes.remove(mesh)
    shape = {"type": "skinned", "color": piece.zone, "bone_names": names, "joints": joints, "weights": weights,
             "vertices": [[round(c, 5) for c in (v.x, v.y, v.z)] for v in vertices],
             "normals": [[round(c, 4) for c in (n.x, n.y, n.z)] for n in normals], "indices": indices, "collision": False}
    if piece.part:
        shape["part"] = piece.part
    if piece.darken:
        shape["darken"] = piece.darken
    if piece.lighten:
        shape["lighten"] = piece.lighten
    return shape


DRAPE = {"body": None}


def make_drape_body(body):
    """Cuerpo de madera como colisionador de la simulación de tela (gravedad en -y: ejes de Godot)."""
    if DRAPE["body"] is not None:
        bpy.data.objects.remove(DRAPE["body"])
    bm = bmesh.new()
    for part in build_body(body):
        offset = {}
        for v in part.bm.verts:
            offset[v] = bm.verts.new(v.co)
        for f in part.bm.faces:
            try:
                bm.faces.new([offset[v] for v in f.verts])
            except ValueError:
                pass
        part.bm.free()
    mesh = bpy.data.meshes.new("cuerpo_colision")
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new("cuerpo_colision", mesh)
    bpy.context.scene.collection.objects.link(obj)
    col = obj.modifiers.new("col", "COLLISION")
    obj.collision.thickness_outer = .004
    obj.collision.cloth_friction = 8
    bpy.context.scene.gravity = (0, -9.81, 0)
    bpy.context.scene.frame_start = 1
    DRAPE["body"] = obj


def write_piece(body, slot, index, parts, hides, chains=None):
    geometry = [s for s in (piece_to_shape(body, p) for p in parts) if s]
    tris = sum(len(s["indices"]) // 3 for s in geometry)
    path = os.path.join(OUT, "%s_%s_%s.json" % (body.id, slot, index))
    doc = {"geometry": geometry}
    if hides:
        doc["hides"] = sorted(set(hides))
    if chains:
        doc["chains"] = [c for cs in chains for c in cs.export()]
    with open(path, "w") as f:
        json.dump(doc, f, ensure_ascii=False, separators=(",", ":"))
    return tris


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    only = set(argv[argv.index("--only") + 1].split(",")) if "--only" in argv else None
    slots = set(argv[argv.index("--slots") + 1].split(",")) if "--slots" in argv else None
    # --pieces 5,6: solo esos índices de las ranuras elegidas (para probar una pieza nueva).
    wanted = set(int(v) for v in argv[argv.index("--pieces") + 1].split(",")) if "--pieces" in argv else None
    bpy.ops.wm.read_factory_settings(use_empty=True)
    os.makedirs(OUT, exist_ok=True)
    builders = {"torso": build_torso, "piernas": build_legs, "cabeza": build_head, "accesorio": build_accessory, "gafas": build_glasses}
    for profile in CATALOG["perfiles"]:
        if only and profile["id"] not in only:
            continue
        body = Body(profile)
        make_drape_body(body)
        report = {}
        if not slots or "cuerpo" in slots:
            report["cuerpo"] = [write_piece(body, "cuerpo", 0, build_body(body), [])]
        for slot, build in builders.items():
            if slots and slot not in slots:
                continue
            report[slot] = []
            for index, piece_def in enumerate(CATALOG["piezas"][slot]):
                if wanted and index not in wanted:
                    continue
                result = build(body, piece_def)
                parts, hides = result[0], result[1]
                chains = result[2] if len(result) > 2 else None
                report[slot].append(write_piece(body, slot, index, parts, hides, chains))
                if slot == "accesorio" and piece_def["style"] == "bag":
                    parts, hides, chains = build_accessory(body, piece_def, high=True)
                    write_piece(body, slot, "%d_falda" % index, parts, hides, chains)
        print("CHARACTERS %s %s" % (profile["id"], report))


main()
