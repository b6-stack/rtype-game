class_name EnemyBomber
extends EnemyBase

## Bomber enemy — flies slowly left, periodically drops proximity mines.

const MINE_DAMAGE: int = 2


func _ready() -> void:
	max_health = 40
	current_health = 40
	move_speed = 130.0
	score_value = 280
	shoot_cooldown = 2.0
	bullet_color = Color(1.0, 0.5, 0.0)
	bullet_speed = 0.0
	bullet_damage = MINE_DAMAGE
	enemy_color = Color(0.7, 0.4, 0.2)
	size_scale = 1.2
	super._ready()


func _move(_delta: float) -> void:
	velocity.x = -move_speed * 0.6
	velocity.y = 0.0


func _shoot() -> void:
	_drop_mine()


func _drop_mine() -> void:
	var mine := Area2D.new()
	mine.name = "EnemyMine"

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 15.0
	shape.shape = circle
	mine.add_child(shape)

	var poly := Polygon2D.new()
	poly.polygon = PackedVector2Array([
		Vector2(0.0, -15.0),
		Vector2(15.0, 0.0),
		Vector2(0.0, 15.0),
		Vector2(-15.0, 0.0)
	])
	poly.color = Color(1.0, 0.5, 0.0)
	mine.add_child(poly)

	mine.collision_layer = 8
	mine.collision_mask = 2  # player layer
	mine.global_position = global_position

	if bullet_container:
		bullet_container.add_child(mine)
	else:
		get_tree().current_scene.add_child(mine)

	mine.body_entered.connect(_on_mine_hit.bind(mine))

	var timer := Timer.new()
	timer.wait_time = 3.0
	timer.one_shot = true
	mine.add_child(timer)
	timer.timeout.connect(mine.queue_free)
	timer.start()


func _on_mine_hit(body: Node, mine: Area2D) -> void:
	if body == player_ref:
		if body.has_method("take_damage"):
			body.take_damage(MINE_DAMAGE)
	mine.queue_free()
