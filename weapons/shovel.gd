# Shovel (Pá) weapon - combo dash attacker with life-steal special.
# Stops to aim before the first big dash. Follow-up dashes only trigger if close.
# After a set number of hits, fires a life-steal projectile.
# Wears a dapper top hat.
class_name WeaponShovel extends WeaponBase

const SPECIAL_PROJECTILE_OUTLINE_DIRECTIONS = [
	Vector2(-1.0, 0.0),
	Vector2(1.0, 0.0),
	Vector2(0.0, -1.0),
	Vector2(0.0, 1.0),
	Vector2(-1.0, -1.0),
	Vector2(1.0, -1.0),
	Vector2(-1.0, 1.0),
	Vector2(1.0, 1.0),
]

const PA_ATTACK_SFX_STREAM = preload("res://sfx/pa_atk_01.ogg")
const PA_ULT_SFX_STREAM = preload("res://sfx/pa_ulti_01.ogg")
const PA_KILL_VOICE_STREAMS = [
	preload("res://sfx/voices/pa/mortis_kill_01.ogg"),
	preload("res://sfx/voices/pa/mortis_kill_02.ogg"),
	preload("res://sfx/voices/pa/mortis_kill_03.ogg"),
	preload("res://sfx/voices/pa/mortis_kill_04.ogg"),
	preload("res://sfx/voices/pa/mortis_kill_05.ogg"),
]
const PA_ULT_VOICE_STREAMS = [
	preload("res://sfx/voices/pa/mortis_ulti_vo_01.ogg"),
	preload("res://sfx/voices/pa/mortis_ulti_vo_02.ogg"),
	preload("res://sfx/voices/pa/mortis_ulti_vo_03.ogg"),
]

# ==============================================================
# >>>  EDITABLE VALUES  <<<
# ==============================================================
var max_combo: int = 3                 # Number of dashes per combo
var combo_interval: float = 0.3        # Delay between dashes (seconds)
var charge_recharge_time: float = 1.5  # Rest per used dash (seconds)
var first_dash_force: float = 1220.0   # Force of 1st dash (bigger)
var normal_dash_force: float = 760.0   # Force of 2nd/3rd dashes
var base_damage: float = 27.0         # Damage per dash hit
var close_range: float = 400.0        # Max distance to continue combo

# --- Aiming ---
var aim_duration: float = 0.3          # How long to stop and aim before big dash

# ==============================================================
# >>>  EDITABLE ASSETS (Optional)  <<<
# ==============================================================
@export var custom_weapon_texture: Texture2D = null
@export var custom_super_texture: Texture2D = null
# ==============================================================

# --- Life Steal Special ---
var hits_for_special: int = 3          # Hits needed to trigger special
var lifesteal_percent: float = 0.50    # % of damage healed back (0.15 = 15%)
var special_damage: float = 7.0        # Damage of the life-steal projectile
var special_proj_speed: float = 500.0  # Speed of the special projectile
var special_projectile_count: int = 3
var special_projectile_hit_radius: float = 30.0
var special_projectile_visual_size: float = 48.0
var special_projectile_lane_spacing: float = 20.0
var special_projectile_hover: float = 13.0
var special_projectile_launch_interval: float = 0.08
var special_projectile_min_range: float = 380.0
var special_projectile_max_range: float = 720.0
var special_projectile_pierce_distance: float = 180.0
var special_projectile_outline_size: float = 2.0
var special_projectile_glow_color: Color = Color(0.55, 0.95, 1.0, 0.58)
var kill_voice_cooldown: float = 1.4
# ==============================================================

# --- Internal State ---
var combo_index: int = 0
var combo_timer: float = 0.0
var cooldown_timer: float = 0.0
var aim_timer: float = 0.0
var aim_target: Node = null
var active_dash_target: Node = null
# States: "ready", "aiming", "dashing", "combo_wait", "cooldown"
var state: String = "ready"
var dash_duration: float = 0.24
var dash_timer: float = 0.0
var total_hits: int = 0
var followup_dash_confirm_range: float = 190.0
var followup_dash_confirm_angle_degrees: float = 34.0
var dash_retarget_window: float = 0.09
var dash_retarget_strength: float = 0.32

# --- Hitbox ---
var shovel_area: Area2D = null
var hit_targets: Dictionary = {}
var orbit_angle: float = 0.0
var orbit_speed: float = 3.0

# --- Trail ---
var trail_points: Array = []

# --- Visual ---
var aim_line_alpha: float = 0.0       # For pulsing aim line
var active_special_projectiles: Array = []
var attack_sfx_player: AudioStreamPlayer2D = null
var ult_sfx_player: AudioStreamPlayer2D = null
var kill_voice_player: AudioStreamPlayer2D = null
var ult_voice_player: AudioStreamPlayer2D = null
var kill_voice_cooldown_timer: float = 0.0
var dash_swing_timer: float = 0.0
var dash_swing_duration: float = 0.26
var dash_swing_angle: float = 0.0
var dash_swing_is_first: bool = false
var weapon_texture_size: Vector2 = Vector2.ZERO
var super_texture_size: Vector2 = Vector2.ZERO
var super_texture_longest_side: float = 1.0

var projectile_scene: PackedScene = preload("res://Projectile.tscn")

func setup(owner: Node):
	super.setup(owner)
	_setup_sfx_players()
	_setup_voice_players()
	weapon_name = "Pá"
	
	if custom_weapon_texture == null and ResourceLoader.exists("res://weapons/texturas/pa.png"):
		custom_weapon_texture = load("res://weapons/texturas/pa.png")
	if custom_super_texture == null and ResourceLoader.exists("res://weapons/texturas/pa_super.png"):
		custom_super_texture = load("res://weapons/texturas/pa_super.png")
	_refresh_texture_cache()
		
	orbit_angle = randf() * TAU
	
	shovel_area = Area2D.new()
	shovel_area.collision_layer = 0
	shovel_area.collision_mask = 1
	
	var shape = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = Vector2(54, 38)
	shape.shape = rect
	shovel_area.add_child(shape)
	
	shovel_area.body_entered.connect(_on_shovel_hit)
	
	add_child(shovel_area)

func _refresh_texture_cache():
	weapon_texture_size = custom_weapon_texture.get_size() if custom_weapon_texture else Vector2.ZERO
	super_texture_size = custom_super_texture.get_size() if custom_super_texture else Vector2.ZERO
	super_texture_longest_side = max(max(super_texture_size.x, super_texture_size.y), 1.0)

func _setup_sfx_players():
	if attack_sfx_player and is_instance_valid(attack_sfx_player):
		return
	attack_sfx_player = AudioStreamPlayer2D.new()
	attack_sfx_player.stream = PA_ATTACK_SFX_STREAM
	attack_sfx_player.volume_db = -3.0
	add_child(attack_sfx_player)
	
	ult_sfx_player = AudioStreamPlayer2D.new()
	ult_sfx_player.stream = PA_ULT_SFX_STREAM
	ult_sfx_player.volume_db = -2.0
	add_child(ult_sfx_player)

func _play_attack_sfx():
	if not attack_sfx_player:
		return
	attack_sfx_player.pitch_scale = randf_range(0.96, 1.04)
	attack_sfx_player.play()

func _play_ult_sfx():
	if not ult_sfx_player:
		return
	ult_sfx_player.pitch_scale = randf_range(0.98, 1.03)
	ult_sfx_player.play()

func _setup_voice_players():
	if kill_voice_player and is_instance_valid(kill_voice_player):
		return
	kill_voice_player = AudioStreamPlayer2D.new()
	kill_voice_player.volume_db = -1.0
	add_child(kill_voice_player)

	ult_voice_player = AudioStreamPlayer2D.new()
	ult_voice_player.volume_db = -2.0
	add_child(ult_voice_player)

func _play_random_voice(player: AudioStreamPlayer2D, voice_streams: Array):
	if not player or voice_streams.is_empty():
		return
	player.stream = voice_streams[randi() % voice_streams.size()]
	player.pitch_scale = randf_range(0.98, 1.02)
	player.play()

func _play_kill_voice():
	_play_random_voice(kill_voice_player, PA_KILL_VOICE_STREAMS)

func _play_ult_voice():
	_play_random_voice(ult_voice_player, PA_ULT_VOICE_STREAMS)

func _on_shovel_hit(body: Node):
	if body == owner_ball: return
	if not owner_ball.is_alive: return
	if state != "dashing": return
	if owner_ball.has_method("is_enemy") and not owner_ball.is_enemy(body): return
	if body.has_method("take_damage") and body.is_alive:
		if hit_targets.has(body): return
		hit_targets[body] = true
		body.take_damage(base_damage, owner_ball)
		total_hits += 1
		
		if total_hits >= hits_for_special:
			total_hits = 0
			_fire_special()

func process_weapon(delta: float):
	kill_voice_cooldown_timer = max(0.0, kill_voice_cooldown_timer - delta)
	dash_swing_timer = max(0.0, dash_swing_timer - delta)
	match state:
		"ready":
			_state_ready(delta)
		"aiming":
			_state_aiming(delta)
		"dashing":
			_state_dashing(delta)
		"combo_wait":
			_state_combo_wait(delta)
		"cooldown":
			_state_cooldown(delta)
	
	_process_special_projectiles(delta)
	
	# Orbit when idle
	if state != "dashing" and state != "aiming":
		orbit_angle += orbit_speed * delta
	
	# Update hitbox position and rotation
	if shovel_area:
		var hb_pos = Vector2(cos(orbit_angle), sin(orbit_angle)) * 48.0
		shovel_area.position = hb_pos
		shovel_area.rotation = orbit_angle
	
	# Record trail during dash
	if state == "dashing" and owner_ball and owner_ball.is_inside_tree():
		var trail_color = Color(1.0, 0.15, 0.1, 1.0) if combo_index == 0 else Color(0.15, 0.5, 1.0, 1.0)
		var max_life = 0.6 if combo_index == 0 else 0.3
		trail_points.append({
			"pos": owner_ball.global_position,
			"color": trail_color,
			"life": max_life,
			"max_life": max_life,
			"size": 10.0 if combo_index == 0 else 6.0,
		})
	
	# Decay trail
	var i = trail_points.size() - 1
	while i >= 0:
		trail_points[i].life -= delta
		if trail_points[i].life <= 0:
			trail_points.remove_at(i)
		i -= 1
	
	# Aim line pulse
	if state == "aiming":
		aim_line_alpha = 0.5 + sin(aim_timer * 15.0) * 0.4
	
	queue_redraw()

func _state_ready(delta: float):
	var target = _find_nearest_target()
	if target:
		combo_index = 0
		aim_target = target
		aim_timer = aim_duration
		state = "aiming"
		# STOP the ball completely to aim
		if owner_ball is RigidBody2D:
			owner_ball.linear_velocity = Vector2.ZERO
		# Point shovel at target
		var dir = (target.global_position - owner_ball.global_position).normalized()
		orbit_angle = dir.angle()
		
		# Leve zoom na camera
		var main = _get_main_node()
		if main and main.has_method("apply_temporary_zoom"):
			main.apply_temporary_zoom(1.15, aim_duration)

func _state_aiming(delta: float):
	# Keep ball still while aiming
	if owner_ball is RigidBody2D:
		owner_ball.linear_velocity = Vector2.ZERO
	
	# Keep pointing at the target if it moves
	if is_instance_valid(aim_target) and aim_target.is_alive:
		var dir = (aim_target.global_position - owner_ball.global_position).normalized()
		orbit_angle = dir.angle()
	
	aim_timer -= delta
	if aim_timer <= 0:
		if is_instance_valid(aim_target) and aim_target.is_alive:
			_start_dash(aim_target)
		else:
			state = "ready"
			aim_target = null
			
			# Reset zoom if aim cancelled
			var main = _get_main_node()
			if main and main.has_method("reset_zoom"):
				main.reset_zoom(0.2)

func _state_dashing(delta: float):
	_update_dash_retargeting()
	dash_timer -= delta
	if dash_timer <= 0:
		active_dash_target = null
		if combo_index == 0:
			var main = _get_main_node()
			if main and main.has_method("reset_zoom"):
				main.reset_zoom(0.18)
		hit_targets.clear()
		combo_index += 1
		if combo_index >= max_combo:
			state = "cooldown"
			cooldown_timer = combo_index * charge_recharge_time
		else:
			# Only continue combo if a target is close enough
			var target = _find_nearest_target()
			if target:
				var dist_sq = owner_ball.global_position.distance_squared_to(target.global_position)
				if dist_sq <= close_range * close_range:
					state = "combo_wait"
					combo_timer = combo_interval
				else:
					# Too far, go to cooldown and wait for next big dash
					state = "cooldown"
					cooldown_timer = combo_index * charge_recharge_time
			else:
				state = "cooldown"
				cooldown_timer = combo_index * charge_recharge_time

func _state_combo_wait(delta: float):
	combo_timer -= delta
	if combo_timer <= 0:
		var target = _find_nearest_target()
		if target:
			if _should_commit_followup_dash(target):
				_start_dash(target)
			else:
				state = "cooldown"
				cooldown_timer = combo_index * charge_recharge_time
		else:
			state = "cooldown"
			cooldown_timer = combo_index * charge_recharge_time

func _should_commit_followup_dash(target: Node) -> bool:
	if not is_instance_valid(owner_ball) or not _is_valid_enemy(target):
		return false
	var to_target = target.global_position - owner_ball.global_position
	var dist_sq = to_target.length_squared()
	if dist_sq > close_range * close_range:
		return false
	if dist_sq > followup_dash_confirm_range * followup_dash_confirm_range:
		return false
	var forward = Vector2(cos(orbit_angle), sin(orbit_angle))
	if forward == Vector2.ZERO:
		return false
	var target_dir = to_target.normalized()
	var min_dot = cos(deg_to_rad(followup_dash_confirm_angle_degrees))
	return forward.dot(target_dir) >= min_dot

func _update_dash_retargeting():
	if dash_timer <= 0.0:
		return
	if dash_duration <= 0.0:
		return
	var elapsed = dash_duration - dash_timer
	if elapsed > dash_retarget_window:
		return
	if not is_instance_valid(owner_ball) or not (owner_ball is RigidBody2D):
		return
	if not _is_valid_enemy(active_dash_target):
		return
	var desired_dir = (active_dash_target.global_position - owner_ball.global_position).normalized()
	if desired_dir == Vector2.ZERO:
		return
	var current_vel: Vector2 = owner_ball.linear_velocity
	var current_speed = current_vel.length()
	if current_speed <= 0.0:
		return
	var current_dir = current_vel / current_speed
	var new_dir = current_dir.slerp(desired_dir, clamp(dash_retarget_strength, 0.0, 1.0)).normalized()
	owner_ball.linear_velocity = new_dir * current_speed
	orbit_angle = new_dir.angle()

func _state_cooldown(delta: float):
	cooldown_timer -= delta
	if cooldown_timer <= 0:
		state = "ready"

func _start_dash(target: Node):
	state = "dashing"
	dash_timer = dash_duration
	hit_targets.clear()
	aim_target = null
	active_dash_target = target
	_play_attack_sfx()
	
	# Zoom pulse on the first dash, including the 9:16 camera when active.
	var main = _get_main_node()
	if main:
		if combo_index == 0 and main.has_method("apply_temporary_zoom"):
			main.apply_temporary_zoom(1.35, 0.08)
		elif main.has_method("reset_zoom"):
			main.reset_zoom(0.15)
	
	var dir = (target.global_position - owner_ball.global_position).normalized()
	var force = first_dash_force if combo_index == 0 else normal_dash_force
	
	orbit_angle = dir.angle()
	dash_swing_angle = orbit_angle
	dash_swing_timer = dash_swing_duration
	dash_swing_is_first = combo_index == 0
	
	if owner_ball is RigidBody2D:
		owner_ball.linear_velocity = dir * force * 0.5
		owner_ball.apply_central_impulse(dir * force * owner_ball.mass)

func _fire_special():
	var target = _find_nearest_target()
	if not target: return
	_play_ult_sfx()
	_play_ult_voice()

	var start_pos = owner_ball.global_position
	var target_offset = target.global_position - start_pos
	if target_offset.length_squared() <= 0.01:
		target_offset = Vector2.RIGHT.rotated(randf() * TAU)
	var dir = target_offset.normalized()
	var travel_distance = clamp(target_offset.length() + special_projectile_pierce_distance, special_projectile_min_range, special_projectile_max_range)
	var end_pos = start_pos + dir * travel_distance
	var count = max(special_projectile_count, 1)
	var middle = float(count - 1) * 0.5
	for i in range(count):
		var lane = float(i) - middle
		active_special_projectiles.append({
			"start_pos": start_pos,
			"end_pos": end_pos,
			"pos": start_pos,
			"last_pos": start_pos,
			"progress": 0.0,
			"phase": "out",
			"delay": float(i) * special_projectile_launch_interval,
			"lane": lane,
			"age": 0.0,
			"angle": (end_pos - start_pos).angle(),
			"target_id": target.get_instance_id(),
			"phase_hits": {},
		})
	
	_spawn_special_particles()

func on_owner_eliminated_target(target: Node):
	if kill_voice_cooldown_timer > 0.0:
		return
	kill_voice_cooldown_timer = kill_voice_cooldown
	if ult_voice_player and ult_voice_player.playing:
		ult_voice_player.stop()
	_play_kill_voice()

func _process_special_projectiles(delta: float):
	var i = active_special_projectiles.size() - 1
	while i >= 0:
		var bat = active_special_projectiles[i]
		bat["age"] = float(bat.get("age", 0.0)) + delta
		var delay = float(bat.get("delay", 0.0))
		if delay > 0.0:
			bat["delay"] = delay - delta
			active_special_projectiles[i] = bat
			i -= 1
			continue
		
		var start_pos: Vector2 = bat["start_pos"]
		var end_pos: Vector2 = bat["end_pos"]
		var phase = String(bat.get("phase", "out"))
		var hit_phase = phase
		var return_pos = _get_special_projectile_home_position(bat)
		var current_path_start = return_pos if phase == "return" else start_pos
		var path_len = max(current_path_start.distance_to(end_pos), 80.0)
		var step = (special_proj_speed / path_len) * delta
		var progress = float(bat.get("progress", 0.0))
		
		if phase == "out":
			progress = min(progress + step, 1.0)
			if progress >= 1.0:
				phase = "return"
		else:
			progress = max(progress - step, 0.0)
		
		bat["phase"] = phase
		bat["progress"] = progress
		var last_pos: Vector2 = bat.get("pos", start_pos)
		var current_pos = _get_special_projectile_position(bat)
		bat["last_pos"] = last_pos
		bat["pos"] = current_pos
		var move_dir = current_pos - last_pos
		if move_dir.length_squared() > 0.01:
			bat["angle"] = move_dir.angle()
		
		_check_special_projectile_hits(bat, last_pos, current_pos, hit_phase)
		
		if phase == "return" and progress <= 0.0:
			active_special_projectiles.remove_at(i)
		else:
			active_special_projectiles[i] = bat
		i -= 1

func _get_special_projectile_position(bat: Dictionary) -> Vector2:
	var start_pos: Vector2 = bat["start_pos"]
	var end_pos: Vector2 = bat["end_pos"]
	var progress = clamp(float(bat.get("progress", 0.0)), 0.0, 1.0)
	var phase = String(bat.get("phase", "out"))
	var home_pos = _get_special_projectile_home_position(bat)
	var base_pos = home_pos.lerp(end_pos, progress) if phase == "return" else start_pos.lerp(end_pos, progress)
	var path_dir = end_pos - home_pos if phase == "return" else end_pos - start_pos
	if path_dir.length_squared() <= 0.01:
		path_dir = Vector2.RIGHT
	var perp = path_dir.normalized().rotated(PI * 0.5)
	var arc = sin(progress * PI)
	var lane_offset = float(bat.get("lane", 0.0)) * special_projectile_lane_spacing * arc
	var glide_offset = sin(progress * TAU + float(bat.get("lane", 0.0)) * 0.85) * special_projectile_hover * arc
	return base_pos + perp * (lane_offset + glide_offset)

func _get_special_projectile_home_position(bat: Dictionary) -> Vector2:
	if is_instance_valid(owner_ball):
		return owner_ball.global_position
	return bat.get("start_pos", Vector2.ZERO)

func _check_special_projectile_hits(bat: Dictionary, from_pos: Vector2, to_pos: Vector2, phase: String):
	var radius_sq = special_projectile_hit_radius * special_projectile_hit_radius
	for child in _get_ball_candidates():
		if not _is_valid_enemy(child):
			continue
		var dist_sq = _distance_sq_to_segment(child.global_position, from_pos, to_pos)
		if dist_sq <= radius_sq:
			_hit_special_projectile_target(bat, child, phase, to_pos)

func _hit_special_projectile_target(bat: Dictionary, target: Node, phase: String, hit_pos: Vector2):
	if not is_instance_valid(target): return
	if not target.has_method("take_damage"): return
	var target_id = target.get_instance_id()
	var phase_key = "%s_%s" % [phase, str(target_id)]
	var phase_hits: Dictionary = bat.get("phase_hits", {})
	if phase_hits.has(phase_key):
		return
	phase_hits[phase_key] = true
	bat["phase_hits"] = phase_hits
	
	var hp_before = special_damage
	var can_read_hp = _has_node_property(target, "current_hp")
	if can_read_hp:
		hp_before = float(target.get("current_hp"))
	
	target.take_damage(special_damage, owner_ball)
	
	var actual_damage = special_damage
	if is_instance_valid(target) and can_read_hp:
		actual_damage = max(0.0, hp_before - float(target.get("current_hp")))
	if actual_damage <= 0.0:
		return
	
	_heal_owner(actual_damage * lifesteal_percent)
	_spawn_special_hit_particles(hit_pos, phase == "return")

func _distance_sq_to_segment(point: Vector2, a: Vector2, b: Vector2) -> float:
	var ab = b - a
	var len_sq = ab.length_squared()
	if len_sq <= 0.01:
		return point.distance_squared_to(a)
	var t = clamp((point - a).dot(ab) / len_sq, 0.0, 1.0)
	var closest = a + ab * t
	return point.distance_squared_to(closest)

func _spawn_special_hit_particles(hit_pos: Vector2, is_return_hit: bool):
	if not owner_ball or not owner_ball.is_inside_tree(): return
	var fx_scale = _short_video_fx_scale()
	var particles = CPUParticles2D.new()
	particles.emitting = true
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = 10 if is_return_hit else 6
	particles.lifetime = 0.36
	particles.direction = Vector2.ZERO
	particles.spread = 180.0
	particles.initial_velocity_min = 35.0
	particles.initial_velocity_max = 95.0
	particles.gravity = Vector2.ZERO
	particles.scale_amount_min = 2.0 * fx_scale
	particles.scale_amount_max = (5.5 if is_return_hit else 4.0) * fx_scale
	particles.color = Color(0.35, 1.0, 0.55, 0.85) if not is_return_hit else Color(0.75, 1.0, 0.45, 0.95)
	particles.global_position = hit_pos
	owner_ball.get_parent().add_child(particles)
	owner_ball.get_tree().create_timer(0.8).timeout.connect(func():
		if is_instance_valid(particles): particles.queue_free()
	)

func _spawn_special_particles():
	if not owner_ball or not owner_ball.is_inside_tree(): return
	var particles = CPUParticles2D.new()
	particles.emitting = true
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = 8
	particles.lifetime = 0.5
	particles.direction = Vector2.ZERO
	particles.spread = 180.0
	particles.initial_velocity_min = 50.0
	particles.initial_velocity_max = 120.0
	particles.gravity = Vector2.ZERO
	particles.scale_amount_min = 3.0
	particles.scale_amount_max = 6.0
	particles.color = Color(0.2, 1.0, 0.3, 0.8)
	particles.global_position = owner_ball.global_position
	owner_ball.get_parent().add_child(particles)
	owner_ball.get_tree().create_timer(1.0).timeout.connect(func():
		if is_instance_valid(particles): particles.queue_free()
	)

func _find_nearest_target() -> Node:
	return _find_nearest_enemy()

func _get_main_node() -> Node:
	if not owner_ball or not owner_ball.is_inside_tree(): return null
	return owner_ball.get_tree().root.get_node_or_null("Main")

func _draw():
	# ===== TOP HAT =====
	var hat_color = Color(0.12, 0.12, 0.14)
	var hat_band = Color(0.7, 0.15, 0.15)
	# Hat brim
	draw_line(Vector2(-18, -30), Vector2(18, -30), hat_color, 4.0)
	# Hat body
	var hat_body = PackedVector2Array([
		Vector2(-12, -30),
		Vector2(-12, -52),
		Vector2(12, -52),
		Vector2(12, -30),
	])
	draw_colored_polygon(hat_body, hat_color)
	# Hat top highlight
	draw_line(Vector2(-12, -52), Vector2(12, -52), Color(0.25, 0.25, 0.3), 2.0)
	# Hat band
	draw_line(Vector2(-12, -34), Vector2(12, -34), hat_band, 3.0)
	
	# ===== AIM LINE (while aiming) =====
	if state == "aiming" and is_instance_valid(aim_target) and aim_target.is_alive:
		var target_local = aim_target.global_position - owner_ball.global_position
		# Dashed aim line
		var line_dir = target_local.normalized()
		var line_len = target_local.length()
		var dash_len = 12.0
		var gap_len = 8.0
		var d = 40.0  # start from outside the ball
		while d < line_len:
			var seg_end = min(d + dash_len, line_len)
			draw_line(
				line_dir * d,
				line_dir * seg_end,
				Color(1.0, 0.3, 0.2, aim_line_alpha),
				2.0
			)
			d += dash_len + gap_len
		# Crosshair at target
		var cross_size = 8.0
		draw_line(target_local - Vector2(cross_size, 0), target_local + Vector2(cross_size, 0), Color(1, 0.3, 0.2, aim_line_alpha), 2.0)
		draw_line(target_local - Vector2(0, cross_size), target_local + Vector2(0, cross_size), Color(1, 0.3, 0.2, aim_line_alpha), 2.0)
		draw_arc(target_local, 10.0, 0, TAU, 16, Color(1, 0.3, 0.2, aim_line_alpha * 0.6), 1.5)
	
	_draw_dash_swing()
	
	# ===== SHOVEL WEAPON =====
	var dash_weapon_push = 0.0
	if state == "dashing":
		var dash_progress = 1.0 - clamp(dash_timer / max(dash_duration, 0.01), 0.0, 1.0)
		dash_weapon_push = sin(dash_progress * PI) * 12.0
	var pos = Vector2(cos(orbit_angle), sin(orbit_angle)) * (48.0 + dash_weapon_push)
	var dir_vec = pos.normalized()
	
	if custom_weapon_texture:
		# Pixel art usually points UP. Rotate by PI/2 so it points RIGHT (outward).
		# We also scale it by 2.0 or 2.5 to match the size of the procedural shovel.
		var scale_factor = 2.5
		draw_set_transform(pos, orbit_angle + PI/2, Vector2(scale_factor, scale_factor))
		# Offset by half size so it centers on 'pos'
		draw_texture_rect(custom_weapon_texture, Rect2(-weapon_texture_size/2, weapon_texture_size), false)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		# Handle
		var handle_start = pos - dir_vec * 22.0
		draw_line(handle_start, pos, Color(0.55, 0.35, 0.15), 3.5)
		
		# Shovel blade
		var perp = dir_vec.rotated(PI / 2) * 11.0
		var tip = pos + dir_vec * 10.0
		var blade_points = PackedVector2Array([
			pos - perp,
			pos + perp,
			tip + perp * 0.6,
			tip - perp * 0.6,
		])
		draw_colored_polygon(blade_points, Color(0.55, 0.55, 0.6))
		# Metal edge
		draw_line(tip - perp * 0.6, tip + perp * 0.6, Color(0.85, 0.85, 0.9), 2.0)
		# Rivet details
		draw_circle(pos, 2.0, Color(0.4, 0.4, 0.45))
	
	# ===== TRAIL =====
	if owner_ball and owner_ball.is_inside_tree() and trail_points.size() > 0:
		for point in trail_points:
			var local_pos = point.pos - owner_ball.global_position
			var alpha = point.life / point.max_life
			var sz = point.size * alpha
			var c = point.color
			c.a = alpha * 0.8
			draw_circle(local_pos, sz, c)
	
	# ===== LIFE-STEAL BATS =====
	_draw_special_projectiles()
	
	# ===== DASH CHARGE BARS =====
	var bar_width = 14.0
	var bar_height = 5.0
	var bar_gap = 3.0
	var total_w = bar_width * max_combo + bar_gap * (max_combo - 1)
	var bar_y = 40.0
	var start_x = -total_w / 2.0
	
	for i in range(max_combo):
		var bx = start_x + i * (bar_width + bar_gap)
		var bar_rect = Rect2(bx, bar_y, bar_width, bar_height)
		
		var fill = 0.0
		
		if state == "ready" or state == "aiming":
			fill = 1.0
		elif state == "dashing" or state == "combo_wait":
			var charges_remaining = max_combo - combo_index
			if i < charges_remaining:
				fill = 1.0
		elif state == "cooldown":
			var total_cooldown_time = combo_index * charge_recharge_time
			var elapsed = total_cooldown_time - cooldown_timer
			var fully_recharged_now = floor(elapsed / charge_recharge_time)
			var total_full = (max_combo - combo_index) + fully_recharged_now
			
			if i < total_full:
				fill = 1.0
			elif i == total_full:
				fill = fmod(elapsed, charge_recharge_time) / charge_recharge_time
			else:
				fill = 0.0
		
		draw_rect(bar_rect, Color(0.12, 0.12, 0.12, 0.85))
		if fill > 0:
			var fill_rect = Rect2(bx, bar_y, bar_width * fill, bar_height)
			var fill_color = Color(0.95, 0.75, 0.25, 0.95) if fill >= 1.0 else Color(0.7, 0.6, 0.25, 0.8)
			draw_rect(fill_rect, fill_color)
		draw_rect(bar_rect, Color(0.5, 0.5, 0.5, 0.5), false, 1.0)
	
	# ===== SPECIAL CHARGE BAR =====
	var special_bar_y = bar_y + bar_height + 3.0
	var special_rect = Rect2(start_x, special_bar_y, total_w, 3.0)
	draw_rect(special_rect, Color(0.1, 0.1, 0.1, 0.85))
	var special_fill = float(total_hits) / float(hits_for_special)
	if special_fill > 0:
		var sfill_rect = Rect2(start_x, special_bar_y, total_w * min(special_fill, 1.0), 3.0)
		draw_rect(sfill_rect, Color(0.2, 1.0, 0.3, 0.9))
	draw_rect(special_rect, Color(0.5, 0.5, 0.5, 0.4), false, 1.0)

func _draw_dash_swing():
	if dash_swing_timer <= 0.0:
		return
	var fade = clamp(dash_swing_timer / max(dash_swing_duration, 0.01), 0.0, 1.0)
	var progress = 1.0 - fade
	var color = Color(1.0, 0.2, 0.1) if dash_swing_is_first else Color(0.24, 0.62, 1.0)
	var radius = lerp(46.0, 76.0, progress)
	var arc_half = lerp(0.42, 1.05, progress)
	var start_angle = dash_swing_angle - arc_half
	var end_angle = dash_swing_angle + arc_half
	draw_arc(Vector2.ZERO, radius, start_angle, end_angle, 24, Color(color, 0.72 * fade), lerp(8.0, 2.2, progress))
	draw_arc(Vector2.ZERO, radius * 0.78, start_angle + 0.15, end_angle - 0.15, 20, Color(1.0, 0.95, 0.72, 0.34 * fade), lerp(4.5, 1.4, progress))
	var forward = Vector2.RIGHT.rotated(dash_swing_angle)
	var side = forward.rotated(PI * 0.5)
	var tip = forward * (radius + 8.0)
	draw_colored_polygon(PackedVector2Array([
		forward * 28.0 - side * 8.0 * fade,
		tip,
		forward * 28.0 + side * 8.0 * fade,
	]), Color(color, 0.18 * fade))

func _draw_special_projectiles():
	if not owner_ball or not owner_ball.is_inside_tree(): return
	if active_special_projectiles.is_empty(): return
	var fx_scale = _short_video_fx_scale()
	for bat in active_special_projectiles:
		if float(bat.get("delay", 0.0)) > 0.0:
			continue
		var world_pos: Vector2 = bat.get("pos", owner_ball.global_position)
		var local_pos = world_pos - owner_ball.global_position
		var age = float(bat.get("age", 0.0))
		var wing_pulse = 1.0 + sin(age * 18.0) * 0.08
		var alpha = 0.88 + sin(age * 12.0) * 0.08
		var shadow_color = Color(0.02, 0.02, 0.03, 0.26)
		draw_circle(local_pos + Vector2(3, 5) * fx_scale, special_projectile_hit_radius * 0.55 * fx_scale, shadow_color)
		draw_circle(local_pos, special_projectile_hit_radius * 0.62 * fx_scale, Color(special_projectile_glow_color, special_projectile_glow_color.a * 0.32))
		
		if custom_super_texture:
			var tex_scale = (special_projectile_visual_size * fx_scale) / super_texture_longest_side
			draw_set_transform(local_pos, float(bat.get("angle", 0.0)), Vector2(tex_scale, tex_scale * wing_pulse))
			var outline = max(special_projectile_outline_size, 0.0)
			if outline > 0.0:
				for direction_offset in SPECIAL_PROJECTILE_OUTLINE_DIRECTIONS:
					var offset = direction_offset * outline
					draw_texture_rect(custom_super_texture, Rect2(-super_texture_size / 2.0 + offset, super_texture_size), false, Color(special_projectile_glow_color, special_projectile_glow_color.a * clamp(alpha, 0.0, 1.0)))
			draw_texture_rect(custom_super_texture, Rect2(-super_texture_size / 2.0, super_texture_size), false, Color(1, 1, 1, clamp(alpha, 0.0, 1.0)))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		else:
			var body_color = Color(0.08, 0.02, 0.12, clamp(alpha, 0.0, 1.0))
			var wing_color = Color(0.22, 0.04, 0.28, clamp(alpha * 0.9, 0.0, 1.0))
			var angle = float(bat.get("angle", 0.0))
			var right = Vector2.RIGHT.rotated(angle)
			var up = right.rotated(-PI * 0.5)
			var wing_span = 18.0 * fx_scale * wing_pulse
			var body_len = 12.0 * fx_scale
			draw_circle(local_pos, 6.0 * fx_scale, body_color)
			draw_colored_polygon(PackedVector2Array([
				local_pos - right * 2.0 * fx_scale,
				local_pos - right * body_len - up * wing_span,
				local_pos - right * 6.0 * fx_scale + up * 3.0 * fx_scale,
			]), wing_color)
			draw_colored_polygon(PackedVector2Array([
				local_pos + right * 2.0 * fx_scale,
				local_pos + right * body_len - up * wing_span,
				local_pos + right * 6.0 * fx_scale + up * 3.0 * fx_scale,
			]), wing_color)
