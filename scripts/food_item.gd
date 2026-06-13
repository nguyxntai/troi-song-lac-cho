extends Node3D
class_name FoodItem

enum Stage {
	EMPTY_BOWL,
	BOWL_WITH_NOODLES,
	FULL_BOWL
}

@export var stage: Stage = Stage.EMPTY_BOWL


func _ready() -> void:
	_apply_food_meta()


func set_stage(new_stage: Stage) -> void:
	stage = new_stage
	_apply_food_meta()


func is_servable() -> bool:
	return stage == Stage.FULL_BOWL


func _apply_food_meta() -> void:
	set_meta("food_stage", int(stage))
	set_meta("is_servable_food", is_servable())
