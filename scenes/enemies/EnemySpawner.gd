class_name EnemySpawner
extends Node
## EnemySpawner — instantiates enemy scenes when LevelGenerator requests them.
## Maps enemy_type_id integers to enemy script classes and distinct sprite archetypes.

const ENEMY_SCRIPTS: Array[String] = [
	"res://scenes/enemies/EnemyGrunt.gd",      # 0
	"res://scenes/enemies/EnemyWeaver.gd",     # 1
	"res://scenes/enemies/EnemyDiver.gd",      # 2
	"res://scenes/enemies/EnemySniper.gd",     # 3
	"res://scenes/enemies/EnemySpreader.gd",   # 4
	"res://scenes/enemies/EnemyTurret.gd",     # 5
	"res://scenes/enemies/EnemyShield.gd",     # 6
	"res://scenes/enemies/EnemyZigzag.gd",     # 7
	"res://scenes/enemies/EnemyBomber.gd",     # 8
	"res://scenes/enemies/EnemyStalker.gd",    # 9
	"res://scenes/enemies/EnemyCircler.gd",    # 10
	"res://scenes/enemies/EnemyKamikaze.gd",   # 11
	"res://scenes/enemies/EnemyCloaker.gd",    # 12
	"res://scenes/enemies/EnemySplitter.gd",   # 13
	"res://scenes/enemies/EnemyCharger.gd",    # 14
	"res://scenes/enemies/EnemyTanker.gd",     # 15
	"res://scenes/enemies/EnemyFormation.gd",  # 16
	"res://scenes/enemies/EnemyBoomerang.gd",  # 17
	"res://scenes/enemies/EnemyLeech.gd",      # 18
	"res://scenes/enemies/EnemyOverseer.gd",   # 19
]

const ENEMY_DATA_PATHS: Array[String] = [
	"res://resources/enemies/enemy_grunt.tres",
	"res://resources/enemies/enemy_weaver.tres",
	"res://resources/enemies/enemy_diver.tres",
	"res://resources/enemies/enemy_sniper.tres",
	"res://resources/enemies/enemy_spreader.tres",
	"res://resources/enemies/enemy_turret.tres",
	"res://resources/enemies/enemy_shield.tres",
	"res://resources/enemies/enemy_zigzag.tres",
	"res://resources/enemies/enemy_bomber.tres",
	"res://resources/enemies/enemy_stalker.tres",
	"res://resources/enemies/enemy_circler.tres",
	"res://resources/enemies/enemy_kamikaze.tres",
	"res://resources/enemies/enemy_cloaker.tres",
	"res://resources/enemies/enemy_splitter.tres",
	"res://resources/enemies/enemy_charger.tres",
	"res://resources/enemies/enemy_tanker.tres",
	"res://resources/enemies/enemy_formation.tres",
	"res://resources/enemies/enemy_boomerang.tres",
	"res://resources/enemies/enemy_leech.tres",
	"res://resources/enemies/enemy_overseer.tres",
]

const EnemyBaseScene: PackedScene = preload("res://scenes/enemies/EnemyBase.tscn")

## Injected by Game.gd
var enemy_parent: Node = null
var bullet_container: Node = null
var player_ref: Node = null
var powerup_spawner: PowerUpSpawner = null

## Max enemies alive at once (performance cap)
const MAX_ENEMIES: int = 45

const SPRITE_BASIC := preload("res://assets/sprites/enemy_ship.png")
const SPRITE_BIO := preload("res://assets/sprites/enemy_bio_swarmer.png")
const SPRITE_ARMORED := preload("res://assets/sprites/enemy_armored_turret.png")
const SPRITE_STEALTH := preload("res://assets/sprites/enemy_stealth_cruiser.png")
const SPRITE_MANTA := preload("res://assets/sprites/enemy_manta_flyer.png")
const SPRITE_CRYSTAL := preload("res://assets/sprites/enemy_crystal_sentinel.png")

func _on_enemy_spawn_requested(pos: Vector2, enemy_type_id: int) -> void:
	if enemy_parent == null:
		return
	if enemy_parent.get_child_count() >= MAX_ENEMIES:
		return
	if enemy_type_id < 0 or enemy_type_id >= ENEMY_SCRIPTS.size():
		return

	var enemy: EnemyBase = EnemyBaseScene.instantiate()
	var script: GDScript = load(ENEMY_SCRIPTS[enemy_type_id])
	if script:
		enemy.set_script(script)

	# Apply data resource
	var data_path := ENEMY_DATA_PATHS[enemy_type_id] \
			if enemy_type_id < ENEMY_DATA_PATHS.size() else ""
	if ResourceLoader.exists(data_path):
		var data: EnemyData = load(data_path)
		enemy.init_from_data(data)

	enemy.bullet_container = bullet_container
	enemy.player_ref = player_ref
	enemy.add_to_group("enemies")

	enemy_parent.add_child(enemy)
	enemy.global_position = pos

	# Assign distinct archetype sprite texture
	var sprite_node: Sprite2D = enemy.get_node_or_null("Visual/Sprite2D") as Sprite2D
	if sprite_node:
		match enemy_type_id:
			1, 11, 18:
				sprite_node.texture = SPRITE_BIO
				sprite_node.scale = Vector2(0.065, 0.065) * enemy.size_scale
			4, 5, 6, 8, 15:
				sprite_node.texture = SPRITE_ARMORED
				sprite_node.scale = Vector2(0.065, 0.065) * enemy.size_scale
			3, 7, 9, 12, 19:
				sprite_node.texture = SPRITE_STEALTH
				sprite_node.scale = Vector2(0.065, 0.065) * enemy.size_scale
			10, 16, 17:
				sprite_node.texture = SPRITE_MANTA
				sprite_node.scale = Vector2(0.065, 0.065) * enemy.size_scale
			13:
				sprite_node.texture = SPRITE_CRYSTAL
				sprite_node.scale = Vector2(0.065, 0.065) * enemy.size_scale
			_:
				sprite_node.texture = SPRITE_BASIC
				sprite_node.scale = Vector2(0.065, 0.065) * enemy.size_scale

	# Wire up died signal for scoring
	enemy.died.connect(_on_enemy_died)

func _on_enemy_died(pos: Vector2, score_val: int) -> void:
	GameState.add_score(score_val)
	if powerup_spawner:
		var roll: float = randf()
		if roll < 0.010:      # 1.0% chance for Life Core (+1 HP)
			powerup_spawner.spawn_powerup_at(pos, -1, "life")
		elif roll < 0.018:    # 0.8% chance for Super Shield (6s Invincibility)
			powerup_spawner.spawn_powerup_at(pos, -1, "shield")
		elif roll < 0.098:    # 8.0% chance for Weapon Upgrade Capsule
			powerup_spawner.spawn_powerup_at(pos, -1, "weapon")
