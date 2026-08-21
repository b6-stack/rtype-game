class_name BossSentinel
extends BossBase

## Sentinel Boss
## Has 6 rotating shield segments arranged in a ring at radius 120.
## Only vulnerable when the shield gap faces the player.
## Phase 0: slow rotation. Phase 1: faster + fires at player. Phase 2: gap flicker + 4-way cross.

const SHIELD_COUNT: int = 6
const SHIELD_RADIUS: float = 120.0
const GAP_ANGLE_DEG: float = 45.0  # gap width in degrees

var _shields: Array[Polygon2D] = []
var _shield_rotation: float = 0.0
var _fire_timer: float = 0.0
var _cross_timer: float = 0.0
var _gap_open: bool = true
var _gap_timer: float = 0.0

const GAP_FLICKER_RATE: float = 0.4

var _patrol_dir: int = 1
const PATROL_SPEED: float = 80.0
const PATROL_RANGE: float = 220.0


func _ready() -> void:
	boss_name = "Sentinel"
	max_health = 1000
	phase_count = 3
	boss_color = Color(0.4, 0.6, 0.8, 1.0)
	size_scale = 1.1
	entry_speed = 180.0
	score_value = 7000

	super._ready()
	_create_shields()


func _create_shields() -> void:
	# Each segment spans (360/SHIELD_COUNT - gap) degrees
	var segment_span: float = (360.0 / SHIELD_COUNT) - (GAP_ANGLE_DEG / SHIELD_COUNT)

	for i: int in range(SHIELD_COUNT):
		var poly: Polygon2D = Polygon2D.new()
		poly.polygon = _build_arc_segment(SHIELD_RADIUS, segment_span)
		poly.color = Color(0.4, 0.65, 0.9, 0.85)
		# Rotate each segment to its position in the ring
		poly.rotation_degrees = (360.0 / SHIELD_COUNT) * i
		add_child(poly)
		_shields.append(poly)


func _build_arc_segment(radius: float, span_deg: float) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	var inner_r: float = radius - 14.0
	var steps: int = 8
	var half: float = span_deg * 0.5

	for i: int in range(steps + 1):
		var a: float = deg_to_rad(-half + (span_deg / steps) * i)
		pts.append(Vector2(cos(a) * radius, sin(a) * radius))
	for i: int in range(steps + 1):
		var a: float = deg_to_rad(half - (span_deg / steps) * i)
		pts.append(Vector2(cos(a) * inner_r, sin(a) * inner_r))
	return pts


func _phase_attack(delta: float) -> void:
	_patrol(delta)
	_rotate_shields(delta)
	_handle_gap_flicker(delta)

	if current_phase >= 1:
		_fire_timer += delta
		var rate: float = 1.2 if current_phase == 1 else 0.8
		if _fire_timer >= rate:
			_fire_timer = 0.0
			_fire_at_player(480.0, 14, Color(0.4, 0.7, 1.0, 1.0))

	if current_phase == 2:
		_cross_timer += delta
		if _cross_timer >= 1.6:
			_cross_timer = 0.0
			_fire_cross()


func _patrol(delta: float) -> void:
	var center_y: float = 540.0
	if position.y > center_y + PATROL_RANGE:
		_patrol_dir = -1
	elif position.y < center_y - PATROL_RANGE:
		_patrol_dir = 1
	velocity.y = _patrol_dir * PATROL_SPEED
	velocity.x = 0.0
	move_and_slide()


func _rotate_shields(delta: float) -> void:
	var speed: float = 45.0  # degrees per second phase 0
	match current_phase:
		1:
			speed = 90.0
		2:
			speed = 150.0

	_shield_rotation += speed * delta
	if _shield_rotation > 360.0:
		_shield_rotation -= 360.0

	for i: int in range(_shields.size()):
		var base_angle: float = (360.0 / SHIELD_COUNT) * i
		_shields[i].rotation_degrees = base_angle + _shield_rotation
		_shields[i].visible = _gap_open


func _handle_gap_flicker(delta: float) -> void:
	if current_phase < 2:
		_gap_open = true
		return
	_gap_timer += delta
	if _gap_timer >= GAP_FLICKER_RATE:
		_gap_timer = 0.0
		_gap_open = !_gap_open


func _fire_cross() -> void:
	var directions: Array[Vector2] = [
		Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)
	]
	for dir: Vector2 in directions:
		_spawn_boss_bullet(dir * 500.0, Color(0.5, 0.8, 1.0, 1.0), 16)


func _on_phase_change(new_phase: int) -> void:
	match new_phase:
		1:
			for s: Polygon2D in _shields:
				s.color = Color(0.5, 0.75, 1.0, 0.9)
		2:
			for s: Polygon2D in _shields:
				s.color = Color(0.7, 0.9, 1.0, 1.0)
