# Ball entity - the core combat unit of the simulation.
# Uses RigidBody2D for physics movement and delegates combat behavior to its weapon.
extends RigidBody2D

#region References
const WeaponRegistryScript = preload("res://weapon_registry.gd")
const BOUNCE_SFX_STREAM = preload("res://sfx/Bounce_ball_sfx.mp3")
const SLOW_FX_TEXTURE_PATH = "res://weapons/texturas/slow_fx.png"

signal died(ball)
#endregion

#region Configuration
# --- Configuration ---
var display_name: String = "Ball"
var max_hp: float = 100.0
var current_hp: float = 100.0
var configured_max_hp: float = 100.0
var configured_mass: float = 1.0
var base_damage: float = 10.0
var weapon_type: String = "Shield"
var ball_color: Color = Color.WHITE
var original_color: Color = Color.WHITE
var hit_flash_alpha: float = 0.0
var hit_flash_timer: float = 0.0
var hit_flash_duration: float = 0.08
var impact_fx_cooldown_timer: float = 0.0
var impact_fx_cooldown: float = 0.08
var last_fx_scale: float = 1.0
var slow_fx_texture: Texture2D = null
var team_id: int = 0
var base_gravity_scale: float = 0.45

# --- State ---
var is_alive: bool = true
var speed_modifier: float = 1.0      # Multiplier for base speed, used by slows.
var is_invulnerable: bool = false    # When true, take_damage is blocked.
var speed_limit_override: float = 0.0 # Temporary cap used by dash specials.
var paralysis_timer: float = 0.0
var weapon: WeaponBase = null
var status_effects: Dictionary = {}
var status_effect_serial: int = 0
var last_damage_source: Node = null

# --- Movement ---
var speed_limit: float = 620.0
var impulse_force: float = 430.0
var impulse_timer: float = 0.0
var impulse_interval: float = 1.5
var target_scan_interval: float = 0.12
var target_scan_timer: float = 0.0
var pull_target: Node = null
var is_touching_wall: bool = false
var wall_bounce_queued: bool = false

@onready var hp_label = $HPLabel
@onready var label = $Label
@onready var bounce_sfx_player: AudioStreamPlayer2D = null
#endregion

#region Lifecycle
func setup(config: Dictionary):
	configured_max_hp = config.get("max_hp", 100.0)
	configured_mass = config.get("mass", 1.0)
	var final_config = WeaponRegistryScript.apply_stat_modifiers(config)
	display_name = final_config.get("display_name", "Ball")
	max_hp = final_config.get("max_hp", 100.0)
	current_hp = max_hp
	base_damage = final_config.get("base_damage", 10.0)
	mass = final_config.get("mass", 1.0)
	base_gravity_scale = final_config.get("gravity_scale", 0.45)
	gravity_scale = base_gravity_scale
	
	var natural_color = final_config.get("natural_color", final_config.get("color", Color.WHITE))
	ball_color = natural_color
	original_color = natural_color
	team_id = final_config.get("team_id", 0)
	
	weapon_type = _normalize_weapon_type(final_config.get("weapon_type", "Shield"))
	
	var mat = PhysicsMaterial.new()
	mat.bounce = final_config.get("restitution", 1.0)
	mat.friction = final_config.get("friction", 0.0)
	physics_material_override = mat

func _ready():
	add_to_group("balls")
	if ResourceLoader.exists(SLOW_FX_TEXTURE_PATH):
		slow_fx_texture = load(SLOW_FX_TEXTURE_PATH)
	input_pickable = true
	linear_damp = 0.0
	angular_damp = 0.0
	contact_monitor = true
	max_contacts_reported = 16

	bounce_sfx_player = AudioStreamPlayer2D.new()
	bounce_sfx_player.stream = BOUNCE_SFX_STREAM
	bounce_sfx_player.volume_db = 8.0
	add_child(bounce_sfx_player)
	
	var random_dir = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
	if random_dir == Vector2.ZERO:
		random_dir = Vector2.RIGHT.rotated(randf() * TAU)
	apply_central_impulse(random_dir * impulse_force * mass)
	target_scan_timer = randf() * target_scan_interval
	
	_equip_weapon(weapon_type, true)
	_configure_labels()
	queue_redraw()

func _equip_weapon(type: String, heal_to_full: bool = false):
	if weapon:
		weapon.queue_free()
	
	type = _normalize_weapon_type(type)
	weapon_type = type
	_apply_weapon_stat_modifiers(heal_to_full)
	weapon = WeaponRegistryScript.create_weapon(type)
	
	add_child(weapon)
	weapon.setup(self)

func _apply_weapon_stat_modifiers(heal_to_full: bool):
	var final_config = WeaponRegistryScript.apply_stat_modifiers({
		"weapon_type": weapon_type,
		"max_hp": configured_max_hp,
		"mass": configured_mass,
	})
	max_hp = final_config.get("max_hp", configured_max_hp)
	mass = final_config.get("mass", configured_mass)
	if heal_to_full:
		current_hp = max_hp
	else:
		current_hp = min(current_hp, max_hp)
	_update_hp_label()

func _input_event(viewport, event, shape_idx):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_cycle_weapon()

func _cycle_weapon():
	var types = WeaponRegistryScript.get_weapon_names()
	var idx = types.find(weapon_type)
	if idx < 0:
		idx = 0
	idx = (idx + 1) % types.size()
	weapon_type = types[idx]
	_equip_weapon(weapon_type)
	_configure_labels()
#endregion

#region Physics
func _integrate_forces(state: PhysicsDirectBodyState2D):
	var touching_wall_now = false
	var contact_count = state.get_contact_count()
	for i in range(contact_count):
		var collider = state.get_contact_collider_object(i)
		if collider is StaticBody2D:
			touching_wall_now = true
			break
	if touching_wall_now and not is_touching_wall:
		wall_bounce_queued = true
	is_touching_wall = touching_wall_now

func _physics_process(delta):
	if not is_alive:
		return
	_update_status_effects(delta)
	_play_wall_contact_sfx()
	if freeze:
		return
	impact_fx_cooldown_timer = max(0.0, impact_fx_cooldown_timer - delta)
	if paralysis_timer > 0.0:
		paralysis_timer = max(0.0, paralysis_timer - delta)
		linear_velocity = Vector2.ZERO
		angular_velocity = 0.0
		speed_modifier = 0.0
		_apply_status_caps()
		queue_redraw()
		return
	
	if weapon:
		weapon.process_weapon(delta)
	
	var current_speed = linear_velocity.length()
	var target_base = 380.0 * speed_modifier
	
	if current_speed < target_base:
		var dir = linear_velocity.normalized()
		if dir == Vector2.ZERO:
			dir = Vector2.RIGHT.rotated(randf() * TAU)
		linear_velocity = dir * target_base
	elif speed_modifier < 1.0:
		linear_velocity = linear_velocity.lerp(linear_velocity.normalized() * target_base, delta * 5.0)
	
	# Evitar de ficar quicando em uma linha reta perfeita
	if linear_velocity.length() > 0.0:
		var dir = linear_velocity.normalized()
		if abs(dir.x) < 0.08 or abs(dir.y) < 0.08:
			linear_velocity = linear_velocity.rotated(delta * 2.5)
	
	# Atrair levemente para outras bolas. A busca completa é amortizada, mas a posição usada é sempre atual.
	target_scan_timer -= delta
	if target_scan_timer <= 0.0:
		target_scan_timer = target_scan_interval
		_refresh_pull_target()
	if is_instance_valid(pull_target) and pull_target.get("is_alive"):
		var offset = pull_target.global_position - global_position
		if offset.length_squared() > 1600.0:
			var pull_dir = offset.normalized()
			linear_velocity += pull_dir * (delta * 140.0)
	
	var active_speed_limit = speed_limit
	if speed_limit_override > 0.0:
		active_speed_limit = max(speed_limit, speed_limit_override)
	if linear_velocity.length() > active_speed_limit:
		linear_velocity = linear_velocity.normalized() * active_speed_limit
	
	speed_modifier = move_toward(speed_modifier, 1.0, delta * 1.5)
	_apply_status_caps()

func _play_wall_contact_sfx():
	if not bounce_sfx_player:
		return
	if not wall_bounce_queued:
		return
	wall_bounce_queued = false
	bounce_sfx_player.pitch_scale = randf_range(0.98, 1.02)
	bounce_sfx_player.play()

func _refresh_pull_target():
	pull_target = null
	if not is_inside_tree():
		return
	
	var closest_dist_sq = INF
	var owner_pos = global_position
	for child in get_tree().get_nodes_in_group("balls"):
		if child == self:
			continue
		if not child.has_method("take_damage"):
			continue
		if not child.get("is_alive"):
			continue
		if not is_enemy(child):
			continue
		var dist_sq = owner_pos.distance_squared_to(child.global_position)
		if dist_sq < closest_dist_sq:
			closest_dist_sq = dist_sq
			pull_target = child
#endregion

#region Drawing
func _draw():
	var body_scale = 1.0
	draw_circle(Vector2(3, 5) * body_scale, 34.0 * body_scale, Color(0, 0, 0, 0.28))
	draw_circle(Vector2.ZERO, 33.0 * body_scale, ball_color.darkened(0.18))
	draw_circle(Vector2.ZERO, 29.0 * body_scale, ball_color)
	if hit_flash_alpha > 0.0:
		draw_circle(Vector2.ZERO, 29.0 * body_scale, Color(1.0, 1.0, 1.0, hit_flash_alpha))
	
	var rim_color = Color(1.0, 1.0, 1.0, 0.92)
	if is_invulnerable:
		rim_color = Color(1.0, 0.82, 0.22, 1.0)
	
	# Team Indicator
	if team_id > 0:
		var team_colors = [
			Color(0.2, 0.5, 1.0), # Team 1
			Color(1.0, 0.2, 0.2), # Team 2
			Color(0.2, 0.8, 0.2), # Team 3
			Color(1.0, 1.0, 0.2), # Team 4
		]
		var team_color = team_colors[(team_id - 1) % team_colors.size()]
		draw_arc(Vector2.ZERO, 38.0 * body_scale, 0, TAU, 48, team_color, 4.0 * body_scale)
		draw_arc(Vector2.ZERO, 38.0 * body_scale, 0, TAU, 48, Color.WHITE, 1.0 * body_scale)
	
	draw_arc(Vector2.ZERO, 33.0 * body_scale, 0, TAU, 48, rim_color, 2.8 * body_scale)
	if paralysis_timer > 0.0:
		var stun_alpha = 0.55 + sin(Time.get_ticks_msec() * 0.018) * 0.22
		draw_arc(Vector2.ZERO, 39.0 * body_scale, 0, TAU, 36, Color(0.95, 0.92, 1.0, stun_alpha), 3.0 * body_scale)
		draw_line(Vector2(-15, -39) * body_scale, Vector2(15, -39) * body_scale, Color(0.78, 0.66, 1.0, stun_alpha), 3.0 * body_scale)
	var slow_visual = _get_slow_visual_data()
	if bool(slow_visual.get("active", false)):
		_draw_slow_visual(slow_visual, body_scale)
	draw_arc(Vector2.ZERO, 24.0 * body_scale, -PI * 0.25, PI * 0.15, 18, Color(1, 1, 1, 0.16), 5.0 * body_scale)

func _draw_slow_visual(slow_visual: Dictionary, body_scale: float):
	var slow_color: Color = slow_visual.get("color", Color(0.55, 0.85, 1.0, 0.78))
	var slow_strength = clamp(float(slow_visual.get("strength", 0.4)), 0.0, 1.0)
	if slow_fx_texture:
		_draw_slow_texture_drips(slow_color, slow_strength, body_scale)
	else:
		_draw_slow_ring_fallback(slow_color, slow_strength, body_scale)

func _draw_slow_texture_drips(slow_color: Color, slow_strength: float, body_scale: float):
	var tex_size = slow_fx_texture.get_size()
	var longest_side = max(tex_size.x, tex_size.y)
	var time = Time.get_ticks_msec() * 0.001
	var ball_radius = 29.0
	var drip_count = 8
	for i in range(drip_count):
		var seed = _slow_fx_seed(i, 0.0)
		var speed = 0.58 + _slow_fx_seed(i, 4.1) * 0.56
		var cycle = fposmod(time * speed + float(i) * 0.17, 1.0)
		var y = lerp(-ball_radius * 0.92, ball_radius * 0.96, cycle)
		var max_x = sqrt(max(ball_radius * ball_radius - y * y, 0.0))
		var x = lerp(-max_x, max_x, seed)
		x += sin(time * 1.9 + float(i) * 1.7) * 2.5
		x = clamp(x, -max_x, max_x)
		
		var fade = sin(cycle * PI)
		var alpha = clamp(fade * (0.38 + slow_strength * 0.36), 0.0, 0.86)
		var target_size = lerp(10.0, 18.0, _slow_fx_seed(i, 8.3)) * (0.9 + slow_strength * 0.25)
		var tex_scale = (target_size * body_scale) / max(longest_side, 1.0)
		var stretch = 1.0 + cycle * 0.45
		var pos = Vector2(x, y) * body_scale
		var tilt = sin(time * 1.4 + float(i)) * 0.12
		
		draw_circle(pos + Vector2(0.0, target_size * 0.25) * body_scale, target_size * 0.28 * body_scale, Color(slow_color, alpha * 0.18))
		draw_set_transform(pos, tilt, Vector2(tex_scale * 0.95, tex_scale * stretch))
		draw_texture_rect(slow_fx_texture, Rect2(-tex_size / 2.0, tex_size), false, Color(1.0, 1.0, 1.0, alpha))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_slow_ring_fallback(slow_color: Color, slow_strength: float, body_scale: float):
	var pulse = 0.5 + sin(Time.get_ticks_msec() * 0.012) * 0.5
	slow_color.a = clamp(0.26 + slow_strength * 0.28 + pulse * 0.12, 0.0, 0.86)
	var orbit = Time.get_ticks_msec() * 0.002
	draw_arc(Vector2.ZERO, 42.0 * body_scale, orbit, orbit + TAU, 44, slow_color, 3.0 * body_scale)
	draw_arc(Vector2.ZERO, 47.0 * body_scale, -orbit * 1.2, -orbit * 1.2 + TAU, 36, Color(slow_color, slow_color.a * 0.45), 1.6 * body_scale)
	for i in range(3):
		var angle = orbit + float(i) * TAU / 3.0
		var center = Vector2(cos(angle), sin(angle)) * 36.0 * body_scale
		var tangent = Vector2(cos(angle + PI * 0.5), sin(angle + PI * 0.5))
		draw_line(center - tangent * 5.0 * body_scale, center + tangent * 5.0 * body_scale, Color(slow_color, slow_color.a * 0.9), 2.0 * body_scale)

func _slow_fx_seed(index: int, salt: float) -> float:
	return fposmod(sin(float(index) * 12.9898 + salt) * 43758.5453, 1.0)
#endregion

#region Status Effects
func apply_paralysis(duration: float):
	paralysis_timer = max(paralysis_timer, duration)
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	speed_modifier = 0.0
	queue_redraw()

func apply_status_effect(effect_id: String, duration: float, options: Dictionary) -> String:
	var key = effect_id.strip_edges()
	if key == "":
		status_effect_serial += 1
		key = "effect_%d" % status_effect_serial
	if status_effects.has(key):
		var existing_effect: Dictionary = status_effects[key]
		if _status_options_match(existing_effect, options):
			existing_effect["duration"] = max(duration, 0.0)
			status_effects[key] = existing_effect
			return key
	var effect = options.duplicate(true)
	effect["duration"] = max(duration, 0.0)
	status_effects[key] = effect
	_refresh_status_effects()
	return key

func clear_status_effect(effect_id: String):
	if status_effects.has(effect_id):
		status_effects.erase(effect_id)
		_refresh_status_effects()

func _status_options_match(effect: Dictionary, options: Dictionary) -> bool:
	for option_key in options.keys():
		if not effect.has(option_key):
			return false
		if effect[option_key] != options[option_key]:
			return false
	for effect_key in effect.keys():
		if String(effect_key) == "duration":
			continue
		if not options.has(effect_key):
			return false
	return true

func heal(amount: float):
	if amount <= 0.0 or not is_alive:
		return
	current_hp = min(current_hp + amount, max_hp)
	_update_hp_label()
	queue_redraw()

func _update_status_effects(delta: float):
	if status_effects.is_empty():
		return
	var changed = false
	for key in status_effects.keys():
		var effect = status_effects[key]
		effect["duration"] = float(effect.get("duration", 0.0)) - delta
		if effect["duration"] <= 0.0:
			status_effects.erase(key)
			changed = true
		else:
			status_effects[key] = effect
	if changed:
		_refresh_status_effects()
	else:
		_apply_status_caps()

func _refresh_status_effects():
	var has_speed_cap = false
	var speed_cap = 1.0
	var has_gravity_override = false
	var next_gravity = base_gravity_scale
	var next_invulnerable = false
	var next_speed_limit_override = 0.0
	
	for effect in status_effects.values():
		if effect.has("speed_cap"):
			has_speed_cap = true
			speed_cap = min(speed_cap, float(effect["speed_cap"]))
		if effect.has("gravity_scale"):
			var effect_gravity = float(effect["gravity_scale"])
			next_gravity = effect_gravity if not has_gravity_override else min(next_gravity, effect_gravity)
			has_gravity_override = true
		if effect.get("invulnerable", false):
			next_invulnerable = true
		if effect.has("speed_limit_override"):
			next_speed_limit_override = max(next_speed_limit_override, float(effect["speed_limit_override"]))
	
	gravity_scale = next_gravity if has_gravity_override else base_gravity_scale
	is_invulnerable = next_invulnerable
	speed_limit_override = next_speed_limit_override
	if has_speed_cap:
		speed_modifier = min(speed_modifier, speed_cap)
	queue_redraw()

func _apply_status_caps():
	if status_effects.is_empty():
		return
	var speed_cap = 1.0
	var has_speed_cap = false
	for effect in status_effects.values():
		if effect.has("speed_cap"):
			has_speed_cap = true
			speed_cap = min(speed_cap, float(effect["speed_cap"]))
	if has_speed_cap:
		speed_modifier = min(speed_modifier, speed_cap)
		queue_redraw()

func _get_slow_visual_data() -> Dictionary:
	var active = false
	var speed_cap = 1.0
	var visual_color = Color(0.55, 0.85, 1.0, 0.78)
	for effect in status_effects.values():
		if effect.has("speed_cap"):
			var cap = float(effect["speed_cap"])
			if cap < 0.999:
				active = true
				speed_cap = min(speed_cap, cap)
				if String(effect.get("visual", "")) == "slow" and effect.has("visual_color"):
					visual_color = effect["visual_color"]
	if not active:
		return {"active": false}
	return {
		"active": true,
		"strength": 1.0 - speed_cap,
		"color": visual_color,
	}
#endregion

#region Combat
func take_damage(amount: float, source = null):
	if not is_alive: return
	if is_invulnerable: return
	if amount <= 0.0: return
	# Guard: source may be a freed node when the attacker dies mid-frame
	if source != null and not is_instance_valid(source): return
	if source != null and source.has_method("is_enemy") and not source.is_enemy(self): return
	
	var incoming_damage = amount
	if weapon:
		incoming_damage = weapon.modify_incoming_damage(incoming_damage, source)
	if incoming_damage <= 0.0:
		queue_redraw()
		return
	
	var hp_before = current_hp
	current_hp -= incoming_damage
	if source != null and is_instance_valid(source) and source != self:
		last_damage_source = source
	if weapon:
		weapon.on_owner_damaged(incoming_damage, source)
	
	current_hp = clamp(current_hp, 0, max_hp)
	var actual_damage = max(0.0, hp_before - current_hp)
	
	_update_hp_label()
	
	if impact_fx_cooldown_timer <= 0.0:
		_spawn_impact_particles()
		impact_fx_cooldown_timer = impact_fx_cooldown
	_spawn_damage_popup(actual_damage)
	queue_redraw()
	
	if current_hp <= 0:
		_notify_attacker_of_elimination(source)
		die()
		return
	
	hit_flash_alpha = max(hit_flash_alpha, 0.55)
	hit_flash_timer = hit_flash_duration
	queue_redraw()

func die():
	if not is_alive:
		return
	is_alive = false
	_spawn_death_particles()
	emit_signal("died", self)
	queue_free()

func _notify_attacker_of_elimination(source):
	if source == null or not is_instance_valid(source):
		return
	var attacker_weapon = null
	for property in source.get_property_list():
		if property.has("name") and property["name"] == "weapon":
			attacker_weapon = source.get("weapon")
			break
	if attacker_weapon == null or not is_instance_valid(attacker_weapon):
		return
	if attacker_weapon.has_method("on_owner_eliminated_target"):
		attacker_weapon.on_owner_eliminated_target(self)

func get_last_damage_source() -> Node:
	if last_damage_source and is_instance_valid(last_damage_source):
		return last_damage_source
	return null

func _spawn_impact_particles():
	var parent = get_parent()
	if not parent: return
	var fx_scale = _short_video_fx_scale()
	
	var particles = CPUParticles2D.new()
	particles.emitting = true
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = 6
	particles.lifetime = 0.25
	particles.direction = Vector2.ZERO
	particles.spread = 180.0
	particles.initial_velocity_min = 30.0
	particles.initial_velocity_max = 80.0
	particles.gravity = Vector2.ZERO
	particles.scale_amount_min = 2.0 * fx_scale
	particles.scale_amount_max = 4.0 * fx_scale
	particles.color = original_color.lightened(0.3)
	particles.global_position = global_position
	parent.add_child(particles)
	get_tree().create_timer(0.8).timeout.connect(func():
		if is_instance_valid(particles): particles.queue_free()
	)

func _spawn_death_particles():
	var parent = get_parent()
	if not parent: return
	var fx_scale = _short_video_fx_scale()
	
	var particles = CPUParticles2D.new()
	particles.emitting = true
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = 20
	particles.lifetime = 0.6
	particles.direction = Vector2.ZERO
	particles.spread = 180.0
	particles.initial_velocity_min = 60.0
	particles.initial_velocity_max = 180.0
	particles.gravity = Vector2.ZERO
	particles.scale_amount_min = 3.0 * fx_scale
	particles.scale_amount_max = 7.0 * fx_scale
	particles.color = original_color
	particles.global_position = global_position
	parent.add_child(particles)
	get_tree().create_timer(1.5).timeout.connect(func():
		if is_instance_valid(particles): particles.queue_free()
	)
#endregion

#region Utilities
func _short_video_fx_scale() -> float:
	var scene = get_tree().current_scene
	if scene and scene.has_method("get_short_video_fx_scale"):
		return float(scene.get_short_video_fx_scale())
	return 1.0

func _process(delta):
	if hit_flash_timer > 0.0:
		hit_flash_timer = max(0.0, hit_flash_timer - delta)
		if hit_flash_timer <= 0.0 and hit_flash_alpha > 0.0:
			hit_flash_alpha = 0.0
			queue_redraw()

func _configure_labels():
	var label_scale = 1.0
	if hp_label:
		hp_label.text = str(int(current_hp))
		hp_label.add_theme_font_size_override("font_size", int(round(22.0 * label_scale)))
		hp_label.add_theme_color_override("font_color", Color.WHITE)
		hp_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		hp_label.add_theme_constant_override("outline_size", int(round(5.0 * label_scale)))
		hp_label.position = Vector2(-40, -18) * label_scale
		hp_label.size = Vector2(80, 36) * label_scale
		hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if label:
		label.text = display_name
		label.add_theme_font_size_override("font_size", int(round(11.0 * label_scale)))
		label.add_theme_color_override("font_color", Color(0.88, 0.92, 1.0))
		label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.82))
		label.add_theme_constant_override("outline_size", max(2, int(round(2.0 * label_scale))))
		label.position = Vector2(-40, 35) * label_scale
		label.size = Vector2(80, 23) * label_scale

func _normalize_weapon_type(type_name: String) -> String:
	return WeaponRegistryScript.normalize(type_name)

func _update_hp_label():
	if hp_label:
		hp_label.text = str(int(current_hp))

func _spawn_damage_popup(amount: float):
	if amount < 1.0: return
	var parent = get_parent()
	if not parent: return
	var is_critical = amount >= max(8.0, max_hp * 0.22)
	
	var popup = Label.new()
	popup.text = "-%d" % int(round(amount))
	popup.add_theme_font_size_override("font_size", 14)
	popup.add_theme_color_override("font_color", Color(1.0, 0.42, 0.34) if is_critical else Color(1.0, 0.9, 0.65))
	popup.add_theme_color_override("font_outline_color", Color(0.28, 0.04, 0.02, 0.95) if is_critical else Color(0.12, 0.03, 0.02, 0.9))
	popup.add_theme_constant_override("outline_size", 2)
	popup.global_position = global_position + Vector2(randf_range(-12, 12), -50)
	parent.add_child(popup)
	
	var tween = popup.create_tween()
	tween.set_parallel(true)
	tween.tween_property(popup, "global_position", popup.global_position + Vector2(0, -30), 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(popup, "modulate", Color(1, 1, 1, 0), 0.45)
	tween.finished.connect(func():
		if is_instance_valid(popup): popup.queue_free()
	)

func is_enemy(other: Node) -> bool:
	if not is_instance_valid(other): return false
	if other == self: return false
	if not other.has_method("is_enemy"): return false
	var other_team = other.get("team_id")
	if team_id == 0 or other_team == 0: return true
	return team_id != other_team
#endregion
