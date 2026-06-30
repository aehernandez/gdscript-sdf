@tool
class_name SdfTriangle
extends "res://addons/gdscript_sdf/sdf_shape.gd"

@export var point_a: Vector2 = Vector2(0.0, -10.0):
	set(val):
		point_a = val
		_notify_generator()

@export var point_b: Vector2 = Vector2(10.0, 10.0):
	set(val):
		point_b = val
		_notify_generator()

@export var point_c: Vector2 = Vector2(-10.0, 10.0):
	set(val):
		point_c = val
		_notify_generator()

func get_sdf(p: Vector2) -> float:
	var e0 = point_b - point_a
	var e1 = point_c - point_b
	var e2 = point_a - point_c
	
	var v0 = p - point_a
	var v1 = p - point_b
	var v2 = p - point_c
	
	var pq0 = v0 - e0 * clamp(v0.dot(e0) / e0.dot(e0), 0.0, 1.0)
	var pq1 = v1 - e1 * clamp(v1.dot(e1) / e1.dot(e1), 0.0, 1.0)
	var pq2 = v2 - e2 * clamp(v2.dot(e2) / e2.dot(e2), 0.0, 1.0)
	
	var s = sign(e0.x * e2.y - e0.y * e2.x)
	var d = Vector2(
		min(min(pq0.dot(pq0), pq1.dot(pq1)), pq2.dot(pq2)),
		min(min(s * (v0.x * e0.y - v0.y * e0.x), s * (v1.x * e1.y - v1.y * e1.x)), s * (v2.x * e2.y - v2.y * e2.x))
	)
	
	var dist = -sqrt(d.x) * sign(d.y)
	return -dist if inverse else dist
