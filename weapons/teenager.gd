# Adolescente weapon - fast combo fighter with a real hit dash special.
class_name WeaponTeenager extends WeaponBase

#region Assets
const EDGAR_PUNCH_SFX_STREAM = preload("res://sfx/edgar_punch_01.ogg")
const EDGAR_ULT_SFX_STREAM = preload("res://sfx/edgar_ulti_01.ogg")
const EDGAR_KILL_VOICE_STREAMS = [
	preload("res://sfx/voices/teenager/edgar_kill_vo_01.ogg"),
	preload("res://sfx/voices/teenager/edgar_kill_vo_02.ogg"),
	preload("res://sfx/voices/teenager/edgar_kill_vo_03.ogg"),
	preload("res://sfx/voices/teenager/edgar_kill_vo_04.ogg"),
	preload("res://sfx/voices/teenager/edgar_kill_vo_05.ogg"),
]
const EDGAR_ULT_VOICE_STREAMS = [
	preload("res://sfx/voices/teenager/edgar_ulti_vo_01.ogg"),
	preload("res://sfx/voices/teenager/edgar_ulti_vo_02.ogg"),
	preload("res://sfx/voices/teenager/edgar_ulti_vo_05.ogg"),
]
#endregion

# ==============================================================
#region Editable Values
# >>>  EDITABLE VALUES  <<<
# ==============================================================
var max_combo: int = 3
var punch_interval: float = 0.15
var bar_use_delay: float = 0.42
var charge_recharge_time: float = 1.2

var punch_range: float = 128.0
var punch_tracking_range: float = 190.0
var base_damage: float = 5.0
var punch_force: float = 360.0
var lifesteal_percent: float = 0.25   # Heals 25% of the damage dealt

# --- Special Dash ---
var special_base_cooldown: float = 24.0
var special_hit_reduction: float = 1.8
var special_seek_range: float = 920.0
var special_dash_speed: float = 980.0
var special_dash_duration: float = 0.42
var special_hit_radius: float = 58.0
var special_damage: float = 32.0
var special_knockback: float = 650.0
var kill_voice_cooldown: float = 1.4
# ==============================================================
#endregion

# ==============================================================
#region Editable Assets
# >>>  EDITABLE ASSETS (Optional)  <<<
# ==============================================================
@export var custom_punch_texture: Texture2D = null
@export var punch_texture_size_multiplier: float = 2.0
# ==============================================================
#endregion

#region Internal State
var charges_ready: int = max_combo
var charge_recharge_timer: float = 0.0
var punch_step: int = 0
var punch_timer: float = 0.0
var cooldown_timer: float = 0.0
var state: String = "ready"

var special_cooldown: float = 0.0
var is_special_active: bool = false
var special_dash_timer: float = 0.0
var special_hit_targets: Dictionary = {}
var special_effect_id: String = ""

var orbit_angle: float = 0.0
var orbit_speed: float = 3.5
var attack_angle: float = 0.0
var target_marker: Vector2 = Vector2.ZERO
var target_marker_alpha: float = 0.0

var punch_left_ext: float = 0.0
var punch_right_ext: float = 0.0
var last_punch_left: bool = false
var punch_swooshes: Array = []
var special_dash_trail_points: Array = []
var punch_sfx_player: AudioStreamPlayer2D = null
var ult_sfx_player: AudioStreamPlayer2D = null
var kill_voice_player: AudioStreamPlayer2D = null
var ult_voice_player: AudioStreamPlayer2D = null
var kill_voice_cooldown_timer: float = 0.0
var punch_texture_size: Vector2 = Vector2.ZERO
#endregion

#region Setup
func setup(owner: Node):
	super.setup(owner)
	weapon_name = "Adolescente"
	orbit_angle = randf() * TAU
	attack_angle = orbit_angle
	special_cooldown = special_base_cooldown
	charges_ready = max_combo
	charge_recharge_timer = 0.0
	_setup_sfx_players()
	_setup_voice_players()

	if custom_punch_texture == null and ResourceLoader.exists("res://weapons/texturas/teenager.png"):
		custom_punch_texture = load("res://weapons/texturas/teenager.png")
	_refresh_texture_cache()

func _refresh_texture_cache():
	punch_texture_size = custom_punch_texture.get_size() if custom_punch_texture else Vector2.ZERO

func _exit_tree():
	_finish_special_dash()
#endregion

#region Main Loop
func process_weapon(delta: float):
	if not is_instance_valid(owner_ball) or not owner_ball.is_inside_tree():
		return
	
	kill_voice_cooldown_timer = max(0.0, kill_voice_cooldown_timer - delta)
	orbit_angle += orbit_speed * delta
	punch_left_ext = move_toward(punch_left_ext, 0.0, delta * 7.5)
	punch_right_ext = move_toward(punch_right_ext, 0.0, delta * 7.5)
	target_marker_alpha = move_toward(target_marker_alpha, 0.0, delta * 2.8)
	_process_punch_swooshes(delta)
	_process_special_dash_trails(delta)
	_recharge_charges(delta)
	
	if is_special_active:
		_process_special_dash(delta)
		queue_redraw()
		return
	
	special_cooldown = move_toward(special_cooldown, 0.0, delta)
	
	if special_cooldown <= 0.0 and charges_ready >= max_combo:
		var special_target = _find_nearest_target(special_seek_range)
		if special_target:
			_activate_special(special_target)
			queue_redraw()
			return
	
	match state:
		"ready":
			_state_ready()
		"punching":
			_state_punching(delta)
		"cooldown":
			_state_cooldown(delta)
	
	queue_redraw()

func _state_ready():
	if charges_ready < max_combo:
		return
	
	var target = _find_nearest_target(punch_range)
	if target:
		_start_punch(target)

func _state_punching(delta: float):
	punch_timer -= delta
	if punch_timer > 0.0:
		return
	
	var target = _find_nearest_target(punch_tracking_range)
	if punch_step == 1:
		if target:
			_do_punch(target, false)
		_begin_cooldown()
		return

func _state_cooldown(delta: float):
	cooldown_timer -= delta
	if cooldown_timer <= 0.0:
		state = "ready"
#endregion

#region Attack
func _start_punch(target: Node):
	_consume_charge()
	state = "punching"
	punch_step = 1
	_do_punch(target, true)
	punch_timer = punch_interval

func _begin_cooldown():
	state = "cooldown"
	punch_step = 0
	cooldown_timer = bar_use_delay

func _consume_charge():
	if charges_ready <= 0:
		return
	
	var was_full = charges_ready >= max_combo
	charges_ready = max(0, charges_ready - 1)
	if was_full:
		charge_recharge_timer = 0.0

func _recharge_charges(delta: float):
	if charges_ready >= max_combo:
		charge_recharge_timer = 0.0
		return
	
	charge_recharge_timer += delta
	while charge_recharge_timer >= charge_recharge_time and charges_ready < max_combo:
		charge_recharge_timer -= charge_recharge_time
		charges_ready += 1
	
	if charges_ready >= max_combo:
		charge_recharge_timer = 0.0

func _do_punch(target: Node, is_left: bool):
	if not _is_valid_target(target):
		return
	_play_punch_sfx()
	
	var dist_sq = owner_ball.global_position.distance_squared_to(target.global_position)
	if dist_sq > punch_tracking_range * punch_tracking_range:
		return
	
	var dir = (target.global_position - owner_ball.global_position).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT.rotated(randf() * TAU)
	attack_angle = dir.angle()
	target_marker = target.global_position
	target_marker_alpha = 0.72
	
	if is_left:
		punch_left_ext = 1.0
		last_punch_left = true
	else:
		punch_right_ext = 1.0
		last_punch_left = false
	_spawn_punch_swoosh(is_left)
	
	target.take_damage(base_damage, owner_ball)
	if owner_ball.is_alive:
		_heal_owner(base_damage * lifesteal_percent)
	
	if target is RigidBody2D:
		target.apply_central_impulse(dir * punch_force)
	
	special_cooldown = max(0.0, special_cooldown - special_hit_reduction)
	_spawn_hit_spark(target.global_position, Color(1.0, 0.75, 0.22))

func _activate_special(target: Node):
	if not _is_valid_target(target):
		return
	_play_ult_sfx()
	_play_ult_voice()
	
	is_special_active = true
	special_dash_timer = special_dash_duration
	special_hit_targets.clear()
	special_cooldown = special_base_cooldown
	state = "cooldown"
	cooldown_timer = 0.45
	
	var dir = (target.global_position - owner_ball.global_position).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT.rotated(randf() * TAU)
	attack_angle = dir.angle()
	
	special_effect_id = _status_id("teenager_dash")
	_apply_status_to(owner_ball, special_effect_id, special_dash_duration + 0.08, {
		"invulnerable": true,
		"speed_limit_override": special_dash_speed,
	})
	if owner_ball.has_method("queue_redraw"):
		owner_ball.queue_redraw()
	
	if owner_ball is RigidBody2D:
		owner_ball.linear_velocity = dir * special_dash_speed
	
	_spawn_dash_burst(owner_ball.global_position, dir)
#endregion

#region Audio
func _setup_sfx_players():
	if punch_sfx_player and is_instance_valid(punch_sfx_player):
		return
	punch_sfx_player = AudioStreamPlayer2D.new()
	punch_sfx_player.stream = EDGAR_PUNCH_SFX_STREAM
	punch_sfx_player.volume_db = -2.0
	add_child(punch_sfx_player)

	ult_sfx_player = AudioStreamPlayer2D.new()
	ult_sfx_player.stream = EDGAR_ULT_SFX_STREAM
	ult_sfx_player.volume_db = -2.5
	add_child(ult_sfx_player)

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

func _play_punch_sfx():
	if not punch_sfx_player:
		return
	punch_sfx_player.pitch_scale = randf_range(0.98, 1.04)
	punch_sfx_player.play()

func _play_ult_sfx():
	if not ult_sfx_player:
		return
	ult_sfx_player.pitch_scale = randf_range(0.98, 1.03)
	ult_sfx_player.play()

func _play_kill_voice():
	_play_random_voice(kill_voice_player, EDGAR_KILL_VOICE_STREAMS)

func _play_ult_voice():
	_play_random_voice(ult_voice_player, EDGAR_ULT_VOICE_STREAMS)

func on_owner_eliminated_target(target: Node):
	if kill_voice_cooldown_timer > 0.0:
		return
	kill_voice_cooldown_timer = kill_voice_cooldown
	if ult_voice_player and ult_voice_player.playing:
		ult_voice_player.stop()
	_play_kill_voice()
#endregion

#region Special Processing
func _process_special_dash(delta: float):
	special_dash_timer -= delta
	_add_special_dash_trail_point()
	_apply_special_hits()
	if special_dash_timer <= 0.0:
		_finish_special_dash()

func _spawn_punch_swoosh(is_left: bool):
	punch_swooshes.append({
		"angle": attack_angle,
		"is_left": is_left,
		"time_left": 0.18,
		"duration": 0.18,
	})

func _process_punch_swooshes(delta: float):
	var i = punch_swooshes.size() - 1
	while i >= 0:
		var swoosh = punch_swooshes[i]
		swoosh["time_left"] = float(swoosh.get("time_left", 0.0)) - delta
		if swoosh["time_left"] <= 0.0:
			punch_swooshes.remove_at(i)
		else:
			punch_swooshes[i] = swoosh
		i -= 1

func _add_special_dash_trail_point():
	if not is_special_active:
		return
	if not is_instance_valid(owner_ball):
		return
	special_dash_trail_points.append({
		"pos": owner_ball.global_position,
		"life": 0.34,
		"max_life": 0.34,
	})
	while special_dash_trail_points.size() > 18:
		special_dash_trail_points.remove_at(0)

func _process_special_dash_trails(delta: float):
	var i = special_dash_trail_points.size() - 1
	while i >= 0:
		var trail = special_dash_trail_points[i]
		trail["life"] = float(trail.get("life", 0.0)) - delta
		if trail["life"] <= 0.0:
			special_dash_trail_points.remove_at(i)
		else:
			special_dash_trail_points[i] = trail
		i -= 1

func _finish_special_dash():
	if not is_special_active and special_effect_id == "":
		return
	is_special_active = false
	special_hit_targets.clear()
	if special_effect_id != "":
		_clear_status_from(owner_ball, special_effect_id)
		special_effect_id = ""
	if is_instance_valid(owner_ball):
		if owner_ball.has_method("queue_redraw"):
			owner_ball.queue_redraw()

func _apply_special_hits():
	var parent = owner_ball.get_parent()
	if not parent:
		return
	
	for child in _get_ball_candidates():
		if not _is_valid_enemy(child):
			continue
		if special_hit_targets.has(child):
			continue
		var dist_sq = owner_ball.global_position.distance_squared_to(child.global_position)
		if dist_sq <= special_hit_radius * special_hit_radius:
			special_hit_targets[child] = true
			child.take_damage(special_damage, owner_ball)
			if owner_ball.is_alive:
				_heal_owner(special_damage * lifesteal_percent)
			
			if child is RigidBody2D:
				var dir = (child.global_position - owner_ball.global_position).normalized()
				if dir == Vector2.ZERO:
					dir = Vector2.RIGHT.rotated(attack_angle)
				child.apply_central_impulse(dir * special_knockback)
			_spawn_hit_spark(child.global_position, Color(1.0, 0.9, 0.25))
#endregion

#region Helpers
func _find_nearest_target(max_range: float) -> Node:
	return _find_nearest_enemy(max_range)

func _is_valid_target(target) -> bool:
	return _is_valid_enemy(target)

func _spawn_dash_burst(pos: Vector2, dir: Vector2):
	var particles = CPUParticles2D.new()
	particles.emitting = true
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = 28
	particles.lifetime = 0.38
	particles.direction = -dir
	particles.spread = 38.0
	particles.initial_velocity_min = 90.0
	particles.initial_velocity_max = 240.0
	particles.gravity = Vector2.ZERO
	particles.scale_amount_min = 3.0
	particles.scale_amount_max = 6.0
	particles.color = Color(1.0, 0.78, 0.2)
	particles.global_position = pos
	owner_ball.get_parent().add_child(particles)
	owner_ball.get_tree().create_timer(1.0).timeout.connect(func():
		if is_instance_valid(particles): particles.queue_free()
	)

func _spawn_hit_spark(pos: Vector2, color: Color):
	var parent = owner_ball.get_parent()
	if not parent:
		return
	
	var particles = CPUParticles2D.new()
	particles.emitting = true
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = 10
	particles.lifetime = 0.22
	particles.direction = Vector2.ZERO
	particles.spread = 180.0
	particles.initial_velocity_min = 35.0
	particles.initial_velocity_max = 95.0
	particles.gravity = Vector2.ZERO
	particles.scale_amount_min = 2.0
	particles.scale_amount_max = 4.0
	particles.color = color
	particles.global_position = pos
	parent.add_child(particles)
	owner_ball.get_tree().create_timer(0.7).timeout.connect(func():
		if is_instance_valid(particles): particles.queue_free()
	)
#endregion

#region Drawing
func _draw():
	if not is_instance_valid(owner_ball):
		return
	var anim_t = Time.get_ticks_msec() * 0.001
	
	if target_marker_alpha > 0.0:
		var marker_local = target_marker - owner_ball.global_position
		draw_arc(marker_local, 15.0, 0, TAU, 20, Color(1.0, 0.72, 0.2, target_marker_alpha), 2.0)
	
	_draw_special_dash_trails()
	_draw_punch_swooshes()
	
	if is_special_active:
		var dash_alpha = 0.45 + sin(Time.get_ticks_msec() * 0.035) * 0.22
		draw_arc(Vector2.ZERO, 39.0, 0, TAU, 36, Color(1.0, 0.9, 0.16, dash_alpha), 5.0)
		draw_arc(Vector2.ZERO, special_hit_radius, 0, TAU, 42, Color(1.0, 0.62, 0.05, dash_alpha * 0.45), 2.0)
	
	var punch_dir = Vector2.RIGHT.rotated(attack_angle)
	if state == "ready" or state == "cooldown":
		punch_dir = Vector2.RIGHT.rotated(orbit_angle)
	var punch_perp = punch_dir.rotated(PI / 2)
	var idle_wave = sin(anim_t * 4.8 + orbit_angle * 1.4)
	var idle_wave_alt = sin(anim_t * 4.8 + orbit_angle * 1.4 + PI)
	
	# Idle: orbit radius kept small so scarves hug the ball
	var arm_len = 16.0
	# Punch animation: anticipation (recoils inward) -> thrust straight forward -> retract
	# anticipation peaks early then drops; thrust is the punch_ext value itself
	var left_anticip = max(0.0, 1.0 - punch_left_ext) * punch_left_ext * 4.0
	var right_anticip = max(0.0, 1.0 - punch_right_ext) * punch_right_ext * 4.0
	left_anticip = clamp(left_anticip, 0.0, 1.0)
	right_anticip = clamp(right_anticip, 0.0, 1.0)
	# Base: shoulders close to body, recoil slightly back during anticipation
	var left_base = punch_dir * (6.0 - left_anticip * 8.0) + punch_perp * (14.0 - left_anticip * 4.0)
	var right_base = punch_dir * (6.0 - right_anticip * 8.0) - punch_perp * (14.0 - right_anticip * 4.0)
	# Tip thrusts STRAIGHT forward toward the target; both scarves punch parallel
	var left_thrust = punch_left_ext * 78.0
	var right_thrust = punch_right_ext * 78.0
	var left_fist = left_base + punch_dir * (16.0 + left_thrust) + punch_perp * 6.0
	var right_fist = right_base + punch_dir * (16.0 + right_thrust) - punch_perp * 6.0
	
	if state == "ready" or state == "cooldown":
		left_base = Vector2.RIGHT.rotated(orbit_angle + PI * 0.54 + idle_wave * 0.07) * (arm_len + idle_wave * 1.4)
		right_base = Vector2.RIGHT.rotated(orbit_angle - PI * 0.54 - idle_wave * 0.07) * (arm_len - idle_wave * 1.4)
		var left_idle_dir = left_base.normalized().rotated(-0.20 + idle_wave * 0.1)
		var right_idle_dir = right_base.normalized().rotated(0.20 - idle_wave * 0.1)
		left_fist = left_base + left_idle_dir * (8.0 + idle_wave_alt * 2.0 + punch_left_ext * 12.0)
		right_fist = right_base + right_idle_dir * (8.0 - idle_wave_alt * 2.0 + punch_right_ext * 12.0)
	
	if custom_punch_texture:
		_draw_scarf_arm(left_base, left_fist, punch_left_ext)
		_draw_scarf_arm(right_base, right_fist, punch_right_ext)
	else:
		draw_circle(left_fist, 8.0, Color(1.0, 0.72, 0.18) if punch_left_ext > 0.3 else Color(0.92, 0.48, 0.28))
		draw_circle(right_fist, 8.0, Color(1.0, 0.72, 0.18) if punch_right_ext > 0.3 else Color(0.92, 0.48, 0.28))
	
	_draw_charge_ui()

func _draw_special_dash_trails():
	if special_dash_trail_points.is_empty():
		return
	for trail in special_dash_trail_points:
		var max_life = max(float(trail.get("max_life", 0.34)), 0.01)
		var alpha = clamp(float(trail.get("life", 0.0)) / max_life, 0.0, 1.0)
		var local_pos: Vector2 = trail.get("pos", owner_ball.global_position) - owner_ball.global_position
		draw_circle(local_pos, 18.0 * alpha, Color(1.0, 0.78, 0.16, 0.20 * alpha))
		draw_arc(local_pos, 18.0 * alpha, 0, TAU, 20, Color(1.0, 0.92, 0.35, 0.34 * alpha), 1.6)

func _draw_punch_swooshes():
	for swoosh in punch_swooshes:
		var duration = max(float(swoosh.get("duration", 0.18)), 0.01)
		var fade = clamp(float(swoosh.get("time_left", 0.0)) / duration, 0.0, 1.0)
		var progress = 1.0 - fade
		var angle = float(swoosh.get("angle", attack_angle))
		var forward = Vector2.RIGHT.rotated(angle)
		var side_sign = 1.0 if bool(swoosh.get("is_left", true)) else -1.0
		var side = forward.rotated(PI * 0.5) * side_sign
		var color = Color(1.0, 0.76, 0.2)
		for i in range(3):
			var lane = float(i)
			var start = forward * (18.0 + progress * 18.0 + lane * 3.0) + side * (16.0 - lane * 5.0)
			var end = forward * (76.0 + progress * 18.0 + lane * 4.0) + side * (7.0 - lane * 3.0)
			draw_line(start, end, Color(color, (0.42 - lane * 0.09) * fade), 4.2 - lane)
		var fist_tip = forward * (92.0 + progress * 10.0) + side * 5.0
		draw_circle(fist_tip, 5.5 * fade, Color(1.0, 0.92, 0.48, 0.44 * fade))

func _draw_scarf_arm(base_pos: Vector2, fist_pos: Vector2, extension: float):
	if not custom_punch_texture:
		return
	var segment = fist_pos - base_pos
	var dir = segment.normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT.rotated(attack_angle)

	var ext = clamp(extension, 0.0, 1.0)
	var uniform_scale = max(punch_texture_size_multiplier, 0.1) * (1.0 + ext * 0.22)
	var alpha = 0.82 + ext * 0.18
	var draw_angle = dir.angle() + PI / 2.0

	# Texture is authored upright: top is the striking tip, bottom stays attached to the body.
	draw_set_transform(base_pos, draw_angle, Vector2.ONE * uniform_scale)
	draw_texture_rect(custom_punch_texture, Rect2(-punch_texture_size.x * 0.5, -punch_texture_size.y, punch_texture_size.x, punch_texture_size.y), false, Color(1, 1, 1, alpha))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_charge_ui():
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
		
		if i < charges_ready:
			fill = 1.0
		elif i == charges_ready and charges_ready < max_combo:
			fill = clamp(charge_recharge_timer / charge_recharge_time, 0.0, 1.0)
		
		draw_rect(bar_rect, Color(0.08, 0.08, 0.1, 0.88))
		if fill > 0:
			draw_rect(Rect2(bx, bar_y, bar_width * fill, bar_height), Color(0.95, 0.75, 0.25, 0.95) if fill >= 1.0 else Color(0.7, 0.6, 0.25, 0.8))
		draw_rect(bar_rect, Color(1, 1, 1, 0.18), false, 1.0)
	
	var s_bar_y = bar_y + bar_height + 3.0
	var s_rect = Rect2(start_x, s_bar_y, total_w, 4.0)
	draw_rect(s_rect, Color(0.08, 0.08, 0.1, 0.88))
	
	if special_cooldown <= 0.0:
		var pulse = 0.65 + sin(Time.get_ticks_msec() * 0.012) * 0.3
		draw_rect(Rect2(start_x, s_bar_y, total_w, 4.0), Color(1.0, 0.82, 0.05, pulse))
	else:
		var s_fill = clamp(1.0 - (special_cooldown / special_base_cooldown), 0.0, 1.0)
		draw_rect(Rect2(start_x, s_bar_y, total_w * s_fill, 4.0), Color(0.72, 0.45, 1.0, 0.94))
	draw_rect(s_rect, Color(1, 1, 1, 0.16), false, 1.0)
#endregion
