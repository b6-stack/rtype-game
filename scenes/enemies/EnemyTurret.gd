class_name EnemyTurret
extends EnemyBase

## Turret enemy — enters from right, settles on the scrolling terrain, tracks and fires at player.

var _settled: bool = false
var _barrel: Polygon2D
const SCROLL_SPEED: float = 180.0

func _ready() -> void:
	max_health = 50
	current_health = 50
	move_speed = 220.0
	score_value = 300
	shoot_cooldown = 0.9
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
		# Scroll with the level terrain
		velocity.x = -SCROLL_SPEED
		velocity.y = 0.0
	else:
		velocity.x = -move_speed
		velocity.y = 0.0
		if global_position.x <= 1650.0:
			_settled = true

	# Rotate barrel to aim at player each frame
	if player_ref and _barrel:
		var aim_dir: Vector2 = (player_ref.global_position - global_position).normalized()
		_barrel.rotation = aim_dir.angle()

func _shoot() -> void:
	if _settled:
		_fire_at_player()
