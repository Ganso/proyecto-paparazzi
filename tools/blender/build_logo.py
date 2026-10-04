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
ORANGE = material("naranja", (.9, .29, .03), .5)

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

# El cuerpo: dos bloques apilados (la junta se ve), la empuñadura y la joroba del visor.
box((3.4, 1.4, .88), (0, 0, .44), WHITE)
box((3.4, 1.4, .98), (0, 0, 1.39), WHITE)
box((.62, .36, 1.5), (-1.39, -.86, 1.13), WHITE)                # empuñadura, hacia delante
box((1.55, 1.25, .5), (.45, 0, 2.13), WHITE)                  # bloque del visor
wedge((-.72, 0, 1.88), .9, 1.1, .5, WHITE)                    # pentaprisma inclinado
box((.8, .55, .11), (.4, -.12, 2.435), ORANGE, .025)          # zapata, naranja
box((.2, .2, .1), (1.02, .25, 2.43), WHITE, .02)              # taco
# Mandos naranjas.
box((.55, .42, .12), (-1.2, .3, 1.94), ORANGE, .03)
cylinder(.22, .16, (-1.39, -.82, 1.96), ORANGE, .03)   # disparador
cylinder(.31, .14, (1.28, 0, 1.95), ORANGE, .03)
cylinder(.29, .14, (1.28, 0, 2.10), ORANGE, .03)
# El objetivo: un cilindro grande que sale hacia delante.
cylinder(.95, 1.45, (-.05, -1.35, .98), ORANGE, .06, (math.radians(90), 0, 0))

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
area((-5, -7, 8), 560, 7)
area((6, -6, 3), 90, 9)
area((0, 3, 7), 80, 8)

# Cámara: de frente, un poco desde la izquierda y desde arriba, con focal larga (casi sin fuga).
cam_data = bpy.data.cameras.new("camara")
cam_data.lens = 170
cam = bpy.data.objects.new("camara", cam_data)
cam.location = (-6.5, -21, 5.2)
cam.rotation_euler = (Vector((0, -.6, 1.15)) - Vector(cam.location)).to_track_quat("-Z", "Y").to_euler()
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
bpy.ops.render.render(write_still=True)
print("ICONO:", scene.render.filepath)
