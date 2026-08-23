class_name EnemyBomber
extends EnemyBase

## Bomber enemy — flies slowly left, periodically drops proximity mines that scroll with the world.

const MINE_DAMAGE: int = 2
const SCROLL_SPEED: float = 180.0

func _ready() -> void:
	max_health = 40
	current_health = 40
	move_speed = 130.0
	score_value = 280
	shoot_cooldown = 2.4
	bullet_color = Color(1.0, 0.5, 0.0)
	bullet_speed = 0.0
	bullet_damage = MINE_DAMAGE
	enemy_color = Color(0.7, 0.4, 0.2)
	size_scale = 1.2
	super._ready()

func _move(_delta: float) -> void:
	velocity.x = -move_speed * 0.7
	velocity.y = 0.0

func _shoot() -> void:
	_drop_mine_deferred.call_deferred(global_position)

func _drop_mine_deferred(spawn_pos: Vector2) -> void:
	var container: Node = bullet_container if bullet_container else get_parent()
	if container == null:
		return

	var mine := Area2D.new()
	mine.name = "EnemyMine"

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 16.0
	shape.shape = circle
	mine.add_child(shape)

	var poly := Polygon2D.new()
	poly.polygon = PackedVector2Array([
		Vector2(0.0, -14.0),
		Vector2(14.0, 0.0),
		Vector2(0.0, 14.0),
		Vector2(-14.0, 0.0)
	])
	poly.color = Color(1.0, 0.5, 0.0)
	mine.add_child(poly)

	mine.collision_layer = 8
	mine.collision_mask = 2  # player layer
	container.add_child(mine)
	mine.global_position = spawn_pos

	mine.body_entered.connect(func(body: Node):
		if body.is_in_group("player") or body is Player:
			if body.has_method("_take_hit"):
				body._take_hit("projectile")
			mine.queue_free()
	)

	# Scroll mine with terrain
	var scroll_tween := mine.create_tween()
	scroll_tween.tween_property(mine, "global_position:x", spawn_pos.x - SCROLL_SPEED * 4.0, 4.0)

	var timer := Timer.new()
	timer.wait_time = 4.0
	timer.one_shot = true
	mine.add_child(timer)
	timer.timeout.connect(mine.queue_free)
	timer.start()
