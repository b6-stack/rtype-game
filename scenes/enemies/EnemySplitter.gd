class_name EnemySplitter
extends EnemyBase
## Splitter enemy — on death safely spawns 2 smaller grunts that scroll and take damage properly.

func _ready() -> void:
	max_health = 45
	current_health = 45
	move_speed = 160.0
	score_value = 200
	shoot_cooldown = 2.5
	bullet_color = Color(0.8, 0.8, 0.0)
	bullet_speed = 350.0
	bullet_damage = 1
	enemy_color = Color(0.7, 0.7, 0.0)
	size_scale = 1.3
	super._ready()

func _move(_delta: float) -> void:
	velocity = Vector2(-move_speed, 0.0)

func _shoot() -> void:
	_fire_direction(Vector2.LEFT)

## Safely spawn two small grunts outside physics flush
func _die() -> void:
	_spawn_minis_deferred.call_deferred(global_position)
	super._die()

func _spawn_minis_deferred(spawn_center: Vector2) -> void:
	var enemy_parent: Node = get_parent() if get_parent() else get_tree().current_scene
	if enemy_parent == null:
		return

	var grunt_scene: PackedScene = preload("res://scenes/enemies/EnemyBase.tscn")
	for offset_y in [-25.0, 25.0]:
		var mini: EnemyBase = grunt_scene.instantiate()
		mini.set_script(load("res://scenes/enemies/EnemyGrunt.gd"))
		mini.max_health = 15
		mini.current_health = 15
		mini.move_speed = 220.0
		mini.size_scale = 0.75
		mini.score_value = 60
		mini.enemy_color = Color(0.8, 0.8, 0.2)
		mini.bullet_container = bullet_container
		mini.player_ref = player_ref
		mini.add_to_group("enemies")
		enemy_parent.add_child(mini)
		mini.global_position = spawn_center + Vector2(0.0, offset_y)
