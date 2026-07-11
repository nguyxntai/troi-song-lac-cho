"""Render a quick verification preview of the generated cameo model."""

import bpy
import math
import os
from mathutils import Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
OUT = os.path.join(ROOT, "assets", "OngChu", "OngChu_preview.png")


def look_at(obj, target):
    obj.rotation_euler = (Vector(target) - obj.location).to_track_quat("-Z", "Y").to_euler()


# A neutral studio setup; it is only used for the preview and is never saved.
bpy.ops.mesh.primitive_plane_add(size=200, location=(0, 0.25, 0))
plane = bpy.context.object
mat = bpy.data.materials.new("Preview floor")
mat.diffuse_color = (0.12, 0.18, 0.15, 1)
plane.data.materials.append(mat)

bpy.ops.object.light_add(type="AREA", location=(3.5, -4.0, 5.0))
key = bpy.context.object
key.data.energy = 950
key.data.shape = "DISK"
key.data.size = 4.0
look_at(key, (0, 0, 0.9))

bpy.ops.object.light_add(type="AREA", location=(-3.0, -1.5, 2.0))
fill = bpy.context.object
fill.data.energy = 420
fill.data.size = 3.0
look_at(fill, (0, 0, 1.0))

bpy.ops.object.camera_add(location=(3.0, -5.4, 2.6))
camera = bpy.context.object
camera.data.lens = 58
look_at(camera, (0, 0.15, 1.0))
bpy.context.scene.camera = camera

scene = bpy.context.scene
scene.render.engine = "BLENDER_EEVEE"
scene.render.resolution_x = 700
scene.render.resolution_y = 700
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = "PNG"
scene.render.filepath = OUT
scene.world.color = (0.025, 0.035, 0.05)
scene.frame_set(1)
bpy.ops.render.render(write_still=True)
print("Rendered", OUT)
