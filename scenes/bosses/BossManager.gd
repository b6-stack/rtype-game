class_name BossManager
extends Node
## BossManager — handles boss encounter lifecycle.
## Called by LevelGenerator when a boss trigger chunk is reached.
## Freezes chunk spawning during the fight, shows the boss health bar on HUD,
## and calls GameState.advance_level() on boss defeat.

signal boss_fight_started(boss_name: String, max_hp: int)
signal boss_hp_updated(current: int, maximum: int)
signal boss_fight_ended

const BOSS_SCRIPTS: Array[String] = [
	"res://scenes/bosses/BossIronClaw.gd",    # Level 1
	"res://scenes/bosses/BossHydra.gd",        # Level 2
	"res://scenes/bosses/BossBehemoth.gd",     # Level 3
	"res://scenes/bosses/BossSentinel.gd",     # Level 4
	"res://scenes/bosses/BossSwarmQueen.gd",   # Level 5
	"res://scenes/bosses/BossPhotonCore.gd",   # Level 6
	"res://scenes/bosses/BossAbyssGate.gd",    # Level 7
	"res://scenes/bosses/BossOmega.gd",        # Level 8
	"res://scenes/bosses/BossDreadStar.gd",    # Level 9
	"res://scenes/bosses/BossHyperion.gd",     # Level 10
]

const BOSS_DATA_PATHS: Array[String] = [
	"res://resources/bosses/boss_iron_claw.tres",
	"res://resources/bosses/boss_hydra.tres",
	"res://resources/bosses/boss_behemoth.tres",
	"res://resources/bosses/boss_sentinel.tres",
	"res://resources/bosses/boss_swarm_queen.tres",
	"res://resources/bosses/boss_photon_core.tres",
	"res://resources/bosses/boss_abyss_gate.tres",
	"res://resources/bosses/boss_omega.tres",
	"res://resources/bosses/boss_dread_star.tres",
	"res://resources/bosses/boss_hyperion.tres",
]

const BossBaseScene: PackedScene = preload("res://scenes/bosses/BossBase.tscn")

## Injected by Game.gd
var boss_parent: Node = null
var bullet_container: Node = null
var player_ref: Node = null
var level_generator: LevelGenerator = null
var powerup_spawner: PowerUpSpawner = null
var hud: Node = null

var _current_boss: BossBase = null
var _fight_active: bool = false

func trigger_boss(level: int) -> void:
	if _fight_active:
		return
	var boss_index: int = clampi(level - 1, 0, BOSS_SCRIPTS.size() - 1)
	_spawn_boss(boss_index)

func _spawn_boss(index: int) -> void:
	if boss_parent == null:
		return

	_fight_active = true
	AudioManager.play_boss_sfx()
	AudioManager.play_boss_music()

	# Tell level generator boss is active so it creates open arena chunks
	if level_generator:
		level_generator.is_boss_active = true

	var boss: BossBase = BossBaseScene.instantiate()
	var script: GDScript = load(BOSS_SCRIPTS[index])
	if script:
		boss.set_script(script)

	# Apply data
	var data_path := BOSS_DATA_PATHS[index] if index < BOSS_DATA_PATHS.size() else ""
	if ResourceLoader.exists(data_path):
		var data: BossData = load(data_path)
		boss.init_from_data(data)

	boss.bullet_container = bullet_container
	boss.player_ref = player_ref
	boss.add_to_group("bosses")

	boss_parent.add_child(boss)
	boss.global_position = Vector2(2100.0, 540.0)
	_current_boss = boss

	# Assign distinct boss sprite texture
	var sprite_node = boss.get_node_or_null("Visual/Sprite2D") as Sprite2D
	if sprite_node:
		if index in [1, 2, 4, 6, 8, 9]:
			sprite_node.texture = preload("res://assets/sprites/boss_titan_cruiser.png")
		else:
			sprite_node.texture = preload("res://assets/sprites/boss_ship.png")
		# Scale is left to BossBase's entrance animation (starts small and grows in).

	# Wire signals
	boss.died.connect(_on_boss_died)
	boss.health_changed.connect(_on_boss_health_changed)
	boss.entrance_complete.connect(_on_boss_entrance_complete)

	# Notify HUD
	boss_fight_started.emit(boss.boss_name, boss.max_health)
	if hud and hud.has_method("show_boss_bar"):
		hud.show_boss_bar(boss.boss_name, boss.max_health)

func _on_boss_entrance_complete() -> void:
	pass  # Boss is now in arena; fight logic handled by BossBase

func _on_boss_health_changed(current: int, maximum: int) -> void:
	boss_hp_updated.emit(current, maximum)
	if hud and hud.has_method("update_boss_bar"):
		hud.update_boss_bar(current, maximum)

func _on_boss_died() -> void:
	_fight_active = false
	var boss_pos: Vector2 = Vector2(1200.0, 540.0)
	if _current_boss and is_instance_valid(_current_boss):
		boss_pos = _current_boss.global_position
	_current_boss = null

	if hud and hud.has_method("hide_boss_bar"):
		hud.hide_boss_bar()

	# Drop guaranteed weapon power-up on boss defeat
	if powerup_spawner:
		var next_weapon_idx: int = (GameState.current_weapon_index + 1) % 10
		powerup_spawner.spawn_powerup_at(boss_pos, next_weapon_idx, "weapon")

	boss_fight_ended.emit()

	# Resume normal level generation
	if level_generator:
		level_generator.is_boss_active = false

	# 4.5 seconds pause so player can collect the weapon drop before next level
	await get_tree().create_timer(4.5).timeout
	GameState.advance_level()

func is_fight_active() -> bool:
	return _fight_active
