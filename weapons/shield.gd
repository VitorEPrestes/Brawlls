# Shield weapon - passively reduces/blocks incoming damage.
# Displays a visible protective arc that orbits the ball.
class_name WeaponShield extends WeaponBase

var block_chance: float = 0.3
var damage_reduction: float = 0.5
var orbit_angle: float = 0.0
var orbit_speed: float = 1.5
var blocked_flash: float = 0.0

func setup(owner: Node):
	super.setup(owner)
	weapon_name = "Shield"
	orbit_angle = randf() * TAU

func modify_incoming_damage(amount: float, source = null) -> float:
	if randf() < block_chance:
		blocked_flash = 0.3
		return 0.0
	else:
		blocked_flash = 0.15
		return amount * (1.0 - damage_reduction)

func get_damage_indicator() -> float:
	return 0.0

func process_weapon(delta: float):
	orbit_angle += orbit_speed * delta
	if blocked_flash > 0:
		blocked_flash -= delta
	queue_redraw()

func _draw():
	var radius = 42.0
	var arc_len = PI * 0.7
	var start = orbit_angle - arc_len / 2
	
	# Shield glow when blocking
	var shield_color = Color.CYAN
	if blocked_flash > 0:
		shield_color = Color.WHITE
	
	# Main shield arc
	draw_arc(Vector2.ZERO, radius, start, start + arc_len, 24, shield_color, 6.0)
	# Inner arc for depth
	draw_arc(Vector2.ZERO, radius - 3, start + 0.1, start + arc_len - 0.1, 20, Color(0.2, 0.6, 0.8, 0.5), 3.0)
	# Shield boss (center emblem)
	var mid_pos = Vector2(cos(orbit_angle), sin(orbit_angle)) * radius
	draw_circle(mid_pos, 5.0, Color.LIGHT_BLUE)
