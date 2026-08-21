class_name EnemySplitter
extends EnemyBase

## Splitter enemy — on death spawns 2 smaller grunt-like enemies built entirely in code.


func _ready() -> void:
	max_health = 50
	current_health = 50
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


## Override _die to spawn two mini-grunts before freeing self.
func _die() -> void:
	_spawn_mini_grunt(global_position + Vector2(0.0, -20.0))
	_spawn_mini_grunt(global_position + Vector2(0.0, 20.0))
	super._die()


func _spawn_mini_grunt(spawn_pos: Vector2) -> void:
	# Build a minimal EnemyBase-compatible CharacterBody2D in code.
	# Because EnemyGrunt requires a scene file, we construct a raw node
	# that mimics the grunt using EnemyBase's script directly.
	var grunt: CharacterBody2D = CharacterBody2D.new()
	grunt.name = "MiniGrunt"

	# Visual body
	var poly := Polygon2D.new()
	poly.polygon = PackedVector2Array([
		Vector2(-10.0, -8.0), Vector2(10.0, 0.0), Vector2(-10.0, 8.0)
	])
	poly.color = Color(0.6, 0.8, 0.2)
	poly.scale = Vector2(0.6, 0.6)
	grunt.add_child(poly)

	# Collision
	var col := CollisionShape2D.new()
	var capsule := CapsuleShape2D.new()
	capsule.radius = 7.0
	capsule.height = 14.0
	col.shape = capsule
	grunt.add_child(col)

	grunt.collision_layer = 16   # enemies
	grunt.collision_mask = 4 | 1  # player_bullets | walls

	grunt.global_position = spawn_pos

	# Add to same parent as this enemy so it lives in the scene
	if get_parent():
		get_parent().add_child(grunt)
	else:
		get_tree().current_scene.add_child(grunt)

	# Attach a simple script via a Callable-driven approach using a script resource.
	# Since we cannot attach class-based scripts in pure code without ResourceLoader,
	# drive the mini-grunt with a one-shot process connection.
	var speed: float = 180.0
	grunt.set_meta("speed", speed)
	grunt.set_meta("health", 10)
	grunt.set_meta("player_ref", player_ref)
	grunt.set_meta("bullet_container", bullet_container)

	# Use _process via a lambda stored on the node (Godot 4 supports this pattern)
	grunt.set_script(load("res://scenes/enemies/EnemyGrunt.gd"))

	# Inject dependencies expected by EnemyBase after script is set
	if grunt.has_method("_ready"):
		grunt.set("bullet_container", bullet_container)
		grunt.set("player_ref", player_ref)
