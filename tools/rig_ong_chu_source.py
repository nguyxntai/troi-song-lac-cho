"""Rig the supplied static Ong Chu model, bake a seated pose and export Godot GLB."""

import bpy
import os
from math import radians
from mathutils import Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
SOURCE = os.path.join(ROOT, "assets", "OngChu", "source", "OngChu_source.glb")
OUT_BLEND = os.path.join(ROOT, "assets", "OngChu", "source", "OngChu.blend")
OUT_GLB = os.path.join(ROOT, "assets", "OngChu", "OngChu.glb")


def scene_bounds(obj):
    points = [obj.matrix_world @ Vector(corner) for corner in obj.bound_box]
    low = Vector((min(point[i] for point in points) for i in range(3)))
    high = Vector((max(point[i] for point in points) for i in range(3)))
    return low, high


def make_armature(low, high):
    width = high.x - low.x
    depth = high.y - low.y
    height = high.z - low.z
    cx = (low.x + high.x) * 0.5
    front = low.y + depth * 0.22 # Character face is on the -Y side.
    bpy.ops.object.armature_add(enter_editmode=True, location=(0, 0, 0))
    arm = bpy.context.object
    arm.name = "OngChuRig"
    arm.data.name = "OngChuSkeleton"
    bones = arm.data.edit_bones
    root = bones[0]
    root.name = "Root"
    root.head, root.tail = (cx, 0, low.z), (cx, 0, low.z + height * .25)

    def bone(name, head, tail, parent="Root"):
        value = bones.new(name)
        value.head, value.tail = head, tail
        value.parent = bones[parent]
        return value

    hip = low.z + height * .37
    waist = low.z + height * .54
    chest = low.z + height * .69
    neck = low.z + height * .78
    shoulder = low.z + height * .70
    head = low.z + height * .91
    arm_span = width * .44
    hand_span = width * .60
    leg_x = width * .17

    bone("Hips", (cx, 0, hip), (cx, 0, waist))
    bone("Spine", (cx, 0, waist), (cx, 0, chest), "Hips")
    bone("Chest", (cx, 0, chest), (cx, 0, neck), "Spine")
    bone("Neck", (cx, 0, neck), (cx, 0, head), "Chest")
    bone("Head", (cx, 0, head), (cx, 0, high.z), "Neck")

    for side, sign in (("L", -1), ("R", 1)):
        shoulder_pos = (cx + sign * width * .22, 0, shoulder)
        elbow = (cx + sign * arm_span, 0, shoulder - height * .02)
        wrist = (cx + sign * hand_span, 0, shoulder - height * .04)
        bone("UpperArm." + side, shoulder_pos, elbow, "Chest")
        bone("Forearm." + side, elbow, wrist, "UpperArm." + side)
        bone("Hand." + side, wrist, (wrist[0] + sign * width * .06, 0, wrist[2]), "Forearm." + side)

        hip_pos = (cx + sign * leg_x, 0, hip)
        knee = (cx + sign * leg_x, 0, low.z + height * .20)
        ankle = (cx + sign * leg_x, 0, low.z + height * .045)
        bone("Thigh." + side, hip_pos, knee, "Hips")
        bone("Shin." + side, knee, ankle, "Thigh." + side)
        bone("Foot." + side, ankle, (ankle[0], front, ankle[2]), "Shin." + side)

    bpy.ops.object.mode_set(mode="OBJECT")
    arm.show_in_front = True
    return arm


def create_typing_action(arm):
    bpy.context.view_layer.objects.active = arm
    arm.select_set(True)
    bpy.ops.object.mode_set(mode="POSE")
    action = bpy.data.actions.new("SitTyping")
    arm.animation_data_create()
    arm.animation_data.action = action
    bpy.context.scene.frame_start, bpy.context.scene.frame_end = 1, 48

    keys = ((1, .09, -.04, .0), (13, -.08, .09, .018), (25, .10, -.09, -.014), (37, -.05, .07, .012), (48, .09, -.04, .0))
    for frame, left, right, chest in keys:
        # The base seated pose is keyed on every frame, so the first visible
        # frame is never the source T-pose. Only the forearms vary while typing.
        base_pose = {
            "UpperArm.L": (radians(10), radians(-15), radians(92)),
            "UpperArm.R": (radians(10), radians(15), radians(-92)),
            "Thigh.L": (radians(-88), 0, 0),
            "Thigh.R": (radians(-88), 0, 0),
            "Shin.L": (radians(88), 0, 0),
            "Shin.R": (radians(88), 0, 0),
        }
        for bone_name, rotation in base_pose.items():
            pose_bone = arm.pose.bones[bone_name]
            pose_bone.rotation_mode = "XYZ"
            pose_bone.rotation_euler = rotation
            pose_bone.keyframe_insert(data_path="rotation_euler", frame=frame)
        for bone_name, value, twist in (("Forearm.L", left, radians(-10)), ("Forearm.R", right, radians(10))):
            pose_bone = arm.pose.bones[bone_name]
            pose_bone.rotation_mode = "XYZ"
            pose_bone.rotation_euler = (radians(-28) + value, 0, twist)
            pose_bone.keyframe_insert(data_path="rotation_euler", frame=frame)
        spine = arm.pose.bones["Chest"]
        spine.rotation_mode = "XYZ"
        spine.rotation_euler = (chest, 0, 0)
        spine.keyframe_insert(data_path="rotation_euler", frame=frame)
    bpy.ops.object.mode_set(mode="OBJECT")


def point_segment_distance(point, start, end):
    axis = end - start
    length_sq = axis.length_squared
    if length_sq < 0.000001:
        return (point - start).length
    t = max(0.0, min(1.0, (point - start).dot(axis) / length_sq))
    return (point - (start + axis * t)).length


def bind_by_nearest_bone(model, arm):
    """Stable single-bone weighting for a compact one-piece stylized mesh."""
    model.parent = arm
    modifier = model.modifiers.new("Armature", "ARMATURE")
    modifier.object = arm
    deform_bones = [bone for bone in arm.data.bones if bone.name != "Root"]
    groups = {bone.name: model.vertex_groups.new(name=bone.name) for bone in deform_bones}
    for vertex in model.data.vertices:
        point = vertex.co
        nearest = min(
            deform_bones,
            key=lambda bone: point_segment_distance(point, bone.head_local, bone.tail_local),
        )
        groups[nearest.name].add([vertex.index], 1.0, "REPLACE")


# Clean startup scene and import the provided source GLB.
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=SOURCE)
meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
model = max(meshes, key=lambda obj: obj.dimensions.x * obj.dimensions.y * obj.dimensions.z)
model.name = "OngChu"
bpy.context.view_layer.objects.active = model
model.select_set(True)
bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)

low, high = scene_bounds(model)
armature = make_armature(low, high)

# Automatic weights provide smooth deformation on the supplied one-piece mesh.
bind_by_nearest_bone(model, armature)
create_typing_action(armature)

bpy.ops.object.select_all(action="SELECT")
bpy.context.view_layer.objects.active = armature
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
print("Created", OUT_GLB)
