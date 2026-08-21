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

var _weapon_icon_rect: TextureRect

func _refresh_weapon() -> void:
	const NAMES := ["VULCAN","LASER","PLASMA","MISSILE","WAVE",
					"BOUNCER","DRILL","RICOCHET","GRAVITY","LIGHTNING"]
	var idx := GameState.current_weapon_index
	if _weapon_label:
		_weapon_label.text = "WPN: %s" % (NAMES[idx] if idx < NAMES.size() else "?")
		
		# Add or update TextureRect icon badge next to weapon label
		if _weapon_icon_rect == null or not is_instance_valid(_weapon_icon_rect):
			_weapon_icon_rect = TextureRect.new()
			_weapon_icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			_weapon_icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			_weapon_icon_rect.custom_minimum_size = Vector2(40, 40)
			_weapon_icon_rect.size = Vector2(40, 40)
			_weapon_icon_rect.position = Vector2(270.0, -8.0)
			_weapon_label.add_child(_weapon_icon_rect)
			
		var path := WEAPON_ICON_PATHS[idx] if idx < WEAPON_ICON_PATHS.size() else ""
		if ResourceLoader.exists(path):
			_weapon_icon_rect.texture = load(path)
			_weapon_icon_rect.visible = true

func _refresh_level() -> void:
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
