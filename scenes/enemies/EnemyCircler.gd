class_name EnemyCircler
extends EnemyBase

## Circler enemy — orbits a fixed point offset from spawn. Fires 3-way shot.

const ORBIT_RADIUS: float = 120.0
const ORBIT_SPEED: float = 2.5

var _center_point: Vector2
var _orbit_initialized: bool = false


func _ready() -> void:
	max_health = 30
	current_health = 30
	move_speed = 200.0
	score_value = 250
	shoot_cooldown = 1.5
	bullet_color = Color(0.0, 1.0, 0.8)
	bullet_speed = 360.0
	bullet_damage = 1
	enemy_color = Color(0.1, 0.8, 0.8)
	size_scale = 1.0
	super._ready()


func _move(delta: float) -> void:
	if not _orbit_initialized:
		_center_point = _spawn_position + Vector2(-300.0, 0.0)
		_orbit_initialized = true

	# Calculate target orbit position from elapsed time
	var target_pos: Vector2 = _center_point + Vector2(
		cos(_time * ORBIT_SPEED) * ORBIT_RADIUS,
		sin(_time * ORBIT_SPEED) * ORBIT_RADIUS
	)
	# Drive velocity to reach orbit position each frame
	velocity = (target_pos - global_position) / delta


func _shoot() -> void:
	# 3-way: left, up-left (45 deg), down-left (45 deg)
	var dirs: Array[Vector2] = [
		Vector2.LEFT,
		Vector2(-0.707, -0.707),
		Vector2(-0.707, 0.707)
	]
	for dir in dirs:
		_spawn_enemy_bullet(dir * bullet_speed)
