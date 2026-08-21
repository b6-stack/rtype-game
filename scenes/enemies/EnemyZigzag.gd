class_name EnemyZigzag
extends EnemyBase

## Zigzag enemy — no shooting, changes direction randomly every 0.5-1.0s, tries to ram player.

var _dir_timer: float = 0.0
var _current_dir: Vector2 = Vector2.LEFT
const MAX_DEVIATION_DEG: float = 50.0


func _ready() -> void:
	max_health = 20
	current_health = 20
	move_speed = 260.0
	score_value = 120
	shoot_cooldown = 999.0
	enemy_color = Color(0.9, 0.9, 0.1)
	size_scale = 0.85
	super._ready()
	_pick_new_direction()


func _move(delta: float) -> void:
	_dir_timer -= delta
	if _dir_timer <= 0.0:
		_pick_new_direction()
	velocity = _current_dir * move_speed


func _shoot() -> void:
	pass


func _pick_new_direction() -> void:
	_dir_timer = randf_range(0.5, 1.0)
	var base_dir: Vector2 = Vector2.LEFT
	if player_ref:
		base_dir = get_player_direction()
	var deviation: float = deg_to_rad(randf_range(-MAX_DEVIATION_DEG, MAX_DEVIATION_DEG))
	_current_dir = base_dir.rotated(deviation).normalized()
