import bpy
import os
from mathutils import Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
OUT = os.path.join(ROOT, "assets", "OngChu", "OngChu_side_preview.png")

def look_at(obj, target):
    obj.rotation_euler = (Vector(target) - obj.location).to_track_quat("-Z", "Y").to_euler()

bpy.ops.mesh.primitive_plane_add(size=200, location=(0, 0, 0))
plane = bpy.context.object
mat = bpy.data.materials.new("Floor")
mat.diffuse_color = (0.10, 0.12, 0.14, 1)
plane.data.materials.append(mat)
bpy.ops.object.light_add(type="AREA", location=(3.5, -3.5, 5.0))
key = bpy.context.object
key.data.energy, key.data.size = 950, 4.0
look_at(key, (0, 0, .55))
bpy.ops.object.light_add(type="AREA", location=(-2, 2, 2))
fill = bpy.context.object
fill.data.energy, fill.data.size = 420, 3.0
look_at(fill, (0, 0, .55))
bpy.ops.object.camera_add(location=(3.2, 0.15, 1.25))
camera = bpy.context.object
camera.data.lens = 62
look_at(camera, (0, 0, .57))
scene = bpy.context.scene
scene.camera = camera
scene.frame_set(1)
scene.render.engine = "BLENDER_EEVEE"
scene.render.resolution_x = 700
scene.render.resolution_y = 700
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = "PNG"
scene.render.filepath = OUT
scene.world.color = (0.025, 0.035, 0.05)
bpy.ops.render.render(write_still=True)
