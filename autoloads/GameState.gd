extends Node
## GameState — global singleton managing score, lives, level, weapon selection and scene transitions.

const GAME_SCENE := "res://scenes/game/Game.tscn"
const MENU_SCENE := "res://scenes/main_menu/MainMenu.tscn"
const GAME_OVER_SCENE := "res://scenes/game/game_over/GameOverScreen.tscn"
const WIN_SCENE := "res://scenes/game/win_screen/WinScreen.tscn"

## Bump this alongside export_presets.cfg's version/name on every release
## so the main menu version label reflects what's actually installed.
const APP_VERSION := "2.6.1"

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

## Level biome names (index 0 = level 1) — same names already used as
## comments in LevelGenerator.LEVEL_COLORS / AudioManager.LEVEL_THEMES,
## exposed as real data here so the HUD can display them.
const LEVEL_NAMES: Array[String] = [
	"Blue Cave", "Red Cavern", "Green Base", "Brown Fortress", "Purple Alien",
	"Teal Station", "Crimson Core", "Gold Final", "Cosmic Void", "Solar Core",
]

enum Difficulty { EASY, NORMAL, HARD }
const DIFFICULTY_NAMES: Array[String] = ["EASY", "NORMAL", "HARD"]
## Overall aggression scale applied to enemy speed, fire rate, and spawn density.
const DIFFICULTY_MULTIPLIERS: Array[float] = [0.75, 1.0, 1.3]
## Respawn invincibility duration scale — lower difficulties get more grace
## to recover and reposition before enemies can threaten them again.
const RESPAWN_GRACE_MULTIPLIERS: Array[float] = [1.6, 1.2, 1.0]
## Extra-life score threshold scale. Easy stays at the flat base interval;
## Normal/Hard require proportionally more score per 1-UP, matching the
## "harder difficulty = tougher rewards too" pattern used elsewhere.
const LIFE_GOAL_MULTIPLIERS: Array[float] = [1.0, 1.3, 1.6]
## Base duration for the shield powerup / 1-UP bonus shield, before the
## difficulty grace multiplier (same scale as respawn invincibility) is
## applied — see get_shield_duration().
const SHIELD_BASE_DURATION: float = 10.0
## Score multiplier by difficulty — Hard rewards the extra challenge,
## Easy scores a bit less, Normal is the baseline.
const SCORE_MULTIPLIERS: Array[float] = [0.8, 1.0, 1.1]
## Extra score multiplier while Ultra Mode is enabled — it's an earned
## reward (unlocked by clearing Boss Rush legitimately), not a cheat, so
## unlike god_mode/always_max_charge it does NOT disable scoring.
const ULTRA_MODE_SCORE_MULT: float = 1.15
## Hard cap on the combined (difficulty x Ultra Mode) score multiplier —
## Hard (1.1x) stacked with Ultra (1.15x) would otherwise reach 1.265x.
const MAX_SCORE_MULTIPLIER: float = 1.25
## Ultra Mode combat bonuses.
const ULTRA_MODE_BOSS_DAMAGE_MULT: float = 3.0

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
## Boss Rush: back-to-back fights against all 10 bosses, no regular waves
## between them. Read by LevelGenerator (short lead-in, no filler spawns)
## and persists across the per-level scene reloads inside advance_level().
var boss_rush_mode: bool = false
## Unlocked PERMANENTLY (persisted) the first time the player reaches the
## win screen — a reward for finishing the campaign rather than
## day-one-available. Not granted if cheats were used this run (see
## WinScreen._ready()). This is the real, earned record — see
## is_boss_rush_available() for what actually gates the menu button.
var boss_rush_unlocked: bool = false
## Unlocked PERMANENTLY (persisted) by clearing Boss Rush (also blocked
## by cheats). The real, earned record — see is_ultra_mode_available().
var ultra_mode_unlocked: bool = false
## Session-only toggle (not persisted, like god_mode_enabled) — rainbow
## aftereffect, instant-kill on basic enemies, 3x boss damage, and a
## score bonus. Deliberately NOT part of is_scoring_disabled(): it's an
## earned reward, not a cheat, so score still counts while it's on.
var ultra_mode_enabled: bool = false

## The hidden press-and-hold main-menu tricks set THESE instead of the
## real unlocked flags above — they open the menu buttons for testing,
## for this app instance only (never saved, cleared on restart), and are
## deliberately kept separate so nothing mistakes a testing shortcut for
## an actually-earned unlock (e.g. WinScreen's "already unlocked" skip).
var _boss_rush_test_unlocked: bool = false
var _ultra_mode_test_unlocked: bool = false

var next_life_score_goal: int = SCORE_GOAL_INTERVAL

func _ready() -> void:
	_load_save()

# ── Public API ──────────────────────────────────────────────

func reset() -> void:
	score = 0
	lives = STARTING_LIVES
	level = 1
	current_weapon_index = 0
	boss_rush_mode = false
	# god_mode_enabled / always_max_charge_enabled / ultra_mode_enabled are
	# intentionally NOT reset here — they're all toggleable from the main
	# menu before a run even starts, so clearing them on start_game() would
	# silently undo the player's choice. is_scoring_disabled() covers the
	# score-zeroing side for the first two; Ultra Mode deliberately isn't
	# included there since it's an earned reward, not a cheat.
	cheats_used = false
	is_game_over = false
	next_life_score_goal = get_life_goal_interval()
	score_changed.emit(score)
	lives_changed.emit(lives)
	weapon_changed.emit(current_weapon_index)
	level_changed.emit(level)
	score_goal_updated.emit(score, next_life_score_goal)

func mark_cheats_used() -> void:
	cheats_used = true
	score = 0
	score_changed.emit(0)

## True whenever any cheat (one-shot or a persistent toggle) is active for
## this run — used to zero out score/high-score while cheats are in play.
func is_scoring_disabled() -> bool:
	return cheats_used or god_mode_enabled or always_max_charge_enabled

func add_score(points: int) -> void:
	if is_scoring_disabled():
		score = 0
		score_changed.emit(0)
		return

	var mult: float = get_score_multiplier()
	if ultra_mode_enabled:
		mult *= ULTRA_MODE_SCORE_MULT
	mult = minf(mult, MAX_SCORE_MULTIPLIER)
	score += int(points * mult)
	if score > high_score:
		high_score = score
		_save()
	score_changed.emit(score)

	while score >= next_life_score_goal:
		gain_life()
		life_awarded.emit(lives)
		next_life_score_goal += get_life_goal_interval()

	score_goal_updated.emit(score, next_life_score_goal)

func lose_life() -> void:
	lives = max(0, lives - 1)
	lives_changed.emit(lives)
	# Dying (whether it costs the run or just a respawn) resets the weapon
	# back to Vulcan — losing your upgrade is part of the cost of a hit.
	set_weapon(0)
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

func unlock_boss_rush() -> void:
	if boss_rush_unlocked:
		return
	boss_rush_unlocked = true
	_save()

func unlock_ultra_mode() -> void:
	if ultra_mode_unlocked:
		return
	ultra_mode_unlocked = true
	_save()

## Hidden main-menu hold-trick versions — open the button for THIS APP
## INSTANCE only, never persisted. Deliberately not the same flag as a
## real unlock so code that cares whether it was actually earned (e.g.
## WinScreen) isn't fooled by a testing shortcut.
func test_unlock_boss_rush() -> void:
	_boss_rush_test_unlocked = true

func test_unlock_ultra_mode() -> void:
	_ultra_mode_test_unlocked = true

## What actually gates the main-menu buttons — either a real, earned,
## persisted unlock, or this instance's testing shortcut.
func is_boss_rush_available() -> bool:
	return boss_rush_unlocked or _boss_rush_test_unlocked

func is_ultra_mode_available() -> bool:
	return ultra_mode_unlocked or _ultra_mode_test_unlocked

func get_difficulty_multiplier() -> float:
	return DIFFICULTY_MULTIPLIERS[difficulty]

func get_score_multiplier() -> float:
	return SCORE_MULTIPLIERS[difficulty]

func get_respawn_grace_multiplier() -> float:
	return RESPAWN_GRACE_MULTIPLIERS[difficulty]

func get_life_goal_interval() -> int:
	return int(SCORE_GOAL_INTERVAL * LIFE_GOAL_MULTIPLIERS[difficulty])

## Shared by the shield powerup pickup and the free bonus shield granted
## on a score-based 1-UP, so both always match and both scale with
## difficulty (same grace curve as respawn invincibility).
func get_shield_duration() -> float:
	return SHIELD_BASE_DURATION * get_respawn_grace_multiplier()

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

## No free continues on Hard — if you die there, that's it.
func can_continue() -> bool:
	return difficulty != Difficulty.HARD

## Arcade-style continue: resumes at the CURRENT level (unlike start_game/
## start_boss_rush, which restart from level 1) with a fresh set of lives
## and the weapon reset to Vulcan, at the cost of a one-time score reset.
## Deliberately NOT treated as a cheat — scoring keeps working normally
## afterward, and legitimately finishing the game/Boss Rush from here
## still earns the real unlocks. Gated off entirely on Hard — see
## can_continue().
func continue_game() -> void:
	if not can_continue():
		return
	score = 0
	score_changed.emit(0)
	next_life_score_goal = get_life_goal_interval()
	score_goal_updated.emit(score, next_life_score_goal)
	lives = STARTING_LIVES
	current_weapon_index = 0
	is_game_over = false
	lives_changed.emit(lives)
	weapon_changed.emit(current_weapon_index)
	get_tree().paused = false
	get_tree().change_scene_to_file(GAME_SCENE)

func start_boss_rush() -> void:
	reset()
	boss_rush_mode = true
	get_tree().paused = false
	get_tree().change_scene_to_file(GAME_SCENE)

func go_to_menu() -> void:
	get_tree().paused = false
	AudioManager.stop_music()
	get_tree().change_scene_to_file(MENU_SCENE)

func go_to_game_over() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(GAME_OVER_SCENE)

# ── Persistence ─────────────────────────────────────────────

func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("data", "high_score", high_score)
	cfg.set_value("data", "difficulty", difficulty)
	cfg.set_value("data", "boss_rush_unlocked", boss_rush_unlocked)
	cfg.set_value("data", "ultra_mode_unlocked", ultra_mode_unlocked)
	cfg.save("user://save.cfg")

func _load_save() -> void:
	var cfg := ConfigFile.new()
	if cfg.load("user://save.cfg") == OK:
		high_score = cfg.get_value("data", "high_score", 0)
		difficulty = clampi(cfg.get_value("data", "difficulty", Difficulty.NORMAL), Difficulty.EASY, Difficulty.HARD)
		boss_rush_unlocked = cfg.get_value("data", "boss_rush_unlocked", false)
		ultra_mode_unlocked = cfg.get_value("data", "ultra_mode_unlocked", false)
