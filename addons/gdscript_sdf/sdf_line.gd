@tool
class_name SdfLine
extends "res://addons/gdscript_sdf/sdf_shape.gd"

@export var length: float = 20.0:
	set(val):
		length = max(0.0, val)
		_notify_generator()

@export var thickness: float = 2.0:
	set(val):
		thickness = max(0.0, val)
		_notify_generator()

func get_sdf(p: Vector2) -> float:
	var half_len = length * 0.5
	var pa = p - Vector2(-half_len, 0.0)
	var ba = Vector2(length, 0.0)
	var h = clamp(pa.dot(ba) / ba.dot(ba), 0.0, 1.0)
	var d = (pa - ba * h).length() - thickness * 0.5
	return -d if inverse else d
