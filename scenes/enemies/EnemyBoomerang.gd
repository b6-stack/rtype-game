class_name EnemyBoomerang
extends EnemyBase

## Boomerang enemy — flies left past player, curves back right, returns, then exits.

enum State { FLY_LEFT, CURVE, RETURN }

var _state: State = State.FLY_LEFT
var _curve_timer: float = 0.0
var _current_angle: float = PI  # starts pointing left (180 deg)
const CURVE_DURATION: float = 1.5
const FLY_SPEED: float = 300.0
const PASS_X: float = 400.0  # X threshold to trigger curve


func _ready() -> void:
	max_health = 30
	current_health = 30
	move_speed = FLY_SPEED
	score_value = 220
	shoot_cooldown = 1.8
	bullet_color = Color(0.0, 0.8, 1.0)
	bullet_speed = 350.0
	bullet_damage = 1
	enemy_color = Color(0.0, 0.6, 0.9)
	size_scale = 1.0
	super._ready()
	_current_angle = PI


func _move(delta: float) -> void:
	match _state:
		State.FLY_LEFT:
			velocity = Vector2(-FLY_SPEED, 0.0)
			if global_position.x <= PASS_X:
				_state = State.CURVE
				_curve_timer = 0.0
				_current_angle = PI  # Pointing left at start of curve

		State.CURVE:
			_curve_timer += delta
			var t: float = clamp(_curve_timer / CURVE_DURATION, 0.0, 1.0)
			# Interpolate angle from PI (left) to 0 (right)
			_current_angle = lerp(PI, 0.0, t)
			var dir := Vector2(cos(_current_angle), sin(_current_angle))
			velocity = dir * FLY_SPEED
			if _curve_timer >= CURVE_DURATION:
				_state = State.RETURN

		State.RETURN:
			velocity = Vector2(FLY_SPEED * 1.2, 0.0)
			# Self-destroy when off the right edge of the viewport
			if global_position.x > 2100.0:
				queue_free()


func _shoot() -> void:
	# Fire at a slight curve — angle bullet offset from straight left
	var shoot_angle: float = PI + deg_to_rad(15.0 if _state == State.FLY_LEFT else -15.0)
	var dir := Vector2(cos(shoot_angle), sin(shoot_angle))
	_spawn_enemy_bullet(dir * bullet_speed)
