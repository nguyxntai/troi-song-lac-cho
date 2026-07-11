"""Convert the supplied GLB to a Mixamo-compatible FBX without altering it."""

import bpy
import os

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
SOURCE = os.path.join(ROOT, "assets", "OngChu", "source", "OngChu_source.glb")
OUTPUT = os.path.join(ROOT, "assets", "OngChu", "source", "OngChu_mixamo.fbx")

bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=SOURCE)
bpy.ops.object.select_all(action="DESELECT")
for obj in bpy.context.scene.objects:
    if obj.type == "MESH":
        obj.select_set(True)
bpy.ops.export_scene.fbx(
    filepath=OUTPUT,
    use_selection=True,
    object_types={"MESH"},
    apply_unit_scale=True,
    add_leaf_bones=False,
    bake_anim=False,
    path_mode="COPY",
    embed_textures=True,
)
print("Created", OUTPUT)
