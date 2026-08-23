class_name EnemyShield
extends EnemyBase

## Shield enemy — slow, frontal shield blocks incoming fire from the right. No shooting.

var _shield_poly: Polygon2D
var _shield_area: Area2D


func _ready() -> void:
	max_health = 50
	current_health = 50
	move_speed = 120.0
	score_value = 350
	shoot_cooldown = 999.0
	enemy_color = Color(0.3, 0.5, 0.9)
	size_scale = 1.2
	super._ready()

	_shield_area = Area2D.new()
	_shield_area.name = "ShieldArea"

	var shield_col := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(18.0, 50.0)
	shield_col.shape = rect
	shield_col.position = Vector2(30.0, 0.0)
	_shield_area.add_child(shield_col)

	_shield_poly = Polygon2D.new()
	_shield_poly.polygon = PackedVector2Array([
		Vector2(20.0, -28.0),
		Vector2(38.0, -18.0),
		Vector2(38.0, 18.0),
		Vector2(20.0, 28.0),
	])
	_shield_poly.color = Color(0.5, 0.7, 1.0, 0.75)
	_shield_area.add_child(_shield_poly)

	_shield_area.collision_layer = 8
	_shield_area.collision_mask = 4  # player_bullets
	_shield_area.add_to_group("enemy_shield")
	add_child(_shield_area)
	_shield_area.area_entered.connect(_on_shield_hit)


func _move(_delta: float) -> void:
	velocity = Vector2(-move_speed * 0.5, 0.0)


func _shoot() -> void:
	pass


## Override take_damage: damage from right side (shield facing) is blocked by shield area.
## The _on_shield_hit handler deflects/destroys bullets directly.
func take_damage(amount: int) -> void:
	super.take_damage(amount)


func _on_shield_hit(area: Area2D) -> void:
	# Deflect or destroy the bullet that entered the shield. `area` is the
	# Bullet itself (Bullet extends Area2D directly) — NOT a child needing
	# get_parent(). The previous version called area.get_parent(), which is
	# the shared PlayerBullets container, and queue_free()'d THAT on every
	# shield hit — destroying every in-flight player bullet and leaving the
	# container permanently broken for the rest of the run.
	if area is Bullet:
		area.velocity.x = absf(area.velocity.x)
	elif is_instance_valid(area):
		area.queue_free()
