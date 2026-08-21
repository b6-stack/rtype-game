class_name EnemyGrunt
extends EnemyBase

## Simple grunt enemy — flies straight left, fires a single shot left.


func _ready() -> void:
	max_health = 20
	current_health = 20
	move_speed = 180.0
	score_value = 100
	shoot_cooldown = 2.0
	bullet_color = Color(1.0, 0.4, 0.0)
	bullet_speed = 350.0
	bullet_damage = 1
	enemy_color = Color(0.6, 0.8, 0.2)
	size_scale = 1.0
	super._ready()


func _move(_delta: float) -> void:
	velocity = Vector2(-move_speed, 0.0)


func _shoot() -> void:
	_fire_direction(Vector2.LEFT)
