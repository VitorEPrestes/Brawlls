# Arena - generates the physical boundaries (walls) of the battle area.
# Creates 4 StaticBody2D walls around the perimeter.
# Arena size is configurable via the arena_size export variable.
class_name Arena extends Node2D

const SCENARIO_DESERT = "Deserto"
const SCENARIO_CEMETERY = "Cemiterio Noturno"

@export var arena_size: Vector2 = Vector2(800, 600)
@export var scenario_theme: String = SCENARIO_DESERT

func _ready():
	_create_walls()
	queue_redraw()

func set_scenario_theme(theme: String):
	scenario_theme = theme
	_refresh_wall_colors()
	queue_redraw()

# Builds the 4 boundary walls around the arena perimeter.
func _create_walls():
	var thickness = 50.0
	
	# Top wall
	_add_wall(Vector2(arena_size.x / 2, -thickness / 2), Vector2(arena_size.x + thickness * 2, thickness))
	# Bottom wall
	_add_wall(Vector2(arena_size.x / 2, arena_size.y + thickness / 2), Vector2(arena_size.x + thickness * 2, thickness))
	# Left wall
	_add_wall(Vector2(-thickness / 2, arena_size.y / 2), Vector2(thickness, arena_size.y + thickness * 2))
	# Right wall
	_add_wall(Vector2(arena_size.x + thickness / 2, arena_size.y / 2), Vector2(thickness, arena_size.y + thickness * 2))

# Creates a single wall segment with collision and visual representation.
func _add_wall(pos: Vector2, size: Vector2):
	var wall = StaticBody2D.new()
	wall.position = pos
	
	var mat = PhysicsMaterial.new()
	mat.bounce = 1.0
	mat.friction = 0.0
	wall.physics_material_override = mat
	
	var shape = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	
	var color_rect = ColorRect.new()
	color_rect.size = size
	color_rect.position = -size / 2
	color_rect.color = _wall_color()
	
	wall.add_child(shape)
	wall.add_child(color_rect)
	add_child(wall)

func _draw():
	if scenario_theme == SCENARIO_CEMETERY:
		_draw_cemetery()
		return
	_draw_desert()

func _wall_color() -> Color:
	if scenario_theme == SCENARIO_CEMETERY:
		return Color(0.10, 0.11, 0.14)
	return Color(0.49, 0.31, 0.14)

func _refresh_wall_colors():
	for child in get_children():
		if child is StaticBody2D:
			for visual in child.get_children():
				if visual is ColorRect:
					visual.color = _wall_color()

func _draw_desert():
	draw_rect(Rect2(Vector2.ZERO, arena_size), Color(0.84, 0.57, 0.28))
	draw_rect(Rect2(Vector2(8, 8), arena_size - Vector2(16, 16)), Color(0.91, 0.72, 0.41))
	
	_draw_dune_band(arena_size.y * 0.18, arena_size.y * 0.34, Color(0.98, 0.80, 0.46), 0.4)
	_draw_dune_band(arena_size.y * 0.35, arena_size.y * 0.42, Color(0.88, 0.62, 0.31), 1.8)
	_draw_dune_band(arena_size.y * 0.55, arena_size.y * 0.36, Color(0.76, 0.47, 0.22), 3.2)
	
	for i in range(24):
		var t = float(i)
		var pos = Vector2(
			fposmod(43.0 + t * 97.0, max(arena_size.x - 70.0, 1.0)) + 35.0,
			fposmod(31.0 + t * 61.0, max(arena_size.y - 70.0, 1.0)) + 35.0
		)
		var radius = 2.0 + fposmod(t * 1.7, 4.5)
		draw_circle(pos, radius, Color(0.43, 0.27, 0.13, 0.32))
		draw_circle(pos + Vector2(-radius * 0.35, -radius * 0.25), radius * 0.45, Color(0.94, 0.77, 0.50, 0.22))
	
	_draw_cactus(Vector2(arena_size.x * 0.13, arena_size.y * 0.30), 0.75)
	_draw_cactus(Vector2(arena_size.x * 0.87, arena_size.y * 0.68), 0.9)
	
	for y in range(40, int(arena_size.y), 72):
		var wave_color = Color(0.52, 0.31, 0.12, 0.18)
		var start = Vector2(18.0, float(y))
		var previous = start
		for x in range(42, int(arena_size.x - 18), 42):
			var point = Vector2(float(x), float(y) + sin((float(x) * 0.024) + float(y) * 0.015) * 8.0)
			draw_line(previous, point, wave_color, 1.4)
			previous = point
	
	draw_rect(Rect2(Vector2.ZERO, arena_size), Color(0.39, 0.21, 0.07, 0.72), false, 5.0)
	draw_rect(Rect2(Vector2(10, 10), arena_size - Vector2(20, 20)), Color(1.0, 0.91, 0.64, 0.22), false, 1.5)

func _draw_cemetery():
	draw_rect(Rect2(Vector2.ZERO, arena_size), Color(0.035, 0.045, 0.075))
	draw_rect(Rect2(Vector2(8, 8), arena_size - Vector2(16, 16)), Color(0.075, 0.085, 0.105))
	
	_draw_night_sky()
	_draw_moon(Vector2(arena_size.x * 0.82, arena_size.y * 0.16), clamp(arena_size.y * 0.055, 18.0, 34.0))
	_draw_fog_bands()
	
	var ground_y = arena_size.y * 0.62
	draw_rect(Rect2(Vector2(8.0, ground_y), Vector2(arena_size.x - 16.0, arena_size.y - ground_y - 8.0)), Color(0.085, 0.105, 0.075))
	_draw_hill(ground_y + 18.0, 72.0, Color(0.09, 0.12, 0.085), 0.3)
	_draw_hill(ground_y + 68.0, 92.0, Color(0.055, 0.075, 0.06), 1.7)
	
	_draw_dead_tree(Vector2(arena_size.x * 0.14, ground_y + 36.0), 1.0)
	_draw_dead_tree(Vector2(arena_size.x * 0.88, ground_y + 54.0), 0.82)
	
	for i in range(11):
		var t = float(i)
		var pos = Vector2(
			fposmod(62.0 + t * 137.0, max(arena_size.x - 96.0, 1.0)) + 48.0,
			ground_y + fposmod(18.0 + t * 47.0, max(arena_size.y - ground_y - 68.0, 1.0))
		)
		if i % 3 == 0:
			_draw_cross_grave(pos, 0.75 + fposmod(t * 0.13, 0.34))
		else:
			_draw_tombstone(pos, 0.70 + fposmod(t * 0.11, 0.36))
	
	for y in range(int(ground_y + 25.0), int(arena_size.y - 20.0), 42):
		draw_line(Vector2(22.0, float(y)), Vector2(arena_size.x - 22.0, float(y) + sin(float(y) * 0.07) * 5.0), Color(0.25, 0.31, 0.24, 0.17), 1.2)
	
	draw_rect(Rect2(Vector2.ZERO, arena_size), Color(0.52, 0.58, 0.68, 0.45), false, 5.0)
	draw_rect(Rect2(Vector2(10, 10), arena_size - Vector2(20, 20)), Color(0.78, 0.84, 1.0, 0.12), false, 1.5)

func _draw_dune_band(base_y: float, height: float, color: Color, phase: float):
	var points = PackedVector2Array()
	for i in range(13):
		var x = arena_size.x * float(i) / 12.0
		var wave = sin(float(i) * 0.9 + phase) * 14.0 + cos(float(i) * 0.35 + phase) * 8.0
		points.append(Vector2(x, base_y + wave))
	points.append(Vector2(arena_size.x, min(arena_size.y, base_y + height)))
	points.append(Vector2(0.0, min(arena_size.y, base_y + height * 0.92)))
	draw_colored_polygon(points, color)

func _draw_cactus(pos: Vector2, cactus_scale: float):
	var shadow_color = Color(0.30, 0.17, 0.07, 0.20)
	var cactus_color = Color(0.19, 0.42, 0.20, 0.42)
	var highlight_color = Color(0.55, 0.76, 0.38, 0.22)
	var h = 56.0 * cactus_scale
	var arm_h = 26.0 * cactus_scale
	var trunk_w = 7.0 * cactus_scale
	
	draw_circle(pos + Vector2(4.0 * cactus_scale, h * 0.10), 18.0 * cactus_scale, shadow_color)
	draw_line(pos, pos - Vector2(0.0, h), cactus_color, trunk_w)
	draw_line(pos - Vector2(1.2 * cactus_scale, h * 0.88), pos - Vector2(1.2 * cactus_scale, h * 0.22), highlight_color, max(1.2, cactus_scale * 1.7))
	draw_line(pos - Vector2(0.0, h * 0.48), pos + Vector2(-20.0, -h * 0.48), cactus_color, trunk_w * 0.75)
	draw_line(pos + Vector2(-20.0, -h * 0.48), pos + Vector2(-20.0, -h * 0.48 - arm_h), cactus_color, trunk_w * 0.75)
	draw_line(pos - Vector2(0.0, h * 0.60), pos + Vector2(22.0, -h * 0.60), cactus_color, trunk_w * 0.75)
	draw_line(pos + Vector2(22.0, -h * 0.60), pos + Vector2(22.0, -h * 0.60 - arm_h * 0.8), cactus_color, trunk_w * 0.75)

func _draw_night_sky():
	var sky_h = arena_size.y * 0.62
	for i in range(32):
		var t = float(i)
		var pos = Vector2(
			fposmod(19.0 + t * 83.0, max(arena_size.x - 36.0, 1.0)) + 18.0,
			fposmod(16.0 + t * 37.0, max(sky_h - 28.0, 1.0)) + 14.0
		)
		var radius = 0.8 + fposmod(t * 0.31, 1.3)
		draw_circle(pos, radius, Color(0.86, 0.90, 1.0, 0.36))

func _draw_moon(pos: Vector2, radius: float):
	draw_circle(pos, radius, Color(0.86, 0.88, 0.78, 0.86))
	draw_circle(pos + Vector2(radius * 0.34, -radius * 0.16), radius * 0.82, Color(0.075, 0.085, 0.105, 0.92))
	draw_arc(pos, radius + 2.0, -0.6, 1.45, 24, Color(1.0, 1.0, 0.82, 0.24), 2.0)

func _draw_fog_bands():
	for i in range(5):
		var y = arena_size.y * (0.34 + float(i) * 0.085)
		var color = Color(0.70, 0.76, 0.82, 0.065)
		var previous = Vector2(0.0, y)
		for x in range(34, int(arena_size.x) + 34, 34):
			var point = Vector2(float(x), y + sin(float(x) * 0.018 + float(i)) * 8.0)
			draw_line(previous, point, color, 12.0)
			previous = point

func _draw_hill(base_y: float, height: float, color: Color, phase: float):
	var points = PackedVector2Array()
	points.append(Vector2(0.0, arena_size.y))
	points.append(Vector2(0.0, base_y))
	for i in range(13):
		var x = arena_size.x * float(i) / 12.0
		var wave = sin(float(i) * 0.8 + phase) * 12.0 + cos(float(i) * 0.32 + phase) * 7.0
		points.append(Vector2(x, min(arena_size.y, base_y + wave)))
	points.append(Vector2(arena_size.x, arena_size.y))
	draw_colored_polygon(points, color)

func _draw_tombstone(pos: Vector2, scale_value: float):
	var width = 28.0 * scale_value
	var height = 34.0 * scale_value
	var stone = Color(0.34, 0.36, 0.39, 0.78)
	var shade = Color(0.12, 0.13, 0.15, 0.28)
	draw_circle(pos + Vector2(0.0, -height), width * 0.5, stone)
	draw_rect(Rect2(pos + Vector2(-width * 0.5, -height), Vector2(width, height)), stone)
	draw_line(pos + Vector2(-width * 0.3, -height * 0.50), pos + Vector2(width * 0.3, -height * 0.50), Color(0.70, 0.73, 0.76, 0.20), 1.3)
	draw_rect(Rect2(pos + Vector2(-width * 0.5, -height * 0.18), Vector2(width, height * 0.18)), shade)

func _draw_cross_grave(pos: Vector2, scale_value: float):
	var h = 45.0 * scale_value
	var w = 23.0 * scale_value
	var color = Color(0.29, 0.31, 0.34, 0.76)
	draw_line(pos, pos - Vector2(0.0, h), color, 6.0 * scale_value)
	draw_line(pos - Vector2(w * 0.5, h * 0.62), pos + Vector2(w * 0.5, -h * 0.62), color, 5.0 * scale_value)
	draw_circle(pos + Vector2(3.0 * scale_value, 2.0 * scale_value), 12.0 * scale_value, Color(0.0, 0.0, 0.0, 0.12))

func _draw_dead_tree(pos: Vector2, scale_value: float):
	var wood = Color(0.10, 0.075, 0.055, 0.76)
	var h = 86.0 * scale_value
	draw_line(pos, pos - Vector2(0.0, h), wood, 8.0 * scale_value)
	draw_line(pos - Vector2(0.0, h * 0.62), pos + Vector2(-36.0, -h * 0.92) * scale_value, wood, 4.0 * scale_value)
	draw_line(pos - Vector2(0.0, h * 0.72), pos + Vector2(38.0, -h * 1.02) * scale_value, wood, 4.0 * scale_value)
	draw_line(pos + Vector2(-23.0, -h * 0.80) * scale_value, pos + Vector2(-47.0, -h * 1.03) * scale_value, wood, 2.6 * scale_value)
	draw_line(pos + Vector2(25.0, -h * 0.90) * scale_value, pos + Vector2(55.0, -h * 1.06) * scale_value, wood, 2.6 * scale_value)
	draw_circle(pos + Vector2(6.0, 4.0) * scale_value, 24.0 * scale_value, Color(0.0, 0.0, 0.0, 0.16))
