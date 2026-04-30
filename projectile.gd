# Projectile entity used by ranged weapons and specials.
# Travels in a straight line and damages the first ball it hits.
# Supports optional AoE (area of effect) splash damage on impact.
extends Area2D

const OUTLINE_DIRECTIONS = [
	Vector2(-1.0, 0.0),
	Vector2(1.0, 0.0),
	Vector2(0.0, -1.0),
	Vector2(0.0, 1.0),
	Vector2(-1.0, -1.0),
	Vector2(1.0, -1.0),
	Vector2(-1.0, 1.0),
	Vector2(1.0, 1.0),
]

var speed: float = 600.0
var direction: Vector2 = Vector2.ZERO
var damage: float = 10.0
var source: Node = null
var is_active: bool = true
var aoe_radius: float = 0.0
var proj_color: Color = Color.WHITE
var custom_texture: Texture2D = null
var custom_texture_size: Vector2 = Vector2.ZERO
var texture_draw_scale: float = 1.0
var texture_rotation_offset: float = 0.0
var texture_outline_color: Color = Color.TRANSPARENT
var texture_outline_size: float = 0.0
var arena_cull_margin: float = 80.0

# If set, calling this callable on wall hit splits the projectile instead of destroying it
var split_on_wall: bool = false
var on_wall_split: Callable

func setup(dir: Vector2, src: Node, dmg: float = 10.0, aoe: float = 0.0, color: Color = Color.WHITE):
	direction = dir.normalized()
	source = src
	damage = dmg
	aoe_radius = aoe
	proj_color = color
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rotation = direction.angle()
	queue_redraw()
	
	body_entered.connect(_on_body_entered)
	
	# Auto destroy after 3 seconds
	await get_tree().create_timer(3.0).timeout
	if is_active:
		queue_free()

func _physics_process(delta):
	if is_active:
		position += direction * speed * delta
		if _is_outside_arena_bounds(arena_cull_margin):
			_deactivate()

func _draw():
	var fx_scale = _short_video_fx_scale()
	if custom_texture:
		if custom_texture_size == Vector2.ZERO:
			custom_texture_size = custom_texture.get_size()
		var tex_size = custom_texture_size
		draw_set_transform(Vector2.ZERO, texture_rotation_offset, Vector2.ONE * fx_scale * texture_draw_scale)
		if texture_outline_size > 0.0 and texture_outline_color.a > 0.0:
			var outline = max(1.0, texture_outline_size)
			for direction_offset in OUTLINE_DIRECTIONS:
				var offset = direction_offset * outline
				draw_texture_rect(custom_texture, Rect2(-tex_size / 2.0 + offset, tex_size), false, texture_outline_color)
		draw_texture_rect(custom_texture, Rect2(-tex_size/2, tex_size), false)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return

	# Draw projectile circle
	var radius = (12.0 if aoe_radius > 0 else 8.0) * fx_scale
	draw_circle(Vector2.ZERO, radius, proj_color)
	draw_arc(Vector2.ZERO, radius + 1.5, 0.0, TAU, 20, Color(1.0, 1.0, 1.0, 0.45), max(1.4, 1.8 * fx_scale))
	if aoe_radius > 0:
		# Extra glow for explosive projectiles
		draw_circle(Vector2.ZERO, radius + 4.0 * fx_scale, Color(proj_color, 0.3))

func _on_body_entered(body: Node):
	if not is_active: return
	if body == source: return
	
	# Wall hit: optionally split instead of destroy
	if body is StaticBody2D:
		if split_on_wall and on_wall_split.is_valid():
			on_wall_split.call(self)
		_deactivate()
		return
	
	# Direct hit damage
	if body.has_method("take_damage"):
		body.take_damage(damage, source)
		if is_instance_valid(source) and _has_object_property(source, "weapon") and is_instance_valid(source.weapon):
			if source.weapon.has_method("on_projectile_hit"):
				source.weapon.on_projectile_hit(body, damage)
	
	# AoE splash damage to nearby balls
	if aoe_radius > 0:
		_apply_aoe(body)
		_spawn_explosion()
	
	_deactivate()

func _deactivate():
	if not is_active:
		return
	is_active = false
	var parent = get_parent()
	if parent:
		for child in get_children():
			if child is AudioStreamPlayer2D:
				var audio: AudioStreamPlayer2D = child
				audio.reparent(parent, true)
				if audio.playing:
					audio.finished.connect(audio.queue_free, CONNECT_ONE_SHOT)
				else:
					audio.queue_free()
	queue_free()

func _apply_aoe(direct_hit: Node):
	# Damage all nearby balls (excluding direct hit and source)
	var arena = get_parent()
	if not arena: return
	var aoe_radius_sq = aoe_radius * aoe_radius
	for child in get_tree().get_nodes_in_group("balls"):
		if child == direct_hit or child == source: continue
		if not child.has_method("take_damage"): continue
		if not child.is_alive: continue
		if source != null and source.has_method("is_enemy") and not source.is_enemy(child): continue
		var dist_sq = global_position.distance_squared_to(child.global_position)
		if dist_sq <= aoe_radius_sq:
			var dist = sqrt(dist_sq)
			# Damage falls off with distance
			var splash = damage * 0.5 * (1.0 - dist / aoe_radius)
			child.take_damage(splash, source)

func _spawn_explosion():
	# Visual explosion particles at impact point
	var fx_scale = _short_video_fx_scale()
	var particles = CPUParticles2D.new()
	particles.emitting = true
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = 14
	particles.lifetime = 0.5
	particles.direction = Vector2.ZERO
	particles.spread = 180.0
	particles.initial_velocity_min = 40.0
	particles.initial_velocity_max = 120.0
	particles.gravity = Vector2.ZERO
	particles.scale_amount_min = 3.0 * fx_scale
	particles.scale_amount_max = 6.0 * fx_scale
	particles.color = Color(1, 0.5, 0)
	particles.global_position = global_position
	get_parent().add_child(particles)
	# Auto-cleanup
	get_tree().create_timer(1.0).timeout.connect(func():
		if is_instance_valid(particles): particles.queue_free()
	)

func _has_object_property(obj: Object, property_name: String) -> bool:
	if not is_instance_valid(obj):
		return false
	for property in obj.get_property_list():
		if property.has("name") and property["name"] == property_name:
			return true
	return false

func _is_outside_arena_bounds(margin: float) -> bool:
	var arena = get_parent()
	if not arena or not _has_object_property(arena, "arena_size"):
		return false
	var arena_size: Vector2 = arena.get("arena_size")
	var local_pos = arena.to_local(global_position) if arena is Node2D else position
	return not Rect2(Vector2.ZERO, arena_size).grow(margin).has_point(local_pos)

func _short_video_fx_scale() -> float:
	var scene = get_tree().current_scene
	if scene and scene.has_method("get_short_video_fx_scale"):
		return float(scene.get_short_video_fx_scale())
	return 1.0
