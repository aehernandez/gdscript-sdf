@tool
class_name SdfRing
extends "res://addons/gdscript_sdf/sdf_shape.gd"

@export var radius: float = 15.0:
	set(val):
		radius = max(0.0, val)
		_notify_generator()

@export var thickness: float = 4.0:
	set(val):
		thickness = max(0.0, val)
		_notify_generator()

func get_sdf(p: Vector2) -> float:
	var d = abs(p.length() - radius) - thickness * 0.5
	return -d if inverse else d
