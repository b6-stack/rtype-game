class_name EnemyKamikaze
extends EnemyBase

## Kamikaze enemy — bee-lines straight at player at high speed. Explodes on collision.

var _explosion_triggered: bool = false


func _ready() -> void:
	max_health = 15
	current_health = 15
	move_speed = 380.0
	score_value = 150
	shoot_cooldown = 999.0
	enemy_color = Color(1.0, 0.2, 0.1)
	size_scale = 0.8
	super._ready()


func _move(_delta: float) -> void:
	if player_ref:
		velocity = get_player_direction() * move_speed * 2.0
	else:
		velocity = Vector2(-move_speed * 2.0, 0.0)


func _shoot() -> void:
	pass


## Called from body_entered signal — connect this in the scene or via EnemyBase hurt system.
func _on_body_entered(body: Node) -> void:
	if body == player_ref:
		if body.has_method("take_damage"):
			body.take_damage(3)
		_explode()


func _explode() -> void:
	if _explosion_triggered:
		return
	_explosion_triggered = true

	# Visual explosion: a brief expanding ColorRect
	var explosion := ColorRect.new()
	explosion.color = Color(1.0, 0.5, 0.0, 0.85)
	explosion.size = Vector2(60.0, 60.0)
	explosion.position = global_position - Vector2(30.0, 30.0)
	get_tree().current_scene.add_child(explosion)

	# Fade and remove explosion after 0.3 seconds
	var tween: Tween = get_tree().create_tween()
	tween.tween_property(explosion, "modulate:a", 0.0, 0.3)
	tween.tween_callback(explosion.queue_free)

	queue_free()


## Override _die so death also triggers explosion
func _die() -> void:
	_explode()
