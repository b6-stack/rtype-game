class_name EnemySpreader
extends EnemyBase

## Spreader enemy — slow and tanky, fires a 5-way spread shot.

func _ready() -> void:
	max_health = 80
	current_health = 80
	move_speed = 100.0
	score_value = 400
	shoot_cooldown = 2.5
	bullet_color = Color(1.0, 0.8, 0.0)
	bullet_speed = 320.0
	bullet_damage = 1
	enemy_color = Color(0.9, 0.5, 0.1)
	size_scale = 1.4
	super._ready()

func _move(_delta: float) -> void:
	velocity = Vector2(-move_speed * 0.4, 0.0)

func _shoot() -> void:
	# 5-way spread: -60, -30, 0, +30, +60 degrees relative to left (180 deg)
	var base_angle: float = PI  # pointing left
	var spread_angles: Array = [-60.0, -30.0, 0.0, 30.0, 60.0]
	for deg in spread_angles:
		var rad: float = base_angle + deg_to_rad(float(deg))
		var dir := Vector2(cos(rad), sin(rad))
		_spawn_enemy_bullet(dir * bullet_speed)
