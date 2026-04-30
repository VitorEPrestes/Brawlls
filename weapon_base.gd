# WeaponBase - abstract base class for all weapons (Strategy Pattern).
# Each weapon overrides methods to define unique behavior.
# Extends Node2D so weapons can draw visual representations.
class_name WeaponBase extends Node2D

#region State
var owner_ball: Node = null
var weapon_name: String = "Base Weapon"
var _node_property_cache: Dictionary = {}
var _ball_group_cache: Array = []
var _ball_group_cache_frame: int = -1
static var _shared_ball_group_cache: Array = []
static var _shared_ball_group_cache_frame: int = -1
#endregion

#region Interface
# Called once when the weapon is equipped. Store owner reference.
func setup(owner: Node):
	owner_ball = owner

# Called when the owner's weapon hits a target (melee weapons).
func on_hit(target: Node):
	pass

# Called before damage is applied. Defensive weapons can reduce or block it here.
func modify_incoming_damage(amount: float, source = null) -> float:
	return amount

# Called every physics frame. Used for cooldowns, orbiting, firing, etc.
func process_weapon(delta: float):
	pass

# Called after the owner takes damage. Used by defensive weapons (e.g. Shield).
func on_owner_damaged(amount: float, source = null):
	pass

# Called when the owner eliminates another ball.
func on_owner_eliminated_target(target: Node):
	pass

func get_damage_indicator() -> float:
	if _has_node_property(self, "current_damage"):
		return float(get("current_damage"))
	if _has_node_property(self, "base_damage"):
		return float(get("base_damage"))
	if is_instance_valid(owner_ball) and _has_node_property(owner_ball, "base_damage"):
		return float(owner_ball.get("base_damage"))
	return 0.0
#endregion

#region Enemy Search
func _find_nearest_enemy(max_range: float = INF) -> Node:
	var nearest = null
	var min_dist_sq = max_range * max_range
	if not is_instance_valid(owner_ball) or not owner_ball.is_inside_tree():
		return nearest
	var owner_pos = owner_ball.global_position
	for child in _get_ball_candidates():
		if not _is_valid_enemy(child):
			continue
		var dist_sq = owner_pos.distance_squared_to(child.global_position)
		if dist_sq <= min_dist_sq:
			min_dist_sq = dist_sq
			nearest = child
	return nearest

func _get_enemy_candidates() -> Array:
	if not is_instance_valid(owner_ball) or not owner_ball.is_inside_tree():
		return []
	var candidates = []
	for child in _get_ball_candidates():
		if _is_valid_enemy(child):
			candidates.append(child)
	return candidates

func _get_ball_candidates() -> Array:
	if not is_instance_valid(owner_ball) or not owner_ball.is_inside_tree():
		_ball_group_cache = []
		_ball_group_cache_frame = -1
		return _ball_group_cache
	var frame = Engine.get_physics_frames()
	if _shared_ball_group_cache_frame != frame:
		_shared_ball_group_cache = owner_ball.get_tree().get_nodes_in_group("balls")
		_shared_ball_group_cache_frame = frame
	_ball_group_cache = _shared_ball_group_cache
	_ball_group_cache_frame = _shared_ball_group_cache_frame
	return _ball_group_cache

func _is_valid_enemy(target) -> bool:
	if target == owner_ball:
		return false
	if not is_instance_valid(target):
		return false
	if not target.has_method("take_damage"):
		return false
	if not _has_node_property(target, "is_alive"):
		return false
	if not bool(target.get("is_alive")):
		return false
	if owner_ball.has_method("is_enemy") and not owner_ball.is_enemy(target):
		return false
	return true
#endregion

#region Status & Healing
func _apply_status_to(target: Node, effect_id: String, duration: float, options: Dictionary):
	if is_instance_valid(target) and target.has_method("apply_status_effect"):
		target.apply_status_effect(effect_id, duration, options)

func _clear_status_from(target: Node, effect_id: String):
	if is_instance_valid(target) and target.has_method("clear_status_effect"):
		target.clear_status_effect(effect_id)

func _status_id(effect_name: String, target: Node = null) -> String:
	var owner_id = owner_ball.get_instance_id() if is_instance_valid(owner_ball) else 0
	var target_id = target.get_instance_id() if is_instance_valid(target) else 0
	return "%s_%s_%s" % [effect_name, owner_id, target_id]

func _heal_owner(amount: float):
	if is_instance_valid(owner_ball) and owner_ball.has_method("heal"):
		owner_ball.heal(amount)
#endregion

#region Property Helpers
# Object property helpers keep weapon scripts from relying on fragile `"prop" in node` checks.
func _has_node_property(node: Object, property_name: String) -> bool:
	if not is_instance_valid(node):
		return false
	var cache_key = _property_cache_key(node)
	var property_map: Dictionary = _node_property_cache.get(cache_key, {})
	if property_map.is_empty():
		for property in node.get_property_list():
			if property.has("name"):
				property_map[String(property["name"])] = true
		_node_property_cache[cache_key] = property_map
	return property_map.has(String(property_name))

func _set_node_property(node: Object, property_name: String, value) -> bool:
	if _has_node_property(node, property_name):
		node.set(property_name, value)
		return true
	return false

func _property_cache_key(node: Object) -> String:
	var script_path = ""
	var script = node.get_script()
	if script is Resource:
		script_path = script.resource_path
	return "%s|%s" % [node.get_class(), script_path]

func _short_video_fx_scale() -> float:
	var scene = get_tree().current_scene
	if scene and scene.has_method("get_short_video_fx_scale"):
		return float(scene.get_short_video_fx_scale())
	return 1.0

func _spawn_directional_particles(
	world_pos: Vector2,
	direction: Vector2,
	color: Color,
	amount: int = 10,
	lifetime: float = 0.22,
	spread: float = 48.0,
	velocity_min: float = 45.0,
	velocity_max: float = 150.0,
	scale_min: float = 2.0,
	scale_max: float = 5.0
):
	if not is_instance_valid(owner_ball) or not owner_ball.is_inside_tree():
		return
	var parent = owner_ball.get_parent()
	if not parent:
		return
	var fx_scale = _short_video_fx_scale()
	var safe_direction = direction.normalized()
	if safe_direction == Vector2.ZERO:
		safe_direction = Vector2.RIGHT
	var particles = CPUParticles2D.new()
	particles.emitting = true
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = amount
	particles.lifetime = lifetime
	particles.direction = safe_direction
	particles.spread = spread
	particles.initial_velocity_min = velocity_min
	particles.initial_velocity_max = velocity_max
	particles.gravity = Vector2.ZERO
	particles.scale_amount_min = scale_min * fx_scale
	particles.scale_amount_max = scale_max * fx_scale
	particles.color = color
	particles.global_position = world_pos
	parent.add_child(particles)
	owner_ball.get_tree().create_timer(max(lifetime + 0.55, 0.7)).timeout.connect(func():
		if is_instance_valid(particles):
			particles.queue_free()
	)
#endregion
