class_name EnemyTurret
extends EnemyBase

## Turret enemy — enters screen, stops at spawn X, rotates barrel to track player, fires rapidly.

var _settled: bool = false
var _barrel: Polygon2D


func _ready() -> void:
	max_health = 60
	current_health = 60
	move_speed = 160.0
	score_value = 300
	shoot_cooldown = 0.8
	bullet_color = Color(1.0, 0.2, 0.2)
	bullet_speed = 500.0
	bullet_damage = 1
	enemy_color = Color(0.5, 0.5, 0.6)
	size_scale = 1.2
	super._ready()

	# Build a barrel polygon to visualize aiming direction
	_barrel = Polygon2D.new()
	_barrel.polygon = PackedVector2Array([
		Vector2(0.0, -4.0), Vector2(28.0, -3.0), Vector2(28.0, 3.0), Vector2(0.0, 4.0)
	])
	_barrel.color = Color(0.3, 0.3, 0.4)
	add_child(_barrel)


func _move(_delta: float) -> void:
	if _settled:
		velocity = Vector2.ZERO
	else:
		velocity.x = -move_speed
		velocity.y = 0.0
		if global_position.x <= _spawn_position.x - 40.0:
			_settled = true
			velocity = Vector2.ZERO

	# Rotate barrel to aim at player each frame
	if player_ref and _barrel:
		var aim_dir: Vector2 = (player_ref.global_position - global_position).normalized()
		_barrel.rotation = aim_dir.angle()


func _shoot() -> void:
	if _settled:
		_fire_at_player()
