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

const PREVIEW_META = {
	"Shield": {
		"accent": Color(0.24, 0.78, 1.0),
		"role": "Defesa",
		"blurb": "Entra na frente, segura impacto e abre espaco para a equipe.",
		"texture": null,
	},
	"Pa": {
		"accent": Color(1.0, 0.60, 0.19),
		"role": "Explosao",
		"blurb": "Pressiona de perto com ataques pesados e impacto alto.",
		"texture": preload("res://weapons/texturas/pa.png"),
	},
	"Cacto": {
		"accent": Color(0.35, 0.90, 0.48),
		"role": "Zona",
		"blurb": "Controla espaco com estilhacos e cobertura de area.",
		"texture": preload("res://weapons/texturas/cacto_projetil.png"),
	},
	"Laque": {
		"accent": Color(1.0, 0.42, 0.70),
		"role": "Controle",
		"blurb": "Mantem o ritmo da luta com spray continuo e super ampla.",
		"texture": preload("res://weapons/texturas/hairspray.png"),
	},
	"Adolescente": {
		"accent": Color(1.0, 0.85, 0.22),
		"role": "Rush",
		"blurb": "Avanca rapido, cola no alvo e pune erros no corpo a corpo.",
		"texture": preload("res://weapons/texturas/teenager.png"),
	},
	"Colt": {
		"accent": Color(0.98, 0.72, 0.26),
		"role": "Precisao",
		"blurb": "Rajadas longas e burst preciso para duelistas pacientes.",
		"texture": preload("res://weapons/texturas/colt_pistol.png"),
	},
	"Shelly": {
		"accent": Color(1.0, 0.47, 0.30),
		"role": "Shotgun",
		"blurb": "Explode de perto e vira rounds com pressao frontal.",
		"texture": preload("res://weapons/texturas/shelly_shotgun.png"),
	},
	"Frank": {
		"accent": Color(0.76, 0.47, 1.0),
		"role": "Tank",
		"blurb": "Muito peso, muito HP final e presenca forte no centro.",
		"texture": preload("res://weapons/texturas/frank_weapon.png"),
	},
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

static func get_preview_meta(type_name) -> Dictionary:
	var weapon_key = normalize(type_name)
	return PREVIEW_META.get(weapon_key, PREVIEW_META[ORDER[0]])

static func get_preview_texture(type_name) -> Texture2D:
	var meta = get_preview_meta(type_name)
	return meta.get("texture", null)

static func get_preview_accent(type_name) -> Color:
	var meta = get_preview_meta(type_name)
	return meta.get("accent", Color(0.72, 0.78, 0.92))

static func get_preview_role(type_name) -> String:
	var meta = get_preview_meta(type_name)
	return String(meta.get("role", "Brawler"))

static func get_preview_blurb(type_name) -> String:
	var meta = get_preview_meta(type_name)
	return String(meta.get("blurb", "Configuracao personalizada pronta para entrar na arena."))

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
