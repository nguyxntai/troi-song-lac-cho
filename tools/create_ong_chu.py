"""Build the seated laptop cameo character for Godot.

Run with Blender in background mode. The model is deliberately composed from
simple rounded forms so it remains readable from the gameplay camera and cheap
enough to appear as ambient scenery.
"""

import bpy
import math
import os
from mathutils import Vector


ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
OUT_BLEND = os.path.join(ROOT, "assets", "OngChu", "source", "OngChu.blend")
OUT_GLB = os.path.join(ROOT, "assets", "OngChu", "OngChu.glb")


SKIN = (0.78, 0.31, 0.09, 1.0)
SKIN_LIGHT = (1.0, 0.54, 0.20, 1.0)
HAIR = (0.025, 0.018, 0.014, 1.0)
JACKET = (0.16, 0.28, 0.10, 1.0)
SHIRT = (0.92, 0.85, 0.72, 1.0)
SHORTS = (0.055, 0.05, 0.045, 1.0)
SANDAL = (0.035, 0.028, 0.022, 1.0)
SCARF_DARK = (0.055, 0.07, 0.05, 1.0)
SCARF_LIGHT = (0.76, 0.74, 0.58, 1.0)
HEADBAND = (0.22, 0.38, 0.16, 1.0)
EYE = (0.015, 0.010, 0.008, 1.0)
MOUTH = (0.35, 0.05, 0.03, 1.0)


def material(name, color, roughness=0.58):
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    mat.diffuse_color = color
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = color
    bsdf.inputs["Roughness"].default_value = roughness
    return mat


MATS = {}


def smooth(obj):
    if obj.type == "MESH":
        for polygon in obj.data.polygons:
            polygon.use_smooth = True
        bevel = obj.modifiers.new("Soft edges", "BEVEL")
        bevel.width = 0.025
        bevel.segments = 2


def bind_to_bone(obj, bone):
    """Skin one low-poly part to a single bone, preserving its world transform."""
    world = obj.matrix_world.copy()
    obj.parent = ARMATURE
    obj.matrix_world = world
    group = obj.vertex_groups.new(name=bone)
    group.add(list(range(len(obj.data.vertices))), 1.0, "REPLACE")
    modifier = obj.modifiers.new("Armature", "ARMATURE")
    modifier.object = ARMATURE


def finish(obj, name, mat, bone=None):
    obj.name = name
    obj.data.materials.append(mat)
    smooth(obj)
    if bone:
        bind_to_bone(obj, bone)
    return obj


def uv_sphere(name, location, scale, mat, bone=None, segments=20, rings=12):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings, location=location)
    obj = bpy.context.object
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return finish(obj, name, mat, bone)


def cube(name, location, scale, mat, bone=None, rotation=None, bevel=True):
    bpy.ops.mesh.primitive_cube_add(location=location)
    obj = bpy.context.object
    obj.scale = scale
    if rotation:
        obj.rotation_euler = rotation
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.name = name
    obj.data.materials.append(mat)
    if bevel:
        mod = obj.modifiers.new("Soft edges", "BEVEL")
        mod.width = 0.06
        mod.segments = 3
    if bone:
        bind_to_bone(obj, bone)
    return obj


def cylinder_between(name, a, b, radius, mat, bone=None):
    a, b = Vector(a), Vector(b)
    mid = (a + b) * 0.5
    direction = b - a
    bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=radius, depth=direction.length, location=mid)
    obj = bpy.context.object
    obj.rotation_mode = "QUATERNION"
    obj.rotation_quaternion = Vector((0.0, 0.0, 1.0)).rotation_difference(direction.normalized())
    obj.rotation_mode = "XYZ"
    return finish(obj, name, mat, bone)


def create_armature():
    bpy.ops.object.armature_add(enter_editmode=True, location=(0.0, 0.0, 0.0))
    arm = bpy.context.object
    arm.name = "OngChuRig"
    arm.data.name = "OngChuSkeleton"
    edit = arm.data.edit_bones
    root = edit[0]
    root.name = "Root"
    root.head, root.tail = (0, 0, 0.02), (0, 0, 0.38)

    def bone(name, head, tail, parent="Root"):
        b = edit.new(name)
        b.head, b.tail = head, tail
        b.parent = edit[parent]
        return b

    bone("Spine", (0, 0, 0.34), (0, 0, 0.95))
    bone("Chest", (0, 0, 0.92), (0, 0, 1.28), "Spine")
    bone("Neck", (0, 0, 1.24), (0, 0, 1.42), "Chest")
    bone("Head", (0, 0, 1.39), (0, 0, 1.82), "Neck")
    bone("UpperArm.L", (-0.27, 0.0, 1.23), (-0.48, 0.16, 1.13), "Chest")
    bone("Forearm.L", (-0.48, 0.16, 1.13), (-0.34, 0.46, 1.02), "UpperArm.L")
    bone("Hand.L", (-0.34, 0.46, 1.02), (-0.28, 0.55, 1.0), "Forearm.L")
    bone("UpperArm.R", (0.27, 0.0, 1.23), (0.48, 0.16, 1.13), "Chest")
    bone("Forearm.R", (0.48, 0.16, 1.13), (0.34, 0.46, 1.02), "UpperArm.R")
    bone("Hand.R", (0.34, 0.46, 1.02), (0.28, 0.55, 1.0), "Forearm.R")
    bone("Thigh.L", (-0.18, 0.0, 0.55), (-0.18, 0.35, 0.49), "Root")
    bone("Shin.L", (-0.18, 0.35, 0.49), (-0.18, 0.53, 0.16), "Thigh.L")
    bone("Foot.L", (-0.18, 0.53, 0.16), (-0.18, 0.65, 0.10), "Shin.L")
    bone("Thigh.R", (0.18, 0.0, 0.55), (0.18, 0.35, 0.49), "Root")
    bone("Shin.R", (0.18, 0.35, 0.49), (0.18, 0.53, 0.16), "Thigh.R")
    bone("Foot.R", (0.18, 0.53, 0.16), (0.18, 0.65, 0.10), "Shin.R")
    bpy.ops.object.mode_set(mode="OBJECT")
    arm.show_in_front = True
    return arm


def add_character():
    # Torso and clothing.
    uv_sphere("Torso", (0, 0, 0.95), (0.31, 0.20, 0.40), MATS["Jacket"], "Chest")
    cube("ShirtFront", (0, -0.205, 0.97), (0.16, 0.018, 0.25), MATS["Shirt"], "Chest")
    cube("Shorts", (0, 0.05, 0.57), (0.31, 0.20, 0.13), MATS["Shorts"], "Root")

    # Big readable head and facial expression facing -Y (towards laptop/table).
    uv_sphere("Head", (0, -0.02, 1.53), (0.36, 0.31, 0.35), MATS["Skin"], "Head", 24, 16)
    uv_sphere("Ear.L", (-0.35, -0.01, 1.53), (0.075, 0.055, 0.085), MATS["Skin"], "Head")
    uv_sphere("Ear.R", (0.35, -0.01, 1.53), (0.075, 0.055, 0.085), MATS["Skin"], "Head")
    for x in (-0.13, 0.13):
        uv_sphere("Eye", (x, -0.294, 1.57), (0.07, 0.028, 0.09), MATS["Eye"], "Head")
        uv_sphere("EyeHighlight", (x - 0.016, -0.318, 1.605), (0.018, 0.009, 0.025), MATS["Shirt"], "Head")
    uv_sphere("Nose", (0, -0.326, 1.50), (0.045, 0.028, 0.04), MATS["Skin"], "Head")
    uv_sphere("Mouth", (0, -0.315, 1.42), (0.11, 0.018, 0.04), MATS["Mouth"], "Head")

    # Hair cap and chunky tufts.
    uv_sphere("HairCap", (0, 0.005, 1.76), (0.36, 0.30, 0.18), MATS["Hair"], "Head")
    for index, x in enumerate((-0.24, -0.12, 0.0, 0.12, 0.24)):
        uv_sphere("HairTuft.%02d" % index, (x, -0.12, 1.80 + 0.05 * (1.0 - abs(x) * 3.0)), (0.12, 0.13, 0.18), MATS["Hair"], "Head")
    # Green headband and knot.
    cube("Headband", (0, -0.285, 1.71), (0.37, 0.025, 0.06), MATS["Headband"], "Head", bevel=True)
    cube("HeadbandKnot", (0.34, 0.10, 1.65), (0.07, 0.06, 0.07), MATS["Headband"], "Head", rotation=(0.2, 0.5, 0.0))

    # Scarf: two dark strips and pale check accents, fixed to chest.
    for x in (-0.15, 0.15):
        cube("Scarf", (x, -0.265, 1.00), (0.065, 0.025, 0.29), MATS["ScarfDark"], "Chest", rotation=(0.0, 0.0, -x * 0.7))
        for z in (0.86, 0.98, 1.10):
            cube("ScarfCheck", (x, -0.293, z), (0.07, 0.007, 0.025), MATS["ScarfLight"], "Chest")

    # Arms reach forward onto the invisible laptop keyboard.
    for side, sign in (("L", -1), ("R", 1)):
        shoulder = (0.31 * sign, 0.0, 1.20)
        elbow = (0.47 * sign, 0.17, 1.09)
        wrist = (0.30 * sign, 0.47, 1.02)
        cylinder_between("UpperArm." + side, shoulder, elbow, 0.105, MATS["Jacket"], "UpperArm." + side)
        cylinder_between("Forearm." + side, elbow, wrist, 0.082, MATS["Skin"], "Forearm." + side)
        uv_sphere("Hand." + side, wrist, (0.10, 0.09, 0.06), MATS["Skin"], "Hand." + side)

    # Bent legs, sandals and bare shins in seated pose.
    for side, sign in (("L", -1), ("R", 1)):
        hip = (0.18 * sign, 0.04, 0.55)
        knee = (0.18 * sign, 0.35, 0.49)
        ankle = (0.18 * sign, 0.53, 0.16)
        cylinder_between("Thigh." + side, hip, knee, 0.13, MATS["Shorts"], "Thigh." + side)
        cylinder_between("Shin." + side, knee, ankle, 0.095, MATS["Skin"], "Shin." + side)
        cube("Sandal." + side, (0.18 * sign, 0.62, 0.10), (0.14, 0.17, 0.045), MATS["Sandal"], "Foot." + side)
        cube("SandalBand." + side, (0.18 * sign, 0.58, 0.15), (0.14, 0.028, 0.055), MATS["Sandal"], "Foot." + side)


def add_typing_animation():
    bpy.context.view_layer.objects.active = ARMATURE
    ARMATURE.select_set(True)
    bpy.ops.object.mode_set(mode="POSE")
    action = bpy.data.actions.new("SitTyping")
    ARMATURE.animation_data_create()
    ARMATURE.animation_data.action = action
    action.frame_range = (1, 48)
    bpy.context.scene.frame_start, bpy.context.scene.frame_end = (1, 48)
    for frame, left, right, chest in ((1, 0.10, -0.06, 0.0), (13, -0.08, 0.12, 0.018), (25, 0.12, -0.10, -0.012), (37, -0.05, 0.08, 0.012), (48, 0.10, -0.06, 0.0)):
        for bone_name, amount in (("Forearm.L", left), ("Forearm.R", right)):
            pb = ARMATURE.pose.bones[bone_name]
            pb.rotation_mode = "XYZ"
            pb.rotation_euler = (amount, 0.0, 0.0)
            pb.keyframe_insert(data_path="rotation_euler", frame=frame)
        pb = ARMATURE.pose.bones["Chest"]
        pb.rotation_mode = "XYZ"
        pb.rotation_euler = (chest, 0.0, 0.0)
        pb.keyframe_insert(data_path="rotation_euler", frame=frame)
    bpy.ops.object.mode_set(mode="OBJECT")


def export():
    bpy.ops.object.select_all(action="SELECT")
    bpy.context.view_layer.objects.active = ARMATURE
    bpy.ops.wm.save_as_mainfile(filepath=OUT_BLEND)
    bpy.ops.export_scene.gltf(
        filepath=OUT_GLB,
        export_format="GLB",
        use_selection=True,
        export_yup=True,
        export_apply=True,
        export_animations=True,
        export_frame_range=True,
        export_force_sampling=True,
    )


# Clear the startup scene.
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
for datablocks in (bpy.data.materials, bpy.data.meshes, bpy.data.curves, bpy.data.armatures, bpy.data.actions):
    for block in list(datablocks):
        if block.users == 0:
            datablocks.remove(block)

MATS = {name: material(name, value) for name, value in {
    "Skin": SKIN_LIGHT, "Hair": HAIR, "Jacket": JACKET, "Shirt": SHIRT,
    "Shorts": SHORTS, "Sandal": SANDAL, "ScarfDark": SCARF_DARK,
    "ScarfLight": SCARF_LIGHT, "Headband": HEADBAND, "Eye": EYE,
    "Mouth": MOUTH,
}.items()}
ARMATURE = create_armature()
add_character()
add_typing_animation()
export()
print("Created", OUT_GLB)
