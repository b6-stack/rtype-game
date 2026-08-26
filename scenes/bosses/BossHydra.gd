class_name BossHydra
extends BossBase

## Hydra Boss
## Has 3 heads as child Area2D nodes, each with own HP.
## Phase 0: all heads fire. Phase 1: 2 heads. Phase 2: 1 head + boss fires more.
## Phase 3 (core): fires radial 8-shot pattern.

const HEAD_MAX_HP: int = 200
const HEAD_FIRE_RATE: float = 2.2
const HEAD_OFFSETS: Array[Vector2] = [
	Vector2(-60, -80),
	Vector2(0, -100),
	Vector2(60, -80),
]

class HydraHead:
	var node: Area2D
	var hp: int = 200
	var fire_timer: float = 0.0
	var alive: bool = true
	var visual: Polygon2D

var _heads: Array[HydraHead] = []
var _radial_timer: float = 0.0
var _patrol_dir: int = 1
const PATROL_SPEED: float = 100.0
const PATROL_RANGE: float = 200.0

## The phase-3 radial (all heads gone, boss desperate) is a full 360
## spread — reserves a shifting safe lane the same way Dread Star/Photon
## Core/Hyperion do, so the player isn't trapped by it.
const SAFE_LANE_HALF_WIDTH_RAD: float = 0.3927  # 22.5 degrees
const SAFE_LANE_SWEEP_AMPLITUDE_RAD: float = 0.6109  # 35 degrees
const SAFE_LANE_SWEEP_PERIOD: float = 4.5

func _safe_lane_center_angle() -> float:
	return PI + sin(_time * TAU / SAFE_LANE_SWEEP_PERIOD) * SAFE_LANE_SWEEP_AMPLITUDE_RAD

func _in_safe_lane(dir: Vector2) -> bool:
	var diff: float = wrapf(dir.angle() - _safe_lane_center_angle(), -PI, PI)
	return absf(diff) < SAFE_LANE_HALF_WIDTH_RAD

func _fire_radial_avoiding_safe_lane(count: int, speed: float, dmg: int, col: Color, angle_offset_deg: float) -> void:
	for i in count:
		var angle: float = TAU / float(count) * i + deg_to_rad(angle_offset_deg)
		var dir: Vector2 = Vector2.RIGHT.rotated(angle)
		if _in_safe_lane(dir):
			continue
		_spawn_boss_bullet(dir * speed, col, dmg)


func _ready() -> void:
	boss_name = "Hydra"
	max_health = 1850
	phase_count = 3
	boss_color = Color(0.1, 0.8, 0.3, 1.0)
	size_scale = 1.2
	entry_speed = 180.0
	score_value = 8000

	super._ready()
	_create_heads()


func _create_heads() -> void:
	for i: int in range(3):
		var head_data: HydraHead = HydraHead.new()
		head_data.hp = HEAD_MAX_HP

		var area: Area2D = Area2D.new()
		area.name = "Head%d" % i
		area.position = HEAD_OFFSETS[i]
		area.collision_layer = 0
		area.collision_mask = 4  # player bullets
		# Hidden and non-interactive until the boss actually arrives —
		# otherwise heads were fully visible/hittable during the whole
		# entry glide despite the rest of the boss being intangible.
		area.visible = false
		area.monitoring = false

		var col: CollisionShape2D = CollisionShape2D.new()
		var shape: CircleShape2D = CircleShape2D.new()
		shape.radius = 28.0
		col.shape = shape
		area.add_child(col)

		# Visual
		var poly: Polygon2D = Polygon2D.new()
		poly.polygon = _build_hexagon(26.0)
		poly.color = Color(0.2, 0.9, 0.4, 1.0)
		area.add_child(poly)
		head_data.visual = poly

		# Connect bullet hit signal (Area2D area_entered)
		area.area_entered.connect(_on_head_hit.bind(i))

		add_child(area)
		head_data.node = area
		_heads.append(head_data)


func _on_entrance_ready() -> void:
	for head: HydraHead in _heads:
		if head.alive:
			head.node.visible = true
			head.node.monitoring = true


func _build_hexagon(radius: float) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	for i: int in range(6):
		var a: float = deg_to_rad(60.0 * i)
		pts.append(Vector2(cos(a) * radius, sin(a) * radius))
	return pts


func _on_head_hit(area: Area2D, head_index: int) -> void:
	if head_index < 0 or head_index >= _heads.size():
		return
	var head: HydraHead = _heads[head_index]
	if not head.alive:
		return
	# Bullet damage — use 15 as default hit damage
	head.hp -= 15
	if head.hp <= 0:
		_destroy_head(head_index)


func _destroy_head(index: int) -> void:
	var head: HydraHead = _heads[index]
	if not head.alive:
		return
	head.alive = false
	head.node.hide()
	head.node.set_process(false)

	# Count living heads and update phase
	var alive_count: int = 0
	for h: HydraHead in _heads:
		if h.alive:
			alive_count += 1

	match alive_count:
		2:
			if current_phase < 1:
				current_health = int(max_health * 0.66)
		1:
			if current_phase < 2:
				current_health = int(max_health * 0.33)
		0:
			current_health = 0


func _phase_attack(delta: float) -> void:
	_patrol(delta)
	_update_heads(delta)

	if current_phase == 3:
		_radial_timer += delta
		if _radial_timer >= 1.5:
			_radial_timer = 0.0
			_fire_radial_avoiding_safe_lane(8, 480.0, 14, Color(0.1, 1.0, 0.4, 1.0), _time * 30.0)


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


func _update_heads(delta: float) -> void:
	for i: int in range(_heads.size()):
		var head: HydraHead = _heads[i]
		if not head.alive:
			continue
		# Only fire if head's phase index is active
		if i > current_phase:
			continue
		head.fire_timer += delta
		if head.fire_timer >= HEAD_FIRE_RATE:
			head.fire_timer = 0.0
			_fire_from_head(i)


func _fire_from_head(index: int) -> void:
	if player_ref == null:
		return
	var head: HydraHead = _heads[index]
	var world_pos: Vector2 = global_position + head.node.position
	var dir: Vector2 = (player_ref.global_position - world_pos).normalized()
	var vel: Vector2 = dir * 450.0
	_spawn_boss_bullet(vel, Color(0.1, 0.9, 0.3, 1.0), 12)


func _on_phase_change(new_phase: int) -> void:
	match new_phase:
		1:
			# Destroy the third head visually
			if _heads.size() > 2 and _heads[2].alive:
				_destroy_head(2)
		2:
			if _heads.size() > 1 and _heads[1].alive:
				_destroy_head(1)
		3:
			if _heads.size() > 0 and _heads[0].alive:
				_destroy_head(0)
