class_name BossIronClaw
extends BossBase

## Iron Claw Boss
## Phase 0: Patrols up/down, fires at player every 1.5s.
## Phase 1 (<50% HP): Claws spin faster, fires 3-way spread every 1.0s.

# Patrol
const PATROL_SPEED: float = 120.0
const PATROL_RANGE: float = 250.0
var _patrol_dir: int = 1

# Claw nodes
var _claw_top: Polygon2D
var _claw_bottom: Polygon2D
var _claw_angle: float = 0.0

# Fire timing
var _fire_timer: float = 0.0


func _ready() -> void:
	boss_name = "Iron Claw"
	max_health = 800
	phase_count = 2
	boss_color = Color(0.6, 0.6, 0.65, 1.0)
	size_scale = 1.0
	entry_speed = 220.0
	score_value = 5000

	super._ready()
	_create_claws()


func _create_claws() -> void:
	# Build a simple claw polygon shape
	var claw_points: PackedVector2Array = PackedVector2Array([
		Vector2(-10, -5),
		Vector2(40, 0),
		Vector2(-10, 5),
		Vector2(20, 30),
		Vector2(-15, 25),
		Vector2(-10, 5),
	])

	_claw_top = Polygon2D.new()
	_claw_top.polygon = claw_points
	_claw_top.color = Color(0.5, 0.5, 0.6, 1.0)
	_claw_top.position = Vector2(0, -80)
	add_child(_claw_top)

	_claw_bottom = Polygon2D.new()
	_claw_bottom.polygon = claw_points
	_claw_bottom.color = Color(0.5, 0.5, 0.6, 1.0)
	_claw_bottom.position = Vector2(0, 80)
	_claw_bottom.scale = Vector2(1.0, -1.0)
	add_child(_claw_bottom)


func _phase_attack(delta: float) -> void:
	_patrol(delta)
	_rotate_claws(delta)

	var fire_rate: float = 1.5 if current_phase == 0 else 1.0
	_fire_timer += delta
	if _fire_timer >= fire_rate:
		_fire_timer = 0.0
		if current_phase == 0:
			_fire_at_player(500.0, 12, Color(1.0, 0.4, 0.2, 1.0))
		else:
			_fire_three_way_spread()


func _patrol(delta: float) -> void:
	var target_y: float = position.y + _patrol_dir * PATROL_SPEED * delta
	var center_y: float = 540.0
	if target_y > center_y + PATROL_RANGE:
		_patrol_dir = -1
	elif target_y < center_y - PATROL_RANGE:
		_patrol_dir = 1
	velocity.y = _patrol_dir * PATROL_SPEED
	velocity.x = 0.0
	move_and_slide()


func _rotate_claws(delta: float) -> void:
	var spin_speed: float = 90.0 if current_phase == 0 else 200.0
	_claw_angle += spin_speed * delta
	if _claw_angle > 360.0:
		_claw_angle -= 360.0
	_claw_top.rotation_degrees = _claw_angle
	_claw_bottom.rotation_degrees = -_claw_angle


func _fire_three_way_spread() -> void:
	var base_dir: Vector2 = get_player_direction()
	var angle: float = base_dir.angle()
	var spread: float = deg_to_rad(18.0)

	for i: int in range(-1, 2):
		var shot_angle: float = angle + i * spread
		var vel: Vector2 = Vector2.from_angle(shot_angle) * 520.0
		_spawn_boss_bullet(vel, Color(1.0, 0.3, 0.1, 1.0), 12)


func _on_phase_change(new_phase: int) -> void:
	match new_phase:
		1:
			# Increase patrol speed slightly for phase 1
			_patrol_dir = -_patrol_dir
