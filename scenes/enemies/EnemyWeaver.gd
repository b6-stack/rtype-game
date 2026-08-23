class_name EnemyWeaver
extends EnemyBase

## Weaver enemy — flies left in a sine-wave pattern, fires toward the player.


func _ready() -> void:
	max_health = 12
	current_health = 12
	move_speed = 160.0
	score_value = 150
	shoot_cooldown = 2.2
	bullet_color = Color(0.8, 1.0, 0.2)
	bullet_speed = 380.0
	bullet_damage = 1
	enemy_color = Color(0.3, 0.9, 0.4)
	size_scale = 1.0
	super._ready()


func _move(_delta: float) -> void:
	velocity.x = -move_speed
	velocity.y = sin(_time * 3.0) * 120.0


func _shoot() -> void:
	_fire_at_player()
