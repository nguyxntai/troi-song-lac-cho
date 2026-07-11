import bpy
import os
import sys
from mathutils import Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
if "--" not in sys.argv:
    raise RuntimeError("Pass a GLB path after --")
source = sys.argv[sys.argv.index("--") + 1]
out = os.path.join(ROOT, "assets", "OngChu", "source_preview.png")

bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=source)

meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
low = Vector((min((obj.matrix_world @ Vector(corner))[i] for obj in meshes for corner in obj.bound_box) for i in range(3)))
high = Vector((max((obj.matrix_world @ Vector(corner))[i] for obj in meshes for corner in obj.bound_box) for i in range(3)))
target = (low + high) * 0.5
extent = max((high - low).length, 0.5)

def look_at(obj, point):
    obj.rotation_euler = (point - obj.location).to_track_quat("-Z", "Y").to_euler()

bpy.ops.mesh.primitive_plane_add(size=20, location=(target.x, target.y, low.z - 0.01))
floor = bpy.context.object
floor_mat = bpy.data.materials.new("Floor")
floor_mat.diffuse_color = (0.05, 0.08, 0.10, 1)
floor.data.materials.append(floor_mat)

bpy.ops.object.light_add(type="AREA", location=target + Vector((extent, -extent * 1.4, extent * 1.6)))
key = bpy.context.object
key.data.energy = 850
key.data.shape = "DISK"
key.data.size = extent * 2.5
look_at(key, target)
bpy.ops.object.light_add(type="AREA", location=target + Vector((-extent, -extent, extent * .8)))
fill = bpy.context.object
fill.data.energy = 360
fill.data.size = extent * 2.0
look_at(fill, target)
bpy.ops.object.camera_add(location=target + Vector((extent * 1.7, -extent * 2.4, extent * 1.15)))
camera = bpy.context.object
camera.data.lens = 55
look_at(camera, target)

scene = bpy.context.scene
scene.camera = camera
scene.render.engine = "BLENDER_EEVEE"
scene.render.resolution_x = 700
scene.render.resolution_y = 700
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = "PNG"
scene.render.filepath = out
scene.world.color = (0.015, 0.022, 0.032)
bpy.ops.render.render(write_still=True)
print("Rendered", out)
