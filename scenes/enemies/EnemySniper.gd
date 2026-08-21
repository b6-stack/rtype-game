class_name EnemySniper
extends EnemyBase

## Sniper enemy — flies in, stops, aims precisely, fires one high-speed shot, exits left.

enum State { FLY_IN, STOP, FIRE, FLY_OUT }

var _state: State = State.FLY_IN
var _stop_timer: float = 0.0
const STOP_X: float = 1300.0
const HOLD_DURATION: float = 1.5
var _fired: bool = false


func _ready() -> void:
	max_health = 25
	current_health = 25
	move_speed = 220.0
	score_value = 250
	shoot_cooldown = 999.0  # Manually controlled
	bullet_color = Color(1.0, 0.0, 0.2)
	bullet_speed = 700.0
	bullet_damage = 2
	enemy_color = Color(0.2, 0.6, 1.0)
	size_scale = 1.0
	super._ready()


func _move(delta: float) -> void:
	match _state:
		State.FLY_IN:
			velocity.x = -move_speed
			velocity.y = 0.0
			if global_position.x <= STOP_X:
				velocity = Vector2.ZERO
				_state = State.STOP
				_stop_timer = 0.0
				_fired = false

		State.STOP:
			velocity = Vector2.ZERO
			_stop_timer += delta
			if _stop_timer >= HOLD_DURATION and not _fired:
				_state = State.FIRE

		State.FIRE:
			velocity = Vector2.ZERO
			if not _fired:
				_fired = true
				_fire_at_player()
				_state = State.FLY_OUT

		State.FLY_OUT:
			velocity.x = -move_speed * 1.5
			velocity.y = 0.0


func _shoot() -> void:
	pass  # Shooting handled manually in _move
