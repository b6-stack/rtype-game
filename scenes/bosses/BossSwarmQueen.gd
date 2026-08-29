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
	max_health = 1450
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


## Vertical-only patrol; horizontal drift comes from BossBase's default
## movement, set before _phase_attack() runs. Deliberately doesn't touch
## velocity.x, and doesn't call move_and_slide() itself — BossBase calls
## it once after _phase_attack() returns; calling it here too was
## double-applying movement every physics frame.
func _patrol(delta: float) -> void:
	var center_y: float = 540.0
	if position.y > center_y + PATROL_RANGE:
		_patrol_dir = -1
	elif position.y < center_y - PATROL_RANGE:
		_patrol_dir = 1
	velocity.y = _patrol_dir * PATROL_SPEED


func _spawn_grunt() -> void:
	if bullet_container == null:
		return

	var grunt_scene: PackedScene = preload("res://scenes/enemies/EnemyBase.tscn")
	var grunt: EnemyBase = grunt_scene.instantiate()
	grunt.set_script(load("res://scenes/enemies/EnemyGrunt.gd"))
	grunt.bullet_container = bullet_container
	grunt.player_ref = player_ref
	grunt.score_value = 0  # Boss minion: zero score to prevent score farming
	grunt.add_to_group("enemies")

	var parent_node: Node = get_parent() if get_parent() else bullet_container
	parent_node.add_child(grunt)
	grunt.global_position = global_position + Vector2(-40.0, randf_range(-70.0, 70.0))


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
