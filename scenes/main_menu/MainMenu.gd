extends Control
## MainMenu — title screen with Start Game and Quit buttons.

@onready var _start_btn: Button = $Center/VBox/StartButton
@onready var _boss_rush_btn: Button = $Center/VBox/BossRushButton
@onready var _ultra_mode_btn: Button = $Center/VBox/UltraModeButton
@onready var _quit_btn: Button = $Center/VBox/QuitButton
@onready var _hi_score_label: Label = $Center/VBox/HiScoreLabel
@onready var _star_container: Node2D = $StarContainer
@onready var _version_label: Label = $Center/VBox/VersionLabel
@onready var _title_label: Label = $Center/VBox/TitleLabel
@onready var _difficulty_buttons: Array[Button] = [
	$Center/VBox/DifficultyRow/EasyButton,
	$Center/VBox/DifficultyRow/NormalButton,
	$Center/VBox/DifficultyRow/HardButton,
]
@onready var _cheats_open_btn: Button = $Center/VBox/CheatsOpenBtn
@onready var _cheats_overlay: Control = $CheatsOverlay
@onready var _cheats_close_btn: Button = $CheatsOverlay/Panel/VBox/CloseBtn
@onready var _god_mode_btn: Button = $CheatsOverlay/Panel/VBox/CheatGodModeBtn
@onready var _max_charge_btn: Button = $CheatsOverlay/Panel/VBox/CheatMaxChargeBtn

@onready var _options_open_btn: Button = $Center/VBox/OptionsOpenBtn
@onready var _options_overlay: Control = $OptionsOverlay
@onready var _options_close_btn: Button = $OptionsOverlay/Panel/VBox/CloseBtn
@onready var _sound_btn: Button = $OptionsOverlay/Panel/VBox/SoundBtn
@onready var _vibration_btn: Button = $OptionsOverlay/Panel/VBox/VibrationBtn
@onready var _keep_weapon_btn: Button = $OptionsOverlay/Panel/VBox/KeepWeaponBtn
@onready var _fire_density_buttons: Array[Button] = [
	$OptionsOverlay/Panel/VBox/FireDensityRow/LowBtn,
	$OptionsOverlay/Panel/VBox/FireDensityRow/NormalBtn,
	$OptionsOverlay/Panel/VBox/FireDensityRow/HighBtn,
]

const STAR_COUNT: int = 120
var _stars: Array[Dictionary] = []

## Hidden trick: hold the version label for this long to unlock Boss Rush
## early, without having to beat the game first.
const VERSION_HOLD_UNLOCK_TIME: float = 5.0
var _version_holding: bool = false
var _version_hold_elapsed: float = 0.0
var _version_release_grace: float = 0.0

## Hidden trick: hold the game title for this long to unlock Ultra Mode
## early, without having to clear Boss Rush first.
const TITLE_HOLD_UNLOCK_TIME: float = 10.0
var _title_holding: bool = false
var _title_hold_elapsed: float = 0.0
var _title_release_grace: float = 0.0

## A real fingertip can't hold dead-still for 5-10s the way a mouse cursor
## can — natural jitter briefly nudges the touch outside the label's rect
## and Godot delivers that as a release, which previously zeroed elapsed
## progress on the spot. Grace window before a release actually resets
## the counter, so momentary flicker doesn't erase real progress.
const HOLD_RELEASE_GRACE_TIME: float = 0.6

func _ready() -> void:
	AudioManager.play_menu_music()
	_start_btn.pressed.connect(_on_start_pressed)
	_boss_rush_btn.pressed.connect(_on_boss_rush_pressed)
	_quit_btn.pressed.connect(_on_quit_pressed)
	_hi_score_label.text = "HIGH SCORE: %d" % GameState.high_score
	_version_label.text = "v%s" % GameState.APP_VERSION
	_version_label.mouse_filter = Control.MOUSE_FILTER_STOP
	_version_label.gui_input.connect(_on_version_label_input)
	_title_label.mouse_filter = Control.MOUSE_FILTER_STOP
	_title_label.gui_input.connect(_on_title_label_input)
	_setup_boss_rush_button()
	_setup_ultra_mode_button()
	_setup_difficulty_buttons()
	_setup_cheat_buttons()
	_setup_options_menu()
	_generate_stars()
	# Animate title in
	$Center/VBox/TitleLabel.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property($Center/VBox/TitleLabel, "modulate:a", 1.0, 1.2)
	tw.parallel().tween_property($Center/VBox/TitleLabel, "position:y",
			$Center/VBox/TitleLabel.position.y, 0.8).from($Center/VBox/TitleLabel.position.y - 40)

func _process(delta: float) -> void:
	_scroll_stars(delta)
	if not GameState.is_boss_rush_available():
		if _version_holding:
			_version_hold_elapsed += delta
			_version_release_grace = 0.0
		else:
			_version_release_grace += delta
			if _version_release_grace >= HOLD_RELEASE_GRACE_TIME:
				_version_hold_elapsed = 0.0
		if _version_hold_elapsed >= VERSION_HOLD_UNLOCK_TIME:
			_version_holding = false
			GameState.test_unlock_boss_rush()
			_setup_boss_rush_button()
			_flash_unlock_feedback(_version_label)
	if not GameState.is_ultra_mode_available():
		if _title_holding:
			_title_hold_elapsed += delta
			_title_release_grace = 0.0
		else:
			_title_release_grace += delta
			if _title_release_grace >= HOLD_RELEASE_GRACE_TIME:
				_title_hold_elapsed = 0.0
		if _title_hold_elapsed >= TITLE_HOLD_UNLOCK_TIME:
			_title_holding = false
			GameState.test_unlock_ultra_mode()
			_setup_ultra_mode_button()
			_flash_unlock_feedback(_title_label)

## Purely visual unlock feedback — a brief white flash-and-return on the
## held label. Deliberately NOT playing an SFX here: every crash report
## for this trick has coincided with the SFX firing at this exact moment
## while the looping menu music was mid-playback (shrinking the music
## loop didn't stop it recurring), so this drops the extra simultaneous
## audio playback entirely as the next isolation step.
func _flash_unlock_feedback(label: Label) -> void:
	var original: Color = label.modulate
	var tw := create_tween()
	tw.tween_property(label, "modulate", Color(2.0, 2.0, 2.0), 0.1)
	tw.tween_property(label, "modulate", original, 0.3)

func _on_start_pressed() -> void:
	GameState.start_game()

func _on_boss_rush_pressed() -> void:
	if not GameState.is_boss_rush_available():
		return
	GameState.start_boss_rush()

## Boss Rush is unlocked by beating the game once — reward the first
## clear rather than making boss-only content available day one. (The
## hidden hold-trick only opens this for the current app instance —
## see GameState.test_unlock_boss_rush — so it doesn't count as really
## earning it.)
func _setup_boss_rush_button() -> void:
	if GameState.is_boss_rush_available():
		_boss_rush_btn.text = "⚔ BOSS RUSH"
		_boss_rush_btn.disabled = false
		_boss_rush_btn.modulate = Color.WHITE
	else:
		_boss_rush_btn.text = "🔒 BOSS RUSH (BEAT THE GAME)"
		_boss_rush_btn.disabled = true
		_boss_rush_btn.modulate = Color(1, 1, 1, 0.55)

## Ultra Mode is unlocked by clearing Boss Rush — a hidden toggle that
## doesn't even appear on the menu until earned, unlike Boss Rush's
## visible-but-locked treatment. (Same test-vs-real distinction as
## Boss Rush above.)
func _setup_ultra_mode_button() -> void:
	_ultra_mode_btn.visible = GameState.is_ultra_mode_available()
	if not GameState.is_ultra_mode_available():
		return
	if not _ultra_mode_btn.pressed.is_connected(_on_ultra_mode_pressed):
		_ultra_mode_btn.pressed.connect(_on_ultra_mode_pressed)
	_update_ultra_mode_btn_text()

func _on_ultra_mode_pressed() -> void:
	GameState.ultra_mode_enabled = !GameState.ultra_mode_enabled
	_update_ultra_mode_btn_text()
	if GameState.ultra_mode_enabled:
		AudioManager.play_full_charge_ready_sfx()

func _update_ultra_mode_btn_text() -> void:
	if GameState.ultra_mode_enabled:
		_ultra_mode_btn.text = "🌈 ULTRA MODE: ON"
		_ultra_mode_btn.modulate = Color(1.0, 0.9, 0.3)
	else:
		_ultra_mode_btn.text = "🌈 ULTRA MODE: OFF"
		_ultra_mode_btn.modulate = Color.WHITE

func _on_quit_pressed() -> void:
	get_tree().quit()

# ── Hidden version-hold unlock ────────────────────────────────

func _on_version_label_input(event: InputEvent) -> void:
	if GameState.is_boss_rush_available():
		return
	var pressed: bool
	if event is InputEventScreenTouch:
		pressed = event.pressed
	elif event is InputEventMouseButton:
		pressed = event.pressed
	else:
		return
	_version_holding = pressed

func _on_title_label_input(event: InputEvent) -> void:
	if GameState.is_ultra_mode_available():
		return
	var pressed: bool
	if event is InputEventScreenTouch:
		pressed = event.pressed
	elif event is InputEventMouseButton:
		pressed = event.pressed
	else:
		return
	_title_holding = pressed

# ── Arcade cheats (persistent toggles only — dynamic one-shot cheats
# like Nuke/Cycle Weapon/+Lives stay pause-menu-only since they need an
# active run) ──────────────────────────────────────────────────

func _setup_cheat_buttons() -> void:
	_cheats_open_btn.pressed.connect(_on_cheats_open_pressed)
	_cheats_close_btn.pressed.connect(_on_cheats_close_pressed)
	_god_mode_btn.pressed.connect(_on_cheat_god_mode)
	_max_charge_btn.pressed.connect(_on_cheat_max_charge)
	_update_cheat_btn_texts()

## Deliberately a popup the player has to go open, not something visible
## at a glance — matches the pause menu's cheats treatment.
func _on_cheats_open_pressed() -> void:
	_cheats_overlay.visible = true

func _on_cheats_close_pressed() -> void:
	_cheats_overlay.visible = false

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

# ── Options menu ──────────────────────────────────────────────

func _setup_options_menu() -> void:
	_options_open_btn.pressed.connect(_on_options_open_pressed)
	_options_close_btn.pressed.connect(_on_options_close_pressed)
	_sound_btn.pressed.connect(_on_sound_toggle_pressed)
	_vibration_btn.pressed.connect(_on_vibration_toggle_pressed)
	_keep_weapon_btn.pressed.connect(_on_keep_weapon_toggle_pressed)
	for i in _fire_density_buttons.size():
		var btn: Button = _fire_density_buttons[i]
		btn.button_pressed = (i == GameState.enemy_fire_density)
		btn.pressed.connect(_on_fire_density_pressed.bind(i))
	_update_options_btn_texts()

func _on_options_open_pressed() -> void:
	_options_overlay.visible = true

func _on_options_close_pressed() -> void:
	_options_overlay.visible = false

func _on_sound_toggle_pressed() -> void:
	GameState.set_sound_enabled(!GameState.sound_enabled)
	_update_options_btn_texts()

func _on_vibration_toggle_pressed() -> void:
	GameState.set_vibration_enabled(!GameState.vibration_enabled)
	_update_options_btn_texts()
	if GameState.vibration_enabled:
		# Immediate feel-it-now confirmation that the toggle actually did
		# something, same idea as a phone's own vibration-setting preview.
		GameState.vibrate(60, 0.5)

func _on_keep_weapon_toggle_pressed() -> void:
	GameState.set_keep_weapon_on_death(!GameState.keep_weapon_on_death)
	_update_options_btn_texts()

func _on_fire_density_pressed(index: int) -> void:
	GameState.set_enemy_fire_density(index)

func _update_options_btn_texts() -> void:
	if GameState.sound_enabled:
		_sound_btn.text = "🔊 SOUND: ON"
		_sound_btn.modulate = Color.WHITE
	else:
		_sound_btn.text = "🔇 SOUND: OFF"
		_sound_btn.modulate = Color(1, 1, 1, 0.6)

	if GameState.vibration_enabled:
		_vibration_btn.text = "📳 VIBRATION: ON"
		_vibration_btn.modulate = Color.WHITE
	else:
		_vibration_btn.text = "📳 VIBRATION: OFF"
		_vibration_btn.modulate = Color(1, 1, 1, 0.6)

	if GameState.keep_weapon_on_death:
		_keep_weapon_btn.text = "KEEP WEAPON ON DEATH: YES"
		_keep_weapon_btn.modulate = Color(0.3, 1.0, 0.4)
	else:
		_keep_weapon_btn.text = "KEEP WEAPON ON DEATH: NO"
		_keep_weapon_btn.modulate = Color.WHITE

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
