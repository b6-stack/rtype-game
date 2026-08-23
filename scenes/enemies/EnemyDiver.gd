class_name EnemyDiver
extends EnemyBase

## Diver enemy — approaches player Y, dives fast downward, then flees left.
## Fires a burst of 3 shots during the dive.

enum State { APPROACH, DIVE, FLEE }

var _state: State = State.APPROACH
var _dive_timer: float = 0.0
var _burst_count: int = 0
var _burst_timer: float = 0.0
const DIVE_DURATION: float = 0.6
const DIVE_SPEED: float = 500.0
const BURST_INTERVAL: float = 0.12


func _ready() -> void:
	max_health = 15
	current_health = 15
	move_speed = 200.0
	score_value = 200
	shoot_cooldown = 999.0  # Manual burst control
	bullet_color = Color(1.0, 0.6, 0.1)
	bullet_speed = 400.0
	bullet_damage = 1
	enemy_color = Color(0.8, 0.3, 0.8)
	size_scale = 1.1
	super._ready()


func _move(delta: float) -> void:
	if _state == State.APPROACH and _should_disengage():
		_state = State.FLEE

	match _state:
		State.APPROACH:
			velocity.x = -move_speed
			if player_ref:
				var target_y: float = player_ref.global_position.y
				var diff_y: float = target_y - global_position.y
				velocity.y = clamp(diff_y * 4.0, -move_speed, move_speed)
			else:
				velocity.y = 0.0
			if global_position.x < 1600.0:
				if player_ref and abs(global_position.y - player_ref.global_position.y) < 60.0:
					_state = State.DIVE
					_dive_timer = 0.0
					_burst_count = 0
					_burst_timer = 0.0

		State.DIVE:
			velocity.x = -move_speed * 0.3
			velocity.y = DIVE_SPEED
			_burst_timer -= delta
			if _burst_count < 3 and _burst_timer <= 0.0:
				var dir := Vector2(-0.5, 0.5).normalized()
				_spawn_enemy_bullet(dir * bullet_speed)
				_burst_count += 1
				_burst_timer = BURST_INTERVAL
			_dive_timer += delta
			if _dive_timer >= DIVE_DURATION:
				_state = State.FLEE

		State.FLEE:
			velocity.x = -move_speed * 2.5
			velocity.y = 0.0


func _shoot() -> void:
	pass  # Shooting handled manually in _move
