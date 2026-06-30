@tool
class_name SdfShape
extends Node2D

# --- ENUMS ---
enum Operation {
	UNION = 0,
	SUBTRACTION = 1,
	INTERSECTION = 2
}

# --- PROPERTIES ---
@export var operation: Operation = Operation.UNION:
	set(val):
		operation = val
		_notify_generator()

@export_range(0.0, 100.0, 0.1) var smooth_k: float = 0.0:
	set(val):
		smooth_k = max(0.0, val)
		_notify_generator()

@export var color: Color = Color.WHITE:
	set(val):
		color = val
		_notify_generator()

@export var inverse: bool = false:
	set(val):
		inverse = val
		_notify_generator()

# --- ENGINE CALLS ---
func _init() -> void:
	set_notify_transform(true)

func _enter_tree() -> void:
	_notify_generator()

func _exit_tree() -> void:
	_notify_generator()

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED or what == NOTIFICATION_VISIBILITY_CHANGED:
		_notify_generator()

# --- PUBLIC METHODS ---
# To be overridden by subclasses.
# p is the query point in local space (with local position, rotation, and scale already applied).
func get_sdf(p: Vector2) -> float:
	return 1e20

# Helper to find and notify the generator node
func _notify_generator() -> void:
	if not is_inside_tree():
		return
	var parent = get_parent()
	while parent:
		if parent.has_method("queue_generation"):
			parent.queue_generation()
			break
		parent = parent.get_parent()
