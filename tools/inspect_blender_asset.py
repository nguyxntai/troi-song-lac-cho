import bpy
import sys
from mathutils import Vector

if "--" in sys.argv:
    filepath = sys.argv[sys.argv.index("--") + 1]
    bpy.ops.import_scene.gltf(filepath=filepath)
bpy.context.scene.frame_set(1)

for obj in bpy.context.scene.objects:
    print("OBJECT", obj.name, obj.type, "dimensions", tuple(round(v, 3) for v in obj.dimensions))
    if obj.type == "MESH":
        points = [obj.matrix_world @ Vector(corner) for corner in obj.bound_box]
        low = tuple(round(min(p[i] for p in points), 3) for i in range(3))
        high = tuple(round(max(p[i] for p in points), 3) for i in range(3))
        print("BOUNDS", low, high)
    if obj.type == "ARMATURE":
        print("BONES", len(obj.data.bones), [bone.name for bone in obj.data.bones][:80])
        if obj.animation_data and obj.animation_data.action:
            print("ACTIVE_ACTION", obj.animation_data.action.name)
        for pose_bone in obj.pose.bones:
            if pose_bone.name in {"UpperArm.L", "UpperArm.R", "Thigh.L", "Thigh.R"}:
                print("POSE", pose_bone.name, tuple(round(v, 3) for v in pose_bone.rotation_euler))
print("ACTIONS", [action.name for action in bpy.data.actions])
