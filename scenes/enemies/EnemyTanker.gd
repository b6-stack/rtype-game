class_name EnemyTanker
extends EnemyBase

## Tanker enemy — very high HP, slow, fires heavy oversized slow bullets.


func _ready() -> void:
	max_health = 200
	current_health = 200
	move_speed = 80.0
	score_value = 500
	shoot_cooldown = 3.0
	bullet_color = Color(0.8, 0.0, 0.0)
	bullet_speed = 200.0
	bullet_damage = 2
	enemy_color = Color(0.4, 0.2, 0.2)
	size_scale = 1.8
	super._ready()


func _move(_delta: float) -> void:
	velocity = Vector2(-move_speed * 0.3, 0.0)


func _shoot() -> void:
	# Fire a heavy bullet — spawn it and scale it up 2.5x after creation
	_fire_at_player()
	# Scale the most-recently-added child of bullet_container (the bullet just spawned)
	if bullet_container and bullet_container.get_child_count() > 0:
		var last: Node = bullet_container.get_child(bullet_container.get_child_count() - 1)
		if last is Node2D:
			last.scale = Vector2(2.5, 2.5)
