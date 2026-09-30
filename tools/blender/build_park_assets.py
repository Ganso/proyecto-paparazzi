"""Generador procedural del mobiliario del parque (docs/futuro/17 §2.2).

Uso (sin interfaz):
    blender -b --factory-startup -P tools/blender/build_park_assets.py -- [--only banco,farola] [--no-bake]

Cada objeto se exporta a assets/parque/<nombre>.glb con mallas llamadas
"<lod>[_<variante>][_<rol>]": lod = hd (Ultra) o lo (resto de perfiles), rol = glass (vidrio
transparente) o bulb (bombilla emisiva); sin rol, la malla es opaca. El color base y la oclusión
ambiental (horneada con Cycles) van en el color de vértice, en espacio lineal.

Toda la geometría se escribe en coordenadas de Godot (x derecha, y arriba, z hacia la cámara) y
se convierte a las de Blender al crear la malla; el exportador glTF deshace el cambio.
"""
import bpy
import bmesh
import math
import os
import random
import sys
from mathutils import Vector, Matrix, noise

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "assets", "parque")

LODS = {
    "hd": {"bevel_segments": 3, "lathe": 32, "tube_sides": 12, "tube_step": 0.03, "detail": True, "clump_subdiv": 2},
    "lo": {"bevel_segments": 0, "lathe": 8, "tube_sides": 5, "tube_step": 0.12, "detail": False, "clump_subdiv": 0},
}


def srgb(hex_color, shade=1.0):
    """Hex sRGB -> RGBA lineal (el atributo de color es lineal)."""
    out = []
    for i in (0, 2, 4):
        c = int(hex_color[i:i + 2], 16) / 255.0
        c = c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
        out.append(c * shade)
    return (out[0], out[1], out[2], 1.0)


def to_blender(v):
    return Vector((v[0], -v[2], v[1]))


class Builder:
    """Acumula geometría (en coordenadas de Godot) con color por cara."""

    def __init__(self):
        self.verts = []
        self.faces = []
        self.colors = []

    def add_bmesh(self, bm, color, xform=None):
        offset = len(self.verts)
        bm.verts.index_update()
        for v in bm.verts:
            co = xform @ v.co if xform is not None else v.co.copy()
            self.verts.append(co)
        for f in bm.faces:
            self.faces.append([offset + v.index for v in f.verts])
            self.colors.append(color)
        bm.free()

    def add(self, verts, faces, color):
        offset = len(self.verts)
        self.verts.extend(Vector(v) for v in verts)
        for f in faces:
            self.faces.append([offset + i for i in f])
            self.colors.append(color)

    def empty(self):
        return not self.faces

    def to_object(self, name, smooth_angle=35.0):
        mesh = bpy.data.meshes.new(name)
        mesh.from_pydata([to_blender(v) for v in self.verts], [], self.faces)
        mesh.validate(clean_customdata=False)
        attr = mesh.color_attributes.new("Col", "FLOAT_COLOR", "CORNER")
        for poly in mesh.polygons:
            color = self.colors[poly.index]
            for li in poly.loop_indices:
                attr.data[li].color = color
        mesh.color_attributes.active_color = attr
        mesh.color_attributes.render_color_index = 0
        for poly in mesh.polygons:
            poly.use_smooth = True
        mesh.set_sharp_from_angle(angle=math.radians(smooth_angle))
        obj = bpy.data.objects.new(name, mesh)
        bpy.context.scene.collection.objects.link(obj)
        return obj


# ---------------------------------------------------------------- primitivas (coordenadas Godot)

def box(b, size, center, color, bevel=0.0, lod=None, rot=None, segments=None):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co = Vector((v.co.x * size[0], v.co.y * size[1], v.co.z * size[2]))
    if segments is None:
        segments = lod["bevel_segments"] if lod else 0
    if bevel > 0 and segments > 0:
        bmesh.ops.bevel(bm, geom=list(bm.edges), offset=min(bevel, min(size) * 0.45), segments=segments,
                        profile=0.5, affect="EDGES", clamp_overlap=True)
    xform = Matrix.Translation(Vector(center))
    if rot is not None:
        xform = xform @ rot
    b.add_bmesh(bm, color, xform)


def lathe(b, profile, center, color, segments, radial=None, phase=0.0, cap_top=True, cap_bottom=True):
    """Superficie de revolución alrededor del eje Y. profile = [(radio, y), ...] de abajo arriba.
    radial(theta, y) multiplica el radio (estrías, nervios)."""
    cx, cy, cz = center
    verts, faces = [], []
    rings = []
    for r, y in profile:
        ring = []
        if r <= 1e-6:
            verts.append((cx, cy + y, cz))
            ring = [len(verts) - 1] * segments
        else:
            for s in range(segments):
                t = phase + s * math.tau / segments
                rr = r * (radial(t, y) if radial else 1.0)
                verts.append((cx + math.sin(t) * rr, cy + y, cz + math.cos(t) * rr))
                ring.append(len(verts) - 1)
        rings.append(ring)
    for k in range(len(rings) - 1):
        a, c = rings[k], rings[k + 1]
        for s in range(segments):
            n = (s + 1) % segments
            quad = [a[s], a[n], c[n], c[s]]
            unique = []
            for q in quad:
                if q not in unique:
                    unique.append(q)
            if len(unique) >= 3:
                faces.append(unique)
    if cap_bottom and profile[0][0] > 1e-6:
        faces.append(list(reversed(rings[0])))
    if cap_top and profile[-1][0] > 1e-6:
        faces.append(list(rings[-1]))
    b.add(verts, faces, color)


def cylinder(b, r, y0, y1, center, color, segments, top=None):
    lathe(b, [(r, y0), (r if top is None else top, y1)], center, color, segments)


def sphere(b, r, center, color, segments, rings=None, squash=1.0):
    rings = rings or max(3, segments // 2)
    profile = []
    for i in range(rings + 1):
        a = -math.pi / 2 + math.pi * i / rings
        profile.append((math.cos(a) * r, math.sin(a) * r * squash))
    profile[0] = (0.0, profile[0][1])
    profile[-1] = (0.0, profile[-1][1])
    lathe(b, profile, center, color, segments)


def catmull(points, step):
    """Curva suave por los puntos de control, remuestreada cada `step` metros aprox."""
    pts = [Vector(p) for p in points]
    if len(pts) < 3:
        return pts
    out = []
    ext = [pts[0] * 2 - pts[1]] + pts + [pts[-1] * 2 - pts[-2]]
    for i in range(1, len(ext) - 2):
        p0, p1, p2, p3 = ext[i - 1], ext[i], ext[i + 1], ext[i + 2]
        n = max(1, int((p2 - p1).length / step))
        for k in range(n):
            t = k / n
            t2, t3 = t * t, t * t * t
            out.append(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3))
    out.append(pts[-1])
    return out


def tube(b, points, radius, color, lod, smooth=True, caps=True, radius_fn=None, sides=None):
    """Barrote o fundición curvada: barrido de un círculo a lo largo de una polilínea."""
    path = catmull(points, lod["tube_step"]) if smooth else [Vector(p) for p in points]
    sides = sides or lod["tube_sides"]
    verts, faces = [], []
    normal = None
    count = len(path)
    for i, p in enumerate(path):
        tangent = (path[min(i + 1, count - 1)] - path[max(i - 1, 0)]).normalized()
        if normal is None:
            ref = Vector((0, 1, 0)) if abs(tangent.y) < 0.9 else Vector((1, 0, 0))
            normal = tangent.cross(ref).normalized()
        else:
            normal = (normal - tangent * normal.dot(tangent)).normalized()
        binormal = tangent.cross(normal)
        r = radius * (radius_fn(i / max(1, count - 1)) if radius_fn else 1.0)
        for s in range(sides):
            a = s * math.tau / sides
            verts.append(tuple(p + (normal * math.cos(a) + binormal * math.sin(a)) * r))
    for i in range(count - 1):
        for s in range(sides):
            n = (s + 1) % sides
            faces.append([i * sides + s, i * sides + n, (i + 1) * sides + n, (i + 1) * sides + s])
    if caps:
        faces.append(list(reversed(range(sides))))
        faces.append([(count - 1) * sides + s for s in range(sides)])
    b.add(verts, faces, color)


# ---------------------------------------------------------------- objetos del parque

IRON = "2a3230"
TEAK = "8f6136"


def build_banco(lod):
    """Banco de listones de teca con bastidores de fundición. Mismo volumen que su colisionador:
    x [-0.825, 0.825], y [0, 0.97], z [-0.055, 0.42]; el asiento mira hacia -z."""
    b = Builder()
    iron = srgb(IRON)
    detail = lod["detail"]
    for x in (-0.66, 0.66):
        # Pata delantera y trasera, travesaño del asiento, respaldo curvo y reposabrazos.
        tube(b, [(x, 0.0, -0.02), (x, 0.2, -0.03), (x, 0.44, -0.035)], 0.024, iron, lod)
        tube(b, [(x, 0.0, 0.36), (x, 0.22, 0.34), (x, 0.44, 0.335), (x, 0.66, 0.375), (x, 0.95, 0.415)], 0.024, iron, lod)
        tube(b, [(x, 0.43, -0.045), (x, 0.42, 0.15), (x, 0.43, 0.345)], 0.021, iron, lod)
        tube(b, [(x, 0.62, 0.37), (x, 0.66, 0.2), (x, 0.655, 0.02), (x, 0.62, -0.035), (x, 0.56, -0.03), (x, 0.52, -0.015)], 0.019, iron, lod)
        if detail:
            # Volutas del reposabrazos y zapatas de las patas.
            tube(b, [(x, 0.52, -0.015), (x, 0.49, 0.01), (x, 0.5, 0.04), (x, 0.535, 0.035), (x, 0.54, 0.005)], 0.011, iron, lod)
            for z in (-0.02, 0.36):
                box(b, (0.07, 0.02, 0.1), (x, 0.01, z), iron, 0.006, lod)
            tube(b, [(x, 0.44, 0.335), (x, 0.3, 0.2), (x, 0.2, 0.06), (x, 0.12, -0.02)], 0.012, iron, lod)
    # Asiento: 4 listones con cantos redondeados y un leve tono distinto por listón.
    for j, z in enumerate((-0.01, 0.095, 0.2, 0.305)):
        box(b, (1.65, 0.03, 0.09), (0, 0.455, z), srgb(TEAK, (0.94, 1.0, 0.97, 1.03)[j]), 0.008, lod)
    # Respaldo inclinado: 3 listones.
    tilt = Matrix.Rotation(math.radians(-14), 4, "X")
    for j, y in enumerate((0.62, 0.745, 0.87)):
        z = 0.375 + (y - 0.62) * 0.2
        box(b, (1.65, 0.1, 0.026), (0, y, z), srgb(TEAK, (1.0, 0.95, 1.02)[j]), 0.008, lod, tilt)
    if detail:
        # Tornillería de latón envejecido donde los listones apoyan en los bastidores.
        for x in (-0.66, 0.66):
            for z in (-0.01, 0.095, 0.2, 0.305):
                cylinder(b, 0.009, 0.47, 0.476, (x, 0, z), srgb("8a7a4e"), 8)
    return {"": b}


def build_farola(lod):
    """Farola clásica de fundición (3,1 m). Vidrio y bombilla en mallas propias."""
    opaque, glass, bulb = Builder(), Builder(), Builder()
    seg = lod["lathe"]
    iron, iron_hi = srgb("28302d"), srgb("343d39")
    detail = lod["detail"]
    base = [(0.16, 0.0), (0.16, 0.05), (0.14, 0.07), (0.14, 0.12), (0.115, 0.15), (0.11, 0.22), (0.085, 0.26), (0.07, 0.30)]
    if not detail:
        base = [(0.15, 0.0), (0.15, 0.16), (0.1, 0.18), (0.068, 0.30)]
    lathe(opaque, base, (0, 0, 0), iron, seg)
    flutes = (lambda t, y: 1.0 + 0.07 * math.cos(8 * t)) if detail else None
    lathe(opaque, [(0.052, 0.30), (0.047, 1.3), (0.042, 2.42)], (0, 0, 0), srgb("323a37"), seg, radial=flutes)
    collar = [(0.05, 1.72), (0.072, 1.74), (0.072, 1.77), (0.05, 1.79)] if detail else [(0.072, 1.73), (0.072, 1.77)]
    lathe(opaque, collar, (0, 0, 0), iron_hi, seg)
    neck = [(0.045, 2.40), (0.06, 2.42), (0.11, 2.48), (0.12, 2.495)]
    lathe(opaque, neck, (0, 0, 0), iron, seg)
    # Linterna: repisa, cuatro pilastras, marco superior, tejadillo y remate.
    box(opaque, (0.34, 0.035, 0.34), (0, 2.51, 0), iron, 0.01, lod)
    for x in (-1.0, 1.0):
        for z in (-1.0, 1.0):
            tube(opaque, [(x * 0.13, 2.52, z * 0.13), (x * 0.155, 2.85, z * 0.155)], 0.012, iron, lod, smooth=False)
    box(opaque, (0.34, 0.025, 0.34), (0, 2.855, 0), iron, 0.008, lod)
    roof = [(0.21, 2.86), (0.2, 2.88), (0.11, 2.95), (0.05, 2.99), (0.03, 3.0)]
    lathe(opaque, roof, (0, 0, 0), iron, 4 if not detail else 16, phase=math.pi / 4 if not detail else 0.0)
    sphere(opaque, 0.03, (0, 3.03, 0), iron_hi, 12 if detail else 6)
    cylinder(opaque, 0.008, 3.05, 3.12, (0, 0, 0), iron_hi, 6)
    # Vidrio: cuatro paneles ligeramente inclinados (la linterna se abre hacia arriba).
    for side in range(4):
        rot = Matrix.Rotation(side * math.pi / 2, 4, "Y")
        verts = [rot @ Vector(p) for p in ((-0.125, 2.53, 0.13), (0.125, 2.53, 0.13), (0.15, 2.84, 0.155), (-0.15, 2.84, 0.155))]
        glass.add([tuple(v) for v in verts], [[0, 1, 2, 3]], srgb("d0e8f0"))
    cylinder(opaque, 0.02, 2.53, 2.60, (0, 0, 0), srgb("76653f"), 8)
    sphere(bulb, 0.038, (0, 2.67, 0), srgb("fff5c0"), 16 if detail else 6, squash=1.3)
    return {"": opaque, "glass": glass, "bulb": bulb}


def build_papelera(lod):
    """Papelera de chapa con nervios verticales y aro superior (r 0.25, h 0.7)."""
    b = Builder()
    seg = lod["lathe"] * 2 if lod["detail"] else lod["lathe"]
    green = srgb("425d57")
    ribs = (lambda t, y: 1.0 + 0.035 * max(0.0, math.cos(12 * t)) ** 8) if lod["detail"] else None
    lathe(b, [(0.2, 0.0), (0.23, 0.03), (0.235, 0.06), (0.25, 0.64)], (0, 0, 0), green, seg, radial=ribs, cap_top=False)
    lathe(b, [(0.25, 0.64), (0.262, 0.655), (0.262, 0.69), (0.25, 0.7), (0.232, 0.7), (0.232, 0.66)], (0, 0, 0), srgb("364c47"), seg, cap_top=False, cap_bottom=False)
    lathe(b, [(0.232, 0.66), (0.228, 0.2), (0.0, 0.2)], (0, 0, 0), srgb("151a19"), seg, cap_bottom=False)
    return {"": b}


def build_jardinera(lod):
    """Jardinera de tablones (0,9 × 0,35 × 0,7) con tres variantes de flor."""
    variants = {}
    flower_colors = ("d6ac4b", "b45c78", "e8dac0")
    for variant, petal in enumerate(flower_colors):
        b = Builder()
        wood = "a78366"
        if lod["detail"]:
            for k in range(3):
                y = 0.06 + k * 0.1
                shade = (0.97, 1.0, 0.95)[k]
                for z in (-0.335, 0.335):
                    box(b, (0.86, 0.095, 0.03), (0, y, z), srgb(wood, shade), 0.006, lod)
                for x in (-0.435, 0.435):
                    box(b, (0.03, 0.095, 0.64), (x, y, 0), srgb(wood, shade * 0.97), 0.006, lod)
            for x in (-0.43, 0.43):
                for z in (-0.33, 0.33):
                    box(b, (0.06, 0.37, 0.06), (x, 0.185, z), srgb("8a6a50"), 0.008, lod)
            box(b, (0.84, 0.02, 0.64), (0, 0.3, 0), srgb("4a3526"), 0.0, lod)
        else:
            box(b, (0.9, 0.35, 0.7), (0, 0.175, 0), srgb(wood), 0.0, lod)
            box(b, (0.84, 0.01, 0.64), (0, 0.352, 0), srgb("4a3526"), 0.0, lod)
        rows = 3 if lod["detail"] else 1
        cols = 7 if lod["detail"] else 5
        for r in range(rows):
            for c in range(cols):
                x = (c - (cols - 1) / 2) * (0.75 / cols)
                z = (r - (rows - 1) / 2) * 0.18
                h = 0.1 + 0.03 * math.sin(c * 1.7 + r * 2.3)
                if lod["detail"]:
                    cylinder(b, 0.006, 0.3, 0.3 + h, (x, 0, z), srgb("4f7a34"), 5)
                    sphere(b, 0.045, (x, 0.3 + h * 0.4, z), srgb("5b8a3c", 0.9 + 0.1 * ((r + c) % 2)), 7, squash=0.6)
                    for p in range(5):
                        a = p * math.tau / 5 + c
                        sphere(b, 0.022, (x + math.sin(a) * 0.022, 0.3 + h, z + math.cos(a) * 0.022), srgb(petal), 6, squash=0.5)
                    sphere(b, 0.012, (x, 0.305 + h, z), srgb("e0b43c"), 6)
                else:
                    cylinder(b, 0.09, 0.35, 0.43, (x * 0.8, 0, 0), srgb(petal), 6)
        variants[str(variant)] = {"": b}
    return variants


def build_verja_tramo(lod):
    """Tramo de verja de 5° a r = 12,8 m (cuerda 1,117 m), centrado en su poste; a lo largo de x."""
    b = Builder()
    iron = srgb("394844")
    half = 0.558
    if not lod["detail"]:
        box(b, (0.03, 1.1, 0.03), (0, 0.55, 0), iron)
        box(b, (2 * half, 0.03, 0.03), (0, 0.8, 0), iron)
        box(b, (2 * half, 0.03, 0.03), (0, 0.15, 0), iron)
        # Barrotes planos mirando al centro del parque (+z), desde donde siempre se ven: 2 triángulos.
        for k in range(1, 8):
            x = -half + k * (2 * half / 8)
            b.add([(x - 0.008, 0.0, 0.0), (x + 0.008, 0.0, 0.0), (x + 0.008, 1.0, 0.0), (x - 0.008, 1.0, 0.0)], [[0, 1, 2, 3]], iron)
        return {"": b}
    # Poste con base y remate de bola.
    # 72 tramos en el parque: biseles de un segmento y anillos de 6 lados (~1.500 triángulos).
    box(b, (0.045, 1.12, 0.045), (0, 0.56, 0), iron, 0.006, lod, segments=1)
    lathe(b, [(0.0, 1.12), (0.03, 1.13), (0.03, 1.145)], (0, 0, 0), iron, 12)
    sphere(b, 0.032, (0, 1.18, 0), iron, 12)
    # Pasamanos superior e inferior.
    for y in (0.15, 0.93):
        box(b, (2 * half, 0.026, 0.02), (0, y, 0), iron, 0.004, lod, segments=1)
    # Barrotes con punta de lanza.
    count = 9
    for k in range(count):
        x = -half + (k + 0.5) * (2 * half / count)
        if abs(x) < 0.04:
            continue
        box(b, (0.014, 1.06, 0.014), (x, 0.53, 0), iron, 0.003, lod, segments=1)
        lathe(b, [(0.0, 1.06), (0.016, 1.075), (0.011, 1.1), (0.0, 1.16)], (x, 0, 0), iron, 4, phase=math.pi / 4)
    # Anillos decorativos entre los pasamanos (motivo de la fundición clásica).
    for k in range(count - 1):
        x = -half + (k + 1) * (2 * half / count)
        tube(b, [(x + 0.035 * math.sin(a), 0.84 + 0.035 * math.cos(a), 0) for a in [i * math.tau / 10 for i in range(11)]], 0.005, iron, lod, smooth=False, caps=False, sides=4)
    return {"": b}


def build_verja_pilar(lod):
    """Pilar de piedra con albardilla y bola (sustituye al poste cada 30°)."""
    b = Builder()
    stone, stone_dark = srgb("cfc6b4"), srgb("b3a993")
    if not lod["detail"]:
        box(b, (0.36, 1.3, 0.36), (0, 0.65, 0), stone)
        box(b, (0.44, 0.08, 0.44), (0, 1.34, 0), stone_dark)
        sphere(b, 0.11, (0, 1.49, 0), stone, 6)
        return {"": b}
    box(b, (0.42, 0.14, 0.42), (0, 0.07, 0), stone_dark, 0.02, lod)
    # Sillares con juntas marcadas: cuatro hiladas ligeramente retranqueadas.
    for k in range(4):
        shade = (1.0, 0.96, 1.02, 0.98)[k]
        box(b, (0.36, 0.265, 0.36), (0, 0.14 + 0.135 + k * 0.275, 0), srgb("cfc6b4", shade), 0.012, lod)
    box(b, (0.46, 0.06, 0.46), (0, 1.27, 0), stone_dark, 0.015, lod)
    lathe(b, [(0.22, 1.30), (0.2, 1.33), (0.08, 1.36), (0.06, 1.38)], (0, 0, 0), stone, 24, phase=math.pi / 4)
    sphere(b, 0.11, (0, 1.48, 0), stone, 24)
    return {"": b}


# ---------------------------------------------------------------- vegetación

def clump(b, center, radius, palette, rng, lod, squash=0.85, lumpiness=0.22):
    """Racimo de follaje: icosfera deformada por ruido, más clara arriba y hacia fuera."""
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=lod["clump_subdiv"], radius=radius)
    seed = Vector((rng.uniform(0, 100), rng.uniform(0, 100), rng.uniform(0, 100)))
    for v in bm.verts:
        n = v.co.normalized()
        bump = noise.noise(n * 1.8 + seed) * 0.55 + noise.noise(n * 4.1 + seed) * 0.3 + noise.noise(n * 9.0 + seed) * 0.15
        v.co = n * radius * (1.0 + lumpiness * bump)
        v.co.y *= squash
        if v.co.y < -radius * 0.45:
            v.co.y = -radius * 0.45 + (v.co.y + radius * 0.45) * 0.35
    offset = len(b.verts)
    bm.verts.index_update()
    base = Vector(center)
    for v in bm.verts:
        b.verts.append(base + v.co)
    for f in bm.faces:
        c = f.calc_center_median()
        up = c.y / radius
        tone = palette[min(len(palette) - 1, max(0, int((up + 1.0) * 0.5 * len(palette))))]
        shade = 0.82 + 0.18 * max(-1.0, min(1.0, up)) + rng.uniform(-0.04, 0.04)
        b.faces.append([offset + v.index for v in f.verts])
        b.colors.append(srgb(tone, shade))
    bm.free()


def branch_path(start, direction, length, rng, bend=0.25, steps=4):
    pts = [Vector(start)]
    d = Vector(direction).normalized()
    for i in range(steps):
        d = (d + Vector((rng.uniform(-bend, bend), rng.uniform(-bend * 0.3, bend * 0.6), rng.uniform(-bend, bend)))).normalized()
        pts.append(pts[-1] + d * (length / steps))
    return pts


SPECIES = {
    # Plátano de sombra: fuste recto y copa ancha de racimos grandes.
    "platano": {"height": (2.4, 3.0), "radius": (0.17, 0.22), "branches": (4, 5), "spread": (1.8, 2.3),
                "rise": (1.1, 1.6), "clump": (0.7, 0.95), "extra": 2, "bark": "6b5a48",
                "palette": ("3d5a2a", "486b33", "577a3d", "6b8f45")},
    # Tilo: copa globosa de muchos racimos medianos, verde luminoso.
    "tilo": {"height": (2.1, 2.5), "radius": (0.15, 0.19), "branches": (5, 6), "spread": (1.2, 1.5),
             "rise": (1.4, 1.9), "clump": (0.65, 0.85), "extra": 3, "bark": "5e4b3a",
             "palette": ("4f7a2c", "608e36", "6fa040", "86b454")},
    # Ciprés: columna de racimos apilados, verde azulado oscuro.
    "cipres": {"height": (0.9, 1.1), "radius": (0.12, 0.15), "branches": (0, 0), "spread": (0, 0),
               "rise": (0, 0), "clump": (0.55, 0.75), "extra": 0, "bark": "4b3e32", "column": (4.2, 5.4),
               "palette": ("223d2e", "274434", "315340", "3b614b")},
    # Arce en otoño: copa asimétrica de oro y ámbar.
    "arce": {"height": (2.2, 2.8), "radius": (0.14, 0.18), "branches": (3, 4), "spread": (1.5, 2.0),
             "rise": (1.0, 1.4), "clump": (0.7, 0.95), "extra": 2, "bark": "564333",
             "palette": ("975d20", "af7629", "c48d35", "d9a847")},
}


def build_tree(species, variant, lod):
    """Árbol por gramática: fuste curvo con cuello radicular, ramas en dos niveles y racimos en
    las puntas. Devuelve {"": follaje, "trunk": madera}. Semilla fija por especie y variante."""
    sp = SPECIES[species]
    rng = random.Random(sum(map(ord, species)) * 97 + variant * 7919)
    # La madera no necesita la resolución del mobiliario: 66 árboles en el parque.
    lod = dict(lod, tube_step=0.18 if lod["detail"] else 1.5, tube_sides=8 if lod["detail"] else 3,
               lathe=16 if lod["detail"] else 5)
    wood, leaves = Builder(), Builder()
    bark = srgb(sp["bark"])
    h = rng.uniform(*sp["height"])
    r0 = rng.uniform(*sp["radius"])
    lean = Vector((rng.uniform(-0.12, 0.12), 1.0, rng.uniform(-0.12, 0.12))).normalized()
    top = Vector((0, 0, 0))
    if "column" in sp:
        # Ciprés: el follaje envuelve el fuste en toda su altura.
        col_h = rng.uniform(*sp["column"])
        trunk = [Vector((0, 0, 0)), lean * (col_h * 0.5), lean * (col_h * 0.85)]
        tube(wood, trunk, r0, bark, lod, radius_fn=lambda t: 1.0 - 0.6 * t)
        levels = 7 if lod["detail"] else 4
        for i in range(levels):
            t = (i + 0.5) / levels
            y = 1.1 + t * (col_h - 0.9)
            # Huso: ancho en el tercio inferior y afilado hacia la punta.
            width = 0.35 + 0.75 * math.sin(math.pi * min(1.0, (1 - t) * 0.85 + 0.12))
            cr = rng.uniform(*sp["clump"]) * width
            around = 3 if lod["detail"] and cr > 0.35 else 1
            for k in range(around):
                a = k * math.tau / around + rng.uniform(0, 1)
                off = Vector((math.sin(a), 0, math.cos(a))) * (cr * 0.35 if around > 1 else 0.0)
                clump(leaves, lean * y + off, cr, sp["palette"], rng, lod, squash=1.25, lumpiness=0.18)
        return {"": leaves, "trunk": wood}
    # Fuste: curva suave con ensanchamiento en la base.
    mid = lean * (h * 0.5) + Vector((rng.uniform(-0.1, 0.1), 0, rng.uniform(-0.1, 0.1)))
    top = lean * h
    tube(wood, [Vector((0, 0, 0)), mid, top], r0, bark, lod, radius_fn=lambda t: 1.0 - 0.35 * t)
    if lod["detail"]:
        flare = lambda t, y: 1.0 + 0.18 * max(0.0, math.cos(5 * t)) * max(0.0, 1 - y / 0.35)
        lathe(wood, [(r0 * 1.55, 0.0), (r0 * 1.25, 0.12), (r0 * 1.02, 0.35)], (0, 0, 0), bark, lod["lathe"], radial=flare, cap_top=False)
    tips = []
    count = rng.randint(*sp["branches"])
    for k in range(count):
        a = k * math.tau / count + rng.uniform(-0.35, 0.35)
        out = Vector((math.sin(a), 0, math.cos(a)))
        start = lean * (h * rng.uniform(0.72, 0.95))
        spread = rng.uniform(*sp["spread"])
        rise = rng.uniform(*sp["rise"])
        direction = out * spread + Vector((0, rise, 0))
        path = branch_path(start, direction, direction.length, rng)
        tube(wood, path, r0 * 0.5, bark, lod, radius_fn=lambda t: 1.0 - 0.7 * t)
        tips.append(path[-1])
        if lod["detail"]:
            for j in range(2):
                base = path[2 + j]
                sub = (out.cross(Vector((0, 1, 0))) * (1 if j else -1) + Vector((0, 0.9, 0)) + out * 0.3)
                sub_path = branch_path(base, sub, rng.uniform(0.6, 0.9), rng, steps=3)
                tube(wood, sub_path, r0 * 0.24, bark, lod, radius_fn=lambda t: 1.0 - 0.7 * t)
                tips.append(sub_path[-1])
    # Racimos: uno por punta, más una cúpula central y racimos de relleno por la copa.
    cmin, cmax = sp["clump"]
    # Cúpula alta y algo menor: deja ver ramas y cielo entre los racimos inferiores.
    crown_center = top + Vector((0, (sp["rise"][0] + sp["rise"][1]) * 0.7, 0))
    tips.append(crown_center)
    for tip in tips:
        # Los racimos cuelgan un poco por fuera de la punta, como el follaje de verdad.
        p = tip + Vector((tip.x - top.x, 0, tip.z - top.z)).normalized() * 0.15 + Vector((0, 0.1, 0))
        clump(leaves, p, rng.uniform(cmin, cmax), sp["palette"], rng, lod)
    if lod["detail"]:
        for k in range(sp["extra"]):
            a = rng.uniform(0, math.tau)
            p = crown_center + Vector((math.sin(a) * rng.uniform(0.7, 1.3), rng.uniform(-0.2, 0.4), math.cos(a) * rng.uniform(0.7, 1.3)))
            clump(leaves, p, rng.uniform(cmin * 0.7, cmax * 0.8), sp["palette"], rng, lod)
    return {"": leaves, "trunk": wood}


def build_arbol(species):
    def build(lod):
        return {str(v): build_tree(species, v, lod) for v in range(TREE_VARIANTS)}
    return build


TREE_VARIANTS = 4


def build_arbusto(lod):
    """Arbustos de radio 1 (se escalan en el parque): racimos de 3 a 5 bolas, 6 variantes."""
    variants = {}
    for v in range(6):
        rng = random.Random(4001 + v * 131)
        b = Builder()
        palette = (("3e5c32", "4d6836", "5c7a3d", "688047"), ("39502b", "4b6435", "58723c", "6a8a48"))[v % 2]
        if lod["detail"]:
            for k in range(rng.randint(3, 5)):
                a = rng.uniform(0, math.tau)
                d = rng.uniform(0.2, 0.45) if k else 0.0
                r = rng.uniform(0.55, 0.75) if k else 0.8
                clump(b, (math.sin(a) * d, r * 0.75, math.cos(a) * d), r, palette, rng, lod, squash=0.9, lumpiness=0.25)
        else:
            clump(b, (0, 0.72, 0), 0.9, palette, rng, lod, squash=0.85)
        variants[str(v)] = {"": b}
    return variants


# ---------------------------------------------------------------- pradera y horizonte

def prism(b, radius, y0, y1, center, color, sides, phase=0.0, top=None):
    """Prisma o tronco de pirámide regular (caras planas): zócalos, tejados, cornisas."""
    lathe(b, [(radius, y0), (radius if top is None else top, y1)], center, color, sides, phase=phase)


def build_quiosco(lod):
    """Quiosco de música octogonal (Ø 4,6 m, 4,9 m de alto): gradas, 8 columnas, barandilla de
    balaustres, cornisa y tejado a ocho aguas con remate."""
    b = Builder()
    detail = lod["detail"]
    ph = math.pi / 8
    stone, cream, wood, roof, iron = srgb("c9c1ae"), srgb("efe8d8"), srgb("8a6a4a"), srgb("5b6e73"), srgb("2f3634")
    # Gradas de piedra y tarima.
    for k, (r, y) in enumerate(((2.55, 0.0), (2.4, 0.18), (2.28, 0.36))):
        prism(b, r, y, y + 0.18, (0, 0, 0), srgb("c9c1ae", 1.0 - 0.04 * k), 8, ph)
    prism(b, 2.2, 0.54, 0.58, (0, 0, 0), wood, 8, ph)
    ring_r = 2.05
    corners = [Vector((math.sin(ph + i * math.tau / 8) * ring_r, 0, math.cos(ph + i * math.tau / 8) * ring_r)) for i in range(8)]
    for c in corners:
        if detail:
            lathe(b, [(0.12, 0.58), (0.12, 0.66), (0.09, 0.7), (0.075, 0.75), (0.07, 3.2), (0.085, 3.25), (0.11, 3.3), (0.11, 3.36)], tuple(c), cream, 16,
                  radial=lambda t, y: 1.0 + 0.05 * math.cos(10 * t) if 0.8 < y < 3.15 else 1.0)
        else:
            cylinder(b, 0.08, 0.58, 3.36, tuple(c), cream, 6)
    # Barandilla: pasamanos y balaustres entre columnas (salvo la entrada).
    for i in range(8):
        if i == 0:
            continue
        a, c = corners[i], corners[(i + 1) % 8]
        direction = (c - a)
        length = direction.length
        mid = (a + c) * 0.5
        rot = Matrix.Rotation(math.atan2(direction.x, direction.z) - math.pi / 2, 4, "Y")
        box(b, (length - 0.16, 0.06, 0.1), (mid.x, 1.5, mid.z), cream, 0.015, lod, rot)
        box(b, (length - 0.16, 0.05, 0.08), (mid.x, 0.68, mid.z), cream, 0.01, lod, rot)
        if detail:
            count = 9
            for k in range(count):
                p = a + direction * ((k + 1) / (count + 1))
                lathe(b, [(0.025, 0.7), (0.04, 0.8), (0.022, 0.95), (0.035, 1.2), (0.025, 1.46)], (p.x, 0, p.z), cream, 8)
        else:
            box(b, (length - 0.16, 0.76, 0.03), (mid.x, 1.09, mid.z), cream, 0.0, lod, rot)
    # Friso, cornisa y tejado.
    prism(b, 2.3, 3.36, 3.62, (0, 0, 0), cream, 8, ph)
    prism(b, 2.55, 3.62, 3.7, (0, 0, 0), srgb("dcd4c2"), 8, ph)
    if detail:
        lathe(b, [(2.6, 3.7), (2.45, 3.85), (1.6, 4.25), (0.7, 4.62), (0.25, 4.78), (0.0, 4.82)], (0, 0, 0), roof, 8, phase=ph)
        for i in range(8):
            a = ph + i * math.tau / 8
            tube(b, [(math.sin(a) * 2.62, 3.72, math.cos(a) * 2.62), (math.sin(a) * 1.62, 4.29, math.cos(a) * 1.62), (math.sin(a) * 0.3, 4.8, math.cos(a) * 0.3)], 0.035, srgb("48575b"), lod, smooth=False, sides=6)
        lathe(b, [(0.0, 4.78), (0.12, 4.82), (0.1, 4.95), (0.04, 5.0), (0.06, 5.12), (0.0, 5.3)], (0, 0, 0), iron, 12)
    else:
        lathe(b, [(2.6, 3.7), (0.0, 4.82)], (0, 0, 0), roof, 8, phase=ph)
    # Iluminación: guirnalda de bombillas colgando bajo el alero y farol central.
    bulbs = Builder()
    wire = srgb("2a2a28")
    for i in range(8):
        a, c = corners[i], corners[(i + 1) % 8]
        pts = []
        for k in range(9):
            t = k / 8
            p = a + (c - a) * t
            sag = 0.16 * math.sin(math.pi * t)
            pts.append((p.x * 1.08, 3.3 - sag, p.z * 1.08))
        if detail:
            tube(b, pts, 0.006, wire, lod, smooth=False, caps=False, sides=4)
        for k in (1, 3, 5, 7) if detail else (4,):
            x, y, z = pts[k]
            sphere(bulbs, 0.04 if detail else 0.06, (x, y - 0.05, z), srgb("fff2c8"), 10 if detail else 4)
    cylinder(b, 0.012, 3.0, 3.6, (0, 0, 0), iron, 6)
    if detail:
        lathe(b, [(0.0, 2.72), (0.14, 2.74), (0.16, 2.78), (0.1, 3.0), (0.03, 3.02)], (0, 0, 0), iron, 8, phase=math.pi / 8)
    sphere(bulbs, 0.09, (0, 2.86, 0), srgb("fff2c8"), 14 if detail else 6, squash=1.2)
    return {"": b, "bulb": bulbs}


def build_estanque(lod):
    """Estanque elíptico (7 × 4,6 m) con borde de piedra, agua y fuente de dos tazas."""
    b, water, spray = Builder(), Builder(), Builder()
    detail = lod["detail"]
    seg = 64 if detail else 16
    ax, az = 3.5, 2.3
    stone = srgb("bdb4a2")
    # Borde bajo (26 cm) para que la lámina de agua se vea desde el paseo.
    rim = [(0.0, 0.18), (0.02, 0.22), (0.1, 0.26), (0.32, 0.26), (0.38, 0.21), (0.42, 0.0)] if detail else [(0.0, 0.18), (0.0, 0.24), (0.4, 0.24), (0.4, 0.0)]
    verts, faces = [], []
    for s_i in range(seg):
        t = s_i * math.tau / seg
        ex, ez = math.sin(t), math.cos(t)
        # Normal hacia fuera de la elipse para desplazar el perfil del bordillo.
        nx, nz = ex / ax, ez / az
        nl = math.hypot(nx, nz)
        nx, nz = nx / nl, nz / nl
        for (d, y) in rim:
            verts.append((ex * ax + nx * d, y, ez * az + nz * d))
    n = len(rim)
    for s_i in range(seg):
        a0, a1 = s_i * n, ((s_i + 1) % seg) * n
        for k in range(n - 1):
            faces.append([a0 + k, a1 + k, a1 + k + 1, a0 + k + 1])
    shade = [srgb("bdb4a2", 1.0 - 0.05 * ((i * 7) % 3)) for i in range(1)]
    b.add(verts, faces, shade[0])
    # Lámina de agua a 0,2 m, casi enrasada con el borde.
    ring = [(math.sin(i * math.tau / seg) * (ax + 0.01), 0.2, math.cos(i * math.tau / seg) * (az + 0.01)) for i in range(seg)]
    # Orden de vértices con la normal hacia arriba (si no, el motor descarta la cara).
    water.add(ring, [list(range(seg))], srgb("3d5f6b"))
    # Fuente: pie, taza grande, fuste y taza pequeña con remate.
    if detail:
        lathe(b, [(0.35, 0.0), (0.3, 0.3), (0.16, 0.4), (0.14, 0.75), (0.2, 0.8), (0.95, 0.9), (1.0, 0.98), (0.92, 1.0), (0.2, 0.95)], (0, 0, 0), stone, 32)
        lathe(b, [(0.2, 0.95), (0.09, 1.05), (0.08, 1.5), (0.14, 1.55), (0.5, 1.62), (0.52, 1.68), (0.46, 1.7), (0.1, 1.66)], (0, 0, 0), srgb("c6bdaa"), 32)
        lathe(b, [(0.1, 1.66), (0.06, 1.75), (0.09, 1.85), (0.0, 1.98)], (0, 0, 0), srgb("c6bdaa"), 16)
        # Láminas de agua de las tazas.
        lathe(water, [(0.9, 0.97), (0.0, 0.97)], (0, 0, 0), srgb("3d5f6b"), 32, cap_bottom=False)
        lathe(water, [(0.47, 1.67), (0.0, 1.67)], (0, 0, 0), srgb("3d5f6b"), 32, cap_bottom=False)
    else:
        lathe(b, [(0.3, 0.0), (0.15, 0.4), (0.15, 0.8), (0.95, 0.95), (0.0, 0.95)], (0, 0, 0), stone, 8)
        lathe(b, [(0.1, 0.95), (0.08, 1.6), (0.5, 1.65), (0.0, 1.7)], (0, 0, 0), stone, 8)
    # Agua en movimiento (material translúcido propio): surtidor central y cortinas que caen de
    # cada taza, abiertas hacia fuera como una lámina real.
    s2 = 32 if detail else 8
    jet = [(0.0, 1.95), (0.03, 2.0), (0.022, 2.35), (0.05, 2.55), (0.09, 2.6), (0.0, 2.63)]
    lathe(spray, jet, (0, 0, 0), srgb("dff3ff"), 16 if detail else 6)
    curtain_upper = [(0.52, 1.66), (0.56, 1.5), (0.6, 1.25), (0.63, 0.99)] if detail else [(0.52, 1.66), (0.63, 0.99)]
    curtain_lower = [(1.0, 0.96), (1.06, 0.8), (1.12, 0.55), (1.16, 0.22)] if detail else [(1.0, 0.96), (1.16, 0.22)]
    lathe(spray, curtain_upper, (0, 0, 0), srgb("d4ecf7"), s2, cap_top=False, cap_bottom=False)
    lathe(spray, curtain_lower, (0, 0, 0), srgb("d4ecf7"), s2, cap_top=False, cap_bottom=False)
    # Espuma donde cae la cortina.
    lathe(spray, [(1.08, 0.205), (1.3, 0.215), (1.45, 0.205)], (0, 0, 0), srgb("f2fbff"), s2, cap_top=False, cap_bottom=False)
    return {"": b, "water": water, "spray": spray}


TOWER_STYLES = (
    # (ancho x, fondo z, alto, color de fachada, color de vidrio, retranqueos, remate)
    (14, 12, 48, "b9c3cc", "6f8aa3", 2, "antena"),
    (18, 14, 34, "c9bda6", "7d8c96", 1, "cornisa"),
    (10, 10, 62, "a7b6c2", "5d7c98", 3, "aguja"),
    (22, 12, 26, "b5a58f", "7a8894", 0, "cornisa"),
    (12, 16, 40, "d0cdc4", "6f8599", 1, "maquinas"),
    (16, 16, 55, "9fb0bd", "58738c", 2, "corona"),
)


def build_torre(lod):
    """Torres del horizonte (a 60–90 m): volumen escalonado, ventanas y remate. 6 estilos."""
    variants = {}
    for v, (wx, wz, height, facade, glass, setbacks, crown) in enumerate(TOWER_STYLES):
        b, windows = Builder(), Builder()
        rng = random.Random(7001 + v)
        levels = setbacks + 1
        y = 0.0
        sx, sz = wx, wz
        for level in range(levels):
            h = height * (0.55 if level == 0 and levels > 1 else (1.0 - 0.55) / max(1, levels - 1)) if levels > 1 else height
            box(b, (sx, h, sz), (0, y + h / 2, 0), srgb(facade), 0.0, lod)
            if lod["detail"]:
                # Ventanas: planos de vidrio ligeramente salientes en cada fachada.
                floors = int(h / 3.2)
                for side in range(4):
                    width = sx if side % 2 == 0 else sz
                    cols = int(width / 2.4)
                    rot = Matrix.Rotation(side * math.pi / 2, 4, "Y")
                    depth = (sz if side % 2 == 0 else sx) / 2 + 0.03
                    for f in range(floors):
                        for c in range(cols):
                            if rng.random() < 0.04:
                                continue
                            cx = -width / 2 + (c + 0.5) * width / cols
                            cy = y + 1.2 + f * 3.2
                            tone = srgb(glass, rng.uniform(0.8, 1.15))
                            # Alfa = 1 en las ventanas que se encienden de noche (una de cada tres).
                            tone = (tone[0], tone[1], tone[2], 1.0 if rng.random() < 0.33 else 0.0)
                            quad = [rot @ Vector((cx - 0.8, cy, depth)), rot @ Vector((cx + 0.8, cy, depth)), rot @ Vector((cx + 0.8, cy + 1.9, depth)), rot @ Vector((cx - 0.8, cy + 1.9, depth))]
                            windows.add([tuple(q) for q in quad], [[0, 1, 2, 3]], tone)
            y += h
            box(b, (sx + 0.6, 0.5, sz + 0.6), (0, y, 0), srgb(facade, 0.9), 0.0, lod)
            sx, sz = sx * 0.78, sz * 0.78
        if crown == "antena":
            cylinder(b, 0.25, y, y + 12, (0, 0, 0), srgb("8b949b"), 8)
        elif crown == "aguja":
            lathe(b, [(sx * 0.5, y), (0.0, y + 14)], (0, 0, 0), srgb(facade, 0.95), 4, phase=math.pi / 4)
        elif crown == "maquinas":
            box(b, (sx * 0.5, 3.5, sz * 0.4), (sx * 0.1, y + 1.75, 0), srgb("9aa1a6"), 0.0, lod)
        elif crown == "corona":
            box(b, (sx, 4.0, sz), (0, y + 2.0, 0), srgb(glass, 1.1), 0.0, lod)
        variants[str(v)] = {"": b, "windows": windows}
    return variants


ASSETS = {
    "banco": build_banco,
    "farola": build_farola,
    "papelera": build_papelera,
    "jardinera": build_jardinera,
    "verja_tramo": build_verja_tramo,
    "verja_pilar": build_verja_pilar,
    "arbol_platano": build_arbol("platano"),
    "arbol_tilo": build_arbol("tilo"),
    "arbol_cipres": build_arbol("cipres"),
    "arbol_arce": build_arbol("arce"),
    "arbusto": build_arbusto,
    "quiosco": build_quiosco,
    "estanque": build_estanque,
    "torre": build_torre,
}

# Distancia de la oclusión ambiental horneada: corta en el mobiliario, larga en el follaje.
AO_DISTANCE = {"arbol_platano": 1.2, "arbol_tilo": 1.2, "arbol_cipres": 0.9, "arbol_arce": 1.2, "arbusto": 0.6}


# ---------------------------------------------------------------- horneado y exportación

def setup_bake_scene():
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 48
    world = bpy.data.worlds.new("mundo")
    scene.world = world
    world.light_settings.distance = 0.35
    # Suelo temporal: da la oclusión de contacto en patas y bases.
    bpy.ops.mesh.primitive_plane_add(size=6.0, location=(0, 0, 0))
    ground = bpy.context.active_object
    ground.name = "suelo_horneado"
    return ground


def bake_ao(obj, objects):
    # Cada malla se hornea sola: las variantes y los dos niveles de detalle comparten el origen.
    for other in objects:
        other.hide_render = other is not obj
    mesh = obj.data
    col = mesh.color_attributes["Col"]
    ao = mesh.color_attributes.new("AO", "FLOAT_COLOR", "CORNER")
    mesh.color_attributes.active_color = ao
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.bake(type="AO", target="VERTEX_COLORS")
    for i, d in enumerate(col.data):
        a = ao.data[i].color[0]
        # Oclusión suavizada: nunca por debajo de 0,45 para no ennegrecer las juntas.
        k = 0.45 + 0.55 * a
        c = d.color
        d.color = (c[0] * k, c[1] * k, c[2] * k, 1.0)
    mesh.color_attributes.remove(ao)
    mesh.color_attributes.active_color = mesh.color_attributes["Col"]


def export(name, objects):
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, name + ".glb")
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True,
                              export_materials="NONE", export_vertex_color="ACTIVE",
                              export_normals=True, export_yup=True, export_apply=True)
    return path


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    only = None
    bake = "--no-bake" not in argv
    if "--only" in argv:
        only = set(argv[argv.index("--only") + 1].split(","))
    for name, build in ASSETS.items():
        if only and name not in only:
            continue
        bpy.ops.wm.read_factory_settings(use_empty=True)
        ground = setup_bake_scene()
        objects = []
        for lod_name, lod in LODS.items():
            for variant, parts in normalise(build(lod)).items():
                for role, builder in parts.items():
                    if builder.empty():
                        continue
                    obj_name = "_".join(p for p in (lod_name, variant, role) if p)
                    objects.append(builder.to_object(obj_name))
        if bake:
            bpy.context.scene.world.light_settings.distance = AO_DISTANCE.get(name, 0.35)
            for obj in objects:
                if not obj.name.endswith(("glass", "bulb", "water", "spray", "windows")) and name != "torre":
                    bake_ao(obj, objects)
            for obj in objects:
                obj.hide_render = False
        bpy.data.objects.remove(ground)
        path = export(name, objects)
        tris = {o.name: sum(len(p.vertices) - 2 for p in o.data.polygons) for o in objects}
        print("ASSET %s -> %s %s" % (name, os.path.relpath(path, ROOT), tris))


def normalise(result):
    """build() devuelve {rol: Builder} o, con variantes, {variante: {rol: Builder}}."""
    first = next(iter(result.values()))
    if isinstance(first, Builder):
        return {"": result}
    return {v: (p if isinstance(p, dict) else {"": p}) for v, p in result.items()}


main()
