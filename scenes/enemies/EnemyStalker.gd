class_name EnemyStalker
extends EnemyBase

## Stalker enemy — mirrors player Y via lerp, fires a side-by-side double shot.

const LERP_RATE: float = 2.0
const SHOT_OFFSET: float = 12.0


func _ready() -> void:
	max_health = 35
	current_health = 35
	move_speed = 150.0
	score_value = 220
	shoot_cooldown = 1.8
	bullet_color = Color(0.6, 0.2, 1.0)
	bullet_speed = 400.0
	bullet_damage = 1
	enemy_color = Color(0.5, 0.1, 0.8)
	size_scale = 1.0
	super._ready()


func _move(delta: float) -> void:
	velocity.x = -move_speed * 0.5
	velocity.y = 0.0
	if player_ref:
		var target_y: float = player_ref.global_position.y
		global_position.y = lerp(global_position.y, target_y, LERP_RATE * delta)


func _shoot() -> void:
	var dir: Vector2 = Vector2.LEFT
	if player_ref:
		dir = get_player_direction()
	var vel: Vector2 = dir * bullet_speed
	var perp: Vector2 = Vector2(-dir.y, dir.x).normalized() * SHOT_OFFSET
	_spawn_bullet_at(global_position + perp, vel)
	_spawn_bullet_at(global_position - perp, vel)


func _spawn_bullet_at(spawn_pos: Vector2, vel: Vector2) -> void:
	var original_pos: Vector2 = global_position
	global_position = spawn_pos
	_spawn_enemy_bullet(vel)
	global_position = original_pos
