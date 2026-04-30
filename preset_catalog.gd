# Battle presets kept separate from the main scene controller.
class_name PresetCatalog extends RefCounted

static func build_presets(weapon_types: Array) -> Array:
	return [
		{
			"name": "Batalha de Times",
			"balls": [
				{"display_name": "Azul 1", "color": Color(0.2, 0.5, 1.0), "weapon_type": "Shelly", "max_hp": 100.0, "mass": 1.0, "team_id": 1},
				{"display_name": "Azul 2", "color": Color(0.2, 0.5, 1.0), "weapon_type": "Frank", "max_hp": 150.0, "mass": 2.0, "team_id": 1},
				{"display_name": "Vermelho 1", "color": Color(1.0, 0.2, 0.2), "weapon_type": "Adolescente", "max_hp": 110.0, "mass": 0.9, "team_id": 2},
				{"display_name": "Vermelho 2", "color": Color(1.0, 0.2, 0.2), "weapon_type": "Pa", "max_hp": 120.0, "mass": 1.4, "team_id": 2},
			]
		},
		{
			"name": "Duelo classico",
			"balls": [
				{"display_name": "Knight", "color": Color(0.22, 0.46, 1.0), "weapon_type": "Shield", "max_hp": 100.0, "mass": 1.0},
				{"display_name": "Archer", "color": Color(0.28, 0.82, 0.36), "weapon_type": "Cacto", "max_hp": 80.0, "mass": 1.0},
			]
		},
		{
			"name": "Teste Adolescente",
			"balls": [
				{"display_name": "Teen", "color": Color(1.0, 0.62, 0.16), "weapon_type": "Adolescente", "max_hp": 115.0, "mass": 0.9},
				{"display_name": "Tank", "color": Color(0.58, 0.64, 0.72), "weapon_type": "Shield", "max_hp": 160.0, "mass": 1.8},
				{"display_name": "Hunter", "color": Color(0.24, 0.76, 0.42), "weapon_type": "Shelly", "max_hp": 95.0, "mass": 1.0},
			]
		},
		{
			"name": "Teste Frank",
			"balls": [
				{"display_name": "Frank", "color": Color(0.52, 0.36, 0.78), "weapon_type": "Frank", "max_hp": 150.0, "mass": 2.25},
				{"display_name": "Spray", "color": Color(1.0, 0.48, 0.72), "weapon_type": "Laque", "max_hp": 95.0, "mass": 0.9},
				{"display_name": "Shelly", "color": Color(0.24, 0.76, 0.42), "weapon_type": "Shelly", "max_hp": 95.0, "mass": 1.0},
			]
		},
		{
			"name": "Free for all",
			"balls": [
				{"display_name": "P1", "color": Color(1.0, 0.3, 0.3), "weapon_type": "Pa", "max_hp": 110.0, "mass": 1.5},
				{"display_name": "P2", "color": Color(0.22, 0.5, 1.0), "weapon_type": "Shield", "max_hp": 100.0, "mass": 1.0},
				{"display_name": "P3", "color": Color(0.28, 0.82, 0.36), "weapon_type": "Cacto", "max_hp": 80.0, "mass": 1.0},
				{"display_name": "P4", "color": Color(1.0, 0.82, 0.18), "weapon_type": "Laque", "max_hp": 85.0, "mass": 0.65},
			]
		},
		{
			"name": "Caos total",
			"balls": [
				{"display_name": "Mage", "color": Color(0.74, 0.34, 0.95), "weapon_type": "Laque", "max_hp": 90.0, "mass": 1.0},
				{"display_name": "Tank", "color": Color(0.58, 0.64, 0.72), "weapon_type": "Shield", "max_hp": 210.0, "mass": 2.0},
				{"display_name": "Assassin", "color": Color(0.14, 0.15, 0.18), "weapon_type": "Cacto", "max_hp": 80.0, "mass": 0.55},
				{"display_name": "Warrior", "color": Color(1.0, 0.52, 0.12), "weapon_type": "Shelly", "max_hp": 125.0, "mass": 1.4},
				{"display_name": "Brute", "color": Color(0.68, 0.44, 0.2), "weapon_type": "Pa", "max_hp": 155.0, "mass": 2.4},
				{"display_name": "Teen", "color": Color(1.0, 0.72, 0.16), "weapon_type": "Adolescente", "max_hp": 110.0, "mass": 0.9},
			]
		},
		{
			"name": "Projetil puro",
			"balls": [
				{"display_name": "Archer", "color": Color(0.28, 0.76, 0.36), "weapon_type": "Shelly", "max_hp": 100.0, "mass": 1.0},
				{"display_name": "Mage", "color": Color(0.8, 0.34, 0.95), "weapon_type": "Laque", "max_hp": 100.0, "mass": 1.0},
				{"display_name": "Cactus", "color": Color(0.1, 0.66, 0.32), "weapon_type": "Cacto", "max_hp": 80.0, "mass": 1.1},
				{"display_name": "Spray", "color": Color(1.0, 0.48, 0.72), "weapon_type": "Laque", "max_hp": 95.0, "mass": 0.9},
			]
		},
		{
			"name": "Teste Colt",
			"balls": [
				{"display_name": "Colt", "color": Color(0.96, 0.68, 0.24), "weapon_type": "Colt", "max_hp": 96.0, "mass": 0.95},
				{"display_name": "Shelly", "color": Color(0.24, 0.76, 0.42), "weapon_type": "Shelly", "max_hp": 95.0, "mass": 1.0},
				{"display_name": "Cacto", "color": Color(0.1, 0.66, 0.32), "weapon_type": "Cacto", "max_hp": 80.0, "mass": 1.1},
			]
		},
		{
			"name": "Stress 20",
			"balls": _make_stress_preset(weapon_types)
		},
	]

static func _make_stress_preset(weapon_types: Array) -> Array:
	var list = []
	var names = ["Alpha", "Beta", "Gamma", "Delta", "Epsilon", "Zeta", "Eta", "Theta", "Iota", "Kappa", "Lambda", "Mu", "Nu", "Xi", "Omicron", "Pi", "Rho", "Sigma", "Tau", "Upsilon"]
	for i in range(20):
		list.append({
			"display_name": names[i],
			"color": Color.from_hsv(float(i) / 20.0, 0.68, 0.95),
			"weapon_type": weapon_types[i % weapon_types.size()],
			"max_hp": 85.0,
			"mass": 1.0,
		})
	return list
