@tool
class_name SdfBox
extends "res://addons/gdscript_sdf/sdf_shape.gd"

@export var size: Vector2 = Vector2(20.0, 20.0):
	set(val):
		size = Vector2(max(0.0, val.x), max(0.0, val.y))
		_notify_generator()

@export var rounded: float = 0.0:
	set(val):
		rounded = max(0.0, val)
		_notify_generator()

func get_sdf(p: Vector2) -> float:
	var r = min(rounded, min(size.x, size.y) * 0.5)
	var b = size * 0.5 - Vector2(r, r)
	var q = p.abs() - b
	var d = Vector2(max(q.x, 0.0), max(q.y, 0.0)).length() + min(max(q.x, q.y), 0.0) - r
	return -d if inverse else d
