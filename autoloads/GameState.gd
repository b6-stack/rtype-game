extends Node
## GameState — global singleton managing score, lives, level, weapon selection and scene transitions.

const GAME_SCENE := "res://scenes/game/Game.tscn"
const MENU_SCENE := "res://scenes/main_menu/MainMenu.tscn"
const GAME_OVER_SCENE := "res://scenes/game/game_over/GameOverScreen.tscn"
const WIN_SCENE := "res://scenes/game/win_screen/WinScreen.tscn"

## Bump this alongside export_presets.cfg's version/name on every release
## so the main menu version label reflects what's actually installed.
const APP_VERSION := "1.2.3"

signal score_changed(new_score: int)
signal lives_changed(new_lives: int)
signal weapon_changed(weapon_index: int)
signal level_changed(new_level: int)
signal score_goal_updated(current_score: int, goal_score: int)
signal life_awarded(new_lives: int)
signal difficulty_changed(new_difficulty: int)
signal game_over

const MAX_LIVES: int = 5
const STARTING_LIVES: int = 3
const TOTAL_LEVELS: int = 10
const SCORE_GOAL_INTERVAL: int = 5000

enum Difficulty { EASY, NORMAL, HARD }
const DIFFICULTY_NAMES: Array[String] = ["EASY", "NORMAL", "HARD"]
## Overall aggression scale applied to enemy speed, fire rate, and spawn density.
const DIFFICULTY_MULTIPLIERS: Array[float] = [0.75, 1.0, 1.3]
## Respawn invincibility duration scale — lower difficulties get more grace
## to recover and reposition before enemies can threaten them again.
const RESPAWN_GRACE_MULTIPLIERS: Array[float] = [1.6, 1.2, 1.0]

var score: int = 0
var lives: int = STARTING_LIVES
var level: int = 1
var current_weapon_index: int = 0
var difficulty: int = Difficulty.NORMAL
var god_mode_enabled: bool = false
var always_max_charge_enabled: bool = false
var cheats_used: bool = false
var high_score: int = 0
var is_game_over: bool = false
var next_life_score_goal: int = SCORE_GOAL_INTERVAL

func _ready() -> void:
	_load_save()

# ── Public API ──────────────────────────────────────────────

func reset() -> void:
	score = 0
	lives = STARTING_LIVES
	level = 1
	current_weapon_index = 0
	god_mode_enabled = false
	always_max_charge_enabled = false
	cheats_used = false
	is_game_over = false
	next_life_score_goal = SCORE_GOAL_INTERVAL
	score_changed.emit(score)
	lives_changed.emit(lives)
	weapon_changed.emit(current_weapon_index)
	level_changed.emit(level)
	score_goal_updated.emit(score, next_life_score_goal)

func mark_cheats_used() -> void:
	cheats_used = true
	score = 0
	score_changed.emit(0)

func add_score(points: int) -> void:
	if cheats_used:
		score = 0
		score_changed.emit(0)
		return

	score += points
	if score > high_score:
		high_score = score
		_save()
	score_changed.emit(score)

	while score >= next_life_score_goal:
		gain_life()
		life_awarded.emit(lives)
		next_life_score_goal += SCORE_GOAL_INTERVAL

	score_goal_updated.emit(score, next_life_score_goal)

func lose_life() -> void:
	lives = max(0, lives - 1)
	lives_changed.emit(lives)
	if lives <= 0:
		is_game_over = true
		game_over.emit()

func gain_life() -> void:
	if lives < MAX_LIVES:
		lives += 1
		lives_changed.emit(lives)

func set_weapon(index: int) -> void:
	current_weapon_index = index
	weapon_changed.emit(index)

func set_difficulty(new_difficulty: int) -> void:
	difficulty = clampi(new_difficulty, Difficulty.EASY, Difficulty.HARD)
	_save()
	difficulty_changed.emit(difficulty)

func get_difficulty_multiplier() -> float:
	return DIFFICULTY_MULTIPLIERS[difficulty]

func get_respawn_grace_multiplier() -> float:
	return RESPAWN_GRACE_MULTIPLIERS[difficulty]

func advance_level() -> void:
	level += 1
	level_changed.emit(level)
	get_tree().paused = false
	if level > TOTAL_LEVELS:
		get_tree().change_scene_to_file(WIN_SCENE)
	else:
		get_tree().change_scene_to_file(GAME_SCENE)

func start_game() -> void:
	reset()
	get_tree().paused = false
	get_tree().change_scene_to_file(GAME_SCENE)

func go_to_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(MENU_SCENE)

func go_to_game_over() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(GAME_OVER_SCENE)

# ── Persistence ─────────────────────────────────────────────

func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("data", "high_score", high_score)
	cfg.set_value("data", "difficulty", difficulty)
	cfg.save("user://save.cfg")

func _load_save() -> void:
	var cfg := ConfigFile.new()
	if cfg.load("user://save.cfg") == OK:
		high_score = cfg.get_value("data", "high_score", 0)
		difficulty = clampi(cfg.get_value("data", "difficulty", Difficulty.NORMAL), Difficulty.EASY, Difficulty.HARD)
