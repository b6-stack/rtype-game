extends Control
## MainMenu — title screen with Start Game and Quit buttons.

@onready var _start_btn: Button = $Center/VBox/StartButton
@onready var _boss_rush_btn: Button = $Center/VBox/BossRushButton
@onready var _quit_btn: Button = $Center/VBox/QuitButton
@onready var _hi_score_label: Label = $Center/VBox/HiScoreLabel
@onready var _star_container: Node2D = $StarContainer
@onready var _version_label: Label = $Center/VBox/VersionLabel
@onready var _difficulty_buttons: Array[Button] = [
	$Center/VBox/DifficultyRow/EasyButton,
	$Center/VBox/DifficultyRow/NormalButton,
	$Center/VBox/DifficultyRow/HardButton,
]
@onready var _cheats_toggle_btn: Button = $Center/VBox/CheatsToggleBtn
@onready var _cheats_panel: VBoxContainer = $Center/VBox/CheatsPanel
@onready var _god_mode_btn: Button = $Center/VBox/CheatsPanel/CheatGodModeBtn
@onready var _max_charge_btn: Button = $Center/VBox/CheatsPanel/CheatMaxChargeBtn

const STAR_COUNT: int = 120
var _stars: Array[Dictionary] = []

## Hidden trick: hold the version label for this long to unlock Boss Rush
## early, without having to beat the game first.
const VERSION_HOLD_UNLOCK_TIME: float = 5.0
var _version_holding: bool = false
var _version_hold_elapsed: float = 0.0

func _ready() -> void:
	_start_btn.pressed.connect(_on_start_pressed)
	_boss_rush_btn.pressed.connect(_on_boss_rush_pressed)
	_quit_btn.pressed.connect(_on_quit_pressed)
	_hi_score_label.text = "HIGH SCORE: %d" % GameState.high_score
	_version_label.text = "v%s" % GameState.APP_VERSION
	_version_label.mouse_filter = Control.MOUSE_FILTER_STOP
	_version_label.gui_input.connect(_on_version_label_input)
	_setup_boss_rush_button()
	_setup_difficulty_buttons()
	_setup_cheat_buttons()
	_generate_stars()
	# Animate title in
	$Center/VBox/TitleLabel.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property($Center/VBox/TitleLabel, "modulate:a", 1.0, 1.2)
	tw.parallel().tween_property($Center/VBox/TitleLabel, "position:y",
			$Center/VBox/TitleLabel.position.y, 0.8).from($Center/VBox/TitleLabel.position.y - 40)

func _process(delta: float) -> void:
	_scroll_stars(delta)
	if _version_holding and not GameState.boss_rush_unlocked:
		_version_hold_elapsed += delta
		if _version_hold_elapsed >= VERSION_HOLD_UNLOCK_TIME:
			_version_holding = false
			GameState.unlock_boss_rush()
			_setup_boss_rush_button()
			AudioManager.play_full_charge_ready_sfx()

func _on_start_pressed() -> void:
	GameState.start_game()

func _on_boss_rush_pressed() -> void:
	if not GameState.boss_rush_unlocked:
		return
	GameState.start_boss_rush()

## Boss Rush is unlocked by beating the game once — reward the first
## clear rather than making boss-only content available day one.
func _setup_boss_rush_button() -> void:
	if GameState.boss_rush_unlocked:
		_boss_rush_btn.text = "⚔ BOSS RUSH"
		_boss_rush_btn.disabled = false
		_boss_rush_btn.modulate = Color.WHITE
	else:
		_boss_rush_btn.text = "🔒 BOSS RUSH (BEAT THE GAME)"
		_boss_rush_btn.disabled = true
		_boss_rush_btn.modulate = Color(1, 1, 1, 0.55)

func _on_quit_pressed() -> void:
	get_tree().quit()

# ── Hidden version-hold unlock ────────────────────────────────

func _on_version_label_input(event: InputEvent) -> void:
	if GameState.boss_rush_unlocked:
		return
	var pressed: bool
	if event is InputEventScreenTouch:
		pressed = event.pressed
	elif event is InputEventMouseButton:
		pressed = event.pressed
	else:
		return
	_version_holding = pressed
	_version_hold_elapsed = 0.0

# ── Arcade cheats (persistent toggles only — dynamic one-shot cheats
# like Nuke/Cycle Weapon/+Lives stay pause-menu-only since they need an
# active run) ──────────────────────────────────────────────────

func _setup_cheat_buttons() -> void:
	_cheats_toggle_btn.pressed.connect(_on_cheats_toggle_pressed)
	_god_mode_btn.pressed.connect(_on_cheat_god_mode)
	_max_charge_btn.pressed.connect(_on_cheat_max_charge)
	_update_cheat_btn_texts()

## Deliberately collapsed by default — cheats should be an explicit
## opt-in the player has to go open, not something visible at a glance.
func _on_cheats_toggle_pressed() -> void:
	_cheats_panel.visible = not _cheats_panel.visible
	_cheats_toggle_btn.text = ("▾" if _cheats_panel.visible else "▸") + " ARCADE CHEATS"

func _on_cheat_god_mode() -> void:
	GameState.mark_cheats_used()
	GameState.god_mode_enabled = !GameState.god_mode_enabled
	_update_cheat_btn_texts()

func _on_cheat_max_charge() -> void:
	GameState.mark_cheats_used()
	GameState.always_max_charge_enabled = !GameState.always_max_charge_enabled
	_update_cheat_btn_texts()
	if GameState.always_max_charge_enabled:
		AudioManager.play_full_charge_ready_sfx()

func _update_cheat_btn_texts() -> void:
	if GameState.god_mode_enabled:
		_god_mode_btn.text = "🛡️ GOD MODE: ON"
		_god_mode_btn.modulate = Color(0.3, 1.0, 0.4)
	else:
		_god_mode_btn.text = "🛡️ GOD MODE: OFF"
		_god_mode_btn.modulate = Color.WHITE

	if GameState.always_max_charge_enabled:
		_max_charge_btn.text = "🚀 ALWAYS MAX CHARGE: ON"
		_max_charge_btn.modulate = Color(0.3, 1.0, 0.4)
	else:
		_max_charge_btn.text = "🚀 ALWAYS MAX CHARGE: OFF"
		_max_charge_btn.modulate = Color.WHITE

# ── Difficulty selector ──────────────────────────────────────

func _setup_difficulty_buttons() -> void:
	for i in _difficulty_buttons.size():
		var btn: Button = _difficulty_buttons[i]
		btn.button_pressed = (i == GameState.difficulty)
		btn.pressed.connect(_on_difficulty_pressed.bind(i))

func _on_difficulty_pressed(index: int) -> void:
	GameState.set_difficulty(index)

# ── Starfield ─────────────────────────────────────────────────

func _generate_stars() -> void:
	_stars.clear()
	var screen_size: Vector2 = get_viewport_rect().size
	for i in STAR_COUNT:
		_stars.append({
			"pos": Vector2(randf() * screen_size.x, randf() * screen_size.y),
			"speed": randf_range(30.0, 150.0),
			"size": randf_range(1.0, 3.5),
			"brightness": randf_range(0.5, 1.0),
		})
	_star_container.queue_redraw()

func _scroll_stars(delta: float) -> void:
	var screen_size: Vector2 = get_viewport_rect().size
	for s in _stars:
		s["pos"].x -= s["speed"] * delta
		if s["pos"].x < -5.0:
			s["pos"].x = screen_size.x + 5.0
			s["pos"].y = randf() * screen_size.y
	_star_container.queue_redraw()
