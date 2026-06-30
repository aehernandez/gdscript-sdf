@tool
class_name SdfSpriteGenerator
extends Sprite2D


# --- PROPERTIES ---
@export_group("Canvas Settings")
@export var sprite_size: Vector2i = Vector2i(64, 64):
	set(val):
		sprite_size = Vector2i(max(1, val.x), max(1, val.y))
		queue_generation()
		if Engine.is_editor_hint():
			queue_redraw()

@export_range(1, 16, 1) var pixel_scale: int = 1:
	set(val):
		pixel_scale = max(1, val)
		queue_generation()

@export var bg_color: Color = Color(0, 0, 0, 0):
	set(val):
		bg_color = val
		queue_generation()

@export var antialiasing: bool = true:
	set(val):
		antialiasing = val
		queue_generation()

@export_group("Symmetry")
@export var horizontal_symmetry: bool = false:
	set(val):
		horizontal_symmetry = val
		queue_generation()

@export var vertical_symmetry: bool = false:
	set(val):
		vertical_symmetry = val
		queue_generation()

@export_group("Outline & Glow")
@export_range(0.0, 20.0, 0.5) var outline_width: float = 0.0:
	set(val):
		outline_width = max(0.0, val)
		queue_generation()

@export var outline_color: Color = Color.BLACK:
	set(val):
		outline_color = val
		queue_generation()

@export_range(0.0, 50.0, 0.5) var glow_width: float = 0.0:
	set(val):
		glow_width = max(0.0, val)
		queue_generation()

@export var glow_color: Color = Color(0.0, 0.5, 1.0, 0.5):
	set(val):
		glow_color = val
		queue_generation()

@export_group("Export Settings")
@export_dir var export_folder: String = "res://sprites/sdf_generated/":
	set(val):
		export_folder = val

@export var export_prefix: String = "sdf_sprite":
	set(val):
		export_prefix = val

@export_group("Actions")
@export_tool_button("Generate Sprite", "Play") var generate_btn := func(): _action_generate()
@export_tool_button("Save PNG & Export", "Save") var save_btn := func(): _action_save_png()
@export_tool_button("Export as Sprite2D Node", "Add") var export_node_btn := func(): _action_export_sprite2d_node()


# --- INTERNAL VARS ---
var _generation_queued := false


# --- ENGINE CALLS ---
func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	queue_generation()
	if DisplayServer.get_name() == "headless":
		call_deferred("_headless_export")

func _headless_export() -> void:
	_generate_and_update()
	export_to_png()

func _enter_tree() -> void:
	queue_generation()
	if Engine.is_editor_hint():
		queue_redraw()

func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	
	# Draw boundary box in editor so users see where the sprite is composed
	var w = float(sprite_size.x)
	var h = float(sprite_size.y)
	var rect = Rect2(-w / 2.0, -h / 2.0, w, h)
	
	# Draw light dashed-like bounding box
	draw_rect(rect, Color(1.0, 1.0, 1.0, 0.25), false, 1.0)
	
	# Draw center crosshair
	draw_line(Vector2(-5, 0), Vector2(5, 0), Color(1.0, 1.0, 1.0, 0.4), 1.0)
	draw_line(Vector2(0, -5), Vector2(0, 5), Color(1.0, 1.0, 1.0, 0.4), 1.0)


# --- GENERATION & REGENERATION ---
func queue_generation() -> void:
	if not is_inside_tree():
		return
	if _generation_queued:
		return
	_generation_queued = true
	call_deferred("_generate_and_update")

func _generate_and_update() -> void:
	_generation_queued = false
	var img = generate_image()
	if img:
		texture = ImageTexture.create_from_image(img)

func generate_image() -> Image:
	var shapes = _gather_shapes(self)
	
	var w = sprite_size.x
	var h = sprite_size.y
	if w <= 0 or h <= 0:
		return null
		
	var img = Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(bg_color)
	
	for y in range(h):
		for x in range(w):
			# Map to local generator coordinate system with center origin (0, 0)
			var p_gen = Vector2(
				x - float(w) / 2.0 + 0.5,
				y - float(h) / 2.0 + 0.5
			)
			
			var col = _evaluate_pixel(p_gen, shapes)
			img.set_pixel(x, y, col)
			
	if pixel_scale > 1:
		img.resize(w * pixel_scale, h * pixel_scale, Image.INTERPOLATE_NEAREST)
		
	return img


# --- INTERNAL ALGORITHMS ---
func _gather_shapes(node: Node) -> Array[SdfShape]:
	var shapes: Array[SdfShape] = []
	for child in node.get_children():
		if child is SdfShape:
			shapes.append(child)
		shapes.append_array(_gather_shapes(child))
	return shapes

func _is_shape_visible(shape: SdfShape) -> bool:
	if shape.is_inside_tree():
		return shape.is_visible_in_tree()
	
	var current: Node = shape
	while current and current != self:
		if "visible" in current and not current.visible:
			return false
		current = current.get_parent()
	return true

func _evaluate_pixel(p_gen: Vector2, shapes: Array[SdfShape]) -> Color:
	# Apply symmetry
	if horizontal_symmetry:
		p_gen.x = abs(p_gen.x)
	if vertical_symmetry:
		p_gen.y = abs(p_gen.y)
		
	var final_d: float = 1e20
	var final_color: Color = Color.TRANSPARENT
	var has_shapes := false
	
	for shape in shapes:
		if not _is_shape_visible(shape):
			continue
		has_shapes = true
		
		# Compute relative transform from shape to generator space.
		# p_shape = T_shape_local_inverse * T_generator_local * p_gen
		var shape_to_gen = global_transform.affine_inverse() * shape.global_transform
		var p_shape = shape_to_gen.affine_inverse() * p_gen
		
		var d = shape.get_sdf(p_shape)
		var col = shape.color
		
		if final_d > 1e19:
			final_d = d
			final_color = col
		else:
			match shape.operation:
				SdfShape.Operation.UNION:
					if shape.smooth_k > 0.0:
						var h = clamp(0.5 + 0.5 * (d - final_d) / shape.smooth_k, 0.0, 1.0)
						final_d = lerp(d, final_d, h) - shape.smooth_k * h * (1.0 - h)
						final_color = col.lerp(final_color, h)
					else:
						if d < final_d:
							final_d = d
							final_color = col
				SdfShape.Operation.SUBTRACTION:
					if shape.smooth_k > 0.0:
						var h = clamp(0.5 - 0.5 * (d + final_d) / shape.smooth_k, 0.0, 1.0)
						final_d = lerp(final_d, -d, h) + shape.smooth_k * h * (1.0 - h)
						final_color = final_color.lerp(col, h)
					else:
						if -d > final_d:
							final_d = -d
							final_color = col
						else:
							final_d = max(final_d, -d)
				SdfShape.Operation.INTERSECTION:
					if shape.smooth_k > 0.0:
						var h = clamp(0.5 - 0.5 * (d - final_d) / shape.smooth_k, 0.0, 1.0)
						final_d = lerp(d, final_d, h) + shape.smooth_k * h * (1.0 - h)
						final_color = col.lerp(final_color, h)
					else:
						if d > final_d:
							final_d = d
							final_color = col
						else:
							final_d = final_d

	if not has_shapes:
		return bg_color
		
	# Determine final pixel color
	if antialiasing:
		# Anti-aliasing with 1-pixel width step
		var core_alpha = clamp(0.5 - final_d, 0.0, 1.0)
		var col_core = Color(final_color.r, final_color.g, final_color.b, final_color.a * core_alpha)
		
		var current_color = col_core
		
		# Outline Layer (drawn behind core)
		var outline_alpha := 0.0
		if outline_width > 0.0:
			var outline_d = final_d - outline_width
			outline_alpha = clamp(0.5 - outline_d, 0.0, 1.0)
			var net_outline_alpha = clamp(outline_alpha - core_alpha, 0.0, 1.0)
			var col_outline = Color(outline_color.r, outline_color.g, outline_color.b, outline_color.a * net_outline_alpha)
			current_color = blend_colors(col_outline, current_color)
			
		# Glow Layer (drawn behind outline/core)
		if glow_width > 0.0:
			var start_d = outline_width if outline_width > 0.0 else 0.0
			var glow_d = final_d - (start_d + glow_width)
			var glow_alpha_mask = clamp(0.5 - glow_d, 0.0, 1.0)
			
			var dist_in_glow = final_d - start_d
			var glow_fade = clamp(1.0 - dist_in_glow / glow_width, 0.0, 1.0)
			
			var prev_cover = clamp((outline_alpha if outline_width > 0.0 else core_alpha), 0.0, 1.0)
			var net_glow_alpha = clamp(glow_alpha_mask - prev_cover, 0.0, 1.0) * glow_fade
			
			var col_glow = Color(glow_color.r, glow_color.g, glow_color.b, glow_color.a * net_glow_alpha)
			current_color = blend_colors(col_glow, current_color)
			
		return blend_colors(bg_color, current_color)
	else:
		# Standard hard edges (aliased)
		if final_d <= 0.0:
			return blend_colors(bg_color, final_color)
		elif outline_width > 0.0 and final_d <= outline_width:
			return blend_colors(bg_color, outline_color)
		elif glow_width > 0.0 and final_d <= (outline_width if outline_width > 0.0 else 0.0) + glow_width:
			var start_d = outline_width if outline_width > 0.0 else 0.0
			var dist_in_glow = final_d - start_d
			var glow_fade = clamp(1.0 - dist_in_glow / glow_width, 0.0, 1.0)
			var col_glow = Color(glow_color.r, glow_color.g, glow_color.b, glow_color.a * glow_fade)
			return blend_colors(bg_color, col_glow)
		else:
			return bg_color

func blend_colors(under: Color, over: Color) -> Color:
	var alpha_out = over.a + under.a * (1.0 - over.a)
	if alpha_out <= 0.0:
		return Color.TRANSPARENT
	var r = (over.r * over.a + under.r * under.a * (1.0 - over.a)) / alpha_out
	var g = (over.g * over.a + under.g * under.a * (1.0 - over.a)) / alpha_out
	var b = (over.b * over.a + under.b * under.a * (1.0 - over.a)) / alpha_out
	return Color(r, g, b, alpha_out)

func generate_uuid() -> String:
	var chars := "0123456789abcdef"
	var uuid := ""
	for i in range(36):
		if i == 8 or i == 13 or i == 18 or i == 23:
			uuid += "-"
		elif i == 14:
			uuid += "4"
		elif i == 19:
			var hex_y = ["8", "9", "a", "b"]
			uuid += hex_y[randi() % 4]
		else:
			uuid += chars[randi() % 16]
	return uuid


# --- ACTIONS ---
func _action_generate() -> void:
	queue_generation()

func _action_save_png() -> void:
	export_to_png()

func _action_export_sprite2d_node() -> void:
	export_as_sprite2d_node()


# --- EXPORT MECHANISMS ---
func export_to_png() -> String:
	var img = generate_image()
	if not img:
		printerr("SdfSpriteGenerator: Failed to generate image.")
		return ""
		
	var folder = export_folder.simplify_path()
	if not folder.begins_with("res://"):
		folder = "res://" + folder
		
	if not DirAccess.dir_exists_absolute(folder):
		var err = DirAccess.make_dir_recursive_absolute(folder)
		if err != OK:
			printerr("SdfSpriteGenerator: Failed to create folder structure: ", folder, ". Error code: ", err)
			return ""
			
	var uuid = generate_uuid()
	var filename = "%s_%s.png" % [export_prefix.validate_filename(), uuid]
	var full_path = folder.path_join(filename)
	
	var err = img.save_png(full_path)
	if err != OK:
		printerr("SdfSpriteGenerator: Failed to save PNG file: ", full_path, ". Error code: ", err)
		return ""
		
	print("SdfSpriteGenerator: Successfully saved PNG to: ", full_path)
	
	if Engine.is_editor_hint():
		var editor = Engine.get_singleton("EditorInterface")
		if editor:
			var efs = editor.get_resource_filesystem()
			if efs:
				efs.reimport_files(PackedStringArray([full_path]))
				print("SdfSpriteGenerator: Reimported resource: ", full_path)
	
	return full_path

func export_as_sprite2d_node() -> void:
	if not Engine.is_editor_hint():
		print("SdfSpriteGenerator: Export to Sprite2D node is an editor-only action.")
		return
		
	var full_path = export_to_png()
	if full_path == "":
		return
		
	var editor = Engine.get_singleton("EditorInterface")
	if not editor:
		printerr("SdfSpriteGenerator: EditorInterface is unavailable.")
		return
		
	var scene_root = editor.get_edited_scene_root()
	if not scene_root:
		printerr("SdfSpriteGenerator: Cannot add Sprite2D node. Active scene root not found.")
		return
		
	# Load the reimported texture
	var tex = load(full_path)
	if not tex:
		# Fallback to load PNG file directly via Image if the engine reimport has a slight delay
		var img = Image.load_from_file(full_path)
		if img:
			tex = ImageTexture.create_from_image(img)
			
	if not tex:
		printerr("SdfSpriteGenerator: Failed to load exported texture.")
		return
		
	var uuid = full_path.get_file().get_basename().split("_")[-1]
	var new_sprite = Sprite2D.new()
	new_sprite.name = "%s_%s" % [export_prefix.capitalize(), uuid]
	new_sprite.texture = tex
	new_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	
	# Position offset relative to generator
	new_sprite.global_position = global_position + Vector2(sprite_size.x * pixel_scale + 32, 0)
	
	scene_root.add_child(new_sprite)
	new_sprite.owner = scene_root
	
	print("SdfSpriteGenerator: Created and added Sprite2D node: ", new_sprite.name)
