@tool
class_name SdfCircle
extends "res://addons/gdscript_sdf/sdf_shape.gd"

@export var radius: float = 10.0:
	set(val):
		radius = max(0.0, val)
		_notify_generator()

func get_sdf(p: Vector2) -> float:
	var d = p.length() - radius
	return -d if inverse else d
