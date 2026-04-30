# Frank - heavy hammer fighter with cone attacks and a stunning super.
class_name WeaponFrank extends WeaponBase

const FRANK_ATTACK_SFX_STREAM = preload("res://sfx/frank_attack.ogg")
const FRANK_SUPER_SFX_STREAM = preload("res://sfx/frank_super.ogg")
const FRANK_SUPER_CHARGE_SFX_STREAM = preload("res://sfx/frank_ulti_swing_01.ogg")
const FRANK_VOICE_STREAMS = [
	preload("res://sfx/voices/frank/frank_vo_01.ogg"),
	preload("res://sfx/voices/frank/frank_vo_02.ogg"),
	preload("res://sfx/voices/frank/frank_vo_03.ogg"),
	preload("res://sfx/voices/frank/frank_vo_04.ogg"),
	preload("res://sfx/voices/frank/frank_vo_05.ogg"),
	preload("res://sfx/voices/frank/frank_vo_06.ogg"),
]

# ==============================================================
# >>>  EDITABLE VALUES  <<<
# ==============================================================
var attack_range: float = 165.0
var attack_seek_range: float = 165.0
var attack_cone_degrees: float = 72.0
var base_damage: float = 30.0
var max_combo: int = 3
var combo_interval: float = 0.95
var charge_recharge_time: float = 2.4
var attack_windup: float = 0.78
var attack_recovery: float = 0.55
var attack_knockback: float = 420.0
var attack_impact_fx_duration: float = 0.34
var attack_impact_fx_radius: float = 86.0
var attack_impact_particle_amount: int = 26
var attack_impact_particle_velocity_min: float = 110.0
var attack_impact_particle_velocity_max: float = 260.0

var heavy_mass: float = 2.25

# --- Super ---
var special_charge_time: float = 30.0
var special_charges_while_attacking: bool = false
var damage_charge_reduction: float = 0.5
var special_seek_range: float = 430.0
var special_range: float = 360.0
var special_cone_degrees: float = 86.0
var special_damage: float = 36.0
var special_windup: float = 1.18
var special_recovery: float = 0.70
var special_paralysis_duration: float = 5
var special_knockback: float = 520.0
var special_fx_duration: float = 0.9
var special_fx_texture_scale: float = 2.8
var special_fx_rotation_offset: float = PI * 0.5
var special_fx_start_offset: float = 0.20
var special_fx_end_offset: float = 0.88
var special_fx_segments: int = 7
var special_fx_step_delay: float = 0.055
var special_fx_side_spread: float = 54.0
var special_fx_scale_growth: float = 0.12
var kill_voice_cooldown: float = 1.4

# ==============================================================
# >>>  EDITABLE ASSETS (Optional)  <<<
# ==============================================================
@export var custom_weapon_texture: Texture2D = null
@export var custom_super_texture: Texture2D = null
@export var custom_super_texture_alt: Texture2D = null
@export var weapon_texture_scale: float = 2.6
# ==============================================================

var state: String = "ready"
var state_timer: float = 0.0
var cooldown_timer: float = 0.0
var combo_index: int = 0
var combo_timer: float = 0.0
var special_timer: float = 0.0
var aim_target: Node = null

var orbit_angle: float = 0.0
var orbit_speed: float = 1.45
var attack_angle: float = 0.0
var impact_flash_timer: float = 0.0
var last_hit_count: int = 0
var active_attack_impacts: Array = []
var active_super_cracks: Array = []
var hammer_swing_timer: float = 0.0
var hammer_swing_duration: float = 0.28
var hammer_swing_angle: float = 0.0
var hammer_swing_is_super: bool = false
var attack_sfx_player: AudioStreamPlayer2D = null
var super_sfx_player: AudioStreamPlayer2D = null
var super_charge_sfx_player: AudioStreamPlayer2D = null
var kill_voice_player: AudioStreamPlayer2D = null
var ult_voice_player: AudioStreamPlayer2D = null
var kill_voice_cooldown_timer: float = 0.0
var weapon_texture_size: Vector2 = Vector2.ZERO
var super_texture_size: Vector2 = Vector2.ZERO
var super_texture_alt_size: Vector2 = Vector2.ZERO

func setup(owner: Node):
	super.setup(owner)
	weapon_name = "Frank"
	_setup_sfx_players()
	_setup_voice_players()
	orbit_angle = randf() * TAU
	attack_angle = orbit_angle
	special_timer = special_charge_time
	
	if custom_weapon_texture == null and ResourceLoader.exists("res://weapons/texturas/frank_weapon.png"):
		custom_weapon_texture = load("res://weapons/texturas/frank_weapon.png")
	if custom_super_texture == null and ResourceLoader.exists("res://weapons/texturas/frank_super_fx.png"):
		custom_super_texture = load("res://weapons/texturas/frank_super_fx.png")
	if custom_super_texture_alt == null and ResourceLoader.exists("res://weapons/texturas/frank_super_fx_02.png"):
		custom_super_texture_alt = load("res://weapons/texturas/frank_super_fx_02.png")
	_refresh_texture_cache()

func _refresh_texture_cache():
	weapon_texture_size = custom_weapon_texture.get_size() if custom_weapon_texture else Vector2.ZERO
	super_texture_size = custom_super_texture.get_size() if custom_super_texture else Vector2.ZERO
	super_texture_alt_size = custom_super_texture_alt.get_size() if custom_super_texture_alt else Vector2.ZERO
	
func _setup_sfx_players():
	if attack_sfx_player and is_instance_valid(attack_sfx_player):
		return
	attack_sfx_player = AudioStreamPlayer2D.new()
	attack_sfx_player.stream = FRANK_ATTACK_SFX_STREAM
	attack_sfx_player.volume_db = -3.0
	add_child(attack_sfx_player)
	
	super_sfx_player = AudioStreamPlayer2D.new()
	super_sfx_player.stream = FRANK_SUPER_SFX_STREAM
	super_sfx_player.volume_db = -2.0
	add_child(super_sfx_player)

	super_charge_sfx_player = AudioStreamPlayer2D.new()
	super_charge_sfx_player.stream = FRANK_SUPER_CHARGE_SFX_STREAM
	super_charge_sfx_player.volume_db = -3.0
	add_child(super_charge_sfx_player)

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
	_play_random_voice(kill_voice_player, FRANK_VOICE_STREAMS)

func _play_ult_voice():
	_play_random_voice(ult_voice_player, FRANK_VOICE_STREAMS)

func _play_attack_sfx():
	if not attack_sfx_player:
		return
	attack_sfx_player.pitch_scale = randf_range(0.96, 1.04)
	attack_sfx_player.play()

func _play_super_sfx():
	if not super_sfx_player:
		return
	super_sfx_player.pitch_scale = randf_range(0.98, 1.03)
	super_sfx_player.play()

func _play_super_charge_sfx():
	if not super_charge_sfx_player:
		return
	super_charge_sfx_player.pitch_scale = randf_range(0.98, 1.03)
	super_charge_sfx_player.play()

func on_owner_damaged(amount: float, source = null):
	if amount <= 0.0:
		return
	special_timer = max(0.0, special_timer - amount * damage_charge_reduction)

func process_weapon(delta: float):
	if not is_instance_valid(owner_ball) or not owner_ball.is_inside_tree():
		return
	
	kill_voice_cooldown_timer = max(0.0, kill_voice_cooldown_timer - delta)
	impact_flash_timer = max(0.0, impact_flash_timer - delta)
	hammer_swing_timer = max(0.0, hammer_swing_timer - delta)
	_process_attack_impacts(delta)
	_process_super_cracks(delta)
	var can_charge_super = state == "ready" or state == "combo_wait" or state == "cooldown" or special_charges_while_attacking
	if can_charge_super and state != "special_windup" and state != "special_recovery":
		special_timer = max(0.0, special_timer - delta)
	if state == "ready":
		orbit_angle += orbit_speed * delta
	
	match state:
		"ready":
			_state_ready(delta)
		"attack_windup":
			_state_attack_windup(delta)
		"attack_recovery":
			_state_attack_recovery(delta)
		"combo_wait":
			_state_combo_wait(delta)
		"cooldown":
			_state_cooldown(delta)
		"special_windup":
			_state_special_windup(delta)
		"special_recovery":
			_state_special_recovery(delta)
	
	queue_redraw()

func _state_ready(delta: float):
	if special_timer <= 0.0:
		var special_target = _find_nearest_target(special_seek_range)
		if special_target:
			_start_special(special_target)
			return
	
	var target = _find_regular_attack_target()
	if target:
		combo_index = 0
		_start_attack(target)

func _state_attack_windup(delta: float):
	_hold_owner_still()
	_track_target(delta, 6.0)
	state_timer -= delta
	if state_timer <= 0.0:
		_play_attack_sfx()
		_start_hammer_swing(false)
		last_hit_count = _apply_cone_damage(attack_range, deg_to_rad(attack_cone_degrees), base_damage, 0.0, attack_knockback)
		impact_flash_timer = 0.18
		_spawn_attack_impact(_impact_position(attack_range))
		state = "attack_recovery"
		state_timer = attack_recovery
		aim_target = null

func _state_attack_recovery(delta: float):
	_hold_owner_still()
	state_timer -= delta
	if state_timer <= 0.0:
		combo_index += 1
		if combo_index >= max_combo:
			state = "cooldown"
			cooldown_timer = combo_index * charge_recharge_time
			return
		
		var target = _find_regular_attack_target()
		if target:
			state = "combo_wait"
			combo_timer = combo_interval
		else:
			state = "cooldown"
			cooldown_timer = combo_index * charge_recharge_time

func _state_combo_wait(delta: float):
	combo_timer -= delta
	if combo_timer <= 0.0:
		var target = _find_regular_attack_target()
		if target:
			_start_attack(target)
		else:
			state = "cooldown"
			cooldown_timer = combo_index * charge_recharge_time

func _state_cooldown(delta: float):
	cooldown_timer -= delta
	if cooldown_timer <= 0.0:
		combo_index = 0
		state = "ready"

func _state_special_windup(delta: float):
	_hold_owner_still()
	_track_target(delta, 4.0)
	state_timer -= delta
	if state_timer <= 0.0:
		_play_super_sfx()
		_start_hammer_swing(true)
		last_hit_count = _apply_cone_damage(
			special_range,
			deg_to_rad(special_cone_degrees),
			special_damage,
			special_paralysis_duration,
			special_knockback
		)
		impact_flash_timer = 0.26
		_spawn_impact_particles(_impact_position(special_range), Color(0.86, 0.76, 1.0), 36, 120.0, 310.0)
		_spawn_super_crack()
		state = "special_recovery"
		state_timer = special_recovery
		special_timer = special_charge_time
		combo_index = 0
		cooldown_timer = 0.0
		aim_target = null

func _state_special_recovery(delta: float):
	_hold_owner_still()
	state_timer -= delta
	if state_timer <= 0.0:
		state = "ready"

func _start_attack(target: Node):
	state = "attack_windup"
	state_timer = attack_windup
	aim_target = target
	_set_attack_angle_to_target(target)
	_hold_owner_still()

func _start_special(target: Node):
	state = "special_windup"
	state_timer = special_windup
	aim_target = target
	_set_attack_angle_to_target(target)
	_play_super_charge_sfx()
	_play_ult_voice()
	_hold_owner_still()

func _start_hammer_swing(is_super: bool):
	hammer_swing_timer = hammer_swing_duration if not is_super else hammer_swing_duration * 1.25
	hammer_swing_angle = attack_angle
	hammer_swing_is_super = is_super

func on_owner_eliminated_target(target: Node):
	if kill_voice_cooldown_timer > 0.0:
		return
	kill_voice_cooldown_timer = kill_voice_cooldown
	if ult_voice_player and ult_voice_player.playing:
		ult_voice_player.stop()
	_play_kill_voice()

func _track_target(delta: float, turn_speed: float):
	if not _is_valid_target(aim_target):
		return
	var to_target = aim_target.global_position - owner_ball.global_position
	if to_target == Vector2.ZERO:
		return
	attack_angle = lerp_angle(attack_angle, to_target.angle(), min(1.0, delta * turn_speed))
	orbit_angle = attack_angle

func _set_attack_angle_to_target(target: Node):
	if not _is_valid_target(target):
		return
	var dir = target.global_position - owner_ball.global_position
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT.rotated(randf() * TAU)
	attack_angle = dir.angle()
	orbit_angle = attack_angle

func _hold_owner_still():
	if _has_node_property(owner_ball, "speed_modifier"):
		owner_ball.speed_modifier = 0.0
	if owner_ball is RigidBody2D:
		owner_ball.linear_velocity = Vector2.ZERO
		owner_ball.angular_velocity = 0.0

func _apply_cone_damage(distance: float, cone_angle: float, damage: float, paralysis_duration: float, knockback: float) -> int:
	var parent = owner_ball.get_parent()
	if not parent:
		return 0
	var hits = 0
	var forward = Vector2.RIGHT.rotated(attack_angle)
	var range_sq = distance * distance
	var cone_cos_sq = cos(cone_angle * 0.5)
	cone_cos_sq *= cone_cos_sq
	var close_hit_sq = 1936.0
	
	for child in _get_ball_candidates():
		if not _is_valid_enemy(child):
			continue
		var offset = child.global_position - owner_ball.global_position
		var dist_sq = offset.length_squared()
		if dist_sq > range_sq:
			continue
		
		if dist_sq > close_hit_sq:
			var forward_dot = forward.dot(offset)
			if forward_dot <= 0.0 or forward_dot * forward_dot < dist_sq * cone_cos_sq:
				continue
		
		hits += 1
		child.take_damage(damage, owner_ball)
		if is_instance_valid(child) and paralysis_duration > 0.0 and child.has_method("apply_paralysis") and bool(child.get("is_alive")):
			child.apply_paralysis(paralysis_duration)
		if is_instance_valid(child) and child is RigidBody2D:
			var push_dir = offset.normalized()
			if push_dir == Vector2.ZERO:
				push_dir = forward
			child.apply_central_impulse(push_dir * knockback)
	
	return hits

func _find_nearest_target(max_range: float) -> Node:
	return _find_nearest_enemy(max_range)

func _find_regular_attack_target() -> Node:
	return _find_nearest_target(min(attack_seek_range, attack_range))

func _is_valid_target(target) -> bool:
	return _is_valid_enemy(target)

func _impact_position(distance: float) -> Vector2:
	return owner_ball.global_position + Vector2.RIGHT.rotated(attack_angle) * (distance * 0.56)

func _spawn_super_crack():
	var forward = Vector2.RIGHT.rotated(attack_angle)
	var perp = forward.rotated(PI * 0.5)
	var segments = max(1, special_fx_segments)
	
	for i in range(segments):
		var t = 0.0 if segments == 1 else float(i) / float(segments - 1)
		var distance = special_range * lerp(special_fx_start_offset, special_fx_end_offset, t)
		var side_wave = sin(t * PI * 2.0 + 0.8) * special_fx_side_spread * 0.45
		var side_jitter = randf_range(-special_fx_side_spread, special_fx_side_spread) * lerp(0.2, 1.0, t)
		var scale = 1.0 + t * special_fx_scale_growth + randf_range(-0.12, 0.16)
		active_super_cracks.append({
			"pos": owner_ball.global_position + forward * distance + perp * (side_wave + side_jitter),
			"angle": attack_angle + randf_range(-0.28, 0.28),
			"time_left": special_fx_duration,
			"duration": special_fx_duration,
			"delay": i * special_fx_step_delay,
			"scale": max(0.45, scale),
			"variant": i % 2,
		})
	
	for branch in range(max(2, int(segments * 0.55))):
		var t = randf_range(0.28, 0.92)
		var side = -1.0 if branch % 2 == 0 else 1.0
		active_super_cracks.append({
			"pos": owner_ball.global_position + forward * (special_range * t) + perp * side * randf_range(special_fx_side_spread * 0.35, special_fx_side_spread * 1.25),
			"angle": attack_angle + side * randf_range(0.55, 0.95),
			"time_left": special_fx_duration * randf_range(0.72, 0.95),
			"duration": special_fx_duration,
			"delay": randf_range(0.04, special_fx_step_delay * segments),
			"scale": randf_range(0.55, 0.9),
			"variant": branch % 2,
		})

func _process_super_cracks(delta: float):
	var i = active_super_cracks.size() - 1
	while i >= 0:
		var crack = active_super_cracks[i]
		if crack.get("delay", 0.0) > 0.0:
			crack["delay"] = max(0.0, float(crack.get("delay", 0.0)) - delta)
		else:
			crack["time_left"] = float(crack.get("time_left", 0.0)) - delta
			if crack["time_left"] <= 0.0:
				active_super_cracks.remove_at(i)
				i -= 1
				continue
		active_super_cracks[i] = crack
		i -= 1

func _spawn_attack_impact(pos: Vector2):
	active_attack_impacts.append({
		"pos": pos,
		"angle": attack_angle,
		"time_left": attack_impact_fx_duration,
		"duration": attack_impact_fx_duration,
		"radius": attack_impact_fx_radius,
		"hit_count": max(1, last_hit_count),
	})
	_spawn_impact_particles(
		pos,
		Color(1.0, 0.74, 0.22),
		attack_impact_particle_amount,
		attack_impact_particle_velocity_min,
		attack_impact_particle_velocity_max
	)
	_spawn_impact_dust(pos)

func _process_attack_impacts(delta: float):
	var i = active_attack_impacts.size() - 1
	while i >= 0:
		var impact = active_attack_impacts[i]
		impact["time_left"] = float(impact.get("time_left", 0.0)) - delta
		if impact["time_left"] <= 0.0:
			active_attack_impacts.remove_at(i)
		else:
			active_attack_impacts[i] = impact
		i -= 1

func _spawn_impact_particles(pos: Vector2, color: Color, amount_override: int = -1, velocity_min: float = 60.0, velocity_max: float = 170.0):
	var parent = owner_ball.get_parent()
	if not parent:
		return
	
	var particles = CPUParticles2D.new()
	particles.emitting = true
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = amount_override if amount_override > 0 else 14 + last_hit_count * 5
	particles.lifetime = 0.32
	particles.direction = Vector2.RIGHT.rotated(attack_angle)
	particles.spread = 68.0
	particles.initial_velocity_min = velocity_min
	particles.initial_velocity_max = velocity_max
	particles.gravity = Vector2.ZERO
	particles.scale_amount_min = 3.0
	particles.scale_amount_max = 6.0
	particles.color = color
	particles.global_position = pos
	parent.add_child(particles)
	owner_ball.get_tree().create_timer(0.8).timeout.connect(func():
		if is_instance_valid(particles): particles.queue_free()
	)

func _spawn_impact_dust(pos: Vector2):
	var parent = owner_ball.get_parent()
	if not parent:
		return
	
	var dust = CPUParticles2D.new()
	dust.emitting = true
	dust.one_shot = true
	dust.explosiveness = 0.82
	dust.amount = 18
	dust.lifetime = 0.42
	dust.direction = Vector2.ZERO
	dust.spread = 180.0
	dust.initial_velocity_min = 35.0
	dust.initial_velocity_max = 120.0
	dust.gravity = Vector2.ZERO
	dust.scale_amount_min = 5.0
	dust.scale_amount_max = 10.0
	dust.color = Color(0.34, 0.24, 0.15, 0.56)
	dust.global_position = pos
	parent.add_child(dust)
	owner_ball.get_tree().create_timer(0.9).timeout.connect(func():
		if is_instance_valid(dust): dust.queue_free()
	)

func _draw():
	if not is_instance_valid(owner_ball):
		return
	
	_draw_active_attack_impacts()
	_draw_active_super_cracks()
	
	if state == "attack_windup":
		var windup_alpha = 0.12 + (1.0 - state_timer / max(attack_windup, 0.01)) * 0.22
		_draw_cone(attack_range, deg_to_rad(attack_cone_degrees), Color(1.0, 0.62, 0.14, windup_alpha), Color(1.0, 0.84, 0.28, 0.62))
	elif state == "attack_recovery" and impact_flash_timer > 0.0:
		_draw_cone(attack_range, deg_to_rad(attack_cone_degrees), Color(1.0, 0.78, 0.25, impact_flash_timer * 0.65), Color(1.0, 0.95, 0.64, impact_flash_timer * 1.8))
	
	if state == "special_windup":
		var alpha = 0.16 + (1.0 - state_timer / max(special_windup, 0.01)) * 0.34
		_draw_cone(special_range, deg_to_rad(special_cone_degrees), Color(0.64, 0.46, 1.0, alpha * 0.45), Color(0.92, 0.86, 1.0, alpha))
	elif state == "special_recovery" and impact_flash_timer > 0.0:
		var alpha = impact_flash_timer * 1.8
		_draw_cone(special_range, deg_to_rad(special_cone_degrees), Color(0.64, 0.46, 1.0, alpha * 0.28), Color(0.92, 0.86, 1.0, alpha))
	
	_draw_hammer_swing()
	_draw_hammer()
	_draw_charge_ui()

func _draw_cone(distance: float, cone_angle: float, fill_color: Color, edge_color: Color):
	var points = PackedVector2Array()
	var segments = 18
	points.append(Vector2.ZERO)
	for i in range(segments + 1):
		var t = float(i) / float(segments)
		var angle = attack_angle - cone_angle * 0.5 + cone_angle * t
		points.append(Vector2.RIGHT.rotated(angle) * distance)
	draw_colored_polygon(points, fill_color)
	for i in range(1, points.size() - 1):
		draw_line(points[i], points[i + 1], edge_color, 2.0)
	draw_line(Vector2.ZERO, points[1], edge_color, 1.6)
	draw_line(Vector2.ZERO, points[points.size() - 1], edge_color, 1.6)

func _draw_active_attack_impacts():
	for impact in active_attack_impacts:
		var duration = max(float(impact.get("duration", attack_impact_fx_duration)), 0.01)
		var progress = 1.0 - clamp(float(impact.get("time_left", 0.0)) / duration, 0.0, 1.0)
		var fade = 1.0 - progress
		var local_pos = impact.get("pos", owner_ball.global_position) - owner_ball.global_position
		var angle = float(impact.get("angle", attack_angle))
		var radius = float(impact.get("radius", attack_impact_fx_radius))
		_draw_attack_impact(local_pos, angle, radius, progress, fade)

func _draw_attack_impact(local_pos: Vector2, angle: float, radius: float, progress: float, fade: float):
	var forward = Vector2.RIGHT.rotated(angle)
	var perp = forward.rotated(PI * 0.5)
	var shock_radius = lerp(radius * 0.32, radius, progress)
	var alpha = clamp(fade, 0.0, 1.0)
	
	draw_arc(local_pos, shock_radius, angle - 1.35, angle + 1.35, 28, Color(1.0, 0.86, 0.35, alpha * 0.95), lerp(5.0, 1.4, progress))
	draw_arc(local_pos, shock_radius * 0.68, angle - 1.05, angle + 1.05, 24, Color(0.18, 0.10, 0.04, alpha * 0.7), lerp(4.0, 1.2, progress))
	
	var center = local_pos + forward * lerp(-10.0, 18.0, progress)
	var scar_len = radius * lerp(0.34, 0.82, progress)
	draw_line(center - forward * scar_len * 0.35, center + forward * scar_len * 0.65, Color(0.16, 0.08, 0.03, alpha), 4.0)
	for i in range(5):
		var t = -0.22 + i * 0.18
		var side = -1.0 if i % 2 == 0 else 1.0
		var branch_start = center + forward * scar_len * t
		var branch_end = branch_start + forward * scar_len * 0.16 + perp * side * radius * (0.18 + progress * 0.10)
		draw_line(branch_start, branch_end, Color(0.24, 0.13, 0.04, alpha * 0.85), 2.4)
	
	var dent_alpha = alpha * 0.35
	draw_circle(local_pos + forward * 10.0, radius * lerp(0.16, 0.25, progress), Color(0.12, 0.07, 0.03, dent_alpha))

func _draw_active_super_cracks():
	for crack in active_super_cracks:
		if float(crack.get("delay", 0.0)) > 0.0:
			continue
		var duration = max(float(crack.get("duration", special_fx_duration)), 0.01)
		var fade = clamp(float(crack.get("time_left", 0.0)) / duration, 0.0, 1.0)
		var local_pos = crack.get("pos", owner_ball.global_position) - owner_ball.global_position
		_draw_super_crack(
			local_pos,
			float(crack.get("angle", attack_angle)),
			fade,
			float(crack.get("scale", 1.0)),
			int(crack.get("variant", 0))
		)

func _draw_super_crack(local_pos: Vector2, angle: float, fade: float, scale_multiplier: float = 1.0, variant: int = 0):
	var alpha = clamp(fade * 1.25, 0.0, 1.0)
	var selected_super_texture: Texture2D = custom_super_texture
	if variant % 2 == 1 and custom_super_texture_alt:
		selected_super_texture = custom_super_texture_alt
	elif selected_super_texture == null and custom_super_texture_alt:
		selected_super_texture = custom_super_texture_alt

	if selected_super_texture:
		var tex_size = super_texture_alt_size if selected_super_texture == custom_super_texture_alt else super_texture_size
		var fx_scale = special_fx_texture_scale * scale_multiplier * _short_video_fx_scale()
		draw_set_transform(local_pos, angle + special_fx_rotation_offset, Vector2.ONE * fx_scale)
		draw_texture_rect(selected_super_texture, Rect2(-tex_size / 2.0, tex_size), false, Color(1, 1, 1, alpha))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	
	var forward = Vector2.RIGHT.rotated(angle)
	var perp = forward.rotated(PI * 0.5)
	var main_len = special_range * 0.58 * scale_multiplier
	var width = special_range * 0.13 * scale_multiplier
	draw_line(local_pos - forward * main_len * 0.5, local_pos + forward * main_len * 0.5, Color(0.15, 0.08, 0.04, alpha), 5.0)
	for i in range(6):
		var t = -0.42 + i * 0.16
		var side = -1.0 if i % 2 == 0 else 1.0
		var branch_start = local_pos + forward * main_len * t
		var branch_end = branch_start + forward * main_len * 0.15 + perp * width * side
		draw_line(branch_start, branch_end, Color(0.22, 0.12, 0.05, alpha * 0.86), 3.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_hammer_swing():
	if hammer_swing_timer <= 0.0:
		return
	var total = hammer_swing_duration * (1.25 if hammer_swing_is_super else 1.0)
	var fade = clamp(hammer_swing_timer / max(total, 0.01), 0.0, 1.0)
	var progress = 1.0 - fade
	var color = Color(0.72, 0.52, 1.0) if hammer_swing_is_super else Color(1.0, 0.68, 0.16)
	var radius = lerp(54.0, 118.0 if hammer_swing_is_super else 86.0, progress)
	var arc_width = lerp(10.0, 2.2, progress) * _short_video_fx_scale()
	var sweep = lerp(0.65, 1.42 if hammer_swing_is_super else 1.08, progress)
	draw_arc(Vector2.ZERO, radius, hammer_swing_angle - sweep, hammer_swing_angle + sweep * 0.35, 26, Color(color, 0.74 * fade), arc_width)
	draw_arc(Vector2.ZERO, radius * 0.78, hammer_swing_angle - sweep * 0.62, hammer_swing_angle + sweep * 0.22, 22, Color(1.0, 0.94, 0.62, 0.32 * fade), max(1.5, arc_width * 0.42))
	var forward = Vector2.RIGHT.rotated(hammer_swing_angle)
	var end = forward * radius
	draw_circle(end, (10.0 if hammer_swing_is_super else 7.0) * fade, Color(color, 0.38 * fade))

func _draw_hammer():
	var using_attack_pose = state != "ready"
	var draw_angle = attack_angle if using_attack_pose else orbit_angle
	var pos = Vector2.RIGHT.rotated(draw_angle) * 48.0
	
	if state == "attack_windup" or state == "special_windup":
		var windup_total = special_windup if state == "special_windup" else attack_windup
		var windup_progress = 1.0 - state_timer / max(windup_total, 0.01)
		pos = Vector2.RIGHT.rotated(draw_angle) * lerp(34.0, 55.0, windup_progress)
		draw_angle -= lerp(0.75, 0.10, windup_progress)
	elif state == "attack_recovery" or state == "special_recovery":
		pos = Vector2.RIGHT.rotated(draw_angle) * 58.0
	
	if custom_weapon_texture:
		draw_set_transform(pos, draw_angle + PI * 0.5, Vector2.ONE * weapon_texture_scale)
		draw_texture_rect(custom_weapon_texture, Rect2(-weapon_texture_size / 2.0, weapon_texture_size), false)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	
	var dir = Vector2.RIGHT.rotated(draw_angle)
	var perp = dir.rotated(PI * 0.5)
	draw_line(pos - dir * 22.0, pos + dir * 12.0, Color(0.38, 0.24, 0.12), 5.0)
	var head_center = pos + dir * 18.0
	var head_points = PackedVector2Array([
		head_center - dir * 10.0 - perp * 15.0,
		head_center - dir * 10.0 + perp * 15.0,
		head_center + dir * 16.0 + perp * 13.0,
		head_center + dir * 16.0 - perp * 13.0,
	])
	draw_colored_polygon(head_points, Color(0.48, 0.50, 0.55))
	draw_line(head_center - dir * 10.0 - perp * 15.0, head_center + dir * 16.0 - perp * 13.0, Color(0.86, 0.86, 0.9), 2.0)

func _draw_charge_ui():
	var bar_width = 14.0
	var bar_h = 5.0
	var bar_gap = 3.0
	var bar_w = bar_width * max_combo + bar_gap * (max_combo - 1)
	var bar_x = -bar_w * 0.5
	var bar_y = 42.0
	
	var used_attacks = combo_index
	if state == "attack_windup" or state == "attack_recovery":
		used_attacks += 1
	
	for i in range(max_combo):
		var bx = bar_x + i * (bar_width + bar_gap)
		var bar_rect = Rect2(bx, bar_y, bar_width, bar_h)
		var fill = 0.0
		
		if state == "ready" or state == "special_windup" or state == "special_recovery":
			fill = 1.0
		elif state == "attack_windup" or state == "attack_recovery" or state == "combo_wait":
			var charges_remaining = max_combo - used_attacks
			if i < charges_remaining:
				fill = 1.0
		elif state == "cooldown":
			var total_cooldown = max(1, combo_index) * charge_recharge_time
			var elapsed = total_cooldown - cooldown_timer
			var fully_recharged_now = floor(elapsed / charge_recharge_time)
			var total_full = (max_combo - combo_index) + fully_recharged_now
			
			if i < total_full:
				fill = 1.0
			elif i == total_full:
				fill = fmod(elapsed, charge_recharge_time) / charge_recharge_time
		
		draw_rect(bar_rect, Color(0.08, 0.08, 0.1, 0.88))
		if fill > 0.0:
			draw_rect(Rect2(bx, bar_y, bar_width * clamp(fill, 0.0, 1.0), bar_h), Color(0.95, 0.75, 0.25, 0.95) if fill >= 1.0 else Color(0.7, 0.6, 0.25, 0.8))
		draw_rect(bar_rect, Color(1, 1, 1, 0.18), false, 1.0)
	
	var s_bar_y = bar_y + bar_h + 3.0
	draw_rect(Rect2(bar_x, s_bar_y, bar_w, 4.0), Color(0.08, 0.08, 0.1, 0.88))
	var fill = 1.0 if special_timer <= 0.0 else clamp(1.0 - special_timer / special_charge_time, 0.0, 1.0)
	var fill_color = Color(0.86, 0.72, 1.0, 0.95)
	if special_timer <= 0.0:
		var pulse = 0.68 + sin(Time.get_ticks_msec() * 0.012) * 0.28
		fill_color = Color(1.0, 0.93, 0.35, pulse)
	draw_rect(Rect2(bar_x, s_bar_y, bar_w * fill, 4.0), fill_color)
	draw_rect(Rect2(bar_x, s_bar_y, bar_w, 4.0), Color(1, 1, 1, 0.18), false, 1.0)
