@tool
class_name SdfCapsule
extends "res://addons/gdscript_sdf/sdf_shape.gd"

@export_range(0, 1000, 0.1) var height: float = 30.0:
	set(val):
		height = max(0.0, val)
		_notify_generator()

@export_range(0, 100, 0.1) var radius: float = 8.0:
	set(val):
		radius = max(0.0, val)
		_notify_generator()

func get_sdf(p: Vector2) -> float:
	var h = max(0.0, height - 2.0 * radius)
	var half_h = h * 0.5
	var p_clamped = Vector2(p.x, p.y - clamp(p.y, -half_h, half_h))
	var d = p_clamped.length() - radius
	return -d if inverse else d
