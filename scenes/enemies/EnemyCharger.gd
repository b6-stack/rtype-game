class_name EnemyCharger
extends EnemyBase

## Charger enemy — long slow approach then a sudden fast dash. Repeats. No bullets — rams player.

enum State { APPROACH, CHARGE }

var _state: State = State.APPROACH
var _charge_timer: float = 0.0
var _approach_timer: float = 0.0
const APPROACH_DURATION: float = 2.0
const CHARGE_DURATION: float = 0.4
const CHARGE_MULTIPLIER: float = 4.0


func _ready() -> void:
	max_health = 45
	current_health = 45
	move_speed = 100.0
	score_value = 280
	shoot_cooldown = 999.0
	enemy_color = Color(1.0, 0.3, 0.0)
	size_scale = 1.15
	super._ready()


func _move(delta: float) -> void:
	match _state:
		State.APPROACH:
			velocity.x = -move_speed
			velocity.y = 0.0
			_approach_timer += delta
			if _approach_timer >= APPROACH_DURATION:
				_approach_timer = 0.0
				_charge_timer = 0.0
				_state = State.CHARGE

		State.CHARGE:
			velocity.x = -move_speed * CHARGE_MULTIPLIER
			velocity.y = 0.0
			_charge_timer += delta
			if _charge_timer >= CHARGE_DURATION:
				_charge_timer = 0.0
				_approach_timer = 0.0
				_state = State.APPROACH


func _shoot() -> void:
	pass  # No bullets — contact damage via scene HurtBox or body_entered
