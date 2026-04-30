# Central catalog for weapons, aliases, and stat modifiers.
class_name WeaponRegistry extends RefCounted

const ORDER = ["Shield", "Pa", "Cacto", "Laque", "Adolescente", "Colt", "Shelly", "Frank"]

const DEFINITIONS = {
	"Shield": {
		"script": preload("res://weapons/shield.gd"),
	},
	"Pa": {
		"script": preload("res://weapons/shovel.gd"),
	},
	"Cacto": {
		"script": preload("res://weapons/cactus.gd"),
	},
	"Laque": {
		"script": preload("res://weapons/hairspray.gd"),
	},
	"Adolescente": {
		"script": preload("res://weapons/teenager.gd"),
	},
	"Colt": {
		"script": preload("res://weapons/colt.gd"),
	},
	"Shelly": {
		"script": preload("res://weapons/shelly.gd"),
	},
	"Frank": {
		"script": preload("res://weapons/frank.gd"),
		"min_mass": 2.25,
	},
}

const ALIASES = {
	"P": "Pa",
	"Shovel": "Pa",
	"Cactus": "Cacto",
	"Laque de Cabelo": "Laque",
	"Hairspray": "Laque",
	"Pistoleiro": "Colt",
	"Revolver": "Colt",
	"Dual Revolver": "Colt",
	"Escopeta": "Shelly",
	"Shotgun": "Shelly",
	"Sword": "Shield",
	"Dagger": "Adolescente",
	"Hammer": "Frank",
	"Bow": "Shelly",
	"Fire Staff": "Laque",
}

static func get_weapon_names() -> Array:
	return ORDER.duplicate()

static func normalize(type_name) -> String:
	var normalized = String(type_name).strip_edges()
	if DEFINITIONS.has(normalized):
		return normalized
	if ALIASES.has(normalized):
		return ALIASES[normalized]
	return ORDER[0]

static func create_weapon(type_name) -> WeaponBase:
	var weapon_key = normalize(type_name)
	var definition = DEFINITIONS.get(weapon_key, DEFINITIONS[ORDER[0]])
	var script = definition.get("script")
	return script.new()

static func apply_stat_modifiers(config: Dictionary) -> Dictionary:
	var final_config = config.duplicate(true)
	var weapon_key = normalize(final_config.get("weapon_type", ORDER[0]))
	var definition = DEFINITIONS.get(weapon_key, {})
	final_config["weapon_type"] = weapon_key
	
	if definition.has("max_hp_override"):
		final_config["max_hp"] = float(definition["max_hp_override"])
	elif definition.has("max_hp_multiplier"):
		final_config["max_hp"] = float(final_config.get("max_hp", 100.0)) * float(definition["max_hp_multiplier"])
	
	if definition.has("min_mass"):
		final_config["mass"] = max(float(final_config.get("mass", 1.0)), float(definition["min_mass"]))
	
	return final_config

static func stat_summary(config: Dictionary) -> String:
	var final_config = apply_stat_modifiers(config)
	var base_hp = float(config.get("max_hp", 100.0))
	var final_hp = float(final_config.get("max_hp", base_hp))
	var base_mass = float(config.get("mass", 1.0))
	var final_mass = float(final_config.get("mass", base_mass))
	var parts = []
	if not is_equal_approx(base_hp, final_hp):
		parts.append("HP final %.0f" % final_hp)
	if not is_equal_approx(base_mass, final_mass):
		parts.append("Massa final %.2f" % final_mass)
	return " | ".join(PackedStringArray(parts))
