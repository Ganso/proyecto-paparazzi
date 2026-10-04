"""Icono del juego en 3D: una cámara de bloques blanca con el objetivo y los botones naranjas
(diseño del usuario, 04-10-2026). Todo por código, para poder regenerarlo y ajustarlo.

    blender -b --factory-startup -P tools/blender/build_logo.py -- [--out build/marca] [--size 1024] [--samples 192]

Escribe icono.png (cuadrado, fondo transparente). tools/build_logo.sh lo compone sobre el azul
con el nombre debajo.
"""
import bpy, sys, math
from mathutils import Vector

args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
def opt(name, default):
    return args[args.index(name) + 1] if name in args else default
OUT = opt("--out", "build/marca")
SIZE = int(opt("--size", 1024))
SAMPLES = int(opt("--samples", 192))
TURN = int(opt("--turntable", 0))        # fotogramas de una vuelta completa (0: solo el icono)

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene

def material(name, color, roughness):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*color, 1)
    bsdf.inputs["Roughness"].default_value = roughness
    return m

WHITE = material("blanco", (.84, .83, .8), .55)
ORANGE = material("naranja", (.92, .23, .02), .5)

def finish(obj, mat, bevel):
    obj.data.materials.append(mat)
    mod = obj.modifiers.new("bisel", "BEVEL")
    mod.width = bevel
    mod.segments = 4
    mod.limit_method = "ANGLE"
    for poly in obj.data.polygons: poly.use_smooth = True
    return obj

def box(size, centre, mat, bevel=.05, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=1, location=centre, rotation=rot)
    obj = bpy.context.object
    obj.scale = size
    bpy.ops.object.transform_apply(scale=True)
    return finish(obj, mat, bevel)

def cylinder(radius, depth, centre, mat, bevel=.04, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cylinder_add(vertices=96, radius=radius, depth=depth, location=centre, rotation=rot)
    return finish(bpy.context.object, mat, bevel)

def wedge(centre, width, depth, height, mat):
    """Prisma inclinado (el pentaprisma): cae hacia la izquierda."""
    w, d, h = width / 2, depth / 2, height
    verts = [(-w, -d, 0), (w, -d, 0), (w, d, 0), (-w, d, 0), (w, -d, h), (w, d, h), (-w * .1, -d, h), (-w * .1, d, h)]
    faces = [(0, 3, 2, 1), (0, 1, 4, 6), (1, 2, 5, 4), (2, 3, 7, 5), (3, 0, 6, 7), (4, 5, 7, 6)]
    mesh = bpy.data.meshes.new("prisma")
    mesh.from_pydata(verts, [], faces)
    obj = bpy.data.objects.new("prisma", mesh)
    obj.location = centre
    scene.collection.objects.link(obj)
    bpy.context.view_layer.objects.active = obj
    return finish(obj, mat, .04)

# Los bloques, como en el diseño del usuario (segunda referencia, 04-10-2026):
#   · el cuerpo en dos losas apiladas, con la junta a la vista;
#   · la columna de la empuñadura a la izquierda, más salida hacia delante y partida por la misma junta;
#   · encima, el bloque del visor con su rampa (el pentaprisma) cayendo hacia la izquierda;
#   · zapata, placa, botón redondo y dial de dos discos en naranja, y unos taquitos blancos;
#   · el objetivo, un cilindro naranja casi tan alto como el cuerpo.
SEAM = .8
GRIP = 1.2                                                               # ancho de la columna de la empuñadura
box((3.4 - GRIP, 1.4, SEAM), (GRIP / 2, 0, SEAM / 2), WHITE)             # losa de abajo
box((3.4 - GRIP, 1.4, .9), (GRIP / 2, 0, SEAM + .45), WHITE)             # losa de arriba
box((GRIP, 1.85, SEAM), (-1.7 + GRIP / 2, -.225, SEAM / 2), WHITE)       # empuñadura, abajo
box((GRIP, 1.85, .9), (-1.7 + GRIP / 2, -.225, SEAM + .45), WHITE)       # empuñadura, arriba
TOP = SEAM + .9
box((1.1, 1.15, .5), (.47, .05, TOP + .25), WHITE)                       # bloque del visor
wedge((-.58, .05, TOP), 1.0, 1.05, .47, WHITE)                           # rampa del pentaprisma
box((.72, .5, .11), (.47, -.02, TOP + .555), ORANGE, .025)               # zapata
box((.18, .18, .1), (.92, .3, TOP + .55), WHITE, .02)                    # taco junto a la zapata
box((.55, .42, .12), (-1.33, .28, TOP + .06), ORANGE, .03)               # placa, detrás del botón
cylinder(.23, .16, (-1.22, -.72, TOP + .08), ORANGE, .03)                # botón redondo, sobre la empuñadura
box((.15, .15, .09), (-.86, .5, TOP + .045), WHITE, .02)
cylinder(.31, .15, (1.33, .08, TOP + .075), ORANGE, .03)                 # dial: dos discos
cylinder(.29, .15, (1.33, .08, TOP + .225), ORANGE, .03)
for x, y in ((1.2, -.5), (1.56, -.42), (1.58, .52)):
    box((.13, .13, .08), (x, y, TOP + .04), WHITE, .02)                  # taquitos
# El objetivo: algo a la derecha del centro, casi tan alto como el cuerpo.
cylinder(.93, 1.4, (.6, -1.38, .88), ORANGE, .06, (math.radians(90), 0, 0))
# La trasera: plana, con una pantalla rectangular naranja y, a su derecha (vista desde atrás), un
# único círculo plano a modo de cruceta.
box((1.9, .05, 1.1), (.55, .715, .87), ORANGE, .02)
cylinder(.33, .05, (-1.05, .715, .87), ORANGE, .02, (math.radians(90), 0, 0))

# Luces: una principal arriba a la izquierda, relleno suave y un mundo claro neutro.
world = bpy.data.worlds.new("mundo")
world.use_nodes = True
world.node_tree.nodes["Background"].inputs["Color"].default_value = (1, 1, 1, 1)
world.node_tree.nodes["Background"].inputs["Strength"].default_value = .32
scene.world = world
def area(location, energy, size, target=(0, -.3, 1)):
    data = bpy.data.lights.new("luz", "AREA")
    data.energy = energy
    data.size = size
    obj = bpy.data.objects.new("luz", data)
    obj.location = location
    obj.rotation_euler = (Vector(target) - Vector(location)).to_track_quat("-Z", "Y").to_euler()
    scene.collection.objects.link(obj)
area((1, -9, 9), 620, 8)
area((11, -2, 4), 150, 9)
area((-7, -5, 5), 150, 9)
area((0, 7, 7), 160, 8)

# Cámara: de frente, un poco desde la izquierda y desde arriba, con focal larga (casi sin fuga).
cam_data = bpy.data.cameras.new("camara")
cam_data.lens = 100                     # tres cuartos: unos 40° desde la derecha y 18° desde arriba
cam = bpy.data.objects.new("camara", cam_data)
cam.location = (7.83, -10.02, 3.75)        # de frente, algo desde la derecha y desde arriba
cam.rotation_euler = (Vector((-.05, -.55, .98)) - Vector(cam.location)).to_track_quat("-Z", "Y").to_euler()
scene.collection.objects.link(cam)
scene.camera = cam

scene.render.engine = "CYCLES"
scene.cycles.samples = SAMPLES
scene.cycles.use_denoising = False   # (the Debian build has no denoiser: more samples instead)
scene.render.film_transparent = True
scene.render.resolution_x = SIZE
scene.render.resolution_y = SIZE
scene.view_settings.view_transform = "Standard"
scene.render.image_settings.file_format = "PNG"
scene.render.image_settings.color_mode = "RGBA"
scene.render.filepath = bpy.path.abspath("//") + OUT + "/icono.png" if bpy.data.filepath else OUT + "/icono.png"
if TURN > 0:
    # Vuelta completa: la cámara y las luces quietas, el objeto gira sobre su eje vertical.
    cam_data.lens = 76       # más abierto: de lado, el objetivo se salía del cuadro
    pivot = bpy.data.objects.new("giro", None)
    scene.collection.objects.link(pivot)
    for obj in list(scene.collection.objects):
        if obj.type == "MESH": obj.parent = pivot
    base = OUT + "/giro"
    for k in range(TURN):
        pivot.rotation_euler = (0, 0, -math.tau * k / TURN)
        scene.render.filepath = "%s/giro_%03d.png" % (base, k)
        bpy.ops.render.render(write_still=True)
    print("GIRO:", base)
else:
    bpy.ops.render.render(write_still=True)
    print("ICONO:", scene.render.filepath)
