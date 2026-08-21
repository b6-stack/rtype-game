class_name EnemyCloaker
extends EnemyBase

## Cloaker enemy — periodically turns invisible. Fires surprise shots only while invisible.

const VISIBLE_DURATION: float = 2.0
const CLOAKED_DURATION: float = 1.0

var _cloak_timer: float = 0.0
var _is_cloaked: bool = false


func _ready() -> void:
	max_health = 30
	current_health = 30
	move_speed = 170.0
	score_value = 300
	shoot_cooldown = 999.0  # Manual fire control
	bullet_color = Color(0.5, 0.0, 1.0)
	bullet_speed = 420.0
	bullet_damage = 1
	enemy_color = Color(0.4, 0.0, 0.8)
	size_scale = 1.0
	super._ready()
	_cloak_timer = VISIBLE_DURATION


func _process(delta: float) -> void:
	_cloak_timer -= delta
	if _cloak_timer <= 0.0:
		if _is_cloaked:
			# Become visible again
			_is_cloaked = false
			modulate.a = 1.0
			_cloak_timer = VISIBLE_DURATION
		else:
			# Cloak
			_is_cloaked = true
			modulate.a = 0.1
			_cloak_timer = CLOAKED_DURATION
			# Fire surprise shot when going invisible
			_fire_at_player()


func _move(_delta: float) -> void:
	velocity = Vector2(-move_speed, 0.0)


func _shoot() -> void:
	# Only fires via the cloak cycle above
	pass
