# Cactus weapon - combo shooter.
# Fires a projectile that splits into fragments.
# Aims before firing. Charges up attacks like Shovel.
# Special: Creates an AoE zone that slows enemies, does DoT, and heals Cactus.
class_name WeaponCactus extends WeaponBase

const SPIKE_ATTACK_SFX_STREAM = preload("res://sfx/spike_atk_01.ogg")
const SPIKE_SPLIT_SFX_STREAM = preload("res://sfx/spike_atk_projectile.ogg")
const SPIKE_SUPER_SFX_STREAM = preload("res://sfx/spike_super.ogg")

# ==============================================================
# >>>  EDITABLE VALUES  <<<
# ==============================================================
var max_combo: int = 3                 # Number of shots per combo
var combo_interval: float = 1        # Delay between shots
var charge_recharge_time: float = 1.2  # Rest per used shot (slower than shovel)

var base_damage: float = 26.0
var large_projectile_damage: float = 18.0
var proj_speed: float = 400.0
var split_distance: float = 220.0
var split_count: int = 6
var fragment_damage_multiplier: float = 0.35 # Fragments do 25% damage

var aim_duration: float = 0.5          # How long to aim before shooting

# --- Special Zone (Thorn Patch) ---
var hits_for_special: int = 6          # Projectile hits to trigger special
var special_zone_radius: float = 120.0
var special_zone_duration: float = 5.0
var special_zone_dps: float = 8.0     # Damage per second inside zone
var special_zone_slow: float = 0.90    # Reduces speed by 90% (easier to escape)
var special_lifesteal_pct: float = 0.40 # Heals 40% of DoT dealt
var zone_status_refresh_interval: float = 0.08
var zone_status_duration: float = 0.18

# ==============================================================
# >>>  EDITABLE ASSETS (Optional)  <<<
# ==============================================================
@export var custom_weapon_texture: Texture2D = null
@export var custom_projectile_texture: Texture2D = null
@export var custom_fragment_texture: Texture2D = null
# ==============================================================

# --- Internal State ---
var combo_index: int = 0
var combo_timer: float = 0.0
var cooldown_timer: float = 0.0
var aim_timer: float = 0.0
var aim_target: Node = null
var state: String = "ready"
var total_hits: int = 0

var projectile_scene: PackedScene = preload("res://Projectile.tscn")
var orbit_angle: float = 0.0
var orbit_speed: float = 2.0

var active_projectiles: Array = []
var active_zones: Array = [] # {pos: Vector2, time_left: float}
var active_split_rings: Array = []
var zone_status_timer: float = 0.0
var attack_sfx_player: AudioStreamPlayer2D = null
var split_sfx_player: AudioStreamPlayer2D = null
var super_sfx_player: AudioStreamPlayer2D = null
var launch_flash_timer: float = 0.0
var launch_flash_duration: float = 0.18
var launch_flash_angle: float = 0.0
var launcher_kick_timer: float = 0.0
var launcher_kick_duration: float = 0.16

func setup(owner: Node):
	super.setup(owner)
	weapon_name = "Cacto"
	orbit_angle = randf() * TAU
	_setup_sfx_players()
	
	if custom_projectile_texture == null and ResourceLoader.exists("res://weapons/texturas/cacto_projetil.png"):
		custom_projectile_texture = load("res://weapons/texturas/cacto_projetil.png")
	if custom_fragment_texture == null and ResourceLoader.exists("res://weapons/texturas/cacto_fragmento.png"):
		custom_fragment_texture = load("res://weapons/texturas/cacto_fragmento.png")

func _setup_sfx_players():
	if attack_sfx_player and is_instance_valid(attack_sfx_player):
		return
	attack_sfx_player = AudioStreamPlayer2D.new()
	attack_sfx_player.stream = SPIKE_ATTACK_SFX_STREAM
	attack_sfx_player.volume_db = -1.5
	add_child(attack_sfx_player)

	split_sfx_player = AudioStreamPlayer2D.new()
	split_sfx_player.stream = SPIKE_SPLIT_SFX_STREAM
	split_sfx_player.volume_db = -2.0
	add_child(split_sfx_player)

	super_sfx_player = AudioStreamPlayer2D.new()
	super_sfx_player.stream = SPIKE_SUPER_SFX_STREAM
	super_sfx_player.volume_db = -2.0
	add_child(super_sfx_player)

func _play_attack_sfx():
	if not attack_sfx_player:
		return
	attack_sfx_player.pitch_scale = randf_range(0.97, 1.03)
	attack_sfx_player.play()

func _play_split_sfx():
	if not split_sfx_player:
		return
	split_sfx_player.pitch_scale = randf_range(0.98, 1.02)
	split_sfx_player.play()

func _play_super_sfx():
	if not super_sfx_player:
		return
	super_sfx_player.pitch_scale = randf_range(0.98, 1.03)
	super_sfx_player.play()

func on_projectile_hit(body: Node, dmg: float):
	if is_equal_approx(dmg, large_projectile_damage):
		_play_split_sfx()
	total_hits += 1
	if total_hits >= hits_for_special:
		total_hits = 0
		_spawn_special_zone(body.global_position)

func get_damage_indicator() -> float:
	return large_projectile_damage

func process_weapon(delta: float):
	launch_flash_timer = max(0.0, launch_flash_timer - delta)
	launcher_kick_timer = max(0.0, launcher_kick_timer - delta)
	match state:
		"ready":
			_state_ready(delta)
		"aiming":
			_state_aiming(delta)
		"combo_wait":
			_state_combo_wait(delta)
		"cooldown":
			_state_cooldown(delta)
	
	if state != "aiming":
		orbit_angle += orbit_speed * delta
		
	_process_projectiles()
	_process_zones(delta)
	_process_split_rings(delta)
	queue_redraw()

func _state_ready(delta: float):
	var target = _find_nearest_target()
	if target:
		combo_index = 0
		aim_target = target
		aim_timer = aim_duration
		state = "aiming"

func _state_aiming(delta: float):
	if is_instance_valid(aim_target) and aim_target.is_alive:
		var dir = (aim_target.global_position - owner_ball.global_position).normalized()
		orbit_angle = dir.angle()
	
	aim_timer -= delta
	if aim_timer <= 0:
		if is_instance_valid(aim_target) and aim_target.is_alive:
			_fire()
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
			aim_target = null

func _state_combo_wait(delta: float):
	combo_timer -= delta
	if combo_timer <= 0:
		var target = _find_nearest_target()
		if target:
			aim_target = target
			aim_timer = 0.2 # Shorter aim for follow-up shots
			state = "aiming"
		else:
			state = "cooldown"
			cooldown_timer = combo_index * charge_recharge_time

func _state_cooldown(delta: float):
	cooldown_timer -= delta
	if cooldown_timer <= 0:
		state = "ready"

func _fire():
	if not owner_ball or not owner_ball.is_inside_tree(): return
	var parent = owner_ball.get_parent()
	if not parent: return
	_play_attack_sfx()
	
	var dir = Vector2(cos(orbit_angle), sin(orbit_angle))
	launch_flash_angle = orbit_angle
	launch_flash_timer = launch_flash_duration
	launcher_kick_timer = launcher_kick_duration
	_spawn_directional_particles(
		owner_ball.global_position + dir * 34.0,
		dir,
		Color(0.45, 1.0, 0.32, 0.88),
		9,
		0.2,
		32.0,
		65.0,
		180.0,
		2.0,
		4.8
	)
	
	# Small recoil impulse
	if owner_ball is RigidBody2D:
		owner_ball.apply_central_impulse(-dir * 200.0 * owner_ball.mass)
	
	var proj = projectile_scene.instantiate()
	parent.add_child(proj)
	proj.global_position = owner_ball.global_position + dir * 30.0
	proj.setup(dir, owner_ball, large_projectile_damage, 0.0, Color(0.1, 0.7, 0.2))
	proj.speed = proj_speed
	proj.custom_texture = custom_projectile_texture
	proj.split_on_wall = true
	proj.on_wall_split = _split_projectile
	
	active_projectiles.append({
		"proj": proj,
		"start_pos": proj.global_position
	})

func _process_projectiles():
	var i = active_projectiles.size() - 1
	while i >= 0:
		var item = active_projectiles[i]
		var proj = item["proj"]
		
		if not is_instance_valid(proj) or not proj.is_active:
			active_projectiles.remove_at(i)
			i -= 1
			continue
			
		var dist_sq = proj.global_position.distance_squared_to(item["start_pos"])
		if dist_sq >= split_distance * split_distance:
			_split_projectile(proj)
			active_projectiles.remove_at(i)
		i -= 1

func _split_projectile(parent_proj: Node):
	if not is_instance_valid(parent_proj): return
	var parent = parent_proj.get_parent()
	if not parent: return
	_play_split_sfx()
	
	var split_pos = parent_proj.global_position
	active_split_rings.append({
		"pos": split_pos,
		"time_left": 0.34,
		"duration": 0.34,
	})
	var base_angle = parent_proj.direction.angle()
	var angle_step = TAU / split_count
	var frag_damage = base_damage * fragment_damage_multiplier
	
	for i in range(split_count):
		var angle = base_angle + i * angle_step
		var dir = Vector2(cos(angle), sin(angle))
		
		var frag = projectile_scene.instantiate()
		parent.add_child(frag)
		frag.global_position = split_pos
		frag.setup(dir, owner_ball, frag_damage, 0.0, Color(0.4, 0.9, 0.5))
		frag.speed = proj_speed * 1.2
		frag.custom_texture = custom_fragment_texture
		frag.texture_outline_color = Color(1.0, 1.0, 1.0, 0.95)
		frag.texture_outline_size = 2.0
		
	parent_proj.is_active = false
	parent_proj.queue_free()
	
	var particles = CPUParticles2D.new()
	particles.emitting = true
	particles.one_shot = true
	particles.amount = 12
	particles.lifetime = 0.3
	particles.direction = Vector2.ZERO
	particles.spread = 180.0
	particles.initial_velocity_min = 30.0
	particles.initial_velocity_max = 60.0
	particles.gravity = Vector2.ZERO
	particles.scale_amount_min = 2.0
	particles.scale_amount_max = 4.0
	particles.color = Color(0.1, 0.7, 0.2)
	particles.global_position = split_pos
	parent.add_child(particles)
	owner_ball.get_tree().create_timer(1.0).timeout.connect(func():
		if is_instance_valid(particles): particles.queue_free()
	)

func _process_split_rings(delta: float):
	var i = active_split_rings.size() - 1
	while i >= 0:
		var ring = active_split_rings[i]
		ring["time_left"] = float(ring.get("time_left", 0.0)) - delta
		if ring["time_left"] <= 0.0:
			active_split_rings.remove_at(i)
		else:
			active_split_rings[i] = ring
		i -= 1

func _spawn_special_zone(target_pos: Vector2):
	_play_super_sfx()
	zone_status_timer = 0.0
	active_zones.append({
		"pos": target_pos,
		"time_left": special_zone_duration
	})
	
	# Spawn visual explosion for zone creation
	var parent = owner_ball.get_parent()
	if parent:
		var particles = CPUParticles2D.new()
		particles.emitting = true
		particles.one_shot = true
		particles.amount = 30
		particles.lifetime = 0.8
		particles.direction = Vector2.ZERO
		particles.spread = 180.0
		particles.initial_velocity_min = 100.0
		particles.initial_velocity_max = 200.0
		particles.gravity = Vector2.ZERO
		particles.scale_amount_min = 4.0
		particles.scale_amount_max = 8.0
		particles.color = Color(0.6, 0.1, 0.6)
		particles.global_position = target_pos
		parent.add_child(particles)
		owner_ball.get_tree().create_timer(1.0).timeout.connect(func():
			if is_instance_valid(particles): particles.queue_free()
		)

func _process_zones(delta: float):
	if not is_instance_valid(owner_ball): return
	var parent = owner_ball.get_parent()
	if not parent: return
	
	var i = active_zones.size() - 1
	var total_healing = 0.0
	if i < 0:
		zone_status_timer = 0.0
		return
	
	zone_status_timer = max(0.0, zone_status_timer - delta)
	var refresh_zone_status = zone_status_timer <= 0.0
	if refresh_zone_status:
		zone_status_timer = zone_status_refresh_interval
	var zone_radius_sq = special_zone_radius * special_zone_radius
	var candidates = _get_ball_candidates()
	
	while i >= 0:
		var zone = active_zones[i]
		zone.time_left -= delta
		
		if zone.time_left <= 0:
			active_zones.remove_at(i)
			i -= 1
			continue
			
		# Apply effects to enemies in zone
		for child in candidates:
			if not _is_valid_enemy(child):
				continue
			var dist_sq = zone.pos.distance_squared_to(child.global_position)
			if dist_sq <= zone_radius_sq:
				# Apply DoT
				var dmg = special_zone_dps * delta
				child.take_damage(dmg, owner_ball)
				total_healing += dmg * special_lifesteal_pct
				
				if refresh_zone_status:
					_apply_status_to(child, _status_id("cactus_zone", child), zone_status_duration, {
						"speed_cap": max(0.0, 1.0 - special_zone_slow),
					})
					
		i -= 1
		
	if total_healing > 0 and owner_ball.is_alive:
		_heal_owner(total_healing)

func _find_nearest_target() -> Node:
	return _find_nearest_enemy()

func _draw():
	if not is_instance_valid(owner_ball): return
	
	# Draw active zones in world coordinates translated to local
	for zone in active_zones:
		var local_pos = zone.pos - owner_ball.global_position
		# Pulsing opacity
		var alpha = 0.2 + sin(zone.time_left * 10.0) * 0.1
		# Fade out at the end
		if zone.time_left < 1.0:
			alpha *= zone.time_left
		
		# Draw outer ring
		draw_circle(local_pos, special_zone_radius, Color(0.6, 0.1, 0.6, alpha * 0.5))
		draw_arc(local_pos, special_zone_radius, 0, TAU, 32, Color(0.8, 0.2, 0.8, alpha * 2.0), 3.0)
		
		# Draw some inner thorns
		for i in range(8):
			var angle = (i / 8.0) * TAU + zone.time_left
			var thorn_pos = local_pos + Vector2(cos(angle), sin(angle)) * (special_zone_radius * 0.7)
			var tip = thorn_pos + Vector2(cos(angle), sin(angle)) * 15.0
			draw_line(thorn_pos, tip, Color(0.4, 0.0, 0.4, alpha * 2.0), 3.0)
	_draw_split_rings()
	
	# --- Draw Cactus Weapon ---
	var kick = clamp(launcher_kick_timer / max(launcher_kick_duration, 0.01), 0.0, 1.0)
	var weapon_scale = 1.0 + sin(kick * PI) * 0.12
	var pos = Vector2(cos(orbit_angle), sin(orbit_angle)) * (36.0 - kick * 8.0)
	
	if custom_weapon_texture:
		draw_set_transform(pos, orbit_angle, Vector2.ONE * weapon_scale)
		var tex_size = custom_weapon_texture.get_size()
		draw_texture_rect(custom_weapon_texture, Rect2(-tex_size/2, tex_size), false)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		draw_set_transform(pos, orbit_angle, Vector2.ONE * weapon_scale)
		var rect = Rect2(-8, -14, 16, 28)
		draw_rect(rect, Color(0.15, 0.6, 0.2), false, 4.0)
		draw_rect(rect, Color(0.2, 0.8, 0.3))
		
		# Spikes
		draw_line(Vector2(8, -10), Vector2(14, -12), Color(0.0, 0.4, 0.0), 2.0)
		draw_line(Vector2(8, 0), Vector2(14, 2), Color(0.0, 0.4, 0.0), 2.0)
		draw_line(Vector2(8, 10), Vector2(14, 8), Color(0.0, 0.4, 0.0), 2.0)
		draw_line(Vector2(-8, -10), Vector2(-14, -12), Color(0.0, 0.4, 0.0), 2.0)
		draw_line(Vector2(-8, 0), Vector2(-14, 2), Color(0.0, 0.4, 0.0), 2.0)
		draw_line(Vector2(-8, 10), Vector2(-14, 8), Color(0.0, 0.4, 0.0), 2.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# Aim line
	if state == "aiming" and is_instance_valid(aim_target) and aim_target.is_alive:
		var target_local = aim_target.global_position - owner_ball.global_position
		var aim_total = aim_duration if combo_index == 0 else 0.2
		var aim_progress = 1.0 - clamp(aim_timer / max(aim_total, 0.01), 0.0, 1.0)
		var pulse = 0.65 + sin(Time.get_ticks_msec() * 0.018) * 0.22
		draw_line(pos, target_local, Color(0.2, 0.9, 0.34, (0.34 + aim_progress * 0.28) * pulse), 2.0 + aim_progress * 1.4)
		draw_arc(pos, 13.0 + aim_progress * 8.0, 0, TAU, 20, Color(0.7, 1.0, 0.34, 0.38 + aim_progress * 0.28), 2.0)
		draw_arc(target_local, 12.0 + aim_progress * 6.0, 0, TAU, 16, Color(0.2, 0.8, 0.3, 0.5 + aim_progress * 0.3), 2.0)
	_draw_launch_flash()
		
	# --- UI Charge Bars ---
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
			else: fill = 0.0
		
		draw_rect(bar_rect, Color(0.12, 0.12, 0.12, 0.85))
		if fill > 0:
			draw_rect(Rect2(bx, bar_y, bar_width * fill, bar_height), Color(0.95, 0.75, 0.25, 0.95) if fill >= 1.0 else Color(0.7, 0.6, 0.25, 0.8))
		draw_rect(bar_rect, Color(0.5, 0.5, 0.5, 0.5), false, 1.0)
		
	# --- Special Bar ---
	var s_bar_y = bar_y + bar_height + 3.0
	var s_rect = Rect2(start_x, s_bar_y, total_w, 3.0)
	draw_rect(s_rect, Color(0.1, 0.1, 0.1, 0.85))
	var s_fill = float(total_hits) / float(hits_for_special)
	if s_fill > 0:
		draw_rect(Rect2(start_x, s_bar_y, total_w * min(s_fill, 1.0), 3.0), Color(0.6, 0.1, 0.6, 0.9))
	draw_rect(s_rect, Color(0.5, 0.5, 0.5, 0.4), false, 1.0)

func _draw_launch_flash():
	if launch_flash_timer <= 0.0:
		return
	var fade = clamp(launch_flash_timer / max(launch_flash_duration, 0.01), 0.0, 1.0)
	var dir = Vector2.RIGHT.rotated(launch_flash_angle)
	var side = dir.rotated(PI * 0.5)
	var muzzle_pos = dir * 42.0
	var length = 28.0 * fade
	var width = 13.0 * fade
	draw_colored_polygon(PackedVector2Array([
		muzzle_pos - side * width,
		muzzle_pos + side * width,
		muzzle_pos + dir * length,
	]), Color(0.5, 1.0, 0.26, 0.34 * fade))
	draw_circle(muzzle_pos, 5.0 * fade, Color(0.92, 1.0, 0.58, 0.72 * fade))
	for i in range(3):
		var lane = float(i) - 1.0
		var thorn_dir = dir.rotated(lane * 0.16)
		draw_line(muzzle_pos, muzzle_pos + thorn_dir * length * (0.75 + abs(lane) * 0.18), Color(0.85, 1.0, 0.38, 0.5 * fade), 1.5)

func _draw_split_rings():
	for ring in active_split_rings:
		var duration = max(float(ring.get("duration", 0.34)), 0.01)
		var fade = clamp(float(ring.get("time_left", 0.0)) / duration, 0.0, 1.0)
		var progress = 1.0 - fade
		var local_pos: Vector2 = ring.get("pos", owner_ball.global_position) - owner_ball.global_position
		var radius = lerp(8.0, 52.0, progress)
		draw_arc(local_pos, radius, 0, TAU, 34, Color(0.62, 1.0, 0.34, 0.72 * fade), lerp(5.0, 1.3, progress))
		for i in range(split_count):
			var angle = float(i) * TAU / float(max(split_count, 1))
			var dir = Vector2.RIGHT.rotated(angle)
			draw_line(local_pos + dir * (radius * 0.25), local_pos + dir * radius, Color(0.28, 0.9, 0.28, 0.28 * fade), 1.2)
