# Main scene controller - battle setup, UI, camera framing, and live stats.
extends Node2D

#region References
const WeaponRegistryScript = preload("res://weapon_registry.gd")

# --- UI References ---
@onready var side_panel: PanelContainer = $CanvasLayer/Panel
@onready var side_margin: MarginContainer = $CanvasLayer/Panel/MarginContainer
@onready var scroll_outer: ScrollContainer = $CanvasLayer/Panel/MarginContainer/ScrollOuter
@onready var ui_root: VBoxContainer = $CanvasLayer/Panel/MarginContainer/ScrollOuter/VBox
@onready var btn_start: Button = $CanvasLayer/Panel/MarginContainer/ScrollOuter/VBox/BtnStart
@onready var btn_reset: Button = $CanvasLayer/Panel/MarginContainer/ScrollOuter/VBox/BtnReset
@onready var btn_add: Button = $CanvasLayer/Panel/MarginContainer/ScrollOuter/VBox/BtnAdd
@onready var btn_clear: Button = $CanvasLayer/Panel/MarginContainer/ScrollOuter/VBox/BtnClear
@onready var weapon_option: OptionButton = $CanvasLayer/Panel/MarginContainer/ScrollOuter/VBox/HBoxWeapon/WeaponOption
@onready var input_name: LineEdit = $CanvasLayer/Panel/MarginContainer/ScrollOuter/VBox/HBoxName/InputName
@onready var color_picker: ColorPickerButton = $CanvasLayer/Panel/MarginContainer/ScrollOuter/VBox/HBoxColor/ColorPicker
@onready var spin_hp: SpinBox = $CanvasLayer/Panel/MarginContainer/ScrollOuter/VBox/HBoxHP/SpinHP
@onready var spin_mass: SpinBox = $CanvasLayer/Panel/MarginContainer/ScrollOuter/VBox/HBoxMass/SpinMass
@onready var arena_option: OptionButton = $CanvasLayer/Panel/MarginContainer/ScrollOuter/VBox/ArenaOption
@onready var scenario_option: OptionButton = $CanvasLayer/Panel/MarginContainer/ScrollOuter/VBox/ScenarioOption
@onready var ball_list: VBoxContainer = $CanvasLayer/Panel/MarginContainer/ScrollOuter/VBox/ScrollContainer/BallList
@onready var lbl_winner: Label = $CanvasLayer/Panel/MarginContainer/ScrollOuter/VBox/LblWinner
@onready var battle_container: Node2D = $BattleContainer
@onready var camera: Camera2D = $Camera2D
@onready var stats_panel: PanelContainer = $CanvasLayer/StatsPanel
@onready var stats_label: Label = $CanvasLayer/StatsPanel/MarginContainer/StatsLabel

# --- Scene References ---
var ball_scene: PackedScene = preload("res://Ball.tscn")
var arena_scene: PackedScene = preload("res://Arena.tscn")
#endregion

#region State
# --- State ---
var is_battling: bool = false
var current_arena: Node2D = null
var balls_config: Array = []
var ball_counter: int = 0
var battle_elapsed: float = 0.0
var active_balls: Array = []
var battle_total_count: int = 0
var base_zoom_factor: float = 1.0
var camera_tween: Tween = null
var vertical_base_zoom_factor: float = 1.0
var vertical_zoom_multiplier: float = 1.0
var vertical_camera_tween: Tween = null
var btn_vertical: Button
var team_option: OptionButton
var selected_ball_index: int = -1
var status_surface: PanelContainer = null
var lobby_queue_label: Label = null
var lobby_arena_label: Label = null
var lobby_scenario_label: Label = null
var queue_count_label: Label = null
var preview_surface: PanelContainer = null
var preview_portrait_surface: PanelContainer = null
var preview_role_chip: PanelContainer = null
var preview_team_chip: PanelContainer = null
var preview_source_label: Label = null
var preview_name_label: Label = null
var preview_role_label: Label = null
var preview_team_label: Label = null
var preview_texture_rect: TextureRect = null
var preview_texture_fallback: Label = null
var preview_color_badge: ColorRect = null
var preview_blurb_label: Label = null
var preview_summary_label: Label = null
var is_vertical_mode: bool = false
var side_panel_was_visible: bool = true
var pre_vertical_window_size: Vector2i = Vector2i(1280, 720)
var vertical_overlay: CanvasLayer = null
var vertical_subviewport: SubViewport = null
var vertical_container: SubViewportContainer = null
var vertical_camera: Camera2D = null
var vertical_bg: ColorRect = null
var vertical_border: Panel = null
var vertical_arena_border: Panel = null
var vertical_title_panel: PanelContainer = null
var vertical_title_label: RichTextLabel = null
var vertical_stats_panel: PanelContainer = null
var vertical_stats_label: RichTextLabel = null
var vertical_close_button: Button = null
var vertical_countdown_label: Label = null
var vertical_countdown_tween: Tween = null
var is_start_countdown: bool = false
var start_countdown_timer: float = 0.0
var last_countdown_second: int = -1
var countdown_display_marker: int = -99
var brawl_countdown_font: Font = null
var stats_refresh_timer: float = 0.0
var menu_layout_applied: bool = false
var kill_streak_by_attacker: Dictionary = {}
var ko_freeze_timer: float = 0.0
var ko_freeze_active: bool = false
var ko_focus_position: Vector2 = Vector2.ZERO
var ko_focus_timer: float = 0.0
var camera_home_position: Vector2 = Vector2.ZERO
var camera_focus_tween: Tween = null
var camera_shake_timer: float = 0.0
var camera_shake_duration: float = 0.0
var camera_shake_intensity: float = 0.0
#endregion

#region Constants
# --- Constants ---
const SIDE_PANEL_WIDTH = 620.0
const VERTICAL_ASPECT = 9.0 / 16.0
const VERTICAL_PADDING = 10.0
const VERTICAL_CAMERA_PADDING = 14.0
const VERTICAL_CAMERA_ZOOM_BOOST = 1.18
const VERTICAL_ARENA_RATIO = 0.98
const VERTICAL_STAGE_TOP_RATIO = 0.145
const VERTICAL_FX_SCALE = 1.48
const START_COUNTDOWN_SECONDS = 3.0
const START_BRAWLLS_HOLD_SECONDS = 1.0
const STATS_REFRESH_INTERVAL = 0.12
const KILL_STREAK_WINDOW = 2.1
const KO_FREEZE_DURATION = 0.09
const KO_ZOOM_MULTIPLIER = 1.22
const KO_ZOOM_IN_DURATION = 0.08
const KO_ZOOM_HOLD_DURATION = 0.1
const KO_ZOOM_OUT_DURATION = 0.16
const KO_SHAKE_INTENSITY = 9.0
const KO_SHAKE_DURATION = 0.18
const KO_FOCUS_DURATION = 0.36
const KO_RING_SEGMENTS = 34
const GOLDEN_RATIO_CONJUGATE = 0.61803398875
const MIN_COLOR_DISTANCE = 0.16
const PANEL_BG = Color(0.055, 0.065, 0.085, 0.96)
const PANEL_BORDER = Color(0.26, 0.34, 0.46, 0.9)
const CARD_BG = Color(0.095, 0.11, 0.145, 0.96)
const CARD_BG_HOVER = Color(0.13, 0.16, 0.21, 0.98)
const ACCENT = Color(0.35, 0.72, 1.0)
const GOOD = Color(0.26, 0.9, 0.48)
const WARN = Color(1.0, 0.76, 0.25)
const DANGER = Color(1.0, 0.28, 0.24)
const ARCADE_CYAN = Color(0.26, 0.84, 1.0)
const ARCADE_PINK = Color(1.0, 0.36, 0.66)
const ARCADE_ORANGE = Color(1.0, 0.60, 0.18)
const SURFACE_ALT = Color(0.11, 0.09, 0.16, 0.98)
const SURFACE_ALT_BORDER = Color(0.36, 0.29, 0.50, 0.95)
const SURFACE_CARD = Color(0.08, 0.10, 0.16, 0.98)
const SURFACE_CARD_BORDER = Color(0.22, 0.32, 0.46, 0.92)
const TEXT_SOFT = Color(0.94, 0.97, 1.0)
const TEXT_MUTED = Color(0.64, 0.72, 0.84)
const SCENARIO_DESERT = Arena.SCENARIO_DESERT
const SCENARIO_CEMETERY = Arena.SCENARIO_CEMETERY
const DESERT_CLEAR = Color(0.70, 0.48, 0.26)
const DESERT_FRAME = Color(0.86, 0.63, 0.33)
const DESERT_PANEL = Color(0.96, 0.86, 0.64, 0.98)
const DESERT_BORDER = Color(0.49, 0.28, 0.10)
const CEMETERY_CLEAR = Color(0.035, 0.045, 0.075)
const CEMETERY_FRAME = Color(0.09, 0.105, 0.15)
const CEMETERY_PANEL = Color(0.80, 0.82, 0.78, 0.98)
const CEMETERY_BORDER = Color(0.26, 0.30, 0.40, 0.95)
#endregion

#region Configuration
var weapon_types = WeaponRegistryScript.get_weapon_names()

var arena_sizes = {
	"Pequena 600x400": Vector2(600, 400),
	"Media 800x600": Vector2(800, 600),
	"Grande 1200x800": Vector2(1200, 800),
	"Enorme 1600x1000": Vector2(1600, 1000),
}

var scenario_themes = [
	SCENARIO_DESERT,
	SCENARIO_CEMETERY,
]

var default_colors = [
	Color(0.22, 0.55, 1.0),
	Color(1.0, 0.28, 0.26),
	Color(0.24, 0.82, 0.38),
	Color(1.0, 0.82, 0.18),
	Color(0.74, 0.36, 0.96),
	Color(1.0, 0.52, 0.12),
	Color(0.62, 0.66, 0.72),
	Color(0.1, 0.66, 0.52),
	Color(0.52, 0.36, 0.78),
]
#endregion

#region Lifecycle
func _ready():
	randomize()
	_connect_ui()
	_apply_ui_text()
	_apply_ui_style()
	_populate_options()
	_apply_scenario_chrome()
	_update_lobby_header()
	_update_preview()
	get_viewport().size_changed.connect(_on_viewport_resized)
	_set_status("Monte a fila e adicione pelo menos 2 bolas.", WARN)
	_sync_ui_state()
	_update_stats()

func _process(delta):
	_update_ko_freeze(delta)
	_update_ko_focus(delta)
	_update_camera_shake(delta)

	if is_start_countdown:
		start_countdown_timer = max(0.0, start_countdown_timer - delta)
		var countdown_marker = _current_countdown_marker()
		if countdown_marker != last_countdown_second:
			last_countdown_second = countdown_marker
			countdown_display_marker = countdown_marker
			if countdown_marker > 0:
				_set_status("Batalha comeca em %d..." % countdown_marker, WARN)
			else:
				_set_status("Brawlls!", ACCENT)
			_update_vertical_countdown_overlay(true)
		else:
			_update_vertical_countdown_overlay(false)
		if start_countdown_timer <= 0.0:
			_start_battle_now()
			return
	
	if is_battling:
		battle_elapsed += delta
		stats_refresh_timer -= delta
		if stats_refresh_timer <= 0.0:
			stats_refresh_timer = STATS_REFRESH_INTERVAL
			check_winner()
			_update_stats()
	
	if is_vertical_mode and current_arena:
		_update_vertical_camera()
#endregion

#region UI Setup
func _connect_ui():
	btn_start.pressed.connect(_on_start_pressed)
	btn_reset.pressed.connect(_on_reset_pressed)
	btn_add.pressed.connect(_on_add_pressed)
	btn_clear.pressed.connect(_on_clear_pressed)
	arena_option.item_selected.connect(_on_arena_selected)
	scenario_option.item_selected.connect(_on_scenario_selected)
	weapon_option.item_selected.connect(_on_form_option_changed)
	input_name.text_changed.connect(_on_form_text_changed)
	spin_hp.value_changed.connect(_on_form_value_changed)
	spin_mass.value_changed.connect(_on_form_value_changed)
	
	btn_vertical = Button.new()
	btn_vertical.text = "Modo 9:16"
	ui_root.add_child(btn_vertical)
	btn_vertical.pressed.connect(_toggle_vertical_mode)
	
	team_option = OptionButton.new()
	team_option.add_item("FFA (Nenhum)", 0)
	team_option.add_item("Time 1 (Azul)", 1)
	team_option.add_item("Time 2 (Vermelho)", 2)
	team_option.add_item("Time 3 (Verde)", 3)
	team_option.add_item("Time 4 (Amarelo)", 4)
	var team_hbox = HBoxContainer.new()
	var team_lbl = Label.new()
	team_lbl.text = "Time:"
	team_lbl.add_theme_font_size_override("font_size", 13)
	team_lbl.add_theme_color_override("font_color", Color(0.67, 0.76, 0.88))
	team_lbl.custom_minimum_size = Vector2(50, 0)
	team_hbox.add_child(team_lbl)
	team_hbox.add_child(team_option)
	team_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	team_option.item_selected.connect(_on_form_option_changed)
	ui_root.add_child(team_hbox)
	ui_root.move_child(team_hbox, btn_add.get_index())

func _apply_ui_text():
	$CanvasLayer/Panel/MarginContainer/ScrollOuter/VBox/LblTitle.text = "BRAWLLS"
	$CanvasLayer/Panel/MarginContainer/ScrollOuter/VBox/LblArenaSize.text = "Arena"
	$CanvasLayer/Panel/MarginContainer/ScrollOuter/VBox/LblScenario.text = "Cenario"
	$CanvasLayer/Panel/MarginContainer/ScrollOuter/VBox/LblAdd.text = "Montar brawler"
	$CanvasLayer/Panel/MarginContainer/ScrollOuter/VBox/HBoxName/LblName.text = "Nome"
	$CanvasLayer/Panel/MarginContainer/ScrollOuter/VBox/HBoxWeapon/LblWeapon.text = "Arma"
	$CanvasLayer/Panel/MarginContainer/ScrollOuter/VBox/HBoxColor/LblColor.text = "Cor"
	$CanvasLayer/Panel/MarginContainer/ScrollOuter/VBox/HBoxHP/LblHP.text = "HP"
	$CanvasLayer/Panel/MarginContainer/ScrollOuter/VBox/HBoxMass/LblMass.text = "Massa"
	$CanvasLayer/Panel/MarginContainer/ScrollOuter/VBox/LblList.text = "Fila pronta"
	input_name.placeholder_text = "Ex: Shelly Azul"
	btn_add.text = "Adicionar a fila"
	btn_clear.text = "Limpar fila"
	btn_start.text = "Comecar batalha"
	btn_reset.text = "Resetar arena"

func _apply_ui_style():
	side_panel.offset_left = -SIDE_PANEL_WIDTH
	side_panel.custom_minimum_size = Vector2(SIDE_PANEL_WIDTH, 0)
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.04, 0.045, 0.075, 0.985)
	panel_style.border_color = Color(0.42, 0.30, 0.66, 0.85)
	panel_style.border_width_left = 2
	panel_style.shadow_color = Color(0, 0, 0, 0.55)
	panel_style.shadow_size = 18
	panel_style.shadow_offset = Vector2(-4, 0)
	side_panel.add_theme_stylebox_override("panel", panel_style)
	side_margin.add_theme_constant_override("margin_left", 16)
	side_margin.add_theme_constant_override("margin_top", 16)
	side_margin.add_theme_constant_override("margin_right", 16)
	side_margin.add_theme_constant_override("margin_bottom", 16)
	scroll_outer.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	ui_root.add_theme_constant_override("separation", 12)
	
	stats_panel.offset_left = 16
	stats_panel.offset_top = 16
	stats_panel.offset_right = 330
	stats_panel.offset_bottom = 146
	stats_panel.add_theme_stylebox_override("panel", _make_style(Color(0.045, 0.052, 0.07, 0.88), Color(0.28, 0.38, 0.52, 0.65), 1, 6))
	stats_label.add_theme_font_size_override("font_size", 14)
	stats_label.add_theme_color_override("font_color", Color(0.94, 0.97, 1.0))
	stats_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.92))
	stats_label.add_theme_constant_override("outline_size", 2)
	stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	
	var title = $CanvasLayer/Panel/MarginContainer/ScrollOuter/VBox/LblTitle
	title.text = "BRAWL  LLS"
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color(1.0, 0.97, 0.99))
	title.add_theme_color_override("font_outline_color", Color(0.55, 0.18, 0.62, 0.95))
	title.add_theme_constant_override("outline_size", 5)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	for label_path in [
		"LblArenaSize",
		"LblScenario",
		"LblAdd",
		"LblList",
	]:
		var section_label: Label = ui_root.get_node(label_path)
		section_label.add_theme_font_size_override("font_size", 13)
		section_label.add_theme_color_override("font_color", Color(0.86, 0.90, 0.99))
		section_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.7))
		section_label.add_theme_constant_override("outline_size", 1)
	
	for sep in ui_root.get_children():
		if sep is HSeparator:
			sep.modulate = Color(0.35, 0.43, 0.56, 0.45)
	
	_style_button(btn_start, ARCADE_CYAN)
	_style_button(btn_reset, Color(0.50, 0.55, 0.66))
	_style_button(btn_add, ARCADE_ORANGE)
	_style_button(btn_clear, DANGER)
	_style_button(weapon_option, Color(0.34, 0.46, 0.78))
	_style_button(arena_option, Color(0.34, 0.46, 0.78))
	_style_button(scenario_option, Color(0.34, 0.46, 0.78))
	if team_option: _style_button(team_option, Color(0.46, 0.34, 0.78))
	_style_button(color_picker, Color(0.32, 0.46, 0.66))
	_style_line_edit(input_name)
	_style_spinbox(spin_hp)
	_style_spinbox(spin_mass)
	if btn_vertical:
		_style_button(btn_vertical, ARCADE_PINK)
	
	# Garantir valores explicitos (independente do .tscn)
	spin_hp.min_value = 10.0
	spin_hp.max_value = 1000.0
	spin_hp.step = 10.0
	spin_hp.value = 100.0
	spin_mass.min_value = 0.1
	spin_mass.max_value = 5.0
	spin_mass.step = 0.1
	spin_mass.value = 1.0
	
	lbl_winner.add_theme_font_size_override("font_size", 16)
	lbl_winner.add_theme_color_override("font_color", Color(0.93, 0.97, 1.0))
	lbl_winner.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.92))
	lbl_winner.add_theme_constant_override("outline_size", 3)
	lbl_winner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_winner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	
	btn_start.tooltip_text = "Inicia a luta com os brawlers montados na fila."
	btn_reset.tooltip_text = "Remove a arena atual e volta para a configuracao."
	btn_add.tooltip_text = "Adiciona bola personalizada com HP/Massa/Arma definidos acima."
	btn_clear.tooltip_text = "Remove todas as bolas da fila."
	spin_hp.tooltip_text = "HP usado ao clicar '+ Adicionar'."
	spin_mass.tooltip_text = "Massa usada ao clicar '+ Adicionar'."
	
	var color_row = color_picker.get_parent()
	if color_row:
		color_row.visible = false
	color_picker.disabled = true
	_arrange_menu_layout()

func _arrange_menu_layout():
	if menu_layout_applied:
		return
	menu_layout_applied = true
	
	var title = ui_root.get_node("LblTitle") as Label
	var lbl_arena = ui_root.get_node("LblArenaSize") as Label
	var lbl_scenario = ui_root.get_node("LblScenario") as Label
	var lbl_add = ui_root.get_node("LblAdd") as Label
	var lbl_list = ui_root.get_node("LblList") as Label
	var hbox_name = ui_root.get_node("HBoxName") as HBoxContainer
	var hbox_weapon = ui_root.get_node("HBoxWeapon") as HBoxContainer
	var hbox_hp = ui_root.get_node("HBoxHP") as HBoxContainer
	var hbox_mass = ui_root.get_node("HBoxMass") as HBoxContainer
	var queue_scroll = ball_list.get_parent() as ScrollContainer
	var team_row = (team_option.get_parent() as HBoxContainer) if team_option else null
	
	for child in ui_root.get_children():
		if child is HSeparator:
			child.visible = false
	
	var hero_card = PanelContainer.new()
	hero_card.add_theme_stylebox_override("panel", _make_style_accent_top(Color(0.10, 0.08, 0.18, 0.98), ARCADE_PINK, 18, 3, 14.0))
	hero_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ui_root.add_child(hero_card)
	ui_root.move_child(hero_card, title.get_index() + 1)
	var hero_body = _make_card_body(hero_card, 16, 14, 16, 16, 12)
	var hero_top = HBoxContainer.new()
	hero_top.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hero_top.add_theme_constant_override("separation", 12)
	hero_body.add_child(hero_top)
	
	var hero_copy = VBoxContainer.new()
	hero_copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hero_copy.add_theme_constant_override("separation", 6)
	hero_top.add_child(hero_copy)
	
	var hero_kicker = Label.new()
	hero_kicker.text = "▍ LOBBY  ARCADE"
	hero_kicker.add_theme_font_size_override("font_size", 12)
	hero_kicker.add_theme_color_override("font_color", ARCADE_ORANGE)
	hero_kicker.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.55))
	hero_kicker.add_theme_constant_override("outline_size", 1)
	hero_copy.add_child(hero_kicker)
	
	var hero_title = Label.new()
	hero_title.text = "Monte a fila, veja o loadout e entre na arena."
	hero_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hero_title.add_theme_font_size_override("font_size", 20)
	hero_title.add_theme_color_override("font_color", TEXT_SOFT)
	hero_title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.65))
	hero_title.add_theme_constant_override("outline_size", 2)
	hero_copy.add_child(hero_title)
	
	var hero_subtitle = Label.new()
	hero_subtitle.text = "Cada brawler tem identidade, role e cor — preview ao vivo no card ao lado."
	hero_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hero_subtitle.add_theme_font_size_override("font_size", 12)
	hero_subtitle.add_theme_color_override("font_color", TEXT_MUTED)
	hero_copy.add_child(hero_subtitle)
	
	var hero_chips = VBoxContainer.new()
	hero_chips.add_theme_constant_override("separation", 6)
	hero_chips.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hero_top.add_child(hero_chips)
	
	var queue_chip = _make_chip("Fila vazia", ARCADE_CYAN)
	lobby_queue_label = queue_chip["label"]
	hero_chips.add_child(queue_chip["panel"])
	var arena_chip = _make_chip("Arena", ARCADE_ORANGE)
	lobby_arena_label = arena_chip["label"]
	hero_chips.add_child(arena_chip["panel"])
	var scenario_chip = _make_chip("Cenario", ARCADE_PINK)
	lobby_scenario_label = scenario_chip["label"]
	hero_chips.add_child(scenario_chip["panel"])
	
	status_surface = PanelContainer.new()
	status_surface.add_theme_stylebox_override("panel", _make_style_ex(Color(0.05, 0.085, 0.13, 0.95), Color(0.20, 0.30, 0.46, 0.85), 1, 12, 0.0, Color.BLACK, 14, 10))
	hero_body.add_child(status_surface)
	var status_margin = MarginContainer.new()
	status_margin.add_theme_constant_override("margin_left", 4)
	status_margin.add_theme_constant_override("margin_top", 2)
	status_margin.add_theme_constant_override("margin_right", 4)
	status_margin.add_theme_constant_override("margin_bottom", 2)
	status_surface.add_child(status_margin)
	_move_menu_control(lbl_winner, status_margin)
	lbl_winner.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	lbl_winner.custom_minimum_size = Vector2(0, 24)
	
	var content_row = HBoxContainer.new()
	content_row.name = "LobbyContent"
	content_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_row.add_theme_constant_override("separation", 12)
	ui_root.add_child(content_row)
	ui_root.move_child(content_row, hero_card.get_index() + 1)
	
	var setup_card = PanelContainer.new()
	setup_card.add_theme_stylebox_override("panel", _make_style_accent_top(SURFACE_ALT, ARCADE_ORANGE, 16, 3, 10.0))
	setup_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	setup_card.size_flags_stretch_ratio = 1.06
	content_row.add_child(setup_card)
	var setup_body = _make_card_body(setup_card, 14, 12, 14, 14, 10)
	
	var setup_kicker = Label.new()
	setup_kicker.text = "▍ SETUP"
	setup_kicker.add_theme_font_size_override("font_size", 10)
	setup_kicker.add_theme_color_override("font_color", ARCADE_ORANGE)
	setup_body.add_child(setup_kicker)
	
	var setup_title = Label.new()
	setup_title.text = "Montar partida"
	setup_title.add_theme_font_size_override("font_size", 19)
	setup_title.add_theme_color_override("font_color", TEXT_SOFT)
	setup_body.add_child(setup_title)
	
	var setup_copy = Label.new()
	setup_copy.text = "Escolha arena, cenario e adicione brawlers manualmente."
	setup_copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	setup_copy.add_theme_font_size_override("font_size", 12)
	setup_copy.add_theme_color_override("font_color", TEXT_MUTED)
	setup_body.add_child(setup_copy)
	
	var match_grid = GridContainer.new()
	match_grid.columns = 2
	match_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	match_grid.add_theme_constant_override("h_separation", 8)
	match_grid.add_theme_constant_override("v_separation", 6)
	setup_body.add_child(match_grid)
	
	lbl_arena.custom_minimum_size = Vector2(72, 0)
	lbl_scenario.custom_minimum_size = Vector2(72, 0)
	_move_menu_control(lbl_arena, match_grid)
	_move_menu_control(arena_option, match_grid)
	_move_menu_control(lbl_scenario, match_grid)
	_move_menu_control(scenario_option, match_grid)
	
	var setup_sep = HSeparator.new()
	setup_sep.modulate = Color(0.38, 0.32, 0.54, 0.52)
	setup_body.add_child(setup_sep)
	
	lbl_add.add_theme_font_size_override("font_size", 18)
	_move_menu_control(lbl_add, setup_body)
	
	var form_note = Label.new()
	form_note.text = "A preview acompanha o rascunho atual. Use os cards da fila para inspecionar um brawler ja adicionado."
	form_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	form_note.add_theme_font_size_override("font_size", 11)
	form_note.add_theme_color_override("font_color", TEXT_MUTED)
	setup_body.add_child(form_note)
	
	_move_menu_control(hbox_name, setup_body)
	_move_menu_control(hbox_weapon, setup_body)
	if team_row:
		_move_menu_control(team_row, setup_body)
	
	var stat_row = HBoxContainer.new()
	stat_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stat_row.add_theme_constant_override("separation", 8)
	setup_body.add_child(stat_row)
	_move_menu_control(hbox_hp, stat_row)
	_move_menu_control(hbox_mass, stat_row)
	hbox_hp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox_mass.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	_move_menu_control(btn_add, setup_body)
	btn_add.custom_minimum_size = Vector2(0, 42)
	
	preview_surface = PanelContainer.new()
	preview_surface.add_theme_stylebox_override("panel", _make_style_accent_top(SURFACE_CARD, ARCADE_CYAN, 16, 3, 12.0))
	preview_surface.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_row.add_child(preview_surface)
	var preview_body = _make_card_body(preview_surface, 14, 12, 14, 14, 10)
	
	var preview_kicker = Label.new()
	preview_kicker.text = "▍ PREVIEW"
	preview_kicker.add_theme_font_size_override("font_size", 10)
	preview_kicker.add_theme_color_override("font_color", ARCADE_CYAN)
	preview_body.add_child(preview_kicker)
	
	var preview_header = Label.new()
	preview_header.text = "Loadout ao vivo"
	preview_header.add_theme_font_size_override("font_size", 19)
	preview_header.add_theme_color_override("font_color", TEXT_SOFT)
	preview_body.add_child(preview_header)
	
	var preview_top = HBoxContainer.new()
	preview_top.add_theme_constant_override("separation", 8)
	preview_body.add_child(preview_top)
	preview_color_badge = ColorRect.new()
	preview_color_badge.custom_minimum_size = Vector2(16, 16)
	preview_color_badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	preview_top.add_child(preview_color_badge)
	preview_source_label = Label.new()
	preview_source_label.text = "Rascunho atual"
	preview_source_label.add_theme_font_size_override("font_size", 12)
	preview_source_label.add_theme_color_override("font_color", TEXT_MUTED)
	preview_top.add_child(preview_source_label)
	
	preview_name_label = Label.new()
	preview_name_label.text = "Novo Brawler"
	preview_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	preview_name_label.add_theme_font_size_override("font_size", 24)
	preview_name_label.add_theme_color_override("font_color", TEXT_SOFT)
	preview_name_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	preview_name_label.add_theme_constant_override("outline_size", 2)
	preview_body.add_child(preview_name_label)
	
	var preview_chip_row = HBoxContainer.new()
	preview_chip_row.add_theme_constant_override("separation", 8)
	preview_body.add_child(preview_chip_row)
	var role_chip = _make_chip("Arma", ARCADE_CYAN)
	preview_role_chip = role_chip["panel"]
	preview_role_label = role_chip["label"]
	preview_chip_row.add_child(preview_role_chip)
	var team_chip = _make_chip("FFA", Color(0.50, 0.58, 0.70))
	preview_team_chip = team_chip["panel"]
	preview_team_label = team_chip["label"]
	preview_chip_row.add_child(preview_team_chip)
	
	preview_portrait_surface = PanelContainer.new()
	preview_portrait_surface.add_theme_stylebox_override("panel", _make_style_ex(Color(0.06, 0.10, 0.16, 0.95), ARCADE_CYAN.darkened(0.35), 1, 14, 8.0, Color(ARCADE_CYAN.r, ARCADE_CYAN.g, ARCADE_CYAN.b, 0.30), 4, 4))
	preview_portrait_surface.custom_minimum_size = Vector2(0, 170)
	preview_body.add_child(preview_portrait_surface)
	var portrait_margin = MarginContainer.new()
	portrait_margin.add_theme_constant_override("margin_left", 12)
	portrait_margin.add_theme_constant_override("margin_top", 12)
	portrait_margin.add_theme_constant_override("margin_right", 12)
	portrait_margin.add_theme_constant_override("margin_bottom", 12)
	preview_portrait_surface.add_child(portrait_margin)
	var portrait_center = CenterContainer.new()
	portrait_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	portrait_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	portrait_margin.add_child(portrait_center)
	preview_texture_rect = TextureRect.new()
	preview_texture_rect.custom_minimum_size = Vector2(160, 124)
	preview_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait_center.add_child(preview_texture_rect)
	preview_texture_fallback = Label.new()
	preview_texture_fallback.visible = false
	preview_texture_fallback.add_theme_font_size_override("font_size", 28)
	preview_texture_fallback.add_theme_color_override("font_color", TEXT_SOFT)
	portrait_center.add_child(preview_texture_fallback)
	
	preview_summary_label = Label.new()
	preview_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	preview_summary_label.add_theme_font_size_override("font_size", 13)
	preview_summary_label.add_theme_color_override("font_color", TEXT_SOFT)
	preview_body.add_child(preview_summary_label)
	preview_blurb_label = Label.new()
	preview_blurb_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	preview_blurb_label.add_theme_font_size_override("font_size", 12)
	preview_blurb_label.add_theme_color_override("font_color", TEXT_MUTED)
	preview_body.add_child(preview_blurb_label)
	_move_menu_control(btn_vertical, preview_body)
	btn_vertical.custom_minimum_size = Vector2(0, 38)
	
	var queue_card = PanelContainer.new()
	queue_card.add_theme_stylebox_override("panel", _make_style_accent_top(Color(0.06, 0.085, 0.135, 0.98), ARCADE_PINK, 16, 3, 12.0))
	queue_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ui_root.add_child(queue_card)
	ui_root.move_child(queue_card, content_row.get_index() + 1)
	var queue_body = _make_card_body(queue_card, 14, 12, 14, 14, 10)
	var queue_kicker = Label.new()
	queue_kicker.text = "▍ ROSTER"
	queue_kicker.add_theme_font_size_override("font_size", 10)
	queue_kicker.add_theme_color_override("font_color", ARCADE_PINK)
	queue_body.add_child(queue_kicker)
	var queue_header = HBoxContainer.new()
	queue_header.add_theme_constant_override("separation", 8)
	queue_body.add_child(queue_header)
	lbl_list.add_theme_font_size_override("font_size", 19)
	lbl_list.add_theme_color_override("font_color", TEXT_SOFT)
	_move_menu_control(lbl_list, queue_header)
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	queue_header.add_child(spacer)
	var count_chip = _make_chip("Fila vazia", ARCADE_CYAN)
	queue_count_label = count_chip["label"]
	queue_header.add_child(count_chip["panel"])
	
	var action_row = HBoxContainer.new()
	action_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_row.add_theme_constant_override("separation", 8)
	queue_body.add_child(action_row)
	_move_menu_control(btn_start, action_row)
	_move_menu_control(btn_clear, action_row)
	_move_menu_control(btn_reset, action_row)
	btn_start.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_start.size_flags_stretch_ratio = 2.2
	btn_start.custom_minimum_size = Vector2(0, 44)
	
	queue_scroll.custom_minimum_size = Vector2(0, 260)
	queue_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	queue_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_move_menu_control(queue_scroll, queue_body)
	
	for control in [
		arena_option,
		scenario_option,
		input_name,
		weapon_option,
		spin_hp,
		spin_mass,
		btn_add,
		btn_vertical,
		btn_start,
		btn_clear,
		btn_reset,
	]:
		if control:
			control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_winner.custom_minimum_size = Vector2(0, 26)

func _make_menu_column(node_name: String) -> VBoxContainer:
	var column = VBoxContainer.new()
	column.name = node_name
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 7)
	return column

func _move_menu_control(control: Control, new_parent: Node):
	if not control or not new_parent:
		return
	var old_parent = control.get_parent()
	if old_parent == new_parent:
		return
	if old_parent:
		old_parent.remove_child(control)
	new_parent.add_child(control)

func _make_surface_card(bg: Color, border: Color, radius: int = 14) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _make_style(bg, border, 1, radius))
	return panel

func _make_card_body(panel: PanelContainer, margin_left: int = 12, margin_top: int = 12, margin_right: int = 12, margin_bottom: int = 12, separation: int = 8) -> VBoxContainer:
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", margin_left)
	margin.add_theme_constant_override("margin_top", margin_top)
	margin.add_theme_constant_override("margin_right", margin_right)
	margin.add_theme_constant_override("margin_bottom", margin_bottom)
	panel.add_child(margin)
	var body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", separation)
	margin.add_child(body)
	return body

func _make_chip(text: String, color: Color) -> Dictionary:
	var panel = PanelContainer.new()
	var bg = Color(color.r * 0.22, color.g * 0.22, color.b * 0.22, 0.92)
	var border = color.lightened(0.10)
	panel.add_theme_stylebox_override("panel", _make_style_ex(bg, border, 1, 999, 0.0, Color.BLACK, 12, 5))
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 7)
	panel.add_child(row)
	var dot = ColorRect.new()
	dot.color = color.lightened(0.10)
	dot.custom_minimum_size = Vector2(7, 7)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(dot)
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", color.lightened(0.55))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.55))
	label.add_theme_constant_override("outline_size", 1)
	row.add_child(label)
	return {"panel": panel, "label": label}

func _team_color(team_id: int) -> Color:
	match team_id:
		1:
			return Color(0.28, 0.66, 1.0)
		2:
			return Color(1.0, 0.36, 0.34)
		3:
			return Color(0.30, 0.92, 0.50)
		4:
			return Color(1.0, 0.82, 0.22)
		_:
			return Color(0.62, 0.70, 0.82)

func _team_label(team_id: int) -> String:
	if team_id <= 0:
		return "FFA"
	return "Time %d" % team_id

func _populate_options():
	weapon_option.clear()
	for weapon in weapon_types:
		weapon_option.add_item(weapon)
	if weapon_option.get_item_count() > 0:
		weapon_option.selected = 0
	
	arena_option.clear()
	for key in arena_sizes.keys():
		arena_option.add_item(key)
	arena_option.selected = 0
	
	scenario_option.clear()
	for theme in scenario_themes:
		scenario_option.add_item(theme)
	scenario_option.selected = 0

func _on_arena_selected(_index: int):
	_update_lobby_header()
	_update_stats()

func _on_form_text_changed(_text: String):
	_promote_draft_preview()

func _on_form_option_changed(_index: int):
	_promote_draft_preview()

func _on_form_value_changed(_value: float):
	_promote_draft_preview()

func _promote_draft_preview():
	var had_selection = selected_ball_index != -1
	selected_ball_index = -1
	if had_selection:
		_refresh_ball_list()
		return
	_update_preview()
	_update_stats()

func _update_lobby_header():
	if lobby_queue_label:
		lobby_queue_label.text = "%d na fila" % balls_config.size() if balls_config.size() > 0 else "Fila vazia"
	if queue_count_label:
		queue_count_label.text = "%d na fila" % balls_config.size() if balls_config.size() > 0 else "Fila vazia"
	if lobby_arena_label and arena_option and arena_option.get_item_count() > 0:
		lobby_arena_label.text = arena_option.get_item_text(max(arena_option.selected, 0))
	if lobby_scenario_label:
		lobby_scenario_label.text = _selected_scenario_theme()

func _build_draft_config() -> Dictionary:
	var draft_name = input_name.text.strip_edges()
	if draft_name == "":
		draft_name = "Novo Brawler"
	var draft_color = _next_natural_color()
	return {
		"display_name": draft_name,
		"color": draft_color,
		"natural_color": draft_color,
		"weapon_type": WeaponRegistryScript.normalize(_selected_weapon_type()),
		"max_hp": spin_hp.value,
		"mass": spin_mass.value,
		"team_id": team_option.selected if team_option else 0,
	}

func _get_preview_config() -> Dictionary:
	if selected_ball_index >= 0 and selected_ball_index < balls_config.size():
		return balls_config[selected_ball_index].duplicate(true)
	selected_ball_index = -1
	return _build_draft_config()

func _update_preview():
	if not preview_name_label:
		return
	var cfg = _get_preview_config()
	var weapon_key = WeaponRegistryScript.normalize(cfg.get("weapon_type", "Shield"))
	var accent = WeaponRegistryScript.get_preview_accent(weapon_key)
	var final_cfg = WeaponRegistryScript.apply_stat_modifiers(cfg)
	var base_hp = float(cfg.get("max_hp", 100.0))
	var final_hp = float(final_cfg.get("max_hp", base_hp))
	var base_mass = float(cfg.get("mass", 1.0))
	var final_mass = float(final_cfg.get("mass", base_mass))
	var team_id = int(cfg.get("team_id", 0))
	var team_color = _team_color(team_id)
	var texture = WeaponRegistryScript.get_preview_texture(weapon_key)
	var stat_note = WeaponRegistryScript.stat_summary(cfg)
	var hp_text = "HP %.0f" % base_hp
	if not is_equal_approx(base_hp, final_hp):
		hp_text += " -> %.0f" % final_hp
	var mass_text = "Massa %.1f" % base_mass
	if not is_equal_approx(base_mass, final_mass):
		mass_text += " -> %.2f" % final_mass
	
	preview_source_label.text = "Selecionado na fila" if selected_ball_index >= 0 else "Rascunho atual"
	preview_name_label.text = String(cfg.get("display_name", "Novo Brawler"))
	preview_role_label.text = "%s | %s" % [weapon_key, WeaponRegistryScript.get_preview_role(weapon_key)]
	preview_team_label.text = _team_label(team_id)
	preview_summary_label.text = "%s\n%s\n%s" % [hp_text, mass_text, stat_note if stat_note != "" else "Sem bonus extras nesta arma."]
	preview_blurb_label.text = WeaponRegistryScript.get_preview_blurb(weapon_key)
	preview_color_badge.color = Color(cfg.get("color", accent))
	preview_texture_rect.texture = texture
	preview_texture_rect.visible = texture != null
	preview_texture_fallback.visible = texture == null
	preview_texture_fallback.text = weapon_key.substr(0, min(3, weapon_key.length())).to_upper()
	preview_surface.add_theme_stylebox_override("panel", _make_style(SURFACE_CARD, accent.lightened(0.05), 1, 16))
	preview_portrait_surface.add_theme_stylebox_override("panel", _make_style(Color(cfg.get("color", accent)).darkened(0.72), accent, 1, 14))
	preview_role_chip.add_theme_stylebox_override("panel", _make_style(accent.darkened(0.76), accent.lightened(0.08), 1, 13))
	preview_team_chip.add_theme_stylebox_override("panel", _make_style(team_color.darkened(0.76), team_color.lightened(0.06), 1, 13))

func _queue_card_summary_text(config: Dictionary) -> String:
	var final_cfg = WeaponRegistryScript.apply_stat_modifiers(config)
	var base_hp = float(config.get("max_hp", 100.0))
	var final_hp = float(final_cfg.get("max_hp", base_hp))
	var base_mass = float(config.get("mass", 1.0))
	var final_mass = float(final_cfg.get("mass", base_mass))
	var summary = "HP %.0f" % base_hp
	if not is_equal_approx(base_hp, final_hp):
		summary += " -> %.0f" % final_hp
	summary += " | Massa %.1f" % base_mass
	if not is_equal_approx(base_mass, final_mass):
		summary += " -> %.2f" % final_mass
	return summary
#endregion

#region Queue
func _next_natural_color() -> Color:
	var used_colors = []
	for cfg in balls_config:
		if cfg.has("natural_color"):
			used_colors.append(cfg["natural_color"])
		elif cfg.has("color"):
			used_colors.append(cfg["color"])
	return _natural_color_for_slot(balls_config.size(), used_colors)

func _assign_natural_colors_to_queue(force_reassign: bool):
	var used_colors = []
	for i in range(balls_config.size()):
		var cfg = balls_config[i]
		var existing = cfg.get("natural_color", cfg.get("color", null))
		var needs_color = force_reassign or existing == null
		if not needs_color:
			needs_color = not _is_color_unique(existing, used_colors)
		
		var natural_color = _natural_color_for_slot(i, used_colors) if needs_color else existing
		cfg["color"] = natural_color
		cfg["natural_color"] = natural_color
		balls_config[i] = cfg
		used_colors.append(natural_color)

func _natural_color_for_slot(slot: int, used_colors: Array) -> Color:
	if slot < default_colors.size():
		var slot_palette_color = default_colors[slot]
		if _is_color_unique(slot_palette_color, used_colors):
			return slot_palette_color
	
	for fallback_palette_color in default_colors:
		if _is_color_unique(fallback_palette_color, used_colors):
			return fallback_palette_color
	
	for attempt in range(180):
		var hue = fposmod(float(slot) * GOLDEN_RATIO_CONJUGATE + float(attempt) * 0.071, 1.0)
		var saturation = 0.68 + 0.08 * float(attempt % 3)
		var value = 0.96 - 0.07 * float(int(attempt / 3) % 2)
		var candidate = Color.from_hsv(hue, saturation, value)
		if _is_color_unique(candidate, used_colors):
			return candidate
	
	return Color.from_hsv(fposmod(float(slot) * GOLDEN_RATIO_CONJUGATE, 1.0), 0.74, 0.94)

func _is_color_unique(candidate: Color, used_colors: Array) -> bool:
	for used in used_colors:
		if _color_distance(candidate, used) < MIN_COLOR_DISTANCE:
			return false
	return true

func _color_distance(a: Color, b: Color) -> float:
	var dr = a.r - b.r
	var dg = a.g - b.g
	var db = a.b - b.b
	return sqrt(dr * dr + dg * dg + db * db)

func _on_add_pressed():
	var bname = input_name.text.strip_edges()
	if bname == "":
		ball_counter += 1
		bname = "Ball " + str(ball_counter)
	
	var natural_color = _next_natural_color()
	
	var cfg = {
		"display_name": bname,
		"color": natural_color,
		"natural_color": natural_color,
		"weapon_type": WeaponRegistryScript.normalize(_selected_weapon_type()),
		"max_hp": spin_hp.value,
		"mass": spin_mass.value,
		"team_id": team_option.selected if team_option else 0,
	}
	balls_config.append(cfg)
	input_name.text = ""
	selected_ball_index = balls_config.size() - 1
	_refresh_ball_list()
	_set_status("%d bolas na fila." % balls_config.size(), GOOD if balls_config.size() >= 2 else WARN)
	_sync_ui_state()
	_update_stats()

func _on_clear_pressed():
	balls_config.clear()
	ball_counter = 0
	selected_ball_index = -1
	_refresh_ball_list()
	_set_status("Fila limpa. Adicione pelo menos 2 bolas.", WARN)
	_sync_ui_state()
	_update_stats()

func _select_ball_for_preview(index: int):
	if index < 0 or index >= balls_config.size():
		return
	selected_ball_index = index
	_refresh_ball_list()
	_update_stats()

func _refresh_ball_list():
	_assign_natural_colors_to_queue(false)
	if selected_ball_index >= balls_config.size():
		selected_ball_index = -1
	for child in ball_list.get_children():
		child.queue_free()
	
	if balls_config.size() == 0:
		var empty_panel = PanelContainer.new()
		empty_panel.add_theme_stylebox_override("panel", _make_style_ex(Color(0.07, 0.09, 0.16, 0.96), Color(0.30, 0.40, 0.58, 0.70), 1, 14, 0.0, Color.BLACK, 4, 4))
		var empty_body = _make_card_body(empty_panel, 18, 18, 18, 18, 6)
		var empty_kicker = Label.new()
		empty_kicker.text = "▍ FILA"
		empty_kicker.add_theme_font_size_override("font_size", 10)
		empty_kicker.add_theme_color_override("font_color", ARCADE_CYAN)
		empty_body.add_child(empty_kicker)
		var empty_title = Label.new()
		empty_title.text = "Nenhum brawler na fila"
		empty_title.add_theme_font_size_override("font_size", 17)
		empty_title.add_theme_color_override("font_color", TEXT_SOFT)
		empty_body.add_child(empty_title)
		var empty_copy = Label.new()
		empty_copy.text = "Adicione pelo menos 2 brawlers para liberar a batalha. O preview ao lado acompanha o rascunho atual."
		empty_copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty_copy.add_theme_font_size_override("font_size", 12)
		empty_copy.add_theme_color_override("font_color", TEXT_MUTED)
		empty_body.add_child(empty_copy)
		ball_list.add_child(empty_panel)
		_update_lobby_header()
		_update_preview()
		return
	
	for i in range(balls_config.size()):
		var cfg = balls_config[i]
		var weapon_key = WeaponRegistryScript.normalize(cfg.get("weapon_type", "Shield"))
		var accent = WeaponRegistryScript.get_preview_accent(weapon_key)
		var texture = WeaponRegistryScript.get_preview_texture(weapon_key)
		var final_cfg = WeaponRegistryScript.apply_stat_modifiers(cfg)
		var team_id = int(cfg.get("team_id", 0))
		var is_selected = i == selected_ball_index
		var stat_note = WeaponRegistryScript.stat_summary(cfg)
		var row_panel = PanelContainer.new()
		row_panel.custom_minimum_size = Vector2(0, 96)
		var row_bg = CARD_BG_HOVER if is_selected else Color(0.085, 0.105, 0.155, 0.96)
		var row_border = accent if is_selected else Color(0.22, 0.30, 0.42, 0.70)
		row_panel.add_theme_stylebox_override("panel", _make_style_ex(row_bg, row_border, 2 if is_selected else 1, 12, 8.0 if is_selected else 0.0, Color(accent.r, accent.g, accent.b, 0.45) if is_selected else Color.BLACK, 4, 4))
		
		var margin = MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 10)
		margin.add_theme_constant_override("margin_top", 10)
		margin.add_theme_constant_override("margin_right", 10)
		margin.add_theme_constant_override("margin_bottom", 10)
		row_panel.add_child(margin)
		
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		margin.add_child(row)
		
		var portrait = PanelContainer.new()
		portrait.custom_minimum_size = Vector2(74, 74)
		portrait.add_theme_stylebox_override("panel", _make_style_ex(Color(cfg.get("color", accent)).darkened(0.70), accent, 2, 12, 0.0, Color.BLACK, 4, 4))
		row.add_child(portrait)
		var portrait_center = CenterContainer.new()
		portrait_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		portrait_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
		portrait.add_child(portrait_center)
		if texture:
			var icon = TextureRect.new()
			icon.texture = texture
			icon.custom_minimum_size = Vector2(54, 54)
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			portrait_center.add_child(icon)
		else:
			var monogram = Label.new()
			monogram.text = weapon_key.substr(0, min(3, weapon_key.length())).to_upper()
			monogram.add_theme_font_size_override("font_size", 18)
			monogram.add_theme_color_override("font_color", TEXT_SOFT)
			portrait_center.add_child(monogram)
		
		var content = VBoxContainer.new()
		content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		content.add_theme_constant_override("separation", 4)
		row.add_child(content)
		
		var name_label = Label.new()
		name_label.text = String(cfg.get("display_name", "Ball"))
		name_label.clip_text = true
		name_label.add_theme_font_size_override("font_size", 14)
		name_label.add_theme_color_override("font_color", TEXT_SOFT)
		content.add_child(name_label)
		
		var meta_label = Label.new()
		meta_label.text = "%s • %s • %s" % [weapon_key, WeaponRegistryScript.get_preview_role(weapon_key), _team_label(team_id)]
		meta_label.clip_text = true
		meta_label.add_theme_font_size_override("font_size", 11)
		meta_label.add_theme_color_override("font_color", TEXT_MUTED)
		content.add_child(meta_label)
		
		var summary_label = Label.new()
		summary_label.text = _queue_card_summary_text(cfg) + (" | " + stat_note if stat_note != "" else "")
		summary_label.clip_text = true
		summary_label.add_theme_font_size_override("font_size", 11)
		summary_label.add_theme_color_override("font_color", Color(0.84, 0.89, 0.97))
		content.add_child(summary_label)
		
		var hp_row = HBoxContainer.new()
		hp_row.add_theme_constant_override("separation", 6)
		content.add_child(hp_row)
		
		var hp_lbl = Label.new()
		hp_lbl.text = "Ajuste de HP"
		hp_lbl.add_theme_font_size_override("font_size", 11)
		hp_lbl.add_theme_color_override("font_color", TEXT_MUTED)
		hp_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hp_row.add_child(hp_lbl)
		
		var hp_spin = SpinBox.new()
		hp_spin.min_value = 10.0
		hp_spin.max_value = 1000.0
		hp_spin.step = 5.0
		hp_spin.value = cfg.get("max_hp", 100.0)
		hp_spin.custom_minimum_size = Vector2(90, 0)
		hp_spin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_style_spinbox(hp_spin)
		var cap_i = i  # capture loop variable
		var cap_summary_label = summary_label
		hp_spin.value_changed.connect(func(val: float):
			if cap_i < balls_config.size():
				balls_config[cap_i]["max_hp"] = val
				cap_summary_label.text = _queue_card_summary_text(balls_config[cap_i])
				var live_note = WeaponRegistryScript.stat_summary(balls_config[cap_i])
				if live_note != "":
					cap_summary_label.text += " | " + live_note
				if selected_ball_index == cap_i:
					_update_preview()
				_update_stats()
		)
		hp_row.add_child(hp_spin)
		
		var actions = VBoxContainer.new()
		actions.add_theme_constant_override("separation", 6)
		row.add_child(actions)
		
		var btn_preview = Button.new()
		btn_preview.text = "Ativo" if is_selected else "Preview"
		btn_preview.disabled = is_selected
		btn_preview.custom_minimum_size = Vector2(78, 28)
		_style_button(btn_preview, accent)
		var idx_preview = i
		btn_preview.pressed.connect(func(): _select_ball_for_preview(idx_preview))
		actions.add_child(btn_preview)
		
		var btn_remove = Button.new()
		btn_remove.text = "Remover"
		btn_remove.custom_minimum_size = Vector2(78, 28)
		btn_remove.tooltip_text = "Remover"
		_style_button(btn_remove, DANGER)
		var idx = i
		btn_remove.pressed.connect(func(): _remove_ball(idx))
		actions.add_child(btn_remove)
		
		ball_list.add_child(row_panel)
	
	_update_lobby_header()
	_update_preview()

func _remove_ball(index: int):
	if index >= 0 and index < balls_config.size():
		balls_config.remove_at(index)
		if selected_ball_index == index:
			selected_ball_index = -1
		elif selected_ball_index > index:
			selected_ball_index -= 1
		_refresh_ball_list()
		_set_status("%d bolas na fila." % balls_config.size(), GOOD if balls_config.size() >= 2 else WARN)
		_sync_ui_state()
		_update_stats()
#endregion

#region Battle
func _on_start_pressed():
	if is_battling or is_start_countdown:
		return
	if balls_config.size() < 2:
		_set_status("Adicione pelo menos 2 bolas.", WARN)
		_sync_ui_state()
		return
	
	_clear_battle()
	_assign_natural_colors_to_queue(false)
	
	var arena_key = arena_option.get_item_text(arena_option.selected)
	var arena_size = arena_sizes[arena_key]
	current_arena = arena_scene.instantiate()
	current_arena.arena_size = arena_size
	current_arena.scenario_theme = _selected_scenario_theme()
	battle_container.add_child(current_arena)
	_fit_camera_to_arena(arena_size)
	_update_vertical_camera(true)
	
	var positions = _generate_spawn_positions(balls_config.size(), arena_size)
	active_balls.clear()
	battle_total_count = balls_config.size()
	for i in range(balls_config.size()):
		var cfg = balls_config[i].duplicate(true)
		cfg["pos"] = positions[i]
		var ball = ball_scene.instantiate()
		ball.setup(cfg)
		ball.freeze = true
		current_arena.add_child(ball)
		ball.global_position = cfg["pos"]
		ball.linear_velocity = Vector2.ZERO
		ball.angular_velocity = 0.0
		active_balls.append(ball)
		ball.died.connect(_on_ball_died)
	
	_start_battle_countdown()
	_sync_ui_state()
	_update_stats()

func _on_ball_died(dead_ball: Node):
	if is_battling:
		var ko_position = dead_ball.global_position if dead_ball and is_instance_valid(dead_ball) else Vector2.ZERO
		var ko_color = Color(1.0, 0.95, 0.72)
		if dead_ball and is_instance_valid(dead_ball) and _object_has_property(dead_ball, "ball_color"):
			ko_color = Color(dead_ball.get("ball_color")).lightened(0.28)
		var killer = _resolve_killer(dead_ball)
		var streak_count = 1
		if killer:
			streak_count = _register_kill_streak(killer)
			if _object_has_property(killer, "ball_color"):
				ko_color = Color(killer.get("ball_color")).lightened(0.35)
		_trigger_ko_cinematic(killer, ko_position, streak_count, ko_color)

	active_balls.erase(dead_ball)
	check_winner()
	_update_stats()

func _start_battle_countdown():
	is_battling = false
	is_start_countdown = true
	start_countdown_timer = START_COUNTDOWN_SECONDS + START_BRAWLLS_HOLD_SECONDS
	last_countdown_second = -1
	countdown_display_marker = -99
	battle_elapsed = 0.0
	stats_refresh_timer = 0.0
	_set_status("Batalha comeca em %d..." % int(START_COUNTDOWN_SECONDS), WARN)
	_update_vertical_countdown_overlay(true)

func _start_battle_now():
	if not current_arena:
		is_start_countdown = false
		_update_vertical_countdown_overlay(false)
		return
	is_start_countdown = false
	start_countdown_timer = 0.0
	last_countdown_second = -1
	countdown_display_marker = -99
	_update_vertical_countdown_overlay(false)
	
	for ball in _get_ball_nodes():
		ball.freeze = false
	
	is_battling = true
	_set_status("Batalha em andamento.", ACCENT)
	_sync_ui_state()
	_update_stats()

func _generate_spawn_positions(count: int, arena_size: Vector2) -> Array:
	var positions = []
	var min_side = min(arena_size.x, arena_size.y)
	var margin = clamp(min_side * 0.16, 86.0, 160.0)
	var min_distance = clamp(min_side * 0.23, 120.0, 210.0)
	var min_distance_floor = 82.0
	var attempts = 0
	
	while positions.size() < count and attempts < 5200:
		var pos = Vector2(
			randf_range(margin, arena_size.x - margin),
			randf_range(margin, arena_size.y - margin)
		)
		var valid = true
		for existing in positions:
			if pos.distance_to(existing) < min_distance:
				valid = false
				break
		if valid:
			positions.append(pos)
		attempts += 1
		if attempts % 600 == 0 and min_distance > min_distance_floor:
			min_distance = max(min_distance_floor, min_distance * 0.9)
	
	while positions.size() < count:
		var idx = positions.size()
		var cols = ceili(sqrt(float(count)))
		var row_val = idx / cols
		var col_val = idx % cols
		positions.append(Vector2(
			margin + col_val * ((arena_size.x - margin * 2) / max(cols - 1, 1)),
			margin + row_val * ((arena_size.y - margin * 2) / max(cols - 1, 1))
		))
	
	return positions

func _on_reset_pressed():
	is_battling = false
	is_start_countdown = false
	start_countdown_timer = 0.0
	last_countdown_second = -1
	countdown_display_marker = -99
	ko_freeze_timer = 0.0
	ko_freeze_active = false
	camera_shake_timer = 0.0
	camera_shake_duration = 0.0
	camera_shake_intensity = 0.0
	ko_focus_timer = 0.0
	if camera_focus_tween and camera_focus_tween.is_valid():
		camera_focus_tween.kill()
	camera.offset = Vector2.ZERO
	kill_streak_by_attacker.clear()
	_clear_battle()
	_set_status("Arena resetada.", WARN)
	_update_vertical_countdown_overlay(false)
	_sync_ui_state()
	_update_stats()

func _clear_battle():
	is_start_countdown = false
	start_countdown_timer = 0.0
	last_countdown_second = -1
	countdown_display_marker = -99
	ko_freeze_timer = 0.0
	ko_freeze_active = false
	camera_shake_timer = 0.0
	camera_shake_duration = 0.0
	camera_shake_intensity = 0.0
	ko_focus_timer = 0.0
	if camera_focus_tween and camera_focus_tween.is_valid():
		camera_focus_tween.kill()
	camera.offset = Vector2.ZERO
	kill_streak_by_attacker.clear()
	if current_arena:
		current_arena.queue_free()
		current_arena = null
	active_balls.clear()
	battle_total_count = 0
	battle_elapsed = 0.0
	stats_refresh_timer = 0.0
	_update_vertical_countdown_overlay(false)
	_update_vertical_camera(true)

func check_winner():
	if not current_arena:
		return
	
	var alive_balls = _get_alive_balls()
	var active_teams = {}
	var has_ffa = false
	for ball in alive_balls:
		var tid = ball.get("team_id")
		if tid == 0:
			has_ffa = true
			active_teams[ball.get_instance_id()] = true
		else:
			active_teams[tid] = true
			
	if active_teams.size() <= 1:
		is_battling = false
		_set_balls_frozen(false)
		ko_freeze_active = false
		ko_freeze_timer = 0.0
		ko_focus_timer = 0.0
		if active_teams.size() == 1:
			if has_ffa:
				_set_status("Vencedor: " + alive_balls[0].display_name, GOOD)
			else:
				var winning_team = active_teams.keys()[0]
				_set_status("Vencedor: Time " + str(winning_team), GOOD)
		else:
			_set_status("Empate.", WARN)
		_sync_ui_state()
		_update_stats()

func _resolve_killer(dead_ball: Node) -> Node:
	if not dead_ball:
		return null
	if dead_ball.has_method("get_last_damage_source"):
		var source = dead_ball.get_last_damage_source()
		if source and is_instance_valid(source) and source.has_method("take_damage"):
			if source != dead_ball:
				return source
	return null

func _trigger_ko_cinematic(killer: Node, ko_position: Vector2, streak_count: int, accent: Color):
	_apply_ko_freeze(KO_FREEZE_DURATION)
	var streak_factor = clamp(float(streak_count), 1.0, 4.0)
	_apply_camera_shake(KO_SHAKE_INTENSITY + streak_factor * 1.25, KO_SHAKE_DURATION)
	_focus_camera_on_ko(killer, ko_position)
	_spawn_ko_pulse(ko_position, accent, streak_count)
	apply_temporary_zoom(KO_ZOOM_MULTIPLIER + streak_factor * 0.025, KO_ZOOM_IN_DURATION)
	get_tree().create_timer(KO_ZOOM_IN_DURATION + KO_ZOOM_HOLD_DURATION).timeout.connect(func():
		if is_instance_valid(self):
			reset_zoom(KO_ZOOM_OUT_DURATION)
	)

func _register_kill_streak(killer: Node) -> int:
	if not killer or not is_instance_valid(killer):
		return 1

	var now = Time.get_ticks_msec() * 0.001
	var attacker_id = killer.get_instance_id()
	var entry = kill_streak_by_attacker.get(attacker_id, {"count": 0, "last_time": -999.0})
	var count = int(entry.get("count", 0))
	var last_time = float(entry.get("last_time", -999.0))
	if now - last_time <= KILL_STREAK_WINDOW:
		count += 1
	else:
		count = 1
	kill_streak_by_attacker[attacker_id] = {
		"count": count,
		"last_time": now,
	}
	_prune_old_streak_entries(now)
	return count

func _prune_old_streak_entries(now: float):
	var stale_ids = []
	for attacker_id in kill_streak_by_attacker.keys():
		var entry = kill_streak_by_attacker[attacker_id]
		if now - float(entry.get("last_time", 0.0)) > KILL_STREAK_WINDOW * 1.4:
			stale_ids.append(attacker_id)
	for attacker_id in stale_ids:
		kill_streak_by_attacker.erase(attacker_id)

func _spawn_ko_pulse(position: Vector2, color: Color, streak_count: int):
	if not current_arena or not is_instance_valid(current_arena):
		return
	var fx_scale = get_short_video_fx_scale()
	var streak_factor = clamp(float(streak_count), 1.0, 4.0)
	var base_radius = 20.0 * fx_scale
	var ring = Line2D.new()
	ring.closed = true
	ring.width = (4.0 + streak_factor) * fx_scale
	ring.default_color = Color(color.r, color.g, color.b, 0.92)
	ring.points = _circle_points(base_radius, KO_RING_SEGMENTS)
	ring.global_position = position
	current_arena.add_child(ring)

	var fill = Polygon2D.new()
	fill.polygon = _circle_points(base_radius * 0.74, KO_RING_SEGMENTS)
	fill.color = Color(color.r, color.g, color.b, 0.2)
	fill.global_position = position
	current_arena.add_child(fill)

	var max_scale = 2.0 + streak_factor * 0.28
	var pulse_duration = 0.28 + streak_factor * 0.035
	var ring_tween = ring.create_tween()
	ring_tween.set_parallel(true)
	ring_tween.tween_property(ring, "scale", Vector2.ONE * max_scale, pulse_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	ring_tween.tween_property(ring, "modulate", Color(1, 1, 1, 0), pulse_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	ring_tween.finished.connect(func():
		if is_instance_valid(ring):
			ring.queue_free()
	)

	var fill_tween = fill.create_tween()
	fill_tween.set_parallel(true)
	fill_tween.tween_property(fill, "scale", Vector2.ONE * (1.45 + streak_factor * 0.18), pulse_duration * 0.82).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	fill_tween.tween_property(fill, "modulate", Color(1, 1, 1, 0), pulse_duration * 0.82).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	fill_tween.finished.connect(func():
		if is_instance_valid(fill):
			fill.queue_free()
	)

func _circle_points(radius: float, segments: int) -> PackedVector2Array:
	var points = PackedVector2Array()
	for i in range(segments):
		var angle = TAU * float(i) / float(segments)
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points

func _apply_ko_freeze(duration: float):
	if not is_battling:
		return
	ko_freeze_timer = max(ko_freeze_timer, duration)
	if ko_freeze_active:
		return
	ko_freeze_active = true
	_set_balls_frozen(true)

func _update_ko_freeze(delta: float):
	if not ko_freeze_active:
		return
	ko_freeze_timer = max(0.0, ko_freeze_timer - delta)
	if ko_freeze_timer <= 0.0:
		ko_freeze_active = false
		if is_battling:
			_set_balls_frozen(false)

func _update_ko_focus(delta: float):
	if ko_focus_timer > 0.0:
		ko_focus_timer = max(0.0, ko_focus_timer - delta)

func _set_balls_frozen(value: bool):
	for ball in _get_ball_nodes():
		if is_instance_valid(ball):
			ball.freeze = value

func _focus_camera_on_ko(killer: Node, ko_position: Vector2):
	ko_focus_position = ko_position
	ko_focus_timer = KO_FOCUS_DURATION
	if not current_arena or not is_instance_valid(current_arena):
		return
	if camera_focus_tween and camera_focus_tween.is_valid():
		camera_focus_tween.kill()
	var focus_position = ko_position
	if killer and is_instance_valid(killer):
		focus_position = ko_position.lerp(killer.global_position, 0.35)
	var target_position = camera_home_position.lerp(focus_position, 0.28)
	camera_focus_tween = create_tween()
	camera_focus_tween.tween_property(camera, "position", target_position, 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	camera_focus_tween.tween_interval(0.12)
	camera_focus_tween.tween_property(camera, "position", camera_home_position, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _apply_camera_shake(intensity: float, duration: float):
	camera_shake_intensity = max(camera_shake_intensity, intensity)
	camera_shake_timer = max(camera_shake_timer, duration)
	camera_shake_duration = max(camera_shake_duration, camera_shake_timer)

func _update_camera_shake(delta: float):
	if camera_shake_timer <= 0.0:
		if camera.offset != Vector2.ZERO:
			camera.offset = Vector2.ZERO
		camera_shake_duration = 0.0
		camera_shake_intensity = 0.0
		return

	camera_shake_timer = max(0.0, camera_shake_timer - delta)
	var normalized = 1.0
	if camera_shake_duration > 0.001:
		normalized = clamp(camera_shake_timer / camera_shake_duration, 0.0, 1.0)
	var amplitude = camera_shake_intensity * normalized
	camera.offset = Vector2(randf_range(-amplitude, amplitude), randf_range(-amplitude, amplitude))
#endregion

#region Stats
func _update_stats():
	if not stats_label:
		return
	
	if not current_arena:
		var preview_cfg = _get_preview_config()
		var preview_name = String(preview_cfg.get("display_name", "Novo Brawler"))
		var preview_weapon = WeaponRegistryScript.normalize(preview_cfg.get("weapon_type", "Shield"))
		var preview_source = "Fila" if selected_ball_index >= 0 else "Rascunho"
		stats_label.text = "CONFIGURACAO\nFila: %d bola(s)\nArena: %s" % [
			balls_config.size(),
			arena_option.get_item_text(max(arena_option.selected, 0)) if arena_option.get_item_count() > 0 else "-",
		]
		stats_label.text += "\nCenario: %s\nPreview %s: %s (%s)" % [_selected_scenario_theme(), preview_source, preview_name, preview_weapon]
		stats_label.text += "\n--------------------\n%s" % ("Pronto para iniciar" if balls_config.size() >= 2 else "Monte a fila para iniciar")
		_update_vertical_stats()
		return
	
	var alive_balls = _get_alive_balls()
	alive_balls.sort_custom(func(a, b): return a.current_hp > b.current_hp)
	var all_balls = _get_ball_nodes()
	var total_balls = battle_total_count if battle_total_count > 0 else all_balls.size()
	var title = "EM BATALHA"
	if is_start_countdown:
		title = "PREPARANDO"
	elif not is_battling:
		title = "ENCERRADA"
	var text = "%s\nVivos %d/%d | Tempo %s\n" % [title, alive_balls.size(), total_balls, _format_time(battle_elapsed)]
	if is_start_countdown:
		text += "Inicio em %ds\n" % max(1, int(ceil(start_countdown_timer)))
	text += "--------------------\n"
	for ball in alive_balls:
		var speed = int(ball.linear_velocity.length())
		var dmg = _estimate_damage(ball)
		var team_str = " [T%d]" % ball.team_id if ball.team_id > 0 else ""
		text += "%s%s\n" % [ball.display_name, team_str]
		text += "HP %.0f/%.0f | Vel %d | Dano %.1f\n" % [ball.current_hp, ball.max_hp, speed, dmg]
	stats_label.text = text.strip_edges()
	_update_vertical_stats(alive_balls, all_balls)

func _get_alive_balls() -> Array:
	var alive_balls = []
	if not current_arena:
		return alive_balls
	_compact_active_balls()
	for ball in active_balls:
		if ball.has_method("take_damage") and ball.is_alive:
			alive_balls.append(ball)
	return alive_balls

func _get_ball_nodes() -> Array:
	if not current_arena:
		return []
	_compact_active_balls()
	return active_balls.duplicate()

func _compact_active_balls():
	var compacted = []
	for ball in active_balls:
		if is_instance_valid(ball) and ball.has_method("take_damage"):
			compacted.append(ball)
	active_balls = compacted

func _estimate_damage(ball: Node) -> float:
	if not is_instance_valid(ball):
		return 0.0
	if not ball.weapon:
		return float(ball.base_damage)
	var weapon = ball.weapon
	if weapon.has_method("get_damage_indicator"):
		return max(0.0, float(weapon.get_damage_indicator()))
	if _object_has_property(weapon, "current_damage"):
		return float(weapon.get("current_damage"))
	if _object_has_property(weapon, "base_damage"):
		return float(weapon.get("base_damage"))
	return ball.base_damage
#endregion

#region Camera
func _fit_camera_to_arena(arena_size: Vector2):
	var viewport_size = get_viewport_rect().size
	var panel_w = SIDE_PANEL_WIDTH if side_panel.visible else 0.0
	var arena_view_width = max(320.0, viewport_size.x - panel_w - 28.0)
	var arena_view_height = max(260.0, viewport_size.y - 36.0)
	var padded_arena = arena_size + Vector2(120.0, 120.0)
	var zoom_factor = min(arena_view_width / padded_arena.x, arena_view_height / padded_arena.y)
	zoom_factor = clamp(zoom_factor, 0.32, 1.05)
	base_zoom_factor = zoom_factor
	camera.zoom = Vector2(zoom_factor, zoom_factor)
	
	var desired_screen_center = Vector2(arena_view_width / 2.0, viewport_size.y / 2.0)
	var screen_offset = desired_screen_center - viewport_size / 2.0
	camera.position = arena_size / 2.0 - screen_offset / zoom_factor
	camera_home_position = camera.position

func _on_viewport_resized():
	if current_arena:
		_fit_camera_to_arena(current_arena.arena_size)
	if is_vertical_mode:
		_layout_vertical_overlay()

func get_short_video_fx_scale() -> float:
	return VERTICAL_FX_SCALE if is_vertical_mode else 1.0

func apply_temporary_zoom(multiplier: float, duration: float):
	if camera_tween and camera_tween.is_valid():
		camera_tween.kill()
	camera_tween = create_tween()
	camera_tween.tween_property(camera, "zoom", Vector2.ONE * (base_zoom_factor * multiplier), duration).set_trans(Tween.TRANS_SINE)
	if vertical_camera and is_instance_valid(vertical_camera):
		if vertical_camera_tween and vertical_camera_tween.is_valid():
			vertical_camera_tween.kill()
		vertical_camera_tween = create_tween()
		vertical_camera_tween.tween_method(_set_vertical_zoom_multiplier, vertical_zoom_multiplier, multiplier, duration).set_trans(Tween.TRANS_SINE)

func reset_zoom(duration: float = 0.25):
	if camera_tween and camera_tween.is_valid():
		camera_tween.kill()
	camera_tween = create_tween()
	camera_tween.tween_property(camera, "zoom", Vector2.ONE * base_zoom_factor, duration).set_trans(Tween.TRANS_SINE)
	if vertical_camera and is_instance_valid(vertical_camera):
		if vertical_camera_tween and vertical_camera_tween.is_valid():
			vertical_camera_tween.kill()
		vertical_camera_tween = create_tween()
		vertical_camera_tween.tween_method(_set_vertical_zoom_multiplier, vertical_zoom_multiplier, 1.0, duration).set_trans(Tween.TRANS_SINE)
	else:
		vertical_zoom_multiplier = 1.0

func _set_vertical_zoom_multiplier(multiplier: float):
	vertical_zoom_multiplier = multiplier
	if is_vertical_mode:
		_update_vertical_camera()
#endregion

#region UI State
func _sync_ui_state():
	var has_enough_balls = balls_config.size() >= 2
	var lobby_locked = is_battling or is_start_countdown
	btn_start.disabled = lobby_locked or not has_enough_balls
	btn_reset.disabled = current_arena == null
	btn_clear.disabled = lobby_locked or balls_config.size() == 0
	btn_add.disabled = lobby_locked
	btn_vertical.disabled = false
	arena_option.disabled = lobby_locked
	scenario_option.disabled = lobby_locked
	weapon_option.disabled = lobby_locked
	if team_option:
		team_option.disabled = lobby_locked
	input_name.editable = not lobby_locked
	spin_hp.editable = not lobby_locked
	spin_mass.editable = not lobby_locked
	if vertical_close_button and is_instance_valid(vertical_close_button):
		vertical_close_button.disabled = false

func _selected_weapon_type() -> String:
	if weapon_option.get_item_count() == 0:
		return "Shield"
	return weapon_option.get_item_text(weapon_option.selected)

func _selected_scenario_theme() -> String:
	if not scenario_option or scenario_option.get_item_count() == 0:
		return SCENARIO_DESERT
	var index = scenario_option.selected
	if index < 0:
		index = 0
	return scenario_option.get_item_text(index)

func _on_scenario_selected(_index: int):
	_apply_scenario_chrome()
	_update_lobby_header()
	if current_arena:
		if current_arena.has_method("set_scenario_theme"):
			current_arena.set_scenario_theme(_selected_scenario_theme())
		elif _object_has_property(current_arena, "scenario_theme"):
			current_arena.set("scenario_theme", _selected_scenario_theme())
			current_arena.queue_redraw()
	_update_stats()

func _apply_scenario_chrome():
	RenderingServer.set_default_clear_color(_scenario_clear_color())
	_refresh_vertical_overlay_styles()

func _scenario_clear_color() -> Color:
	if _selected_scenario_theme() == SCENARIO_CEMETERY:
		return CEMETERY_CLEAR
	return DESERT_CLEAR

func _set_status(text: String, color: Color):
	lbl_winner.text = text
	lbl_winner.add_theme_color_override("font_color", color)
	if status_surface:
		status_surface.add_theme_stylebox_override("panel", _make_style(color.darkened(0.78), color, 1, 12))
	_update_vertical_stats()

func _format_time(seconds: float) -> String:
	var total = int(seconds)
	var minutes = int(total / 60)
	var secs = total % 60
	return "%02d:%02d" % [minutes, secs]
	
func _current_countdown_marker() -> int:
	var numeric_phase_time = start_countdown_timer - START_BRAWLLS_HOLD_SECONDS
	if numeric_phase_time > 0.0:
		return max(1, int(ceil(numeric_phase_time)))
	return 0
	
func _load_brawl_countdown_font() -> Font:
	if brawl_countdown_font:
		return brawl_countdown_font
	for font_path in [
		"res://fonts/BrawlStars.ttf",
		"res://fonts/Brawl_Stars.ttf",
		"res://fonts/LilitaOne-Regular.ttf",
		"res://BrawlStars.ttf",
	]:
		if ResourceLoader.exists(font_path):
			var loaded_font = load(font_path)
			if loaded_font is Font:
				brawl_countdown_font = loaded_font
				break
	return brawl_countdown_font
	
func _update_vertical_countdown_overlay(animate: bool):
	if not vertical_countdown_label or not is_instance_valid(vertical_countdown_label):
		return
	if not is_vertical_mode or not is_start_countdown:
		vertical_countdown_label.visible = false
		if vertical_countdown_tween and vertical_countdown_tween.is_valid():
			vertical_countdown_tween.kill()
		vertical_countdown_tween = null
		return
	
	var marker = _current_countdown_marker()
	countdown_display_marker = marker
	vertical_countdown_label.visible = true

	var is_brawlls = marker <= 0
	vertical_countdown_label.text = "Brawlls!" if is_brawlls else str(marker)

	# Bigger sizes: numbers very large, "Brawlls!" slightly smaller but still impactful.
	var font_size = _vertical_text_size(280.0, 180, 340) if not is_brawlls else _vertical_text_size(160.0, 110, 200)
	vertical_countdown_label.add_theme_font_size_override("font_size", font_size)
	# Always white text with thick black outline (Brawl Stars style).
	vertical_countdown_label.add_theme_color_override("font_color", Color.WHITE)
	vertical_countdown_label.add_theme_color_override("font_outline_color", Color.BLACK)
	vertical_countdown_label.add_theme_constant_override("outline_size", 16)

	if not animate:
		if not (vertical_countdown_tween and vertical_countdown_tween.is_valid()):
			vertical_countdown_label.scale = Vector2.ONE
			vertical_countdown_label.modulate = Color.WHITE
		return

	if vertical_countdown_tween and vertical_countdown_tween.is_valid():
		vertical_countdown_tween.kill()
	# Start big and transparent, shrink to normal size while fading in.
	vertical_countdown_label.scale = Vector2.ONE * 2.4
	vertical_countdown_label.modulate = Color(1, 1, 1, 0)
	vertical_countdown_tween = create_tween()
	vertical_countdown_tween.tween_property(vertical_countdown_label, "modulate:a", 1.0, 0.10)
	vertical_countdown_tween.parallel().tween_property(vertical_countdown_label, "scale", Vector2.ONE, 0.72).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _object_has_property(obj: Object, property_name: String) -> bool:
	if not is_instance_valid(obj):
		return false
	for property in obj.get_property_list():
		if property.has("name") and property["name"] == property_name:
			return true
	return false
#endregion

#region Style Helpers
func _make_style(bg: Color, border: Color, border_width: int, radius: int) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 7
	style.content_margin_bottom = 7
	return style

func _make_style_ex(bg: Color, border: Color, border_width: int, radius: int, shadow: float = 0.0, shadow_color: Color = Color(0, 0, 0, 0.55), pad_x: int = 10, pad_y: int = 9) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.content_margin_left = pad_x
	style.content_margin_right = pad_x
	style.content_margin_top = pad_y
	style.content_margin_bottom = pad_y
	style.anti_aliasing = true
	style.anti_aliasing_size = 1.0
	if shadow > 0.0:
		style.shadow_color = shadow_color
		style.shadow_size = int(shadow)
		style.shadow_offset = Vector2(0, max(2.0, shadow * 0.4))
	return style

func _make_style_accent_top(bg: Color, accent: Color, radius: int = 16, accent_height: int = 3, shadow: float = 12.0) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = accent
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_width_top = accent_height
	style.border_blend = false
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	style.anti_aliasing = true
	style.anti_aliasing_size = 1.0
	if shadow > 0.0:
		style.shadow_color = Color(accent.r * 0.4, accent.g * 0.4, accent.b * 0.4, 0.45)
		style.shadow_size = int(shadow)
		style.shadow_offset = Vector2(0, 4)
	# Soften the side/bottom borders so only the top reads as a neon stripe
	return style

func _style_button(button: Button, color: Color):
	var radius = 10
	var normal = _make_style_ex(color.darkened(0.30), color.darkened(0.05), 1, radius, 6.0, Color(color.r * 0.5, color.g * 0.5, color.b * 0.5, 0.42), 14, 9)
	var hover = _make_style_ex(color.darkened(0.10), color.lightened(0.22), 1, radius, 12.0, Color(color.r, color.g, color.b, 0.55), 14, 9)
	var pressed = _make_style_ex(color.darkened(0.46), color, 2, radius, 0.0, Color.BLACK, 14, 9)
	var disabled = _make_style_ex(Color(0.13, 0.15, 0.20, 0.85), Color(0.24, 0.27, 0.34, 0.75), 1, radius, 0.0, Color.BLACK, 14, 9)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", hover)
	button.add_theme_stylebox_override("disabled", disabled)
	button.add_theme_color_override("font_color", Color(0.96, 0.98, 1.0))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", Color(0.52, 0.57, 0.64))
	button.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.55))
	button.add_theme_constant_override("outline_size", 2)
	button.add_theme_font_size_override("font_size", 13)

func _style_line_edit(line_edit: LineEdit):
	line_edit.add_theme_stylebox_override("normal", _make_style_ex(CARD_BG, Color(0.28, 0.36, 0.50, 0.80), 1, 8, 0.0, Color.BLACK, 12, 9))
	line_edit.add_theme_stylebox_override("focus", _make_style_ex(CARD_BG_HOVER, ARCADE_CYAN, 2, 8, 8.0, Color(ARCADE_CYAN.r, ARCADE_CYAN.g, ARCADE_CYAN.b, 0.55), 12, 9))
	line_edit.add_theme_color_override("font_color", Color(0.94, 0.97, 1.0))
	line_edit.add_theme_color_override("font_placeholder_color", Color(0.58, 0.65, 0.76))
	line_edit.add_theme_color_override("caret_color", ARCADE_CYAN)
	line_edit.add_theme_font_size_override("font_size", 13)

func _style_spinbox(spinbox: SpinBox):
	spinbox.add_theme_stylebox_override("normal", _make_style_ex(CARD_BG, Color(0.28, 0.36, 0.50, 0.80), 1, 8, 0.0, Color.BLACK, 10, 8))
	spinbox.add_theme_stylebox_override("focus", _make_style_ex(CARD_BG_HOVER, ARCADE_CYAN, 2, 8, 6.0, Color(ARCADE_CYAN.r, ARCADE_CYAN.g, ARCADE_CYAN.b, 0.45), 10, 8))
	spinbox.add_theme_color_override("font_color", Color(0.94, 0.97, 1.0))
	spinbox.add_theme_font_size_override("font_size", 13)

func _refresh_vertical_overlay_styles():
	if vertical_bg and is_instance_valid(vertical_bg):
		vertical_bg.color = _scenario_overlay_color()
	if vertical_border and is_instance_valid(vertical_border):
		vertical_border.add_theme_stylebox_override("panel", _make_vertical_frame_style())
	if vertical_arena_border and is_instance_valid(vertical_arena_border):
		vertical_arena_border.add_theme_stylebox_override("panel", _make_vertical_arena_border_style())
	if vertical_title_panel and is_instance_valid(vertical_title_panel):
		vertical_title_panel.add_theme_stylebox_override("panel", _make_vertical_text_panel_style())
	if vertical_stats_panel and is_instance_valid(vertical_stats_panel):
		vertical_stats_panel.add_theme_stylebox_override("panel", _make_vertical_text_panel_style())

func _make_vertical_frame_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = _scenario_frame_color()
	style.border_color = _scenario_frame_border_color()
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	return style

func _make_vertical_arena_border_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.border_color = _scenario_arena_border_color()
	style.border_width_left = 5
	style.border_width_right = 5
	style.border_width_top = 5
	style.border_width_bottom = 5
	return style

func _make_vertical_text_panel_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.border_color = Color(0, 0, 0, 0)
	style.content_margin_left = 0
	style.content_margin_right = 0
	style.content_margin_top = 0
	style.content_margin_bottom = 0
	return style

func _scenario_overlay_color() -> Color:
	if _selected_scenario_theme() == SCENARIO_CEMETERY:
		return Color(0.0, 0.0, 0.02, 0.78)
	return Color(0.05, 0.035, 0.02, 0.74)

func _scenario_frame_color() -> Color:
	return Color(0.965, 0.93, 0.82, 0.985)

func _scenario_frame_border_color() -> Color:
	return Color(0.0, 0.0, 0.0, 0.18)

func _scenario_arena_border_color() -> Color:
	return Color(0.0, 0.0, 0.0, 1.0)

func _scenario_panel_color() -> Color:
	if _selected_scenario_theme() == SCENARIO_CEMETERY:
		return CEMETERY_PANEL
	return DESERT_PANEL

func _scenario_panel_border_color() -> Color:
	if _selected_scenario_theme() == SCENARIO_CEMETERY:
		return CEMETERY_BORDER
	return DESERT_BORDER
#endregion

#region Vertical Mode
func _toggle_vertical_mode():
	is_vertical_mode = not is_vertical_mode
	if is_vertical_mode:
		pre_vertical_window_size = DisplayServer.window_get_size()
		side_panel_was_visible = side_panel.visible
		side_panel.hide()
		_enter_vertical_camera_mode()
		DisplayServer.window_set_size(Vector2i(1080, 1920))
		_create_vertical_overlay()
		btn_vertical.text = "Fechar 9:16 (ESC)"
		_style_button(btn_vertical, Color(0.6, 0.15, 0.28))
		if stats_panel: stats_panel.hide()
	else:
		_destroy_vertical_overlay()
		_exit_vertical_camera_mode()
		DisplayServer.window_set_size(pre_vertical_window_size)
		if side_panel_was_visible:
			side_panel.show()
		btn_vertical.text = "Modo 9:16"
		_style_button(btn_vertical, Color(0.85, 0.25, 0.55))
		if stats_panel: stats_panel.show()
		if current_arena:
			_fit_camera_to_arena(current_arena.arena_size)
	_sync_ui_state()

func _enter_vertical_camera_mode():
	if camera and is_instance_valid(camera):
		camera.make_current()

func _exit_vertical_camera_mode():
	if camera and is_instance_valid(camera):
		camera.make_current()

func _create_vertical_overlay():
	# Container: overlay sobre o CanvasLayer para nao interferir com o jogo
	vertical_overlay = CanvasLayer.new()
	vertical_overlay.layer = 0
	add_child(vertical_overlay)
	
	# Fundo escuro semi-transparente
	var bg = ColorRect.new()
	vertical_bg = bg
	bg.color = _scenario_overlay_color()
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.anchors_preset = Control.PRESET_FULL_RECT
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vertical_overlay.add_child(bg)
	
	# Painel ocupa a janela toda (que agora é 1080x1920)
	var vp_rect = get_viewport().get_visible_rect()
	var panel_w = vp_rect.size.x
	var panel_h = vp_rect.size.y
	var panel_x = 0.0
	var panel_y = 0.0
	
	# Borda decorativa
	var border = Panel.new()
	vertical_border = border
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	border.add_theme_stylebox_override("panel", _make_vertical_frame_style())
	border.position = Vector2(panel_x - 3, panel_y - 3)
	border.size = Vector2(panel_w + 6, panel_h + 6)
	vertical_overlay.add_child(border)
	
	vertical_subviewport = SubViewport.new()
	# Resolução interna alta para qualidade de gravação (1080x1920)
	var render_w = 1080
	var render_h = 1920
	vertical_subviewport.size = Vector2i(render_w, render_h)
	vertical_subviewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vertical_subviewport.world_2d = get_viewport().world_2d
	vertical_subviewport.transparent_bg = true
	
	vertical_container = SubViewportContainer.new()
	vertical_container.stretch = true
	vertical_container.stretch_shrink = 1
	vertical_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vertical_container.position = Vector2(panel_x, panel_y)
	vertical_container.size = Vector2(panel_w, panel_h)
	vertical_container.add_child(vertical_subviewport)
	vertical_overlay.add_child(vertical_container)
	
	vertical_camera = Camera2D.new()
	vertical_subviewport.add_child(vertical_camera)
	vertical_camera.enabled = true
	vertical_camera.make_current()
	
	vertical_arena_border = Panel.new()
	vertical_arena_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vertical_arena_border.add_theme_stylebox_override("panel", _make_vertical_arena_border_style())
	vertical_overlay.add_child(vertical_arena_border)
	
	vertical_title_panel = PanelContainer.new()
	vertical_title_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vertical_title_panel.add_theme_stylebox_override("panel", _make_vertical_text_panel_style())
	vertical_overlay.add_child(vertical_title_panel)
	
	var title_margin = MarginContainer.new()
	title_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_margin.add_theme_constant_override("margin_left", 0)
	title_margin.add_theme_constant_override("margin_top", 0)
	title_margin.add_theme_constant_override("margin_right", 0)
	title_margin.add_theme_constant_override("margin_bottom", 0)
	vertical_title_panel.add_child(title_margin)
	
	vertical_title_label = RichTextLabel.new()
	vertical_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vertical_title_label.bbcode_enabled = true
	vertical_title_label.fit_content = false
	vertical_title_label.scroll_active = false
	vertical_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vertical_title_label.add_theme_font_size_override("normal_font_size", 32)
	vertical_title_label.add_theme_color_override("default_color", Color.WHITE)
	vertical_title_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	vertical_title_label.add_theme_constant_override("outline_size", 5)
	title_margin.add_child(vertical_title_label)
	
	vertical_stats_panel = PanelContainer.new()
	vertical_stats_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vertical_stats_panel.add_theme_stylebox_override("panel", _make_vertical_text_panel_style())
	vertical_overlay.add_child(vertical_stats_panel)
	
	var stats_margin = MarginContainer.new()
	stats_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stats_margin.add_theme_constant_override("margin_left", 0)
	stats_margin.add_theme_constant_override("margin_top", 0)
	stats_margin.add_theme_constant_override("margin_right", 0)
	stats_margin.add_theme_constant_override("margin_bottom", 0)
	vertical_stats_panel.add_child(stats_margin)
	
	vertical_stats_label = RichTextLabel.new()
	vertical_stats_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vertical_stats_label.bbcode_enabled = true
	vertical_stats_label.fit_content = false
	vertical_stats_label.scroll_active = false
	vertical_stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vertical_stats_label.add_theme_font_size_override("normal_font_size", 26)
	vertical_stats_label.add_theme_color_override("default_color", Color.WHITE)
	vertical_stats_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	vertical_stats_label.add_theme_constant_override("outline_size", 5)
	stats_margin.add_child(vertical_stats_label)

	vertical_close_button = Button.new()
	vertical_close_button.text = "Fechar 9:16"
	vertical_close_button.custom_minimum_size = Vector2(132, 36)
	_style_button(vertical_close_button, ARCADE_PINK)
	vertical_close_button.pressed.connect(_toggle_vertical_mode)
	vertical_overlay.add_child(vertical_close_button)
	
	vertical_countdown_label = Label.new()
	vertical_countdown_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vertical_countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_countdown_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	vertical_countdown_label.clip_text = false
	vertical_countdown_label.visible = false
	vertical_countdown_label.add_theme_font_size_override("font_size", 200)
	vertical_countdown_label.add_theme_color_override("font_color", Color.WHITE)
	vertical_countdown_label.add_theme_color_override("font_outline_color", Color.BLACK)
	vertical_countdown_label.add_theme_constant_override("outline_size", 16)
	var brawl_font = _load_brawl_countdown_font()
	if brawl_font:
		vertical_countdown_label.add_theme_font_override("font", brawl_font)
	vertical_overlay.add_child(vertical_countdown_label)
	
	# Label de instrucao
	var lbl_info = Label.new()
	lbl_info.text = "Area 9:16 para gravacao (ESC para fechar)"
	lbl_info.add_theme_font_size_override("font_size", 12)
	lbl_info.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	lbl_info.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	lbl_info.add_theme_constant_override("outline_size", 3)
	lbl_info.position = Vector2(panel_x, panel_y + panel_h + 6)
	lbl_info.size = Vector2(panel_w, 22)
	lbl_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl_info.visible = false
	vertical_overlay.add_child(lbl_info)
	
	_layout_vertical_overlay()
	_update_vertical_stats()
	_update_vertical_countdown_overlay(false)
	_sync_ui_state()

func _layout_vertical_overlay():
	if not vertical_overlay or not is_instance_valid(vertical_overlay):
		return
	
	var frame_rect = _get_vertical_frame_rect()
	var display_count = max(2, _vertical_display_ball_count())
	var extra_stats_rows = max(display_count - 3, 0)
	var extra_title_rows = max(display_count - 2, 0)
	var content_pad = clamp(frame_rect.size.x * 0.035, 16.0, 28.0)
	var gap = clamp(frame_rect.size.y * 0.008, 8.0, 14.0)
	var title_h = clamp(frame_rect.size.y * 0.075 + float(extra_title_rows) * 10.0, 72.0, 136.0)
	var stats_h = clamp(frame_rect.size.y * 0.075 + float(extra_stats_rows) * 28.0, 78.0, 196.0)
	var content_w = frame_rect.size.x - content_pad * 2.0
	var max_arena_h = frame_rect.size.y - title_h - stats_h - gap * 2.0 - content_pad * 2.0
	var arena_target_h = content_w * VERTICAL_ARENA_RATIO
	var arena_min_h = 180.0 if display_count <= 3 else 148.0
	var arena_h = min(arena_target_h, max_arena_h)
	if max_arena_h >= arena_min_h:
		arena_h = max(arena_h, arena_min_h)
	else:
		arena_h = max(120.0, max_arena_h)
	var stack_h = title_h + gap + arena_h + gap + stats_h
	var top_offset = clamp(frame_rect.size.y * VERTICAL_STAGE_TOP_RATIO, 108.0, 300.0)
	var bottom_safe = clamp(frame_rect.size.y * 0.16, 150.0, 300.0)
	var stack_y = frame_rect.position.y + top_offset
	var max_stack_bottom = frame_rect.position.y + frame_rect.size.y - bottom_safe
	if stack_y + stack_h > max_stack_bottom:
		stack_y = max(frame_rect.position.y + content_pad, max_stack_bottom - stack_h)
	var title_rect = Rect2(
		Vector2(frame_rect.position.x + content_pad, stack_y),
		Vector2(content_w, title_h)
	)
	var arena_rect = Rect2(
		Vector2(title_rect.position.x, title_rect.position.y + title_rect.size.y + gap),
		Vector2(content_w, arena_h)
	)
	var stats_rect = Rect2(
		Vector2(title_rect.position.x, arena_rect.position.y + arena_rect.size.y + gap),
		Vector2(content_w, stats_h)
	)
	
	if vertical_bg and is_instance_valid(vertical_bg):
		vertical_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	if vertical_border and is_instance_valid(vertical_border):
		var pad = 0.0
		vertical_border.position = frame_rect.position - Vector2(pad, pad)
		vertical_border.size = frame_rect.size + Vector2(pad * 2.0, pad * 2.0)
	
	if vertical_title_panel and is_instance_valid(vertical_title_panel):
		vertical_title_panel.position = title_rect.position
		vertical_title_panel.size = title_rect.size
	
	if vertical_container and is_instance_valid(vertical_container):
		vertical_container.position = arena_rect.position
		vertical_container.size = arena_rect.size
	
	if vertical_arena_border and is_instance_valid(vertical_arena_border):
		var arena_border_pad = 0.0
		vertical_arena_border.position = arena_rect.position - Vector2(arena_border_pad, arena_border_pad)
		vertical_arena_border.size = arena_rect.size + Vector2(arena_border_pad * 2.0, arena_border_pad * 2.0)
	
	if vertical_subviewport and is_instance_valid(vertical_subviewport):
		vertical_subviewport.size = Vector2i(max(1, int(round(arena_rect.size.x))), max(1, int(round(arena_rect.size.y))))
	
	if vertical_stats_panel and is_instance_valid(vertical_stats_panel):
		vertical_stats_panel.position = stats_rect.position
		vertical_stats_panel.size = stats_rect.size
	
	if vertical_countdown_label and is_instance_valid(vertical_countdown_label):
		# Covers the full 9:16 frame so horizontal+vertical centering work correctly.
		# pivot_offset at center ensures scale animation stays on-center.
		vertical_countdown_label.position = frame_rect.position
		vertical_countdown_label.size = frame_rect.size
		vertical_countdown_label.pivot_offset = frame_rect.size * 0.5

	if vertical_close_button and is_instance_valid(vertical_close_button):
		var viewport_size = get_viewport().get_visible_rect().size
		var button_size = vertical_close_button.custom_minimum_size
		if button_size.x <= 0.0 or button_size.y <= 0.0:
			button_size = Vector2(132, 36)
		vertical_close_button.size = button_size
		var close_margin = 12.0
		var right_space = viewport_size.x - (frame_rect.position.x + frame_rect.size.x)
		var left_space = frame_rect.position.x
		var top_space = frame_rect.position.y
		var bottom_space = viewport_size.y - (frame_rect.position.y + frame_rect.size.y)
		var close_pos = Vector2(close_margin, close_margin)
		var has_outside_slot = false
		if right_space >= button_size.x + close_margin:
			close_pos = Vector2(frame_rect.position.x + frame_rect.size.x + close_margin, frame_rect.position.y + close_margin)
			has_outside_slot = true
		elif left_space >= button_size.x + close_margin:
			close_pos = Vector2(frame_rect.position.x - button_size.x - close_margin, frame_rect.position.y + close_margin)
			has_outside_slot = true
		elif bottom_space >= button_size.y + close_margin:
			close_pos = Vector2(
				clamp(frame_rect.position.x + frame_rect.size.x - button_size.x, close_margin, viewport_size.x - button_size.x - close_margin),
				frame_rect.position.y + frame_rect.size.y + close_margin
			)
			has_outside_slot = true
		elif top_space >= button_size.y + close_margin:
			close_pos = Vector2(
				clamp(frame_rect.position.x + frame_rect.size.x - button_size.x, close_margin, viewport_size.x - button_size.x - close_margin),
				frame_rect.position.y - button_size.y - close_margin
			)
			has_outside_slot = true

		vertical_close_button.visible = has_outside_slot
		if has_outside_slot:
			vertical_close_button.position = close_pos
	
	_update_vertical_camera(true)

func _get_vertical_frame_rect() -> Rect2:
	var viewport_size = get_viewport().get_visible_rect().size
	var menu_width = SIDE_PANEL_WIDTH if side_panel.visible else 0.0
	var game_width = max(240.0, viewport_size.x - menu_width)
	var max_width = max(160.0, game_width - VERTICAL_PADDING * 2.0)
	var max_height = max(280.0, viewport_size.y - VERTICAL_PADDING * 2.0)
	var frame_height = max_height
	var frame_width = frame_height * VERTICAL_ASPECT
	
	if frame_width > max_width:
		frame_width = max_width
		frame_height = frame_width / VERTICAL_ASPECT
	
	var frame_x = (game_width - frame_width) / 2.0
	var frame_y = (viewport_size.y - frame_height) / 2.0
	return Rect2(Vector2(frame_x, frame_y), Vector2(frame_width, frame_height))

func _update_vertical_camera(snap: bool = false):
	if not vertical_camera or not is_instance_valid(vertical_camera):
		return
	if not vertical_subviewport or not is_instance_valid(vertical_subviewport):
		return
	
	var arena_size = _get_vertical_arena_size()
	var viewport_size = Vector2(vertical_subviewport.size.x, vertical_subviewport.size.y)
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return
	
	var padded_arena = arena_size + Vector2(VERTICAL_CAMERA_PADDING * 2.0, VERTICAL_CAMERA_PADDING * 2.0)
	var contain_zoom = min(viewport_size.x / padded_arena.x, viewport_size.y / padded_arena.y)
	var cover_zoom = max(viewport_size.x / padded_arena.x, viewport_size.y / padded_arena.y)
	var zoom_factor = min(cover_zoom, contain_zoom * VERTICAL_CAMERA_ZOOM_BOOST)
	zoom_factor = clamp(zoom_factor, 0.18, 3.0)
	vertical_base_zoom_factor = zoom_factor
	var final_zoom = vertical_base_zoom_factor * vertical_zoom_multiplier
	vertical_camera.zoom = Vector2.ONE * final_zoom
	var target_position = _get_vertical_camera_focus(arena_size, viewport_size, final_zoom)
	if snap or vertical_camera.position == Vector2.ZERO:
		vertical_camera.position = target_position
	else:
		vertical_camera.position = vertical_camera.position.lerp(target_position, 0.16)

func _get_vertical_camera_focus(arena_size: Vector2, viewport_size: Vector2, final_zoom: float) -> Vector2:
	var focus = arena_size / 2.0
	if current_arena:
		var balls = _get_alive_balls()
		if balls.size() == 0:
			balls = _get_ball_nodes()
		if balls.size() > 0:
			var min_pos = Vector2(100000000.0, 100000000.0)
			var max_pos = Vector2(-100000000.0, -100000000.0)
			var valid_count = 0
			for ball in balls:
				if not is_instance_valid(ball):
					continue
				var local_pos = current_arena.to_local(ball.global_position)
				min_pos.x = min(min_pos.x, local_pos.x)
				min_pos.y = min(min_pos.y, local_pos.y)
				max_pos.x = max(max_pos.x, local_pos.x)
				max_pos.y = max(max_pos.y, local_pos.y)
				valid_count += 1
			if valid_count > 0:
				focus = (min_pos + max_pos) * 0.5
				if balls.size() == 1:
					focus = focus.lerp(arena_size / 2.0, 0.25)
	if ko_focus_timer > 0.0 and current_arena:
		var ko_local = current_arena.to_local(ko_focus_position)
		var ko_weight = clamp(ko_focus_timer / KO_FOCUS_DURATION, 0.0, 1.0) * 0.5
		focus = focus.lerp(ko_local, ko_weight)
	
	var half_view = viewport_size / max(final_zoom, 0.001) * 0.5
	var guard = Vector2(VERTICAL_CAMERA_PADDING, VERTICAL_CAMERA_PADDING)
	var min_focus = half_view - guard
	var max_focus = arena_size - half_view + guard
	
	if min_focus.x <= max_focus.x:
		focus.x = clamp(focus.x, min_focus.x, max_focus.x)
	else:
		focus.x = arena_size.x * 0.5
	
	if min_focus.y <= max_focus.y:
		focus.y = clamp(focus.y, min_focus.y, max_focus.y)
	else:
		focus.y = arena_size.y * 0.5
	
	return focus

func _get_vertical_arena_size() -> Vector2:
	if current_arena:
		return current_arena.arena_size
	if arena_option.get_item_count() > 0:
		var index = arena_option.selected
		if index < 0:
			index = 0
		var key = arena_option.get_item_text(index)
		if arena_sizes.has(key):
			return arena_sizes[key]
	return Vector2(800.0, 600.0)
#endregion

#region Vertical Stats
func _vertical_text_size(base_size: float, min_size: int, max_size: int) -> int:
	var width = 900.0
	if vertical_title_panel and is_instance_valid(vertical_title_panel) and vertical_title_panel.size.x > 0.0:
		width = vertical_title_panel.size.x
	elif vertical_stats_panel and is_instance_valid(vertical_stats_panel) and vertical_stats_panel.size.x > 0.0:
		width = vertical_stats_panel.size.x
	return int(round(clamp(base_size * width / 900.0, float(min_size), float(max_size))))

func _vertical_matchup_font_size(left_name: String, right_name: String) -> int:
	var size = _vertical_text_size(42.0, 29, 50)
	var visible_chars = max(1.0, float(left_name.length() + right_name.length() + 4))
	if visible_chars > 20.0:
		size = max(27, int(round(float(size) * 20.0 / visible_chars)))
	return size

func _vertical_display_ball_count() -> int:
	if current_arena:
		return _get_ball_nodes().size()
	return balls_config.size()

func _vertical_roster_font_size(ball_count: int, base_size: int) -> int:
	var reduction = max(ball_count - 3, 0)
	return max(10, base_size - reduction * 3)

func _vertical_accent_bbcode() -> String:
	if _selected_scenario_theme() == SCENARIO_CEMETERY:
		return "#5c78c8"
	return "#b86f2f"

func _vertical_meta_bbcode() -> String:
	if _selected_scenario_theme() == SCENARIO_CEMETERY:
		return "#6f80a8"
	return "#8a653d"

func _vertical_soft_bbcode() -> String:
	if _selected_scenario_theme() == SCENARIO_CEMETERY:
		return "#7f90b5"
	return "#a37c4f"

func _vertical_roster_lines(balls: Array, font_size: int, show_speed: bool = true) -> String:
	var lines: Array[String] = []
	var meta = _vertical_meta_bbcode()
	var soft = _vertical_soft_bbcode()
	var compact = balls.size() > 3
	for ball in balls:
		if not is_instance_valid(ball):
			continue
		var line = "[b][color=%s]%s[/color][/b] [color=%s]HP %.0f[/color]" % [
			_ball_text_color(ball),
			_ball_name_text(ball),
			meta,
			float(ball.current_hp)
		]
		if compact:
			line += " [color=%s]D%.1f[/color]" % [
				meta,
				_estimate_damage(ball)
			]
		else:
			line += " [color=%s]|[/color] [color=%s]D %.1f[/color]" % [
				soft,
				meta,
				_estimate_damage(ball)
			]
		if show_speed:
			if compact:
				line += " [color=%s]V%d[/color]" % [
					meta,
					int(ball.linear_velocity.length())
				]
			else:
				line += " [color=%s]|[/color] [color=%s]V %d[/color]" % [
					soft,
					meta,
					int(ball.linear_velocity.length())
				]
		lines.append(line)
	return "[center][font_size=%d]%s[/font_size][/center]" % [
		font_size,
		"\n".join(lines)
	]

func _vertical_names_only_title(balls: Array, font_size: int) -> String:
	var parts: Array[String] = []
	var accent = _vertical_accent_bbcode()
	if balls.size() == 2:
		var left = balls[0]
		var right = balls[1]
		return "[center][font_size=%d][b][color=%s]%s[/color][/b] [color=%s]|[/color] [b][color=%s]%s[/color][/b][/font_size][/center]" % [
			font_size,
			_ball_text_color(left),
			_ball_name_text(left),
			accent,
			_ball_text_color(right),
			_ball_name_text(right)
		]
	for ball in balls:
		if not is_instance_valid(ball):
			continue
		parts.append("[b][color=%s]%s[/color][/b]" % [
			_ball_text_color(ball),
			_ball_name_text(ball)
		])
	return "[center][font_size=%d]%s[/font_size][/center]" % [
		font_size,
		(" [color=%s]|[/color] " % accent).join(parts)
	]

func _vertical_queue_names_only_title(title_size: int, accent_color: String, first_name: String, first_color: String, second_name: String, second_color: String) -> String:
	if balls_config.size() <= 2:
		return "[center][font_size=%d][b][color=%s]%s[/color][/b] [color=%s]|[/color] [b][color=%s]%s[/color][/b][/font_size][/center]" % [
			title_size,
			first_color,
			first_name,
			accent_color,
			second_color,
			second_name
		]
	var parts: Array[String] = []
	for cfg in balls_config:
		parts.append("[b][color=%s]%s[/color][/b]" % [
			_color_to_bbcode(cfg.get("color", Color.WHITE)),
			String(cfg.get("display_name", "Bola"))
		])
	return "[center][font_size=%d]%s[/font_size][/center]" % [
		max(22, title_size - 2),
		(" [color=%s]|[/color] " % accent_color).join(parts)
	]

func _update_vertical_stats(alive_override = null, all_override = null):
	if not vertical_title_label or not is_instance_valid(vertical_title_label):
		return
	if not vertical_stats_label or not is_instance_valid(vertical_stats_label):
		return
	
	var title_size = _vertical_text_size(42.0, 29, 50)
	var title_sub_size = _vertical_text_size(23.0, 16, 30)
	var stats_main_size = _vertical_text_size(34.0, 24, 42)
	var stats_sub_size = _vertical_text_size(21.0, 16, 27)
	
	var alive_balls = (alive_override if alive_override != null else _get_alive_balls()).duplicate()
	var all_balls = (all_override if all_override != null else _get_ball_nodes()).duplicate()
	
	if current_arena and all_balls.size() > 0:
		var left = all_balls[0]
		var right = all_balls[1] if all_balls.size() > 1 else null
		
		var accent_color = _vertical_accent_bbcode()
		var meta_color = _vertical_meta_bbcode()
		var roster_font_size = _vertical_roster_font_size(all_balls.size(), stats_sub_size)
		
		if all_balls.size() == 2 and right:
			title_size = _vertical_matchup_font_size(_ball_name_text(left), _ball_name_text(right))
		else:
			title_size = _vertical_text_size(32.0, 22, 38)
			title_size = max(18, title_size - max(all_balls.size() - 3, 0) * 2)
		vertical_title_label.text = _vertical_names_only_title(all_balls, title_size)
		
		if is_start_countdown:
			vertical_stats_label.text = "[center][font_size=%d][b][color=%s]PREPARAR...[/color][/b][/font_size]\n[font_size=%d][color=%s]Aguardando inicio[/color][/font_size][/center]" % [
				stats_main_size,
				accent_color,
				stats_sub_size,
				meta_color
			]
			if all_balls.size() > 2:
				vertical_stats_label.text += "\n" + _vertical_roster_lines(all_balls, roster_font_size, false)
		elif not is_battling:
			var winner_text = "EMPATE"
			var winner_color = accent_color
			if alive_balls.size() == 1:
				winner_text = "VENCEDOR: " + _ball_name_text(alive_balls[0])
				winner_color = _ball_text_color(alive_balls[0])
			elif alive_balls.size() > 1:
				var tid = _ball_team_id(alive_balls[0])
				winner_text = "VENCEDOR: TIME " + str(tid)
				winner_color = _ball_text_color(alive_balls[0])
			vertical_stats_label.text = "[center][font_size=%d][b][color=%s]%s[/color][/b][/font_size]\n[font_size=%d][color=%s]Tempo %s[/color][/font_size][/center]" % [
				stats_main_size,
				winner_color,
				winner_text,
				stats_sub_size,
				meta_color,
				_format_time(battle_elapsed)
			]
			if all_balls.size() > 2:
				vertical_stats_label.text += "\n" + _vertical_roster_lines(all_balls, roster_font_size, false)
		elif all_balls.size() == 2 and right:
			var left_color = _ball_text_color(left)
			var right_color = _ball_text_color(right)
			vertical_stats_label.text = "[center][font_size=%d][b][color=%s]HP %.0f[/color][/b]    [b][color=%s]HP %.0f[/color][/b][/font_size]\n[font_size=%d][color=%s]Dano %.1f x %.1f | Vel %d x %d[/color][/font_size][/center]" % [
				stats_main_size,
				left_color,
				left.current_hp,
				right_color,
				right.current_hp,
				stats_sub_size,
				meta_color,
				_estimate_damage(left),
				_estimate_damage(right),
				int(left.linear_velocity.length()),
				int(right.linear_velocity.length())
			]
		else:
			vertical_stats_label.text = _vertical_roster_lines(all_balls, roster_font_size, true)
		return
	
	var first_cfg = balls_config[0] if balls_config.size() > 0 else {}
	var second_cfg = balls_config[1] if balls_config.size() > 1 else {}
	var first_name = first_cfg.get("display_name", "Bola 1")
	var second_name = second_cfg.get("display_name", "Bola 2")
	var first_color = _color_to_bbcode(first_cfg.get("color", Color(1.0, 0.24, 0.24)))
	var second_color = _color_to_bbcode(second_cfg.get("color", Color(0.25, 0.95, 0.25)))
	var accent_color = _vertical_accent_bbcode()
	var meta_color = _vertical_meta_bbcode()
	if balls_config.size() <= 2:
		title_size = _vertical_matchup_font_size(first_name, second_name)
	else:
		title_size = _vertical_text_size(30.0, 20, 36)
		title_size = max(18, title_size - max(balls_config.size() - 3, 0) * 2)
	vertical_title_label.text = _vertical_queue_names_only_title(title_size, accent_color, first_name, first_color, second_name, second_color)
	vertical_stats_label.text = "[center][font_size=%d][color=%s]%d bola(s) na fila[/color][/font_size]\n[font_size=%d][color=%s]Escolha as armas e inicie[/color][/font_size][/center]" % [
		stats_main_size,
		accent_color,
		balls_config.size(),
		stats_sub_size,
		meta_color
	]

func _ball_name_text(ball: Node) -> String:
	if not ball:
		return "-"
	return str(ball.get("display_name"))

func _ball_text_color(ball: Node) -> String:
	if not ball:
		return "#f4f0df"
	if _object_has_property(ball, "original_color"):
		return _color_to_bbcode(ball.get("original_color"))
	if _object_has_property(ball, "ball_color"):
		return _color_to_bbcode(ball.get("ball_color"))
	return "#f4f0df"

func _ball_team_id(ball: Node) -> int:
	if not ball or not is_instance_valid(ball):
		return 0
	if _object_has_property(ball, "team_id"):
		return int(ball.get("team_id"))
	return 0

func _color_to_bbcode(color: Color) -> String:
	return "#" + color.to_html(false)
#endregion

#region Vertical Cleanup
func _destroy_vertical_overlay():
	if vertical_camera_tween and vertical_camera_tween.is_valid():
		vertical_camera_tween.kill()
	if vertical_countdown_tween and vertical_countdown_tween.is_valid():
		vertical_countdown_tween.kill()
	vertical_countdown_tween = null
	if vertical_overlay and is_instance_valid(vertical_overlay):
		vertical_overlay.queue_free()
	vertical_overlay = null
	vertical_subviewport = null
	vertical_container = null
	vertical_camera = null
	vertical_bg = null
	vertical_border = null
	vertical_arena_border = null
	vertical_title_panel = null
	vertical_title_label = null
	vertical_stats_panel = null
	vertical_stats_label = null
	vertical_close_button = null
	vertical_countdown_label = null
	vertical_base_zoom_factor = 1.0
	vertical_zoom_multiplier = 1.0
	vertical_camera_tween = null

func _unhandled_input(event):
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if is_vertical_mode:
			_toggle_vertical_mode()
#endregion
