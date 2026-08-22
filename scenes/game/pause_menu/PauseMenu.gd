extends CanvasLayer
## PauseMenu — overlay shown when the game is paused with Arcade Cheats.

@onready var _resume_btn: Button = $Overlay/Panel/VBox/ResumeButton
@onready var _quit_btn: Button = $Overlay/Panel/VBox/QuitButton

@onready var _god_mode_btn: Button = $Overlay/Panel/VBox/CheatGodModeBtn
@onready var _add_lives_btn: Button = $Overlay/Panel/VBox/CheatAddLivesBtn
@onready var _cycle_weapon_btn: Button = $Overlay/Panel/VBox/CheatCycleWeaponBtn
@onready var _nuke_btn: Button = $Overlay/Panel/VBox/CheatNukeBtn
@onready var _max_charge_btn: Button = $Overlay/Panel/VBox/CheatMaxChargeBtn
@onready var _skip_level_btn: Button = $Overlay/Panel/VBox/CheatSkipLevelBtn

signal resume_requested
signal quit_requested

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_resume_btn.pressed.connect(_on_resume_pressed)
	_quit_btn.pressed.connect(_on_quit_pressed)

	# Connect Cheat Buttons
	_god_mode_btn.pressed.connect(_on_cheat_god_mode)
	_add_lives_btn.pressed.connect(_on_cheat_add_lives)
	_cycle_weapon_btn.pressed.connect(_on_cheat_cycle_weapon)
	_nuke_btn.pressed.connect(_on_cheat_nuke)
	_max_charge_btn.pressed.connect(_on_cheat_max_charge)
	_skip_level_btn.pressed.connect(_on_cheat_skip_level)

	visible = false
	_update_cheat_btn_texts()

func _on_resume_pressed() -> void:
	hide_menu()
	resume_requested.emit()

func _on_quit_pressed() -> void:
	hide_menu()
	quit_requested.emit()
	GameState.go_to_menu()

func show_menu() -> void:
	visible = true
	get_tree().paused = true
	_update_cheat_btn_texts()
	_resume_btn.grab_focus()

func hide_menu() -> void:
	visible = false
	get_tree().paused = false

# ── Cheat Handlers ─────────────────────────────────────────────

func _on_cheat_god_mode() -> void:
	GameState.mark_cheats_used()
	GameState.god_mode_enabled = !GameState.god_mode_enabled
	_update_cheat_btn_texts()

func _on_cheat_add_lives() -> void:
	GameState.mark_cheats_used()
	for i in 5:
		GameState.gain_life()
	AudioManager.play_pickup_sfx()

func _on_cheat_cycle_weapon() -> void:
	GameState.mark_cheats_used()
	var next_idx: int = (GameState.current_weapon_index + 1) % 10
	GameState.set_weapon(next_idx)
	AudioManager.play_pickup_sfx()

func _on_cheat_nuke() -> void:
	GameState.mark_cheats_used()
	var enemies := get_tree().get_nodes_in_group("enemies")
	for e in enemies:
		if is_instance_valid(e) and not e.is_queued_for_deletion():
			if e.has_method("take_damage"):
				e.take_damage(999999)
			elif e.has_method("_die"):
				e.call_deferred("_die")
			else:
				e.queue_free()
	AudioManager.play_superweapon_sfx()

func _on_cheat_max_charge() -> void:
	GameState.mark_cheats_used()
	GameState.always_max_charge_enabled = !GameState.always_max_charge_enabled
	_update_cheat_btn_texts()
	if GameState.always_max_charge_enabled:
		AudioManager.play_full_charge_ready_sfx()

func _on_cheat_skip_level() -> void:
	# No skipping past the final level/boss — that's the actual ending,
	# not something to cheat through.
	if GameState.level >= GameState.TOTAL_LEVELS:
		return
	GameState.mark_cheats_used()
	hide_menu()
	GameState.advance_level()

func _update_cheat_btn_texts() -> void:
	if _god_mode_btn:
		if GameState.god_mode_enabled:
			_god_mode_btn.text = "🛡️ GOD MODE: ON"
			_god_mode_btn.modulate = Color(0.3, 1.0, 0.4)
		else:
			_god_mode_btn.text = "🛡️ GOD MODE: OFF"
			_god_mode_btn.modulate = Color.WHITE

	if _max_charge_btn:
		if GameState.always_max_charge_enabled:
			_max_charge_btn.text = "🚀 ALWAYS MAX CHARGE: ON"
			_max_charge_btn.modulate = Color(0.3, 1.0, 0.4)
		else:
			_max_charge_btn.text = "🚀 ALWAYS MAX CHARGE: OFF"
			_max_charge_btn.modulate = Color.WHITE

	if _skip_level_btn:
		if GameState.level >= GameState.TOTAL_LEVELS:
			_skip_level_btn.text = "⏭ SKIP LEVEL (FINAL LEVEL)"
			_skip_level_btn.disabled = true
			_skip_level_btn.modulate = Color(1, 1, 1, 0.5)
		else:
			_skip_level_btn.text = "⏭ SKIP LEVEL"
			_skip_level_btn.disabled = false
			_skip_level_btn.modulate = Color.WHITE
