# Laquê de Cabelo (Hairspray) weapon - shoots persistent smoke clouds.
# Only attacks when an enemy is in range. Uses a 3-charge system.
# Special: Creates an aura around itself that slows enemies and deals DoT.
class_name WeaponHairspray extends WeaponBase

const HAIRSPRAY_ATTACK_SFX_STREAM = preload("res://sfx/Hairspray_attack_sfx.mp3")
const HAIRSPRAY_ULT_SFX_STREAM = preload("res://sfx/Hairspray_ult_sfx.ogg")
const HAIRSPRAY_KILL_VOICE_STREAMS = [
	preload("res://sfx/voices/hairspray/emz_kill_vo_01.ogg"),
	preload("res://sfx/voices/hairspray/emz_kill_vo_02.ogg"),
	preload("res://sfx/voices/hairspray/emz_kill_vo_03.ogg"),
	preload("res://sfx/voices/hairspray/emz_kill_vo_04.ogg"),
	preload("res://sfx/voices/hairspray/emz_kill_vo_06.ogg"),
]
const HAIRSPRAY_ULT_VOICE_STREAMS = [
	preload("res://sfx/voices/hairspray/emz_ulti_vo_01.ogg"),
]

# ==============================================================
# >>>  EDITABLE VALUES  <<<
# ==============================================================
var max_combo: int = 3                 # Number of shots per combo
var combo_interval: float = 1.2       # Delay between shots
var charge_recharge_time: float = 1.5  # Rest per used shot

var attack_range: float = 300.0        # Will only fire if an enemy is within this range
var smoke_distance: float = 50.0       # How far from the ball the smoke starts
var smoke_travel: float = 150.0        # How far the smoke travels before stopping
var smoke_radius: float = 90.0         # Size of the smoke cloud
var smoke_duration: float = 2          # How long the smoke cloud persists in the air
var smoke_speed: float = 120.0         # Smoke movement speed
var smoke_dps: float = 22.0            # Damage per second to enemies inside the smoke
var smoke_damage_tick: float = 0.25    # Applies smoke damage in intervals to avoid per-frame lag
var smoke_chain_ratio: float = 0.75    # Secondary and tertiary smoke travel/size scale
var smoke_side_variation: float = 28.0 # Random left/right offset each spray
var smoke_forward_variation: float = 12.0 # Random forward/back offset each spray
var smoke_spread_degrees: float = 16.0 # Random angle spread for secondary smokes
var smoke_rotation_speed_min: float = 0.8 # Minimum spin speed after launch (rad/s)
var smoke_rotation_speed_max: float = 2.2 # Maximum spin speed after launch (rad/s)
var max_active_smokes: int = 22          # Safety cap to avoid runaway frame cost in larger battles

# --- Special Aura ---
var hits_for_special: int = 5          # Number of smoke ticks to trigger special
var special_duration: float = 5.0      # How long the aura lasts around the ball
var special_radius: float = 175.0      # Size of the special aura
var special_dps: float = 6.0           # Damage per second of the aura
var special_slow: float = 1          # Enemies in aura: max speed_modifier = (1 - special_slow)
var special_slow_drag: float = 8.0     # Extra brake so the aura slow feels immediate.
var special_gravity_scale: float = 0.0 # Owner gravity during special (float effect)
var special_status_refresh_interval: float = 0.08
var special_status_duration: float = 0.18
var kill_voice_cooldown: float = 1.4

# ==============================================================
# >>>  EDITABLE ASSETS (Optional)  <<<
# ==============================================================
@export var custom_weapon_texture: Texture2D = null
@export var custom_smoke_texture: Texture2D = null
@export var custom_super_texture: Texture2D = null
@export var smoke_texture_opacity: float = 0.45
@export var smoke_texture_size_multiplier: float = 1.2
@export var super_texture_opacity: float = 0.46
@export var super_texture_rotation_speed: float = 0.65
# ==============================================================

# --- Internal State ---
var combo_index: int = 0
var combo_timer: float = 0.0
var cooldown_timer: float = 0.0
var aim_target: Node = null
var state: String = "ready"
var total_hits: int = 0

var special_timer: float = 0.0
var is_special_active: bool = false
var special_owner_effect_id: String = ""
var special_status_timer: float = 0.0

var orbit_angle: float = 0.0
var orbit_speed: float = 2.0

var active_smokes: Array = [] # {pos, dir, time_left, traveled, max_travel, radius, radius_sq, rot, rot_speed}
var smoke_damage_timer: float = 0.0
var super_visual: Sprite2D = null
var smoke_texture_size: Vector2 = Vector2.ZERO
var smoke_texture_longest_side: float = 1.0
var super_texture_size: Vector2 = Vector2.ZERO
var super_texture_longest_side: float = 1.0
var attack_sfx_player: AudioStreamPlayer2D = null
var ult_sfx_player: AudioStreamPlayer2D = null
var kill_voice_player: AudioStreamPlayer2D = null
var ult_voice_player: AudioStreamPlayer2D = null
var kill_voice_cooldown_timer: float = 0.0
var spray_burst_timer: float = 0.0
var spray_burst_duration: float = 0.24
var spray_burst_angle: float = 0.0

func setup(owner: Node):
	super.setup(owner)
	weapon_name = "Laquê"
	orbit_angle = randf() * TAU
	_setup_attack_sfx_player()
	_setup_ult_sfx_player()
	_setup_voice_players()

	if custom_smoke_texture == null and ResourceLoader.exists("res://weapons/texturas/hairspray.png"):
		custom_smoke_texture = load("res://weapons/texturas/hairspray.png")
	if custom_super_texture == null and ResourceLoader.exists("res://weapons/texturas/hairspray_super.png"):
		custom_super_texture = load("res://weapons/texturas/hairspray_super.png")
	_refresh_texture_cache()
	_setup_super_visual()

func get_damage_indicator() -> float:
	return special_dps if is_special_active else smoke_dps

func _refresh_texture_cache():
	smoke_texture_size = custom_smoke_texture.get_size() if custom_smoke_texture else Vector2.ZERO
	smoke_texture_longest_side = max(max(smoke_texture_size.x, smoke_texture_size.y), 1.0)
	super_texture_size = custom_super_texture.get_size() if custom_super_texture else Vector2.ZERO
	super_texture_longest_side = max(max(super_texture_size.x, super_texture_size.y), 1.0)

func _exit_tree():
	if special_owner_effect_id != "":
		_clear_status_from(owner_ball, special_owner_effect_id)
		special_owner_effect_id = ""
	if super_visual and is_instance_valid(super_visual):
		super_visual.queue_free()
	super_visual = null

func _setup_super_visual():
	if not is_instance_valid(owner_ball):
		return
	if not custom_super_texture:
		return
	if super_visual and is_instance_valid(super_visual):
		return
	
	super_visual = Sprite2D.new()
	super_visual.texture = custom_super_texture
	super_visual.centered = true
	super_visual.visible = false
	super_visual.show_behind_parent = true
	super_visual.modulate = Color(1, 1, 1, clamp(super_texture_opacity, 0.0, 1.0))
	owner_ball.add_child(super_visual)
	_update_super_visual()

func _update_super_visual():
	if not super_visual or not is_instance_valid(super_visual):
		return
	if not custom_super_texture:
		return
	var target_diameter = special_radius * 2.0
	var tex_scale = target_diameter / super_texture_longest_side
	super_visual.position = Vector2.ZERO
	super_visual.scale = Vector2.ONE * tex_scale
	super_visual.modulate = Color(1, 1, 1, clamp(super_texture_opacity, 0.0, 1.0))

func process_weapon(delta: float):
	orbit_angle += orbit_speed * delta
	kill_voice_cooldown_timer = max(0.0, kill_voice_cooldown_timer - delta)
	spray_burst_timer = max(0.0, spray_burst_timer - delta)
	
	match state:
		"ready":
			_state_ready(delta)
		"combo_wait":
			_state_combo_wait(delta)
		"cooldown":
			_state_cooldown(delta)
	
	_process_smokes(delta)
	_process_special_aura(delta)
	if is_special_active and super_visual and is_instance_valid(super_visual):
		super_visual.rotation += super_texture_rotation_speed * delta
	queue_redraw()

func _state_ready(delta: float):
	var target = _find_nearest_target(attack_range)
	if target:
		combo_index = 0
		_fire(target)
		combo_index += 1
		state = "combo_wait"
		combo_timer = combo_interval

func _state_combo_wait(delta: float):
	combo_timer -= delta
	if combo_timer <= 0:
		var target = _find_nearest_target(attack_range)
		if target:
			_fire(target)
			combo_index += 1
			if combo_index >= max_combo:
				state = "cooldown"
				cooldown_timer = combo_index * charge_recharge_time
			else:
				state = "combo_wait"
				combo_timer = combo_interval
		else:
			state = "cooldown"
			cooldown_timer = combo_index * charge_recharge_time

func _state_cooldown(delta: float):
	cooldown_timer -= delta
	if cooldown_timer <= 0:
		state = "ready"

func _fire(target: Node):
	if not owner_ball or not owner_ball.is_inside_tree(): return
	var parent = owner_ball.get_parent()
	if not parent: return
	_play_attack_sfx()

	# Aim at the target
	var dir_vec = (target.global_position - owner_ball.global_position).normalized()
	orbit_angle = dir_vec.angle()
	spray_burst_angle = orbit_angle
	spray_burst_timer = spray_burst_duration
	var base_pos = owner_ball.global_position + dir_vec * smoke_distance
	var perp = dir_vec.rotated(PI * 0.5)
	var angle_spread = deg_to_rad(smoke_spread_degrees)

	var main_pos = base_pos \
		+ perp * randf_range(-smoke_side_variation, smoke_side_variation) \
		+ dir_vec * randf_range(-smoke_forward_variation, smoke_forward_variation)
	_add_smoke(main_pos, dir_vec.rotated(randf_range(-angle_spread * 0.35, angle_spread * 0.35)), 1.0, 1.0)

	var second_scale = smoke_chain_ratio
	var second_pos = main_pos \
		+ perp * randf_range(-smoke_side_variation * 0.9, smoke_side_variation * 0.9) \
		+ dir_vec * randf_range(-smoke_forward_variation, smoke_forward_variation)
	_add_smoke(second_pos, dir_vec.rotated(randf_range(-angle_spread, angle_spread)), second_scale, second_scale)

	var third_scale = smoke_chain_ratio * smoke_chain_ratio
	var second_dir = (second_pos - owner_ball.global_position).normalized()
	if second_dir == Vector2.ZERO:
		second_dir = dir_vec
	var third_pos = second_pos \
		+ perp * randf_range(-smoke_side_variation * 0.7, smoke_side_variation * 0.7) \
		+ second_dir * randf_range(-smoke_forward_variation * 0.8, smoke_forward_variation * 0.8)
	_add_smoke(third_pos, dir_vec.rotated(randf_range(-angle_spread * 1.2, angle_spread * 1.2)), third_scale, third_scale)

	# Push ball back slightly
	if owner_ball is RigidBody2D:
		owner_ball.apply_central_impulse(-dir_vec * 150.0 * owner_ball.mass)
	_spawn_directional_particles(
		owner_ball.global_position + dir_vec * 45.0,
		dir_vec,
		Color(1.0, 0.42, 0.82, 0.78),
		7,
		0.18,
		28.0,
		45.0,
		130.0,
		2.0,
		4.4
	)

func _setup_attack_sfx_player():
	if attack_sfx_player and is_instance_valid(attack_sfx_player):
		return
	attack_sfx_player = AudioStreamPlayer2D.new()
	attack_sfx_player.stream = HAIRSPRAY_ATTACK_SFX_STREAM
	attack_sfx_player.volume_db = 2.0
	add_child(attack_sfx_player)

func _play_attack_sfx():
	if not attack_sfx_player:
		return
	attack_sfx_player.pitch_scale = randf_range(0.97, 1.04)
	attack_sfx_player.play()

func _setup_ult_sfx_player():
	if ult_sfx_player and is_instance_valid(ult_sfx_player):
		return
	ult_sfx_player = AudioStreamPlayer2D.new()
	ult_sfx_player.stream = HAIRSPRAY_ULT_SFX_STREAM
	ult_sfx_player.volume_db = -4.0
	add_child(ult_sfx_player)

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
	_play_random_voice(kill_voice_player, HAIRSPRAY_KILL_VOICE_STREAMS)

func _play_ult_voice():
	_play_random_voice(ult_voice_player, HAIRSPRAY_ULT_VOICE_STREAMS)

func _add_smoke(spawn_pos: Vector2, smoke_dir: Vector2, travel_scale: float, size_scale: float):
	if active_smokes.size() >= max_active_smokes:
		active_smokes.remove_at(0)
	var safe_scale = max(size_scale, 0.1)
	var smoke_radius_value = smoke_radius * safe_scale
	var rotation_dir = -1.0 if randf() < 0.5 else 1.0
	var rotation_speed = randf_range(smoke_rotation_speed_min, smoke_rotation_speed_max) * rotation_dir
	active_smokes.append({
		"pos": spawn_pos,
		"dir": smoke_dir.normalized(),
		"time_left": smoke_duration,
		"traveled": 0.0,
		"max_travel": smoke_travel * max(travel_scale, 0.1),
		"radius": smoke_radius_value,
		"radius_sq": smoke_radius_value * smoke_radius_value,
		"rot": randf() * TAU,
		"rot_speed": rotation_speed
	})

func _process_smokes(delta: float):
	var parent = owner_ball.get_parent()
	if not parent: return
	
	var i = active_smokes.size() - 1
	while i >= 0:
		var smoke = active_smokes[i]
		smoke.time_left -= delta
		smoke.rot += smoke.rot_speed * delta
		smoke.rot_speed = move_toward(smoke.rot_speed, 0.0, delta * 0.8)
		# Advance smoke only while it hasn't reached max travel distance
		if smoke.traveled < smoke.max_travel:
			var step = smoke_speed * delta
			var remaining = max(smoke.max_travel - smoke.traveled, 0.0)
			var move_amount = min(step, remaining)
			smoke.pos += smoke.dir * move_amount
			smoke.traveled += move_amount
		
		if smoke.time_left <= 0:
			active_smokes.remove_at(i)
		i -= 1

	if active_smokes.is_empty():
		return

	var tick = max(smoke_damage_tick, 0.05)
	smoke_damage_timer -= delta
	if smoke_damage_timer > 0.0:
		return
	var elapsed = tick + abs(min(smoke_damage_timer, 0.0))
	smoke_damage_timer = tick

	for child in _get_ball_candidates():
		if not _is_valid_enemy(child):
			continue
		var target_pos = child.global_position
		var inside_any_smoke = false
		for smoke in active_smokes:
			if target_pos.distance_squared_to(smoke.pos) <= smoke.radius_sq:
				inside_any_smoke = true
				break
		if inside_any_smoke:
			var dmg = smoke_dps * elapsed
			child.take_damage(dmg, owner_ball)
			_register_hit(1)

func _register_hit(amount: int = 1):
	if is_special_active: return
	total_hits += amount
	if total_hits >= hits_for_special:
		total_hits = 0
		_activate_special()

func _activate_special():
	is_special_active = true
	special_timer = special_duration
	special_status_timer = 0.0
	_play_ult_sfx()
	_play_ult_voice()
	_setup_super_visual()
	if super_visual and is_instance_valid(super_visual):
		_update_super_visual()
		super_visual.visible = true
	
	special_owner_effect_id = _status_id("hairspray_float")
	_apply_status_to(owner_ball, special_owner_effect_id, special_duration + 0.1, {
		"gravity_scale": special_gravity_scale,
	})
	
	# Visual pop
	var particles = CPUParticles2D.new()
	particles.emitting = true
	particles.one_shot = true
	particles.amount = 20
	particles.lifetime = 0.5
	particles.direction = Vector2.ZERO
	particles.spread = 180.0
	particles.initial_velocity_min = 100.0
	particles.initial_velocity_max = 300.0
	particles.gravity = Vector2.ZERO
	particles.scale_amount_min = 4.0
	particles.scale_amount_max = 8.0
	particles.color = Color(1.0, 0.4, 0.8)
	particles.global_position = owner_ball.global_position
	owner_ball.get_parent().add_child(particles)
	owner_ball.get_tree().create_timer(1.0).timeout.connect(func():
		if is_instance_valid(particles): particles.queue_free()
	)

func on_owner_eliminated_target(target: Node):
	if kill_voice_cooldown_timer > 0.0:
		return
	kill_voice_cooldown_timer = kill_voice_cooldown
	if ult_voice_player and ult_voice_player.playing:
		ult_voice_player.stop()
	_play_kill_voice()

func _process_special_aura(delta: float):
	if not is_special_active: return
	if not is_instance_valid(owner_ball): return
	var parent = owner_ball.get_parent()
	if not parent: return
	
	special_timer -= delta
	if special_timer <= 0:
		is_special_active = false
		if super_visual and is_instance_valid(super_visual):
			super_visual.visible = false
		_clear_status_from(owner_ball, special_owner_effect_id)
		special_owner_effect_id = ""
		return
	
	special_status_timer = max(0.0, special_status_timer - delta)
	var refresh_status = special_status_timer <= 0.0
	if refresh_status:
		special_status_timer = special_status_refresh_interval
		
	var special_radius_sq = special_radius * special_radius
	for child in _get_ball_candidates():
		if not _is_valid_enemy(child):
			continue
		var dist_sq = owner_ball.global_position.distance_squared_to(child.global_position)
		if dist_sq <= special_radius_sq:
			# Damage over time
			child.take_damage(special_dps * delta, owner_ball)
			if child is RigidBody2D:
				child.linear_velocity = child.linear_velocity.lerp(Vector2.ZERO, clamp(delta * special_slow_drag, 0.0, 1.0))
			if refresh_status:
				_apply_status_to(child, _status_id("hairspray_aura", child), special_status_duration, {
					"speed_cap": max(0.0, 1.0 - special_slow),
					"visual": "slow",
					"visual_color": Color(1.0, 0.32, 0.82, 0.85),
				})

func _find_nearest_target(max_range: float) -> Node:
	return _find_nearest_enemy(max_range)

func _draw():
	if not is_instance_valid(owner_ball): return
	
	# Draw active smokes
	for smoke in active_smokes:
		var local_pos = smoke.pos - owner_ball.global_position
		var alpha = min(smoke.time_left, 0.5) * 2.0 # Fade out
		
		if custom_smoke_texture:
			var target_diameter = smoke.radius * 2.0 * max(smoke_texture_size_multiplier, 0.1)
			var tex_scale = target_diameter / smoke_texture_longest_side
			draw_set_transform(local_pos, smoke.rot, Vector2.ONE * tex_scale)
			draw_texture_rect(custom_smoke_texture, Rect2(-smoke_texture_size/2, smoke_texture_size), false, Color(1, 1, 1, alpha * clamp(smoke_texture_opacity, 0.0, 1.0)))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		else:
			draw_circle(local_pos, smoke.radius, Color(0.8, 0.8, 0.9, alpha * 0.6))
			draw_circle(local_pos + Vector2(10, 10), smoke.radius * 0.8, Color(0.9, 0.9, 1.0, alpha * 0.7))
			draw_circle(local_pos + Vector2(-15, 5), smoke.radius * 0.7, Color(0.7, 0.7, 0.8, alpha * 0.5))

	# Draw special aura
	if is_special_active:
		if custom_super_texture:
			if super_visual and is_instance_valid(super_visual):
				super_visual.visible = true
		else:
			var alpha = clamp(super_texture_opacity, 0.0, 1.0)
			draw_circle(Vector2.ZERO, special_radius, Color(1.0, 0.3, 0.7, alpha))
			draw_arc(Vector2.ZERO, special_radius, 0, TAU, 32, Color(1.0, 0.5, 0.8, alpha * 1.35), 3.0)

	# Draw Hairspray Can
	var spray_kick = clamp(spray_burst_timer / max(spray_burst_duration, 0.01), 0.0, 1.0)
	var spray_kick_curve = sin(spray_kick * PI)
	var draw_angle = orbit_angle - spray_kick_curve * 0.10
	var pos = Vector2.RIGHT.rotated(orbit_angle) * (36.0 - spray_kick * 7.0)
	
	if custom_weapon_texture:
		draw_set_transform(pos, draw_angle, Vector2.ONE * (1.0 + spray_kick_curve * 0.05))
		var tex_size = custom_weapon_texture.get_size()
		draw_texture_rect(custom_weapon_texture, Rect2(-tex_size/2, tex_size), false)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		var dir_vec = Vector2.RIGHT.rotated(draw_angle)
		var perp = dir_vec.rotated(PI/2)
		var can_length = 24.0
		var can_width = 10.0
		
		var back = pos - dir_vec * (can_length/2)
		var front = pos + dir_vec * (can_length/2)
		
		var body_points = PackedVector2Array([
			back - perp * can_width,
			back + perp * can_width,
			front + perp * can_width,
			front - perp * can_width,
		])
		# Main body (pinkish)
		draw_colored_polygon(body_points, Color(0.9, 0.4, 0.6))
		
		# Cap (white)
		var cap_points = PackedVector2Array([
			front - perp * (can_width * 0.8),
			front + perp * (can_width * 0.8),
			front + dir_vec * 6.0 + perp * (can_width * 0.8),
			front + dir_vec * 6.0 - perp * (can_width * 0.8),
		])
		draw_colored_polygon(cap_points, Color(0.95, 0.95, 0.95))
		
		# Nozzle
		draw_circle(front + dir_vec * 8.0, 3.0, Color(0.4, 0.4, 0.4))
	_draw_spray_burst()

	# UI Charge Bars
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
		
		if state == "ready":
			fill = 1.0
		elif state == "combo_wait":
			var charges_remaining = max_combo - combo_index
			if i < charges_remaining: fill = 1.0
		elif state == "cooldown":
			var total_cooldown = combo_index * charge_recharge_time
			var elapsed = total_cooldown - cooldown_timer
			var fully_recharged_now = floor(elapsed / charge_recharge_time)
			var total_full = (max_combo - combo_index) + fully_recharged_now
			
			if i < total_full: fill = 1.0
			elif i == total_full: fill = fmod(elapsed, charge_recharge_time) / charge_recharge_time
		
		draw_rect(bar_rect, Color(0.12, 0.12, 0.12, 0.85))
		if fill > 0:
			draw_rect(Rect2(bx, bar_y, bar_width * fill, bar_height), Color(0.95, 0.75, 0.25, 0.95) if fill >= 1.0 else Color(0.7, 0.6, 0.25, 0.8))
		draw_rect(bar_rect, Color(0.5, 0.5, 0.5, 0.5), false, 1.0)
		
	# Special Bar
	var s_bar_y = bar_y + bar_height + 3.0
	var s_rect = Rect2(start_x, s_bar_y, total_w, 3.0)
	draw_rect(s_rect, Color(0.1, 0.1, 0.1, 0.85))
	var s_fill = float(total_hits) / float(hits_for_special)
	if s_fill > 0 and not is_special_active:
		draw_rect(Rect2(start_x, s_bar_y, total_w * min(s_fill, 1.0), 3.0), Color(1.0, 0.3, 0.7, 0.9))
	elif is_special_active:
		draw_rect(Rect2(start_x, s_bar_y, total_w * (special_timer / special_duration), 3.0), Color(1.0, 0.8, 0.2, 0.9))
	draw_rect(s_rect, Color(0.5, 0.5, 0.5, 0.4), false, 1.0)

func _draw_spray_burst():
	if spray_burst_timer <= 0.0:
		return
	var fade = clamp(spray_burst_timer / max(spray_burst_duration, 0.01), 0.0, 1.0)
	var progress = 1.0 - fade
	var dir = Vector2.RIGHT.rotated(spray_burst_angle)
	var side = dir.rotated(PI * 0.5)
	var nozzle_pos = dir * 52.0
	var jet_len = lerp(34.0, 82.0, progress)
	var jet_width = lerp(8.0, 30.0, progress)
	draw_colored_polygon(PackedVector2Array([
		nozzle_pos - side * jet_width * 0.25,
		nozzle_pos + side * jet_width * 0.25,
		nozzle_pos + dir * jet_len + side * jet_width,
		nozzle_pos + dir * jet_len - side * jet_width,
	]), Color(1.0, 0.38, 0.78, 0.18 * fade))
	for i in range(6):
		var t = float(i) / 5.0
		var wobble = sin(Time.get_ticks_msec() * 0.015 + float(i) * 1.7) * 0.5
		var bubble_pos = nozzle_pos + dir * (jet_len * t) + side * (wobble + float(i % 2) - 0.5) * jet_width * t
		var radius = lerp(2.0, 8.0, t) * fade
		draw_circle(bubble_pos, radius, Color(1.0, 0.62, 0.9, (0.42 - t * 0.18) * fade))
	draw_line(nozzle_pos, nozzle_pos + dir * jet_len, Color(1.0, 0.82, 0.94, 0.35 * fade), 2.0)
