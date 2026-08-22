class_name EnemyLeech
extends EnemyBase

## Leech enemy — moves to nearest wall (top/bottom), latches on, scrolls with world and fires at player.

enum State { SEEK_WALL, LATCHED }

var _state: State = State.SEEK_WALL
var _wall_y: float = 0.0
const LATCH_THRESHOLD: float = 12.0
const VIEWPORT_HEIGHT: float = 1080.0
const SCROLL_SPEED: float = 180.0

func _ready() -> void:
	max_health = 35
	current_health = 35
	move_speed = 140.0
	score_value = 200
	shoot_cooldown = 1.4
	bullet_color = Color(0.5, 1.0, 0.2)
	bullet_speed = 380.0
	bullet_damage = 1
	enemy_color = Color(0.2, 0.6, 0.1)
	size_scale = 1.2
	super._ready()

	# Determine nearest wall at spawn
	var dist_top: float = global_position.y
	var dist_bottom: float = VIEWPORT_HEIGHT - global_position.y
	_wall_y = 35.0 if dist_top < dist_bottom else VIEWPORT_HEIGHT - 35.0

func _move(_delta: float) -> void:
	match _state:
		State.SEEK_WALL:
			velocity.x = -move_speed
			var diff_y: float = _wall_y - global_position.y
			velocity.y = clamp(diff_y * 6.0, -move_speed, move_speed)
			if abs(diff_y) < LATCH_THRESHOLD:
				_state = State.LATCHED
				global_position.y = _wall_y
				velocity.x = -SCROLL_SPEED
				velocity.y = 0.0

		State.LATCHED:
			# Scroll left naturally with the world terrain
			velocity.x = -SCROLL_SPEED
			velocity.y = 0.0

func _shoot() -> void:
	_fire_at_player()
