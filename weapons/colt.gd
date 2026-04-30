# Colt - dual revolver marksman with slow tracking bursts and a charged super.
class_name WeaponColt extends WeaponBase

const PROJECTILE_COLOR = Color(0.98, 0.82, 0.38)
const SUPER_PROJECTILE_COLOR = Color(1.0, 0.58, 0.24)
const SUPER_TRAIL_COLOR = Color(0.48, 0.87, 1.0)

const COLT_ATK_SFX_STREAM = preload("res://sfx/colt_atk.wav")
const COLT_ULT_SFX_STREAM = preload("res://sfx/colt_ult.ogg")
const COLT_KILL_VOICE_STREAMS = [
	preload("res://sfx/voices/colt/colt_kill_01.ogg"),
	preload("res://sfx/voices/colt/colt_kill_02.ogg"),
	preload("res://sfx/voices/colt/colt_kill_03.ogg"),
	preload("res://sfx/voices/colt/colt_kill_04.ogg"),
	preload("res://sfx/voices/colt/colt_kill_05.ogg"),
	preload("res://sfx/voices/colt/colt_kill_06.ogg"),
	preload("res://sfx/voices/colt/colt_kill_07.ogg"),
]
const COLT_ULT_VOICE_STREAMS = [
	preload("res://sfx/voices/colt/colt_ulti_01.ogg"),
	preload("res://sfx/voices/colt/colt_ulti_02.ogg"),
	preload("res://sfx/voices/colt/colt_ulti_03.ogg"),
	preload("res://sfx/voices/colt/colt_ulti_04.ogg"),
]

# ==============================================================
# >>>  EDITABLE VALUES  <<<
# ==============================================================

# --- Basic attack ---
var attack_range: float = 365.0         # Max range to start shooting
var basic_burst_shots: int = 8          # Shots per burst
var basic_damage: float = 4             # Damage per bullet
var basic_projectile_speed: float = 680.0 # Bullet speed (px/s)
var basic_projectile_range: float = 350.0 # Max travel distance per bullet
var basic_windup: float = 0.38          # Delay before first shot fires (s)
var basic_shot_interval: float = 0.11   # Time between shots in a burst (s)
var basic_turn_speed: float = 4.0       # Aim tracking speed during basic attack
var basic_lead_strength: float = 0.92   # How much to lead moving targets (0–1)
var shot_cooldown: float = 1.2          # Cooldown after a burst ends (s)

# --- Ammo ---
var max_ammo: int = 3                   # Max burst charges
var ammo_recharge_time: float = 1.55    # Time to recharge one charge (s)

# --- Super ---
var hits_for_super: int = 12            # Hits needed to charge super
var super_seek_range: float = 430.0     # Range at which super auto-targets
var super_burst_shots: int = 30         # Bullets fired during super burst
var super_damage: float = 5             # Damage per super bullet
var super_projectile_speed: float = 760.0 # Super bullet speed (px/s)
var super_projectile_range: float = 470.0 # Max travel distance per super bullet
var super_windup: float = 0.58          # Delay before super burst starts (s)
var super_shot_interval: float = 0.09   # Time between shots in super burst (s)
var super_turn_speed: float = 2.25      # Aim tracking speed during super
var super_lead_strength: float = 1.0    # Lead multiplier for super bullets
var super_recovery: float = 0.4         # Recovery time after super burst ends (s)

# ==============================================================
# >>>  EDITABLE ASSETS (Optional)  <<<
# ==============================================================
@export var custom_weapon_texture: Texture2D = null
@export var custom_attack_texture: Texture2D = null
@export var custom_super_texture: Texture2D = null
@export var weapon_texture_scale: float = 2.0
@export var attack_projectile_texture_scale: float = 2.6
@export var super_projectile_texture_scale: float = 2.4
@export var super_trail_max_points: int = 32
@export var super_trail_min_spacing: float = 6.0
@export var super_trail_width: float = 22.0

var projectile_scene: PackedScene = preload("res://Projectile.tscn")

var current_ammo: int = 3
var ammo_timer: float = 0.0
var burst_in_progress: bool = false
var must_reload_full: bool = false

var state: String = "ready"
var state_timer: float = 0.0
var cooldown_timer: float = 0.0
var aim_target: Node = null
var orbit_angle: float = 0.0
var orbit_speed: float = 2.0
var burst_shots_remaining: int = 0
var shot_timer: float = 0.0
var tracked_hits: int = 0
var super_ready: bool = false
var using_super_burst: bool = false
var shot_side_sign: float = -1.0
var active_projectiles: Array = []
var active_muzzle_flashes: Array = []
var muzzle_flash_timer: float = 0.0
var left_recoil_timer: float = 0.0
var right_recoil_timer: float = 0.0
var recoil_duration: float = 0.12
var recoil_strength: float = 6.0
var shot_flash_duration: float = 0.11
var aim_glow_timer: float = 0.0
var aim_glow_duration: float = 0.22
var kill_voice_player: AudioStreamPlayer2D = null
var ult_voice_player: AudioStreamPlayer2D = null
var kill_voice_cooldown: float = 1.4
var kill_voice_cooldown_timer: float = 0.0

func setup(owner: Node):
	super.setup(owner)
	weapon_name = "Colt"
	orbit_angle = randf() * TAU
	current_ammo = max_ammo
	ammo_timer = 0.0
	burst_in_progress = false
	must_reload_full = false
	_setup_voice_players()
	if custom_weapon_texture == null and ResourceLoader.exists("res://weapons/texturas/colt_pistol.png"):
		custom_weapon_texture = load("res://weapons/texturas/colt_pistol.png")
	if custom_attack_texture == null and ResourceLoader.exists("res://weapons/texturas/colt_attack.png"):
		custom_attack_texture = load("res://weapons/texturas/colt_attack.png")
	if custom_super_texture == null and ResourceLoader.exists("res://weapons/texturas/colt_super.png"):
		custom_super_texture = load("res://weapons/texturas/colt_super.png")

func get_damage_indicator() -> float:
	return super_damage * float(super_burst_shots) if super_ready else basic_damage * float(basic_burst_shots)

func on_projectile_hit(body: Node, dmg: float):
	if using_super_burst or state == "super_windup" or state == "super_burst" or state == "super_recovery":
		return
	if not is_instance_valid(body):
		return
	tracked_hits += 1
	if tracked_hits >= hits_for_super:
		tracked_hits = hits_for_super
		super_ready = true

func process_weapon(delta: float):
	if not is_instance_valid(owner_ball) or not owner_ball.is_inside_tree():
		return

	kill_voice_cooldown_timer = max(0.0, kill_voice_cooldown_timer - delta)
	muzzle_flash_timer = max(0.0, muzzle_flash_timer - delta)
	aim_glow_timer = max(0.0, aim_glow_timer - delta)
	left_recoil_timer = max(0.0, left_recoil_timer - delta)
	right_recoil_timer = max(0.0, right_recoil_timer - delta)
	if current_ammo < max_ammo and not burst_in_progress and state != "super_windup" and state != "super_burst" and state != "super_recovery":
		ammo_timer = max(0.0, ammo_timer - delta)
		if ammo_timer <= 0.0:
			current_ammo += 1
			if current_ammo < max_ammo:
				ammo_timer = ammo_recharge_time
			else:
				ammo_timer = 0.0
				must_reload_full = false
	_process_projectiles()
	_process_muzzle_flashes(delta)
	if state == "ready":
		orbit_angle += orbit_speed * delta

	match state:
		"ready":
			_state_ready()
		"basic_windup":
			_state_basic_windup(delta)
		"basic_burst":
			_state_burst(delta, false)
		"super_windup":
			_state_super_windup(delta)
		"super_burst":
			_state_burst(delta, true)
		"super_recovery":
			_state_super_recovery(delta)
		"cooldown":
			_state_cooldown(delta)

	queue_redraw()

func _state_ready():
	if super_ready:
		var special_target = _find_nearest_target(super_seek_range)
		if special_target:
			_start_super(special_target)
			return

	var can_start_basic = not must_reload_full and current_ammo > 0 and (burst_in_progress or current_ammo >= max_ammo)
	if not can_start_basic:
		return

	var target = _find_nearest_target(attack_range)
	if target:
		_start_basic_attack(target)

func _state_basic_windup(delta: float):
	_track_target(delta, basic_turn_speed)
	state_timer -= delta
	if state_timer <= 0.0:
		state = "basic_burst"
		shot_timer = 0.0

func _state_super_windup(delta: float):
	_hold_owner_still()
	_track_target(delta, super_turn_speed)
	state_timer -= delta
	if state_timer <= 0.0:
		state = "super_burst"
		shot_timer = 0.0

func _state_burst(delta: float, is_super: bool):
	if is_super:
		_hold_owner_still()
	var turn_speed = super_turn_speed if is_super else basic_turn_speed
	_track_target(delta, turn_speed)
	shot_timer -= delta
	if shot_timer > 0.0:
		return

	if burst_shots_remaining <= 0:
		if is_super:
			state = "super_recovery"
			state_timer = super_recovery
		else:
			state = "cooldown"
			cooldown_timer = shot_cooldown
		return

	_fire_shot(is_super)
	burst_shots_remaining -= 1
	shot_timer = super_shot_interval if is_super else basic_shot_interval

	if burst_shots_remaining <= 0:
		if is_super:
			state = "super_recovery"
			state_timer = super_recovery
		else:
			state = "cooldown"
			cooldown_timer = shot_cooldown

func _state_super_recovery(delta: float):
	_hold_owner_still()
	state_timer -= delta
	if state_timer <= 0.0:
		state = "cooldown"
		cooldown_timer = shot_cooldown

func _state_cooldown(delta: float):
	cooldown_timer -= delta
	if cooldown_timer <= 0.0:
		state = "ready"
		using_super_burst = false

func _start_basic_attack(target: Node):
	aim_target = target
	burst_shots_remaining = basic_burst_shots
	using_super_burst = false
	if not burst_in_progress:
		burst_in_progress = true
	current_ammo = max(0, current_ammo - 1)
	if current_ammo <= 0:
		current_ammo = 0
		burst_in_progress = false
		must_reload_full = true
	if current_ammo < max_ammo and ammo_timer <= 0.0:
		ammo_timer = ammo_recharge_time
	state = "basic_windup"
	state_timer = basic_windup
	aim_glow_timer = aim_glow_duration
	_set_attack_angle_to_target(target, basic_projectile_speed, basic_lead_strength)

func _start_super(target: Node):
	aim_target = target
	burst_shots_remaining = super_burst_shots
	using_super_burst = true
	super_ready = false
	tracked_hits = 0
	burst_in_progress = false
	must_reload_full = current_ammo < max_ammo
	state = "super_windup"
	state_timer = super_windup
	aim_glow_timer = aim_glow_duration
	_set_attack_angle_to_target(target, super_projectile_speed, super_lead_strength)
	_play_ult_voice()

func _fire_shot(is_super: bool):
	if not is_instance_valid(owner_ball) or not owner_ball.is_inside_tree():
		return
	var parent = owner_ball.get_parent()
	if not parent:
		return

	var projectile = projectile_scene.instantiate()
	var dir = Vector2.RIGHT.rotated(orbit_angle)
	var fired_side_sign = shot_side_sign
	var side_offset = Vector2(-dir.y, dir.x) * 11.0 * fired_side_sign
	var muzzle_pos = owner_ball.global_position + dir * 34.0 + side_offset
	parent.add_child(projectile)
	projectile.global_position = muzzle_pos
	projectile.setup(dir, owner_ball, super_damage if is_super else basic_damage, 0.0, SUPER_PROJECTILE_COLOR if is_super else PROJECTILE_COLOR)
	projectile.speed = super_projectile_speed if is_super else basic_projectile_speed
	var chosen_texture = custom_super_texture if is_super else custom_attack_texture
	projectile.custom_texture = chosen_texture
	if chosen_texture:
		var tex_scale = super_projectile_texture_scale if is_super else attack_projectile_texture_scale
		projectile.texture_draw_scale = tex_scale
		projectile.texture_rotation_offset = PI / 2.0
	var trail: Line2D = null
	if is_super:
		trail = _spawn_super_trail(parent, muzzle_pos)
	active_projectiles.append({
		"proj": projectile,
		"start_pos": muzzle_pos,
		"max_distance": super_projectile_range if is_super else basic_projectile_range,
		"trail": trail,
	})
	_attach_sfx_to_projectile(projectile, is_super)
	_register_muzzle_flash(muzzle_pos, dir, fired_side_sign, is_super)
	if fired_side_sign < 0.0:
		right_recoil_timer = recoil_duration
	else:
		left_recoil_timer = recoil_duration
	shot_side_sign *= -1.0
	muzzle_flash_timer = 0.08

	if owner_ball is RigidBody2D:
		var recoil = 95.0 if is_super else 70.0
		owner_ball.apply_central_impulse(-dir * recoil * owner_ball.mass)

func _register_muzzle_flash(world_pos: Vector2, dir: Vector2, fired_side_sign: float, is_super: bool):
	active_muzzle_flashes.append({
		"pos": world_pos,
		"dir": dir,
		"side": fired_side_sign,
		"time_left": shot_flash_duration,
		"duration": shot_flash_duration,
		"is_super": is_super,
	})
	var color = SUPER_PROJECTILE_COLOR if is_super else PROJECTILE_COLOR
	_spawn_directional_particles(
		world_pos,
		dir,
		Color(color, 0.92),
		8 if is_super else 5,
		0.16,
		26.0,
		80.0 if is_super else 55.0,
		220.0 if is_super else 150.0,
		2.0,
		5.0 if is_super else 3.8
	)

func _process_muzzle_flashes(delta: float):
	var i = active_muzzle_flashes.size() - 1
	while i >= 0:
		var flash = active_muzzle_flashes[i]
		flash["time_left"] = float(flash.get("time_left", 0.0)) - delta
		if flash["time_left"] <= 0.0:
			active_muzzle_flashes.remove_at(i)
		else:
			active_muzzle_flashes[i] = flash
		i -= 1

func _process_projectiles():
	var spacing_sq = super_trail_min_spacing * super_trail_min_spacing
	var i = active_projectiles.size() - 1
	while i >= 0:
		var item = active_projectiles[i]
		var projectile = item["proj"]
		var trail = item.get("trail")
		if not is_instance_valid(projectile) or not projectile.is_active:
			if trail != null and is_instance_valid(trail):
				_fade_and_free_trail(trail)
			active_projectiles.remove_at(i)
			i -= 1
			continue
		if trail != null and is_instance_valid(trail):
			var pos = projectile.global_position
			var pts_count = trail.get_point_count()
			if pts_count == 0 or trail.get_point_position(pts_count - 1).distance_squared_to(pos) >= spacing_sq:
				trail.add_point(pos)
				if trail.get_point_count() > super_trail_max_points:
					trail.remove_point(0)
		var max_distance = float(item["max_distance"])
		if projectile.global_position.distance_squared_to(item["start_pos"]) >= max_distance * max_distance:
			if trail != null and is_instance_valid(trail):
				_fade_and_free_trail(trail)
			projectile._deactivate()
			active_projectiles.remove_at(i)
		i -= 1

func _spawn_super_trail(parent: Node, start_pos: Vector2) -> Line2D:
	var line := Line2D.new()
	line.top_level = true
	line.width = super_trail_width
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	var grad := Gradient.new()
	grad.set_color(0, Color(SUPER_TRAIL_COLOR.r, SUPER_TRAIL_COLOR.g, SUPER_TRAIL_COLOR.b, 0.0))
	grad.set_color(1, Color(SUPER_TRAIL_COLOR.r, SUPER_TRAIL_COLOR.g, SUPER_TRAIL_COLOR.b, 0.85))
	line.gradient = grad
	parent.add_child(line)
	line.add_point(start_pos)
	return line

func _fade_and_free_trail(trail: Line2D):
	if not is_instance_valid(trail):
		return
	var tween = trail.create_tween()
	tween.tween_property(trail, "modulate:a", 0.0, 0.26)
	tween.tween_callback(trail.queue_free)

func _track_target(delta: float, turn_speed: float):
	if not _is_valid_target(aim_target):
		aim_target = _find_nearest_target(super_seek_range if using_super_burst or state == "super_windup" else attack_range)
		if not _is_valid_target(aim_target):
			return
	var predicted_angle = _get_target_aim_angle(aim_target, super_projectile_speed if using_super_burst or state == "super_windup" else basic_projectile_speed, super_lead_strength if using_super_burst or state == "super_windup" else basic_lead_strength)
	if predicted_angle == null:
		return
	orbit_angle = lerp_angle(orbit_angle, predicted_angle, min(1.0, delta * turn_speed))

func _set_attack_angle_to_target(target: Node, projectile_speed: float, lead_strength: float):
	var predicted_angle = _get_target_aim_angle(target, projectile_speed, lead_strength)
	if predicted_angle == null:
		return
	orbit_angle = predicted_angle

func _get_target_aim_angle(target: Node, projectile_speed: float, lead_strength: float):
	if not _is_valid_target(target):
		return null
	var origin = owner_ball.global_position
	var target_pos = target.global_position
	var travel_time = origin.distance_to(target_pos) / max(projectile_speed, 1.0)
	travel_time = clamp(travel_time * lead_strength, 0.0, 0.55)
	var target_velocity = Vector2.ZERO
	if _has_node_property(target, "linear_velocity"):
		target_velocity = target.linear_velocity
	var predicted_pos = target_pos + target_velocity * travel_time
	var dir = predicted_pos - origin
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT.rotated(randf() * TAU)
	return dir.angle()

func _hold_owner_still():
	if _has_node_property(owner_ball, "speed_modifier"):
		owner_ball.speed_modifier = 0.0
	if owner_ball is RigidBody2D:
		owner_ball.linear_velocity = Vector2.ZERO
		owner_ball.angular_velocity = 0.0

func _find_nearest_target(max_range: float) -> Node:
	return _find_nearest_enemy(max_range)

func _is_valid_target(target: Node) -> bool:
	return _is_valid_enemy(target)

func on_owner_eliminated_target(target: Node):
	if kill_voice_cooldown_timer > 0.0:
		return
	kill_voice_cooldown_timer = kill_voice_cooldown
	if ult_voice_player and ult_voice_player.playing:
		ult_voice_player.stop()
	_play_kill_voice()

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
	_play_random_voice(kill_voice_player, COLT_KILL_VOICE_STREAMS)

func _play_ult_voice():
	_play_random_voice(ult_voice_player, COLT_ULT_VOICE_STREAMS)

func _attach_sfx_to_projectile(projectile: Node, is_super: bool):
	var sfx = AudioStreamPlayer2D.new()
	sfx.stream = COLT_ULT_SFX_STREAM if is_super else COLT_ATK_SFX_STREAM
	sfx.volume_db = -4.0 if is_super else -3.0
	sfx.pitch_scale = randf_range(0.97, 1.05)
	sfx.autoplay = true
	projectile.add_child(sfx)

func _draw_aim_glow(forward: Vector2, accent: Color):
	if state != "basic_windup" and state != "super_windup":
		return
	var total = super_windup if state == "super_windup" else basic_windup
	var progress = 1.0 - clamp(state_timer / max(total, 0.01), 0.0, 1.0)
	var max_len = super_projectile_range if state == "super_windup" else basic_projectile_range
	var line_len = lerp(64.0, max_len * 0.82, progress)
	var start = forward * 32.0
	var end = forward * line_len
	var pulse = 0.74 + sin(Time.get_ticks_msec() * 0.03) * 0.18
	var alpha = (0.22 + progress * 0.42) * pulse
	draw_line(start, end, Color(accent, alpha * 0.48), lerp(2.0, 5.0, progress))
	draw_line(start, end, Color(1.0, 0.96, 0.7, alpha * 0.32), 1.2)
	draw_arc(end, lerp(7.0, 14.0, progress), 0.0, TAU, 22, Color(accent, alpha), 1.8)

func _draw_muzzle_flashes():
	for flash in active_muzzle_flashes:
		var duration = max(float(flash.get("duration", shot_flash_duration)), 0.01)
		var fade = clamp(float(flash.get("time_left", 0.0)) / duration, 0.0, 1.0)
		var local_pos: Vector2 = flash.get("pos", owner_ball.global_position) - owner_ball.global_position
		var dir: Vector2 = flash.get("dir", Vector2.RIGHT.rotated(orbit_angle))
		if dir == Vector2.ZERO:
			dir = Vector2.RIGHT.rotated(orbit_angle)
		var side = dir.rotated(PI * 0.5)
		var is_super = bool(flash.get("is_super", false))
		var color = SUPER_PROJECTILE_COLOR if is_super else PROJECTILE_COLOR
		var length = lerp(8.0, 24.0 if is_super else 18.0, fade)
		var width = (10.0 if is_super else 7.0) * fade
		var flash_points = PackedVector2Array([
			local_pos - side * width * 0.45 - dir * 3.0,
			local_pos + side * width * 0.55,
			local_pos + dir * length,
			local_pos - side * width * 0.55,
		])
		draw_colored_polygon(flash_points, Color(color, 0.46 * fade))
		draw_circle(local_pos, (6.0 if is_super else 4.2) * fade, Color(1.0, 0.96, 0.72, 0.75 * fade))
		draw_line(local_pos, local_pos + dir * (42.0 if is_super else 30.0) * fade, Color(1.0, 0.9, 0.48, 0.34 * fade), 1.2)

func _draw():
	if not is_instance_valid(owner_ball):
		return
	var forward = Vector2.RIGHT.rotated(orbit_angle)
	var side = Vector2(-forward.y, forward.x)
	var center = forward * 22.0
	var left_origin = center + side * 9.0
	var right_origin = center - side * 9.0
	var barrel_length = 18.0
	var body_color = Color(0.18, 0.2, 0.24, 0.95)
	var accent = SUPER_PROJECTILE_COLOR if super_ready else PROJECTILE_COLOR
	_draw_aim_glow(forward, accent)

	if custom_weapon_texture:
		var tex_size = custom_weapon_texture.get_size()
		var tex_rect = Rect2(-tex_size / 2.0, tex_size)
		var left_recoil_amt = (left_recoil_timer / recoil_duration) * recoil_strength
		var right_recoil_amt = (right_recoil_timer / recoil_duration) * recoil_strength
		var left_pos = left_origin - forward * left_recoil_amt
		var right_pos = right_origin - forward * right_recoil_amt
		draw_set_transform(left_pos, orbit_angle - left_recoil_amt * 0.018, Vector2.ONE * weapon_texture_scale)
		draw_texture_rect(custom_weapon_texture, tex_rect, false)
		draw_set_transform(right_pos, orbit_angle + right_recoil_amt * 0.018, Vector2.ONE * weapon_texture_scale)
		draw_texture_rect(custom_weapon_texture, tex_rect, false)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		draw_line(left_origin, left_origin + forward * barrel_length, body_color, 5.0)
		draw_line(right_origin, right_origin + forward * barrel_length, body_color, 5.0)
		draw_circle(left_origin, 5.0, body_color)
		draw_circle(right_origin, 5.0, body_color)
		draw_circle(left_origin + forward * (barrel_length + 1.0), 2.4, accent)
		draw_circle(right_origin + forward * (barrel_length + 1.0), 2.4, accent)

	_draw_muzzle_flashes()

	var bar_width = 38.0
	var bar_y = 40.0
	var bar_h = 5.0
	var bx = -bar_width / 2.0
	var charge_w = (bar_width - 2.0) / max_ammo
	for ci in range(max_ammo):
		var cx = bx + ci * (charge_w + 1.0)
		draw_rect(Rect2(cx, bar_y, charge_w, bar_h), Color(0.1, 0.1, 0.12, 0.85))
		if ci < current_ammo:
			draw_rect(Rect2(cx, bar_y, charge_w, bar_h), Color(0.95, 0.75, 0.25, 0.95))
		elif ci == current_ammo and current_ammo < max_ammo:
			var recharge_fill = clamp(1.0 - ammo_timer / ammo_recharge_time, 0.0, 1.0)
			if recharge_fill > 0.0:
				draw_rect(Rect2(cx, bar_y, charge_w * recharge_fill, bar_h), Color(0.72, 0.6, 0.26, 0.84))
		draw_rect(Rect2(cx, bar_y, charge_w, bar_h), Color(1.0, 1.0, 1.0, 0.18), false, 1.0)

	var charge_ratio = clamp(float(tracked_hits) / float(max(hits_for_super, 1)), 0.0, 1.0)
	var charge_bg = Rect2(Vector2(-bar_width * 0.5, -47.0), Vector2(bar_width, 4.0))
	var charge_fg = Rect2(charge_bg.position, Vector2(bar_width * charge_ratio, charge_bg.size.y))
	draw_rect(charge_bg, Color(0.05, 0.05, 0.08, 0.55))
	draw_rect(charge_fg, Color(1.0, 0.62, 0.2, 0.9))
	draw_rect(charge_bg, Color(1.0, 1.0, 1.0, 0.16), false, 1.0)
	if super_ready:
		draw_arc(Vector2.ZERO, 42.0, 0.0, TAU, 36, Color(1.0, 0.58, 0.24, 0.75), 2.0)
