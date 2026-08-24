extends CanvasLayer
## HUD — displays score, 1-UP score goal progress, lives, charge bar, weapon icon, and pause button.

@onready var _score_label: Label = $Control/ScoreLabel
@onready var _hi_score_label: Label = $Control/HiScoreLabel
@onready var _life_goal_bar: ProgressBar = $Control/LifeGoalBar
@onready var _life_goal_label: Label = $Control/LifeGoalBar/LifeGoalLabel
@onready var _lives_container: HBoxContainer = $Control/LivesContainer
@onready var _charge_bar: ProgressBar = $Control/ChargeBar
@onready var _charge_label: Label = $Control/ChargeBar/ChargeLabel
@onready var _pause_btn: Button = $Control/PauseButton
@onready var _weapon_label: Label = $Control/WeaponRow/WeaponLabel
@onready var _weapon_icon_rect: TextureRect = $Control/WeaponRow/WeaponIcon
@onready var _level_label: Label = $Control/LevelLabel
@onready var _ultra_weapon_row: HBoxContainer = $Control/UltraWeaponRow

signal pause_requested

var _charge_level: float = 0.0
var _charge_pulse_tween: Tween

func _ready() -> void:
	_pause_btn.pressed.connect(func(): pause_requested.emit())
	GameState.score_changed.connect(_on_score_changed)
	GameState.lives_changed.connect(_on_lives_changed)
	GameState.weapon_changed.connect(_on_weapon_changed)
	GameState.level_changed.connect(_on_level_changed)
	GameState.score_goal_updated.connect(_on_score_goal_updated)
	GameState.life_awarded.connect(_on_life_awarded)

	_refresh_score()
	_refresh_lives()
	_refresh_weapon()
	_refresh_level()
	_update_goal_bar(GameState.score, GameState.next_life_score_goal)
	_build_ultra_weapon_row()

# ── Public API ────────────────────────────────────────────────

func set_charge(normalized: float) -> void:
	_charge_level = clamp(normalized, 0.0, 1.0)
	_charge_bar.value = _charge_level * 100.0
	
	if _charge_level >= 1.0:
		if _charge_label:
			_charge_label.text = "FULL CHARGE MAX 100%!"
		if _charge_pulse_tween == null:
			AudioManager.play_full_charge_ready_sfx()
			_start_charge_ready_pulse()
	elif _charge_level >= 0.66:
		_stop_charge_pulse()
		_charge_bar.modulate = Color(0.2, 1.0, 0.3) # GREEN
		if _charge_label:
			_charge_label.text = "CHARGING 95% [GREEN]"
	elif _charge_level >= 0.33:
		_stop_charge_pulse()
		_charge_bar.modulate = Color(1.0, 0.9, 0.1) # YELLOW
		if _charge_label:
			_charge_label.text = "CHARGING 90% [YELLOW]"
	else:
		_stop_charge_pulse()
		_charge_bar.modulate = Color(1.0, 0.25, 0.25) # RED
		if _charge_label:
			_charge_label.text = "CHARGING 80% [RED]"

func show_charge_bar(visible: bool) -> void:
	_charge_bar.visible = visible
	if not visible:
		_charge_level = 0.0
		_charge_bar.value = 0.0
		_stop_charge_pulse()

# ── Private ────────────────────────────────────────────────────

func _refresh_score() -> void:
	_score_label.text = "SCORE: %d" % GameState.score
	_hi_score_label.text = "BEST: %d" % GameState.get_display_high_score()

func _update_goal_bar(current: int, goal: int) -> void:
	if _life_goal_bar and _life_goal_label:
		var prev_goal: int = max(0, goal - GameState.get_life_goal_interval())
		var progress: float = 0.0
		if goal > prev_goal:
			progress = float(current - prev_goal) / float(goal - prev_goal)
		_life_goal_bar.value = clamp(progress * 100.0, 0.0, 100.0)
		_life_goal_label.text = "1-UP GOAL: %d" % goal

## Icon row above a small cap (matches Hard's max of 5, gives a little
## headroom) so Normal/Easy's much higher reserve (10/15) doesn't turn
## into a long strip of tiny boxes eating HUD space — falls back to a
## compact "current / max" label instead.
const LIVES_ICON_DISPLAY_CAP: int = 6

func _refresh_lives() -> void:
	for child in _lives_container.get_children():
		child.queue_free()
	var max_lives: int = GameState.get_max_lives()
	if max_lives <= LIVES_ICON_DISPLAY_CAP:
		for i in max_lives:
			var icon := ColorRect.new()
			icon.custom_minimum_size = Vector2(24, 18)
			icon.color = Color(0.2, 1.0, 0.5) if i < GameState.lives else Color(0.2, 0.2, 0.2)
			_lives_container.add_child(icon)
	else:
		var label := Label.new()
		label.text = "LIVES: %d / %d" % [GameState.lives, max_lives]
		label.add_theme_font_size_override("font_size", 20)
		label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.5))
		label.add_theme_color_override("font_outline_color", Color.BLACK)
		label.add_theme_constant_override("outline_size", 3)
		_lives_container.add_child(label)

const WEAPON_ICON_PATHS: Array[String] = [
	"res://assets/sprites/weapons/icon_vulcan.png",
	"res://assets/sprites/weapons/icon_laser.png",
	"res://assets/sprites/weapons/icon_plasma.png",
	"res://assets/sprites/weapons/icon_missile.png",
	"res://assets/sprites/weapons/icon_wave.png",
	"res://assets/sprites/weapons/icon_bouncer.png",
	"res://assets/sprites/weapons/icon_drill.png",
	"res://assets/sprites/weapons/icon_ricochet.png",
	"res://assets/sprites/weapons/icon_gravity.png",
	"res://assets/sprites/weapons/icon_lightning.png",
]

const WEAPON_NAMES: Array[String] = ["VULCAN","LASER","PLASMA","MISSILE","WAVE",
		"BOUNCER","DRILL","RICOCHET","GRAVITY","LIGHTNING"]

var _ultra_weapon_buttons: Array[Button] = []

func _refresh_weapon() -> void:
	var idx := GameState.current_weapon_index
	if _weapon_label:
		_weapon_label.text = WEAPON_NAMES[idx] if idx < WEAPON_NAMES.size() else "?"
	if _weapon_icon_rect:
		var path := WEAPON_ICON_PATHS[idx] if idx < WEAPON_ICON_PATHS.size() else ""
		if ResourceLoader.exists(path):
			_weapon_icon_rect.texture = load(path)
	_refresh_ultra_weapon_highlight()

## Ultra Mode reward: a row of buttons along the bottom letting the player
## jump straight to any weapon instead of only cycling via pickups.
func _build_ultra_weapon_row() -> void:
	if _ultra_weapon_row == null:
		return
	if not GameState.ultra_mode_enabled:
		_ultra_weapon_row.visible = false
		return

	_ultra_weapon_row.visible = true
	for child in _ultra_weapon_row.get_children():
		child.queue_free()
	_ultra_weapon_buttons.clear()

	for i in WEAPON_NAMES.size():
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(148, 56)
		btn.text = WEAPON_NAMES[i]
		btn.add_theme_font_size_override("font_size", 12)
		var icon_path := WEAPON_ICON_PATHS[i] if i < WEAPON_ICON_PATHS.size() else ""
		if ResourceLoader.exists(icon_path):
			btn.icon = load(icon_path)
			btn.expand_icon = true
			btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			btn.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		btn.pressed.connect(_on_ultra_weapon_button_pressed.bind(i))
		_ultra_weapon_row.add_child(btn)
		_ultra_weapon_buttons.append(btn)

	_refresh_ultra_weapon_highlight()

func _on_ultra_weapon_button_pressed(index: int) -> void:
	GameState.set_weapon(index)

func _refresh_ultra_weapon_highlight() -> void:
	var idx := GameState.current_weapon_index
	for i in _ultra_weapon_buttons.size():
		_ultra_weapon_buttons[i].modulate = Color(0.4, 1.0, 0.6) if i == idx else Color.WHITE

func _refresh_level() -> void:
	var idx: int = GameState.level - 1
	if idx >= 0 and idx < GameState.LEVEL_NAMES.size():
		_level_label.text = GameState.LEVEL_NAMES[idx].to_upper()
	else:
		_level_label.text = "LVL %d" % GameState.level

func _start_charge_ready_pulse() -> void:
	_stop_charge_pulse()
	_charge_pulse_tween = create_tween().set_loops()
	_charge_pulse_tween.tween_property(_charge_bar, "modulate", Color(0.2, 1.0, 0.4), 0.08)
	_charge_pulse_tween.tween_property(_charge_bar, "modulate", Color(1.0, 0.9, 0.2), 0.08)
	_charge_pulse_tween.tween_property(_charge_bar, "modulate", Color.WHITE, 0.08)

func _stop_charge_pulse() -> void:
	if _charge_pulse_tween:
		_charge_pulse_tween.kill()
		_charge_pulse_tween = null

# ── Signal handlers ───────────────────────────────────────────

func _on_score_changed(new_score: int) -> void:
	_score_label.text = "SCORE: %d" % new_score
	_hi_score_label.text = "BEST: %d" % GameState.get_display_high_score()
	var tw := _score_label.create_tween()
	tw.tween_property(_score_label, "scale", Vector2(1.15, 1.15), 0.08)
	tw.tween_property(_score_label, "scale", Vector2.ONE, 0.08)

func _on_score_goal_updated(curr: int, goal: int) -> void:
	_update_goal_bar(curr, goal)

func _on_life_awarded(_new_lives: int) -> void:
	_refresh_lives()
	# Celebrate 1-UP milestone with glowing bar flash
	if _life_goal_bar:
		var tw := _life_goal_bar.create_tween()
		tw.tween_property(_life_goal_bar, "modulate", Color(0.2, 1.0, 0.4), 0.15)
		tw.tween_property(_life_goal_bar, "modulate", Color.WHITE, 0.3)

func _on_lives_changed(_new_lives: int) -> void:
	_refresh_lives()

func _on_weapon_changed(_index: int) -> void:
	_refresh_weapon()

func _on_level_changed(_lvl: int) -> void:
	_refresh_level()

# ── Boss Warning Arrival System ───────────────────────────────

const BOSS_HINTS: Dictionary = {
	"Iron Claw": "Focus fire on the central core when its rotating pincers open between strikes!",
	"Hydra": "Destroy the 3 outer heads first to expose and breach the main core!",
	"Behemoth": "Heavy ramming charger! Maneuver vertically to evade its high-speed rushes.",
	"Sentinel": "Force-field barrier! Time your shots to shoot between the rotating shield gaps.",
	"Swarm Queen": "Bio-hive matriarch! Clear the spawned swarm drones, then charge your shots.",
	"Photon Core": "Sweeping particle laser! Slip behind the beam arc as it rotates across the arena.",
	"Abyss Gate": "Dimensional warper! Evade gravity wells and predict its warp positions.",
	"Omega": "Ultimate flagship! Adapt across all phases and unleash maximum Super Charges!"
}

var _warning_container: Control = null
var _warning_flash_rect: ColorRect = null
var _warning_title: Label = null
var _warning_boss_name: Label = null
var _warning_hint: Label = null
var _warning_banner_tween: Tween = null
var _warning_flash_tween: Tween = null

func show_boss_warning(boss_name: String) -> void:
	if _warning_container == null:
		_build_warning_banner()

	_warning_title.text = "⚠️ PREPARE FOR BATTLE! ⚠️"
	_warning_boss_name.text = "TARGET: [ %s ]" % boss_name.to_upper()
	var hint_text: String = BOSS_HINTS.get(boss_name, "Engage with concentrated fire and evade hostile volleys!")
	_warning_hint.text = "💡 TACTICAL HINT: %s" % hint_text

	_warning_container.visible = true
	_warning_container.modulate.a = 1.0
	# STOP (rather than IGNORE) so a tap within the banner's bounds can
	# dismiss it early instead of blocking the player's view of incoming
	# threats for the full ~4s duration with no way to skip it.
	_warning_container.mouse_filter = Control.MOUSE_FILTER_STOP
	_warning_flash_rect.visible = true
	_warning_flash_rect.modulate.a = 0.0

	# Siren alert sound
	AudioManager.play_boss_sfx()

	# Red screen alarm flash (8 pulses over 3.2s)
	_warning_flash_tween = create_tween()
	for i in 8:
		_warning_flash_tween.tween_property(_warning_flash_rect, "modulate:a", 0.28, 0.20)
		_warning_flash_tween.tween_property(_warning_flash_rect, "modulate:a", 0.0, 0.20)

	# Warning banner entrance, display, and fade
	_warning_container.scale = Vector2(0.85, 0.85)
	_warning_banner_tween = create_tween()
	_warning_banner_tween.tween_property(_warning_container, "scale", Vector2(1.05, 1.05), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_warning_banner_tween.tween_property(_warning_container, "scale", Vector2.ONE, 0.15)
	_warning_banner_tween.tween_interval(3.2) # Ample time to read tactical hint
	_warning_banner_tween.tween_property(_warning_container, "modulate:a", 0.0, 0.45)
	_warning_banner_tween.tween_callback(_hide_boss_warning)

func _hide_boss_warning() -> void:
	if _warning_container:
		_warning_container.visible = false
		_warning_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _warning_flash_rect:
		_warning_flash_rect.visible = false

## Lets the player tap anywhere within the warning banner to dismiss it
## immediately, rather than being stuck looking at it for a fixed ~4s.
func _on_warning_banner_input(event: InputEvent) -> void:
	var pressed: bool = (event is InputEventScreenTouch and event.pressed) \
			or (event is InputEventMouseButton and event.pressed)
	if not pressed:
		return
	if _warning_banner_tween and _warning_banner_tween.is_valid():
		_warning_banner_tween.kill()
	if _warning_flash_tween and _warning_flash_tween.is_valid():
		_warning_flash_tween.kill()
	var tw := create_tween()
	tw.tween_property(_warning_container, "modulate:a", 0.0, 0.15)
	tw.tween_callback(_hide_boss_warning)

func _build_warning_banner() -> void:
	var ctrl: Control = $Control
	if ctrl == null:
		return

	# Red alarm backdrop flash
	_warning_flash_rect = ColorRect.new()
	_warning_flash_rect.name = "WarningFlashRect"
	_warning_flash_rect.color = Color(1.0, 0.1, 0.1, 1.0)
	_warning_flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_warning_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_warning_flash_rect.visible = false
	ctrl.add_child(_warning_flash_rect)

	# Perfectly centered Tactical Briefing Warning Box
	_warning_container = PanelContainer.new()
	_warning_container.name = "BossWarningContainer"
	_warning_container.layout_mode = 1
	_warning_container.anchors_preset = Control.PRESET_CENTER
	_warning_container.anchor_left = 0.5
	_warning_container.anchor_right = 0.5
	_warning_container.anchor_top = 0.5
	_warning_container.anchor_bottom = 0.5
	_warning_container.offset_left = -440.0
	_warning_container.offset_right = 440.0
	_warning_container.offset_top = -95.0
	_warning_container.offset_bottom = 95.0
	_warning_container.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_warning_container.grow_vertical = Control.GROW_DIRECTION_BOTH
	_warning_container.pivot_offset = Vector2(440.0, 95.0)
	_warning_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_warning_container.gui_input.connect(_on_warning_banner_input)
	_warning_container.visible = false

	# Styled dark semi-translucent red hazard panel with bright borders
	var style_box := StyleBoxFlat.new()
	style_box.bg_color = Color(0.10, 0.02, 0.02, 0.92)
	style_box.border_color = Color(1.0, 0.35, 0.1, 1.0)
	style_box.set_border_width_all(3)
	style_box.set_corner_radius_all(10)
	style_box.content_margin_left = 24.0
	style_box.content_margin_right = 24.0
	style_box.content_margin_top = 16.0
	style_box.content_margin_bottom = 16.0
	_warning_container.add_theme_stylebox_override("panel", style_box)
	ctrl.add_child(_warning_container)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 6)
	_warning_container.add_child(vbox)

	# 1. Main Title
	_warning_title = Label.new()
	_warning_title.text = "⚠️ PREPARE FOR BATTLE! ⚠️"
	_warning_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_warning_title.add_theme_font_size_override("font_size", 32)
	_warning_title.add_theme_color_override("font_color", Color(1.0, 0.25, 0.25))
	_warning_title.add_theme_color_override("font_outline_color", Color.BLACK)
	_warning_title.add_theme_constant_override("outline_size", 6)
	vbox.add_child(_warning_title)

	# 2. Target Boss Name
	_warning_boss_name = Label.new()
	_warning_boss_name.text = "TARGET: [ BOSS ]"
	_warning_boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_warning_boss_name.add_theme_font_size_override("font_size", 22)
	_warning_boss_name.add_theme_color_override("font_color", Color(0.2, 1.0, 0.9))
	_warning_boss_name.add_theme_color_override("font_outline_color", Color.BLACK)
	_warning_boss_name.add_theme_constant_override("outline_size", 4)
	vbox.add_child(_warning_boss_name)

	# 3. Tactical Combat Hint
	_warning_hint = Label.new()
	_warning_hint.text = "💡 TACTICAL HINT: Focus fire on the core!"
	_warning_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_warning_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_warning_hint.add_theme_font_size_override("font_size", 17)
	_warning_hint.add_theme_color_override("font_color", Color(1.0, 0.92, 0.4))
	_warning_hint.add_theme_color_override("font_outline_color", Color.BLACK)
	_warning_hint.add_theme_constant_override("outline_size", 4)
	vbox.add_child(_warning_hint)
