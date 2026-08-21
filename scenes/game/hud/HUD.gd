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
@onready var _weapon_label: Label = $Control/WeaponLabel
@onready var _level_label: Label = $Control/LevelLabel

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

# ── Public API ────────────────────────────────────────────────

func set_charge(normalized: float) -> void:
	_charge_level = clamp(normalized, 0.0, 1.0)
	_charge_bar.value = _charge_level * 100.0
	_charge_bar.modulate = Color.CYAN.lerp(Color.WHITE, _charge_level)
	if _charge_level >= 1.0 and _charge_pulse_tween == null:
		_start_charge_ready_pulse()
	elif _charge_level < 1.0 and _charge_pulse_tween != null:
		_charge_pulse_tween.kill()
		_charge_pulse_tween = null
		_charge_bar.modulate = Color.CYAN.lerp(Color.WHITE, _charge_level)

func show_charge_bar(visible: bool) -> void:
	_charge_bar.visible = visible
	if not visible:
		_charge_level = 0.0
		_charge_bar.value = 0.0
		if _charge_pulse_tween:
			_charge_pulse_tween.kill()
			_charge_pulse_tween = null

# ── Private ────────────────────────────────────────────────────

func _refresh_score() -> void:
	_score_label.text = "SCORE: %d" % GameState.score
	_hi_score_label.text = "BEST: %d" % GameState.high_score

func _update_goal_bar(current: int, goal: int) -> void:
	if _life_goal_bar and _life_goal_label:
		var prev_goal: int = max(0, goal - GameState.SCORE_GOAL_INTERVAL)
		var progress: float = 0.0
		if goal > prev_goal:
			progress = float(current - prev_goal) / float(goal - prev_goal)
		_life_goal_bar.value = clamp(progress * 100.0, 0.0, 100.0)
		_life_goal_label.text = "1-UP GOAL: %d" % goal

func _refresh_lives() -> void:
	for child in _lives_container.get_children():
		child.queue_free()
	for i in GameState.MAX_LIVES:
		var icon := ColorRect.new()
		icon.custom_minimum_size = Vector2(24, 18)
		icon.color = Color(0.2, 1.0, 0.5) if i < GameState.lives else Color(0.2, 0.2, 0.2)
		_lives_container.add_child(icon)

func _refresh_weapon() -> void:
	const NAMES := ["VULCAN","LASER","PLASMA","MISSILE","WAVE",
					"BOUNCER","DRILL","RICOCHET","GRAVITY","LIGHTNING"]
	var idx := GameState.current_weapon_index
	_weapon_label.text = "WPN: %s" % (NAMES[idx] if idx < NAMES.size() else "?")

func _refresh_level() -> void:
	_level_label.text = "LVL %d" % GameState.level

func _start_charge_ready_pulse() -> void:
	_charge_pulse_tween = create_tween().set_loops()
	_charge_pulse_tween.tween_property(_charge_bar, "modulate", Color.YELLOW, 0.2)
	_charge_pulse_tween.tween_property(_charge_bar, "modulate", Color.WHITE, 0.2)

# ── Signal handlers ───────────────────────────────────────────

func _on_score_changed(new_score: int) -> void:
	_score_label.text = "SCORE: %d" % new_score
	_hi_score_label.text = "BEST: %d" % GameState.high_score
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
