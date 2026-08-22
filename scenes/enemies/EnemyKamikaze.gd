class_name EnemyKamikaze
extends EnemyBase

## Kamikaze enemy — bee-lines straight at player at high speed. Explodes on collision or death.

var _explosion_triggered: bool = false

func _ready() -> void:
	max_health = 15
	current_health = 15
	move_speed = 340.0
	score_value = 150
	shoot_cooldown = 999.0
	enemy_color = Color(1.0, 0.2, 0.1)
	size_scale = 0.85
	super._ready()

func _move(_delta: float) -> void:
	if player_ref and is_instance_valid(player_ref):
		velocity = get_player_direction() * move_speed * 1.8
	else:
		velocity = Vector2(-move_speed * 1.8, 0.0)

func _shoot() -> void:
	pass

func _on_body_entered(body: Node) -> void:
	if body == player_ref or body.is_in_group("player"):
		if body.has_method("_take_hit"):
			body._take_hit("enemy")
		_explode()

func _explode() -> void:
	if _explosion_triggered:
		return
	_explosion_triggered = true
	_spawn_death_flash()
	queue_free()

func _die() -> void:
	_explode()
