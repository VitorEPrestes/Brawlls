# Shelly - Escopeta (Shotgun) weapon.
# Fires 6 pellets per shot; full damage at close range.
# Pellets spread and lose damage over distance.
# Special: fires 3 large slow-pellets that slow any enemy hit.
class_name WeaponShelly extends WeaponBase

const SHELLY_ATTACK_SFX_STREAM = preload("res://sfx/shelly_attack.ogg")
const SHELLY_ULT_SFX_STREAM = preload("res://sfx/shelly_ulti.ogg")
const SHELLY_KILL_VOICE_STREAMS = [
	preload("res://sfx/voices/shelly/shelly_kill_01.ogg"),
	preload("res://sfx/voices/shelly/shelly_kill_02.ogg"),
	preload("res://sfx/voices/shelly/shelly_kill_03.ogg"),
	preload("res://sfx/voices/shelly/shelly_kill_04.ogg"),
	preload("res://sfx/voices/shelly/shelly_kill_05.ogg"),
]
const SHELLY_ULT_VOICE_STREAMS = [
	preload("res://sfx/voices/shelly/shelly_ulti_01.ogg"),
	preload("res://sfx/voices/shelly/shelly_ulti_02.ogg"),
	preload("res://sfx/voices/shelly/shelly_ulti_03.ogg"),
	preload("res://sfx/voices/shelly/shelly_ulti_04.ogg"),
]

# ==============================================================
# >>>  EDITABLE VALUES  <<<
# ==============================================================
var attack_range: float = 340.0        # Max range to start shooting
var pellet_count: int = 6              # Pellets per shot
var pellet_damage: float = 8.5         # Damage per pellet at point-blank
var pellet_speed: float = 620.0        # Pixels/s the pellet travels
var pellet_lifetime: float = 0.55      # How long a pellet lives (defines max range)
var pellet_spread: float = 20.0        # Half-angle spread in degrees at close range
var spread_scale: float = 3.5          # Multiplier applied to spread at max range
var damage_falloff_start: float = 0.35 # Fraction of lifetime where damage starts falling
var damage_falloff_min: float = 0.25   # Minimum damage fraction at max range

var shot_cooldown: float = 1.5         # Seconds between shots

# --- Ammo (3-charge system) ---
var max_ammo: int = 3                  # Max charges
var current_ammo: int = 3              # Current charges (starts full)
var ammo_recharge_time: float = 1.5    # Time to recharge one charge
var ammo_timer: float = 0.0            # Timer per charge
var shot_cooldown_timer: float = 0.0   # Minimum gap between consecutive shots

# --- Special (Big Slow Pellets) ---
var special_cooldown_time: float = 25.0  # Seconds between specials
var special_pellet_count: int = 6       # How many big pellets
var special_damage: float = 10.0        # Damage per big pellet on hit
var special_spread: float = 26.0        # Half-angle spread for big pellets
var special_pellet_radius: float = 45.0 # Hit radius for big pellets
var special_slow_amount: float = 0.20   # speed_modifier cap while slowed (0=stop, 1=normal)
var special_gravity_scale: float = 0.1  # Gravity scale while slowed (0=float)
var special_slow_duration: float = 2.2  # Seconds the slow lasts
var kill_voice_cooldown: float = 1.4

# ==============================================================
# >>>  EDITABLE ASSETS (Optional)  <<<
# ==============================================================
@export var custom_weapon_texture: Texture2D = null
@export var custom_attack_texture: Texture2D = null
@export var custom_super_texture: Texture2D = null
@export var weapon_texture_scale: float = 2.5
@export var attack_texture_scale: float = 1.75
@export var super_texture_scale: float = 2.75
# ==============================================================

# --- Internal State ---
var shot_timer: float = 0.0
var special_cooldown: float = 25.0   # Start fully depleted (equals special_cooldown_time)
var burst_in_progress: bool = false
var must_reload_full: bool = false
var super_trail_max_points: int = 10
var super_trail_spacing: float = 14.0
var super_trail_width: float = 18.0
var super_hit_spark_budget_per_frame: int = 2
var super_hit_sparks_this_frame: int = 0
var super_status_targets_this_frame: Dictionary = {}
var pellet_bounds_margin: float = 80.0
var attack_texture_size: Vector2 = Vector2.ZERO
var super_texture_size: Vector2 = Vector2.ZERO

var orbit_angle: float = 0.0
var orbit_speed: float = 2.2
var attack_sfx_player: AudioStreamPlayer2D = null
var ult_sfx_player: AudioStreamPlayer2D = null
var kill_voice_player: AudioStreamPlayer2D = null
var ult_voice_player: AudioStreamPlayer2D = null
var kill_voice_cooldown_timer: float = 0.0
var shotgun_kick_timer: float = 0.0
var shotgun_kick_duration: float = 0.18
var muzzle_flash_timer: float = 0.0
var muzzle_flash_duration: float = 0.16
var muzzle_flash_angle: float = 0.0
var muzzle_flash_is_special: bool = false

# Active pellets: {pos, dir, speed, time_left, lifetime, is_special}
var active_pellets: Array = []

func setup(owner: Node):
	super.setup(owner)
	weapon_name = "Shelly"
	orbit_angle = randf() * TAU
	current_ammo = max_ammo
	ammo_timer = 0.0
	special_cooldown = special_cooldown_time
	burst_in_progress = false
	must_reload_full = false
	_setup_sfx_players()
	_setup_voice_players()

	if custom_weapon_texture == null and ResourceLoader.exists("res://weapons/texturas/shelly_shotgun.png"):
		custom_weapon_texture = load("res://weapons/texturas/shelly_shotgun.png")
	if custom_attack_texture == null and ResourceLoader.exists("res://weapons/texturas/shelly_attack.png"):
		custom_attack_texture = load("res://weapons/texturas/shelly_attack.png")
	if custom_super_texture == null and ResourceLoader.exists("res://weapons/texturas/shelly_super.png"):
		custom_super_texture = load("res://weapons/texturas/shelly_super.png")
	_refresh_texture_cache()

func get_damage_indicator() -> float:
	return pellet_damage * float(pellet_count)

func _refresh_texture_cache():
	attack_texture_size = custom_attack_texture.get_size() if custom_attack_texture else Vector2.ZERO
	super_texture_size = custom_super_texture.get_size() if custom_super_texture else Vector2.ZERO

func process_weapon(delta: float):
	kill_voice_cooldown_timer = max(0.0, kill_voice_cooldown_timer - delta)
	shotgun_kick_timer = max(0.0, shotgun_kick_timer - delta)
	muzzle_flash_timer = max(0.0, muzzle_flash_timer - delta)
	orbit_angle += orbit_speed * delta
	special_cooldown = move_toward(special_cooldown, 0.0, delta)
	shot_cooldown_timer = move_toward(shot_cooldown_timer, 0.0, delta)

	# Ammo recharge (only ticks when not full)
	if current_ammo < max_ammo and not burst_in_progress:
		ammo_timer -= delta
		if ammo_timer <= 0.0:
			current_ammo += 1
			# Keep ticking for the next charge if still not full
			if current_ammo < max_ammo:
				ammo_timer = ammo_recharge_time
			else:
				ammo_timer = 0.0
				must_reload_full = false

	_process_pellets(delta)

	# Try special first
	if special_cooldown <= 0.0:
		var target = _find_nearest_target(attack_range)
		if target:
			_fire_special(target)
			special_cooldown = special_cooldown_time
			queue_redraw()
			return

	# Regular shot cycle: starts only when fully loaded, then spends all 3 bars.
	var can_shoot_regular = shot_cooldown_timer <= 0.0 and not must_reload_full and current_ammo > 0 and (burst_in_progress or current_ammo >= max_ammo)
	if can_shoot_regular:
		var target = _find_nearest_target(attack_range)
		if target:
			if not burst_in_progress:
				burst_in_progress = true
			_fire_shot(target)
			current_ammo -= 1
			shot_cooldown_timer = shot_cooldown

			if current_ammo <= 0:
				current_ammo = 0
				burst_in_progress = false
				must_reload_full = true

			# Start recharge timer once burst is finished.
			if not burst_in_progress and current_ammo < max_ammo and ammo_timer <= 0.0:
				ammo_timer = ammo_recharge_time

	queue_redraw()

# ---------------------------------------------------------------
func _fire_shot(target: Node):
	if not owner_ball or not owner_ball.is_inside_tree(): return
	_play_attack_sfx()
	var dir_vec = (target.global_position - owner_ball.global_position).normalized()
	orbit_angle = dir_vec.angle()
	_start_muzzle_flash(dir_vec, false)

	for i in range(pellet_count):
		var angle_offset = randf_range(-pellet_spread, pellet_spread)
		var pellet_dir = dir_vec.rotated(deg_to_rad(angle_offset))
		active_pellets.append({
			"pos": owner_ball.global_position + dir_vec * 36.0,
			"dir": pellet_dir,
			"speed": pellet_speed + randf_range(-40.0, 40.0),
			"time_left": pellet_lifetime,
			"lifetime": pellet_lifetime,
			"is_special": false,
			"last_pos": owner_ball.global_position + dir_vec * 36.0,
			"hit_targets": {}
		})

	# Kick-back
	if owner_ball is RigidBody2D:
		owner_ball.apply_central_impulse(-dir_vec * 200.0 * owner_ball.mass)
	_spawn_muzzle_flash(owner_ball.global_position + dir_vec * 36.0, Color(1.0, 0.72, 0.22))

func _fire_special(target: Node):
	if not owner_ball or not owner_ball.is_inside_tree(): return
	_play_ult_sfx()
	_play_ult_voice()
	var dir_vec = (target.global_position - owner_ball.global_position).normalized()
	orbit_angle = dir_vec.angle()
	_start_muzzle_flash(dir_vec, true)

	for i in range(special_pellet_count):
		var angle_offset = randf_range(-special_spread, special_spread)
		var pellet_dir = dir_vec.rotated(deg_to_rad(angle_offset))
		active_pellets.append({
			"pos": owner_ball.global_position + dir_vec * 36.0,
			"dir": pellet_dir,
			"speed": pellet_speed * 0.72,
			"time_left": pellet_lifetime * 1.5,
			"lifetime": pellet_lifetime * 1.5,
			"is_special": true,
			"last_pos": owner_ball.global_position + dir_vec * 36.0,
			"trail": [],
			"hit_targets": {}
		})

	# Bigger kick-back for special
	if owner_ball is RigidBody2D:
		owner_ball.apply_central_impulse(-dir_vec * 320.0 * owner_ball.mass)

	_spawn_muzzle_flash(owner_ball.global_position + dir_vec * 36.0, Color(0.8, 0.55, 1.0))

func _start_muzzle_flash(dir_vec: Vector2, is_special: bool):
	shotgun_kick_timer = shotgun_kick_duration
	muzzle_flash_timer = muzzle_flash_duration
	muzzle_flash_angle = dir_vec.angle()
	muzzle_flash_is_special = is_special

func _setup_sfx_players():
	if attack_sfx_player and is_instance_valid(attack_sfx_player):
		return
	attack_sfx_player = AudioStreamPlayer2D.new()
	attack_sfx_player.stream = SHELLY_ATTACK_SFX_STREAM
	attack_sfx_player.volume_db = -2.0
	add_child(attack_sfx_player)

	ult_sfx_player = AudioStreamPlayer2D.new()
	ult_sfx_player.stream = SHELLY_ULT_SFX_STREAM
	ult_sfx_player.volume_db = -2.0
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

func _play_attack_sfx():
	if not attack_sfx_player:
		return
	attack_sfx_player.pitch_scale = randf_range(0.98, 1.04)
	attack_sfx_player.play()

func _play_ult_sfx():
	if not ult_sfx_player:
		return
	ult_sfx_player.pitch_scale = randf_range(0.98, 1.03)
	ult_sfx_player.play()

func _play_kill_voice():
	_play_random_voice(kill_voice_player, SHELLY_KILL_VOICE_STREAMS)

func _play_ult_voice():
	_play_random_voice(ult_voice_player, SHELLY_ULT_VOICE_STREAMS)

# ---------------------------------------------------------------
func _process_pellets(delta: float):
	var parent = owner_ball.get_parent()
	if not parent: return

	var i = active_pellets.size() - 1
	var candidates = _get_ball_candidates()
	super_hit_sparks_this_frame = 0
	super_status_targets_this_frame.clear()
	while i >= 0:
		var p = active_pellets[i]
		p.time_left -= delta

		if p.time_left <= 0.0:
			active_pellets.remove_at(i)
			i -= 1
			continue

		# Age fraction (0 = just fired, 1 = about to expire)
		var age = 1.0 - (p.time_left / p.lifetime)

		# Spread grows with age for regular pellets (visual drift)
		var drift_angle = 0.0
		if not p.is_special:
			drift_angle = randf_range(-0.015, 0.015) * age * spread_scale

		var move_dir = p.dir.rotated(drift_angle)
		var previous_pos = p.pos
		p.pos += move_dir * p.speed * delta
		p["last_pos"] = previous_pos
		p.dir = (p.dir + move_dir * 0.2).normalized()  # slight steering toward drifted direction
		if p.is_special:
			_update_super_pellet_trail(p, previous_pos)
		if _is_world_pos_outside_arena(p.pos, pellet_bounds_margin):
			active_pellets.remove_at(i)
			i -= 1
			continue

		# Check hits
		var hit_something_destroy_pellet = false
		var hit_radius = special_pellet_radius if p.is_special else 18.0
		var hit_radius_sq = hit_radius * hit_radius
		for child in candidates:
			if not _is_valid_enemy(child):
				continue
			if p.hit_targets.has(child): continue

			if p.pos.distance_squared_to(child.global_position) <= hit_radius_sq:
				if not is_instance_valid(owner_ball): break
				var child_id = child.get_instance_id()
				var dmg = _calc_damage(p)
				child.take_damage(dmg, owner_ball)
				p.hit_targets[child] = true

				if p.is_special:
					if is_instance_valid(child) and not super_status_targets_this_frame.has(child_id):
						super_status_targets_this_frame[child_id] = true
						_apply_status_to(child, _status_id("shelly_slow", child), special_slow_duration, {
							"speed_cap": special_slow_amount,
							"gravity_scale": special_gravity_scale,
						})
					if super_hit_sparks_this_frame < super_hit_spark_budget_per_frame:
						super_hit_sparks_this_frame += 1
						_spawn_hit_spark(p.pos, Color(0.85, 0.6, 1.0), 3)
					# Projeteis especiais nao sao destruidos ao atingir (pierce)
				else:
					_spawn_hit_spark(p.pos, Color(1.0, 0.85, 0.4))
					hit_something_destroy_pellet = true
					break  # pellet normal consumido

		if hit_something_destroy_pellet:
			active_pellets.remove_at(i)
		else:
			active_pellets[i] = p
		
		i -= 1

func _calc_damage(p: Dictionary) -> float:
	if p.is_special:
		return special_damage

	var age = 1.0 - (p.time_left / p.lifetime)
	if age < damage_falloff_start:
		return pellet_damage
	var falloff_t = (age - damage_falloff_start) / (1.0 - damage_falloff_start)
	return pellet_damage * lerp(1.0, damage_falloff_min, falloff_t)

func _update_super_pellet_trail(p: Dictionary, trail_pos: Vector2):
	var trail: Array = p.get("trail", [])
	if trail.is_empty() or trail_pos.distance_squared_to(trail[trail.size() - 1]) >= super_trail_spacing * super_trail_spacing:
		trail.append(trail_pos)
	while trail.size() > super_trail_max_points:
		trail.remove_at(0)
	p["trail"] = trail

func _is_world_pos_outside_arena(world_pos: Vector2, margin: float) -> bool:
	if not is_instance_valid(owner_ball):
		return false
	var arena = owner_ball.get_parent()
	if not arena or not _has_node_property(arena, "arena_size"):
		return false
	var arena_size: Vector2 = arena.get("arena_size")
	var local_pos = arena.to_local(world_pos) if arena is Node2D else world_pos
	return not Rect2(Vector2.ZERO, arena_size).grow(margin).has_point(local_pos)

func _find_nearest_target(max_range: float) -> Node:
	return _find_nearest_enemy(max_range)

func on_owner_eliminated_target(target: Node):
	if kill_voice_cooldown_timer > 0.0:
		return
	kill_voice_cooldown_timer = kill_voice_cooldown
	if ult_voice_player and ult_voice_player.playing:
		ult_voice_player.stop()
	_play_kill_voice()

# ---------------------------------------------------------------
func _spawn_muzzle_flash(pos: Vector2, color: Color):
	var parent = owner_ball.get_parent()
	if not parent: return
	var particles = CPUParticles2D.new()
	particles.emitting = true
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = 14
	particles.lifetime = 0.18
	particles.direction = Vector2.RIGHT.rotated(orbit_angle)
	particles.spread = 35.0
	particles.initial_velocity_min = 80.0
	particles.initial_velocity_max = 200.0
	particles.gravity = Vector2.ZERO
	particles.scale_amount_min = 3.0
	particles.scale_amount_max = 7.0
	particles.color = color
	particles.global_position = pos
	parent.add_child(particles)
	owner_ball.get_tree().create_timer(0.8).timeout.connect(func():
		if is_instance_valid(particles): particles.queue_free()
	)

func _spawn_hit_spark(pos: Vector2, color: Color, amount: int = 6):
	var parent = owner_ball.get_parent()
	if not parent: return
	var particles = CPUParticles2D.new()
	particles.emitting = true
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = amount
	particles.lifetime = 0.18
	particles.direction = Vector2.ZERO
	particles.spread = 180.0
	particles.initial_velocity_min = 30.0
	particles.initial_velocity_max = 90.0
	particles.gravity = Vector2.ZERO
	particles.scale_amount_min = 2.0
	particles.scale_amount_max = 5.0
	particles.color = color
	particles.global_position = pos
	parent.add_child(particles)
	owner_ball.get_tree().create_timer(0.6).timeout.connect(func():
		if is_instance_valid(particles): particles.queue_free()
	)

# ---------------------------------------------------------------
func _draw():
	if not is_instance_valid(owner_ball): return
	var fx_scale = _short_video_fx_scale()

	# Draw active pellets
	for p in active_pellets:
		var local_pos = p.pos - owner_ball.global_position
		var age = 1.0 - (p.time_left / p.lifetime)
		var alpha = clamp(1.0 - age * 0.6, 0.3, 1.0)
		var draw_angle = p.dir.angle() + PI * 0.5
		var last_pos: Vector2 = p.get("last_pos", p.pos - p.dir * 10.0)
		var last_local = last_pos - owner_ball.global_position
		if p.is_special:
			_draw_super_pellet_trail(p, fx_scale, alpha)
			draw_line(last_local, local_pos, Color(0.86, 0.58, 1.0, alpha * 0.32), 7.0 * fx_scale, false)
			if custom_super_texture:
				var tex_size = super_texture_size
				draw_set_transform(local_pos, draw_angle, Vector2.ONE * super_texture_scale * fx_scale)
				draw_texture_rect(custom_super_texture, Rect2(-tex_size / 2.0, tex_size), false, Color(1.0, 1.0, 1.0, alpha))
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			else:
				var draw_radius = special_pellet_radius * 0.4 * fx_scale # Visual radius
				draw_circle(local_pos, draw_radius, Color(0.75, 0.45, 1.0, alpha))
				draw_arc(local_pos, draw_radius, 0, TAU, 16, Color(1.0, 0.9, 1.0, alpha * 0.8), max(2.0, 2.2 * fx_scale))
		else:
			draw_line(last_local, local_pos, Color(1.0, 0.75, 0.24, alpha * 0.34), 3.0 * fx_scale, false)
			if custom_attack_texture:
				var tex_size = attack_texture_size
				draw_set_transform(local_pos, draw_angle, Vector2.ONE * attack_texture_scale * fx_scale)
				draw_texture_rect(custom_attack_texture, Rect2(-tex_size / 2.0, tex_size), false, Color(1.0, 1.0, 1.0, alpha))
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			else:
				draw_circle(local_pos, 3.5 * fx_scale, Color(1.0, 0.85, 0.3, alpha))
				draw_arc(local_pos, 5.0 * fx_scale, 0, TAU, 14, Color(1.0, 1.0, 0.85, alpha * 0.35), 1.2)

	# Special ready pulse around the gun
	if special_cooldown <= 0.0:
		var pulse = 0.5 + sin(Time.get_ticks_msec() * 0.014) * 0.3
		draw_arc(Vector2.ZERO, 44.0, 0, TAU, 32, Color(0.75, 0.45, 1.0, pulse), 3.0)

	# Draw shotgun
	var kick = clamp(shotgun_kick_timer / max(shotgun_kick_duration, 0.01), 0.0, 1.0)
	var kick_curve = sin(kick * PI)
	var draw_angle = orbit_angle + kick_curve * 0.10
	var gun_dir = Vector2.RIGHT.rotated(draw_angle)
	var gun_pos = Vector2.RIGHT.rotated(orbit_angle) * (38.0 - kick * 12.0)
	if custom_weapon_texture:
		draw_set_transform(gun_pos, draw_angle, Vector2.ONE * weapon_texture_scale)
		var tex_size = custom_weapon_texture.get_size()
		draw_texture_rect(custom_weapon_texture, Rect2(-tex_size/2, tex_size), false)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		var dir_vec = gun_dir
		var perp = dir_vec.rotated(PI/2)
		# Barrel (wide tube)
		var barrel_len = 30.0
		var barrel_w = 7.0
		var barrel_start = gun_pos - dir_vec * 6.0
		var barrel_end = gun_pos + dir_vec * barrel_len
		var barrel_pts = PackedVector2Array([
			barrel_start - perp * barrel_w,
			barrel_start + perp * barrel_w,
			barrel_end + perp * (barrel_w * 0.55),
			barrel_end - perp * (barrel_w * 0.55),
		])
		draw_colored_polygon(barrel_pts, Color(0.22, 0.22, 0.28))
		# Stock
		var stock_pts = PackedVector2Array([
			gun_pos - dir_vec * 20.0 - perp * 8.0,
			gun_pos - dir_vec * 20.0 + perp * 8.0,
			gun_pos + perp * 6.0,
			gun_pos - perp * 6.0,
		])
		draw_colored_polygon(stock_pts, Color(0.55, 0.35, 0.18))
		# Pump grip (orange-tan)
		var grip_center = gun_pos + dir_vec * 6.0
		draw_rect(Rect2(grip_center - perp * 5.0 - dir_vec * 5.0, Vector2(10.0, 10.0)), Color(0.7, 0.5, 0.28))
		# Muzzle line
		draw_line(barrel_end - perp * (barrel_w * 0.55), barrel_end + perp * (barrel_w * 0.55), Color(0.9, 0.9, 0.9), 2.5)
	_draw_muzzle_flash()

	# --- UI Bars ---
	var bar_y = 40.0
	var bar_w = 56.0
	var bar_h = 5.0
	var bx = -bar_w / 2.0

	# 3 Ammo charge bars
	var charge_w = (bar_w - 2.0) / max_ammo  # gap of 1px between each
	for ci in range(max_ammo):
		var cx = bx + ci * (charge_w + 1.0)
		draw_rect(Rect2(cx, bar_y, charge_w, bar_h), Color(0.1, 0.1, 0.12, 0.85))
		if ci < current_ammo:
			# Fully charged slot
			draw_rect(Rect2(cx, bar_y, charge_w, bar_h), Color(0.95, 0.75, 0.25, 0.95))
		elif ci == current_ammo and current_ammo < max_ammo:
			# Slot currently recharging - show partial fill
			var recharge_fill = clamp(1.0 - ammo_timer / ammo_recharge_time, 0.0, 1.0)
			if recharge_fill > 0:
				draw_rect(Rect2(cx, bar_y, charge_w * recharge_fill, bar_h), Color(0.7, 0.6, 0.25, 0.8))
		draw_rect(Rect2(cx, bar_y, charge_w, bar_h), Color(1, 1, 1, 0.18), false, 1.0)

	# Special cooldown bar
	var s_bar_y = bar_y + bar_h + 3.0
	draw_rect(Rect2(bx, s_bar_y, bar_w, 4.0), Color(0.08, 0.08, 0.12, 0.88))
	if special_cooldown <= 0.0:
		var pulse = 0.6 + sin(Time.get_ticks_msec() * 0.012) * 0.35
		draw_rect(Rect2(bx, s_bar_y, bar_w, 4.0), Color(0.75, 0.45, 1.0, pulse))
	else:
		var s_fill = clamp(1.0 - special_cooldown / special_cooldown_time, 0.0, 1.0)
		draw_rect(Rect2(bx, s_bar_y, bar_w * s_fill, 4.0), Color(0.65, 0.35, 0.95, 0.9))
	draw_rect(Rect2(bx, s_bar_y, bar_w, 4.0), Color(1, 1, 1, 0.16), false, 1.0)

func _draw_muzzle_flash():
	if muzzle_flash_timer <= 0.0:
		return
	var fade = clamp(muzzle_flash_timer / max(muzzle_flash_duration, 0.01), 0.0, 1.0)
	var dir = Vector2.RIGHT.rotated(muzzle_flash_angle)
	var side = dir.rotated(PI * 0.5)
	var muzzle_pos = dir * 63.0
	var color = Color(0.84, 0.58, 1.0) if muzzle_flash_is_special else Color(1.0, 0.68, 0.18)
	var length = (46.0 if muzzle_flash_is_special else 34.0) * fade
	var width = (28.0 if muzzle_flash_is_special else 22.0) * fade
	var points = PackedVector2Array([
		muzzle_pos - side * width * 0.28,
		muzzle_pos + side * width * 0.28,
		muzzle_pos + dir * length + side * width * 0.55,
		muzzle_pos + dir * (length * 1.18),
		muzzle_pos + dir * length - side * width * 0.55,
	])
	draw_colored_polygon(points, Color(color, 0.32 * fade))
	for i in range(5):
		var lane = (float(i) - 2.0) / 2.0
		var ray_dir = dir.rotated(lane * (0.18 if muzzle_flash_is_special else 0.13))
		draw_line(muzzle_pos, muzzle_pos + ray_dir * length * (0.7 + abs(lane) * 0.22), Color(1.0, 0.92, 0.62, 0.42 * fade), 1.4)
	draw_circle(muzzle_pos, 5.5 * fade, Color(1.0, 0.95, 0.78, 0.72 * fade))

func _draw_super_pellet_trail(p: Dictionary, fx_scale: float, alpha: float):
	var trail: Array = p.get("trail", [])
	if trail.is_empty():
		return
	var next_pos: Vector2 = p.pos
	var trail_size = trail.size()
	for i in range(trail_size - 1, -1, -1):
		var point: Vector2 = trail[i]
		var t = float(i + 1) / float(trail_size + 1)
		var local_point = point - owner_ball.global_position
		var local_next = next_pos - owner_ball.global_position

		# Outer glow (wide, faint purple)
		var glow_w = max(4.0, super_trail_width * 2.2 * t * fx_scale)
		draw_line(local_point, local_next, Color(0.72, 0.28, 1.0, alpha * t * 0.18), glow_w, false)

		# Mid band (purple-pink gradient by lerping color)
		var mid_color = Color(0.88, 0.44, 1.0).lerp(Color(1.0, 0.62, 0.92), 1.0 - t)
		var mid_w = max(2.5, super_trail_width * t * fx_scale)
		draw_line(local_point, local_next, Color(mid_color, alpha * t * 0.65), mid_w, false)

		# Bright core (white-pink, thin)
		var core_w = max(1.2, super_trail_width * 0.35 * t * fx_scale)
		draw_line(local_point, local_next, Color(1.0, 0.88, 1.0, alpha * t * 0.85), core_w, false)

		# Sparkle dots along the trail
		if i % 2 == 0:
			var spark_pos = local_point.lerp(local_next, 0.5)
			var spark_r = randf_range(1.2, 3.0) * t * fx_scale
			draw_circle(spark_pos, spark_r, Color(1.0, 0.78, 1.0, alpha * t * 0.55))

		next_pos = point
