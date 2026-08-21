class_name EnemyFormation
extends EnemyBase

## Formation enemy — leads 2 companion polygon nodes in a V-formation.
## All three fire simultaneously on _shoot.

const COMPANION_OFFSETS: Array = [Vector2(-30.0, -40.0), Vector2(-30.0, 40.0)]
const COMPANION_COLOR: Color = Color(0.2, 0.7, 0.5)
const BOB_AMPLITUDE: float = 18.0
const BOB_SPEED: float = 2.0

var _companions: Array[Polygon2D] = []


func _ready() -> void:
	max_health = 25
	current_health = 25
	move_speed = 170.0
	score_value = 180
	shoot_cooldown = 1.6
	bullet_color = Color(0.1, 0.9, 0.5)
	bullet_speed = 370.0
	bullet_damage = 1
	enemy_color = Color(0.2, 0.8, 0.5)
	size_scale = 1.0
	super._ready()

	# Build companion visual nodes as children
	for offset in COMPANION_OFFSETS:
		var comp := Polygon2D.new()
		comp.polygon = PackedVector2Array([
			Vector2(-12.0, -8.0), Vector2(12.0, 0.0), Vector2(-12.0, 8.0)
		])
		comp.color = COMPANION_COLOR
		comp.position = offset
		add_child(comp)
		_companions.append(comp)


func _move(delta: float) -> void:
	# Lead flies left with a gentle vertical sine bob
	velocity.x = -move_speed
	velocity.y = sin(_time * BOB_SPEED) * BOB_AMPLITUDE


func _shoot() -> void:
	# Leader fires
	_fire_at_player()
	# Each companion fires from its world position
	for comp in _companions:
		var world_pos: Vector2 = global_position + comp.position
		_spawn_bullet_at_position(world_pos)


func _spawn_bullet_at_position(spawn_pos: Vector2) -> void:
	var original_pos: Vector2 = global_position
	global_position = spawn_pos
	_fire_at_player()
	global_position = original_pos
