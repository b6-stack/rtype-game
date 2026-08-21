class_name BossSwarmQueen
extends BossBase

## Swarm Queen Boss
## Phase 0: spawns grunt enemies every 3s + fires 3-way shot.
## Phase 1: spawns grunts every 1.5s + fires 5-way shot.

const GRUNT_SPEED: float = -240.0
const GRUNT_HP: int = 15
const GRUNT_RADIUS: float = 10.0

var _spawn_timer: float = 0.0
var _fire_timer: float = 0.0
var _grunt_count: int = 0

var _patrol_dir: int = 1
const PATROL_SPEED: float = 90.0
const PATROL_RANGE: float = 260.0


func _ready() -> void:
	boss_name = "Swarm Queen"
	max_health = 900
	phase_count = 2
	boss_color = Color(0.6, 0.1, 0.7, 1.0)
	size_scale = 1.0
	entry_speed = 180.0
	score_value = 6000

	super._ready()


func _phase_attack(delta: float) -> void:
	_patrol(delta)

	var spawn_rate: float = 3.0 if current_phase == 0 else 1.5
	var fire_rate: float = 2.0 if current_phase == 0 else 1.2
	var spread_count: int = 3 if current_phase == 0 else 5

	_spawn_timer += delta
	if _spawn_timer >= spawn_rate:
		_spawn_timer = 0.0
		_spawn_grunt()

	_fire_timer += delta
	if _fire_timer >= fire_rate:
		_fire_timer = 0.0
		_fire_spread(spread_count)


func _patrol(delta: float) -> void:
	var center_y: float = 540.0
	if position.y > center_y + PATROL_RANGE:
		_patrol_dir = -1
	elif position.y < center_y - PATROL_RANGE:
		_patrol_dir = 1
	velocity.y = _patrol_dir * PATROL_SPEED
	velocity.x = 0.0
	move_and_slide()


func _spawn_grunt() -> void:
	if bullet_container == null:
		return

	_grunt_count += 1
	var grunt: CharacterBody2D = CharacterBody2D.new()
	grunt.name = "SpawnedGrunt%d" % _grunt_count

	# Collision
	grunt.collision_layer = 16  # enemies
	grunt.collision_mask = 4    # player_bullets

	var col: CollisionShape2D = CollisionShape2D.new()
	var shape: CircleShape2D = CircleShape2D.new()
	shape.radius = GRUNT_RADIUS
	col.shape = shape
	grunt.add_child(col)

	# Visual
	var poly: Polygon2D = Polygon2D.new()
	poly.polygon = _build_diamond(GRUNT_RADIUS)
	poly.color = Color(0.8, 0.2, 0.9, 1.0)
	grunt.add_child(poly)

	# Health tracker via meta
	grunt.set_meta("hp", GRUNT_HP)

	# Spawn near boss with vertical spread
	var spawn_offset: float = randf_range(-60.0, 60.0)
	grunt.global_position = global_position + Vector2(-30.0, spawn_offset)

	# Script inline via movement handled by parent process
	var script: GDScript = GDScript.new()
	script.source_code = """
extends CharacterBody2D
var speed: float = -240.0
func _physics_process(delta):
	velocity.x = speed
	move_and_slide()
	if global_position.x < -100.0:
		queue_free()
"""
	grunt.set_script(script)

	bullet_container.add_child(grunt)


func _build_diamond(r: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(0, -r),
		Vector2(r, 0),
		Vector2(0, r),
		Vector2(-r, 0),
	])


func _fire_spread(count: int) -> void:
	var base_dir: Vector2 = get_player_direction()
	var base_angle: float = base_dir.angle()
	var total_spread: float = deg_to_rad(float(count - 1) * 14.0)
	var step: float = total_spread / max(count - 1, 1)

	for i: int in range(count):
		var a: float = base_angle - total_spread * 0.5 + step * i
		var vel: Vector2 = Vector2.from_angle(a) * 480.0
		_spawn_boss_bullet(vel, Color(0.8, 0.3, 1.0, 1.0), 12)


func _on_phase_change(new_phase: int) -> void:
	match new_phase:
		1:
			_spawn_timer = 0.0
			_fire_timer = 0.0
