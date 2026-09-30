"""Hoja de vista previa de los objetos generados (hd arriba, lo abajo).

    blender -b --factory-startup -P tools/blender/preview_assets.py -- <salida.png> [nombres,...]
"""
import bpy
import math
import os
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SRC = os.path.join(ROOT, "assets", "parque")

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
out = argv[0] if argv else os.path.join(ROOT, "preview.png")
names = argv[1].split(",") if len(argv) > 1 else sorted(f[:-4] for f in os.listdir(SRC) if f.endswith(".glb"))

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
x = 0.0
for name in names:
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=os.path.join(SRC, name + ".glb"))
    width = 0.0
    for obj in set(bpy.data.objects) - before:
        width = max(width, obj.dimensions.x)
    offset = x + width / 2
    for obj in set(bpy.data.objects) - before:
        lod = obj.name.split("_")[0].split(".")[0]
        variant = obj.name.split("_")[1] if obj.name.count("_") and obj.name.split("_")[1].isdigit() else "0"
        obj.hide_render = variant != "0"
        obj.location = (offset, 0 if lod == "hd" else 2.5, 0)
    x += width + 0.4

scene.render.engine = "BLENDER_WORKBENCH"
shading = scene.display.shading
shading.light = "STUDIO"
shading.color_type = "VERTEX"
shading.show_shadows = True
shading.show_cavity = True
scene.render.resolution_x = 2400
scene.render.resolution_y = 1200
cam_data = bpy.data.cameras.new("cam")
cam_data.type = "ORTHO"
cam_data.ortho_scale = x * 0.92
cam = bpy.data.objects.new("cam", cam_data)
scene.collection.objects.link(cam)
# Tres cuartos desde arriba, apuntando al centro de las dos filas (hd delante, lo detrás).
target = bpy.data.objects.new("objetivo", None)
scene.collection.objects.link(target)
target.location = (x / 2, 1.25, 0.9)
cam.location = (x / 2 - 6, -16, 8)
track = cam.constraints.new("TRACK_TO")
track.target = target
track.track_axis = "TRACK_NEGATIVE_Z"
track.up_axis = "UP_Y"
scene.camera = cam
scene.render.filepath = out
bpy.ops.render.render(write_still=True)
print("PREVIEW", out)
