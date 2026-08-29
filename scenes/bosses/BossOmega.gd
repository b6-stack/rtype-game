class_name BossOmega
extends BossBase

## Omega — Level 8 boss, 4 phases combining several previous patterns.
## (Hyperion Prime, Level 10, is the true final boss.)
## Phase 0: Spinning claw attack (IronClaw-style).
## Phase 1: Laser sweep (PhotonCore-style).
## Phase 2: Charge + spawn grunts (Behemoth+SwarmQueen-style).
## Phase 3: 12-way radial + teleport + gravity well at max intensity.

# ── Shared ────────────────────────────────────────────────────────────────────
var _patrol_dir: int = 1
const PATROL_SPEED: float = 100.0
const PATROL_RANGE: float = 230.0

## The dense phase 2/3 radials are exactly the "camp the safe spot" case
## — reserves a shifting safe lane the same way Dread Star/Photon Core/
## Hydra/Behemoth/Hyperion do.
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

# ── Phase 0 – Claw ────────────────────────────────────────────────────────────
var _claw_top: Polygon2D
var _claw_bottom: Polygon2D
var _claw_angle: float = 0.0
var _claw_fire_timer: float = 0.0

# ── Phase 1 – Laser Sweep ─────────────────────────────────────────────────────
var _sweep_timer: float = 0.0
var _sweep_bullet_accum: float = 0.0
const SWEEP_DURATION: float = 1.8
const SWEEP_BULLET_INTERVAL: float = 0.08

# ── Phase 2 – Charge + Grunts ─────────────────────────────────────────────────
enum ChargeState { IDLE, CHARGING, RECOVERING }
var _charge_state: ChargeState = ChargeState.IDLE
var _charge_state_timer: float = 0.0
var _home_x: float = 0.0
var _spawn_timer: float = 0.0
var _grunt_count: int = 0

# ── Phase 3 – All Out ─────────────────────────────────────────────────────────
var _radial_timer: float = 0.0
var _teleport_timer: float = 0.0
var _well_timer: float = 0.0
var _gravity_wells: Array[Area2D] = []
const GRAVITY_FORCE: float = 220.0
const GRAVITY_RADIUS: float = 180.0


func _ready() -> void:
	boss_name = "Omega"
	max_health = 3450
	phase_count = 4
	boss_color = Color(0.6, 0.0, 0.0, 1.0)
	size_scale = 1.5
	entry_speed = 140.0
	score_value = 20000

	super._ready()
	_create_claws()


# ── Claw Setup ────────────────────────────────────────────────────────────────
func _create_claws() -> void:
	var claw_pts: PackedVector2Array = PackedVector2Array([
		Vector2(-12, -6), Vector2(50, 0), Vector2(-12, 6),
		Vector2(25, 38), Vector2(-18, 30), Vector2(-12, 6),
	])

	_claw_top = Polygon2D.new()
	_claw_top.polygon = claw_pts
	_claw_top.color = Color(0.7, 0.1, 0.1, 1.0)
	_claw_top.position = Vector2(0, -100)
	add_child(_claw_top)

	_claw_bottom = Polygon2D.new()
	_claw_bottom.polygon = claw_pts
	_claw_bottom.color = Color(0.7, 0.1, 0.1, 1.0)
	_claw_bottom.position = Vector2(0, 100)
	_claw_bottom.scale = Vector2(1.0, -1.0)
	add_child(_claw_bottom)


# ── Main Attack Dispatch ──────────────────────────────────────────────────────
func _phase_attack(delta: float) -> void:
	match current_phase:
		0: _phase0_claws(delta)
		1: _phase1_sweep(delta)
		2: _phase2_charge_grunts(delta)
		3: _phase3_all_out(delta)


# ── Phase 0: Spinning Claws ───────────────────────────────────────────────────
func _phase0_claws(delta: float) -> void:
	_patrol(delta)
	_claw_angle += 220.0 * delta
	if _claw_angle > 360.0:
		_claw_angle -= 360.0
	_claw_top.rotation_degrees = _claw_angle
	_claw_bottom.rotation_degrees = -_claw_angle

	_claw_fire_timer += delta
	if _claw_fire_timer >= 1.2:
		_claw_fire_timer = 0.0
		_fire_three_way(540.0, Color(1.0, 0.3, 0.1, 1.0), 14)


# ── Phase 1: Laser Sweep ──────────────────────────────────────────────────────
func _phase1_sweep(delta: float) -> void:
	_patrol(delta)
	_sweep_timer += delta
	_sweep_bullet_accum += delta
	if _sweep_timer >= SWEEP_DURATION:
		_sweep_timer = 0.0

	if _sweep_bullet_accum >= SWEEP_BULLET_INTERVAL:
		_sweep_bullet_accum = 0.0
		var t: float = _sweep_timer / SWEEP_DURATION
		# Double sweep
		for i: int in range(2):
			var base_deg: float = 150.0 + i * 60.0
			var current_deg: float = base_deg - t * 180.0
			var vel: Vector2 = Vector2.from_angle(deg_to_rad(current_deg)) * 820.0
			_spawn_boss_bullet(vel, Color(1.0, 0.9, 0.0, 1.0), 20)


# ── Phase 2: Charge + Spawn Grunts ───────────────────────────────────────────
func _phase2_charge_grunts(delta: float) -> void:
	_charge_state_timer += delta
	match _charge_state:
		ChargeState.IDLE:
			_patrol(delta)
			if _charge_state_timer >= 1.0:
				_home_x = position.x
				_charge_state = ChargeState.CHARGING
				_charge_state_timer = 0.0
		ChargeState.CHARGING:
			velocity.x = -950.0
			velocity.y = 0.0
			if _charge_state_timer >= 0.7:
				_charge_state = ChargeState.RECOVERING
				_charge_state_timer = 0.0
		ChargeState.RECOVERING:
			velocity.x = (_home_x - position.x) * 3.5
			velocity.y = 0.0
			if _charge_state_timer >= 1.0:
				_charge_state = ChargeState.IDLE
				_charge_state_timer = 0.0

	_spawn_timer += delta
	if _spawn_timer >= 1.2:
		_spawn_timer = 0.0
		_spawn_grunt()

	# Also fire radial during charge phase
	_radial_timer += delta
	if _radial_timer >= 2.8:
		_radial_timer = 0.0
		_fire_radial_avoiding_safe_lane(5, 500.0, 18, Color(1.0, 0.4, 0.1, 1.0), _time * 20.0)


# ── Phase 3: All-Out ──────────────────────────────────────────────────────────
func _phase3_all_out(delta: float) -> void:
	# Claw rotation (cosmetic)
	_claw_angle += 350.0 * delta
	if _claw_angle > 360.0:
		_claw_angle -= 360.0
	_claw_top.rotation_degrees = _claw_angle
	_claw_bottom.rotation_degrees = -_claw_angle

	# Rapid radial shot
	_radial_timer += delta
	if _radial_timer >= 1.6:
		_radial_timer = 0.0
		_fire_radial_avoiding_safe_lane(7, 560.0, 20, Color(1.0, 0.2, 0.2, 1.0), _time * 30.0)

	# Teleport every 4s
	_teleport_timer += delta
	if _teleport_timer >= 4.0:
		_teleport_timer = 0.0
		_do_teleport()

	# Gravity wells every 6.5s
	_well_timer += delta
	if _well_timer >= 6.5:
		_well_timer = 0.0
		_spawn_gravity_well()

	_update_gravity_wells(delta)


# ── Shared Helpers ────────────────────────────────────────────────────────────
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


func _fire_three_way(speed: float, col: Color, dmg: int) -> void:
	var base_dir: Vector2 = get_player_direction()
	var base_angle: float = base_dir.angle()
	var spread: float = deg_to_rad(18.0)
	for i: int in range(-1, 2):
		_spawn_boss_bullet(Vector2.from_angle(base_angle + i * spread) * speed, col, dmg)


func _do_teleport() -> void:
	var margin: float = 120.0
	global_position = Vector2(
		randf_range(_arena_x - 120.0, _arena_x + 60.0),
		randf_range(margin, 1080.0 - margin)
	)


func _spawn_gravity_well() -> void:
	if bullet_container == null:
		return
	if _gravity_wells.size() >= 3:
		var oldest: Area2D = _gravity_wells.pop_front()
		if is_instance_valid(oldest):
			oldest.queue_free()

	var well: Area2D = Area2D.new()
	well.name = "GravityWell"
	well.collision_layer = 0
	well.collision_mask = 0
	well.global_position = global_position + Vector2(randf_range(-250, 250), randf_range(-180, 180))

	# Deliberately NOT Abyss Gate's smooth-swirling-portal look (rotating
	# rings, orbiting circular chips) — Omega's whole identity is jagged
	# battle-damaged armor, so its trap reads as a cracking singularity
	# tearing itself apart: a strobing jagged fracture ring (flickers
	# on/off instead of spinning), a harshly-pulsing angular void core,
	# and square debris shards that both spiral inward AND tumble on
	# their own axis, unlike Abyss Gate's serene circular orbit.
	var fracture_ring: Polygon2D = Polygon2D.new()
	fracture_ring.polygon = _build_jagged_star_poly(GRAVITY_RADIUS, GRAVITY_RADIUS * 0.72, 10)
	fracture_ring.color = Color(1.0, 0.15, 0.0, 0.28)
	well.add_child(fracture_ring)
	var strobe_tween := fracture_ring.create_tween().set_loops()
	strobe_tween.tween_property(fracture_ring, "modulate:a", 0.15, 0.08)
	strobe_tween.tween_property(fracture_ring, "modulate:a", 1.0, 0.05)
	strobe_tween.tween_interval(0.18)

	var core: Polygon2D = Polygon2D.new()
	core.polygon = _build_jagged_star_poly(28.0, 14.0, 7)
	core.color = Color(0.15, 0.0, 0.0, 0.9)
	well.add_child(core)
	var core_tween := core.create_tween().set_loops()
	core_tween.tween_property(core, "scale", Vector2(1.5, 1.5), 0.12).set_trans(Tween.TRANS_EXPO)
	core_tween.tween_property(core, "scale", Vector2(0.7, 0.7), 0.22).set_trans(Tween.TRANS_EXPO)
	core_tween.tween_interval(0.1)

	var core_rim: Polygon2D = Polygon2D.new()
	core_rim.polygon = _build_circle_poly(30.0, 16)
	core_rim.color = Color(1.0, 0.3, 0.0, 0.6)
	well.add_child(core_rim)

	for i in 6:
		var shard := Polygon2D.new()
		shard.polygon = PackedVector2Array([Vector2(-5, -5), Vector2(5, -5), Vector2(5, 5), Vector2(-5, 5)])
		shard.color = Color(0.6, 0.1, 0.0, 0.95)
		var start_angle: float = (TAU / 6.0) * i + randf_range(-0.2, 0.2)
		shard.position = Vector2(cos(start_angle), sin(start_angle)) * GRAVITY_RADIUS
		well.add_child(shard)
		var shard_tween := shard.create_tween().set_loops()
		shard_tween.tween_method(_orbit_chip.bind(shard, start_angle), 0.0, TAU, 1.3).set_trans(Tween.TRANS_LINEAR)
		var spin_tween := shard.create_tween().set_loops()
		spin_tween.tween_property(shard, "rotation", TAU, 0.5).set_trans(Tween.TRANS_LINEAR)

	well.set_meta("force", GRAVITY_FORCE)
	well.set_meta("radius", GRAVITY_RADIUS)
	bullet_container.add_child(well)
	_gravity_wells.append(well)


## Alternating outer/inner-radius polygon — a jagged "fractured" look in
## place of a smooth circle, distinct from Abyss Gate's rounded rings.
func _build_jagged_star_poly(outer_radius: float, inner_radius: float, points: int) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	var step: float = TAU / float(points * 2)
	for i in points * 2:
		var r: float = outer_radius if i % 2 == 0 else inner_radius
		var a: float = step * i
		pts.append(Vector2(cos(a) * r, sin(a) * r))
	return pts


## Orbits a debris chip around the well's center while spiraling it inward
## over the loop, so it reads as being pulled in rather than just circling.
func _orbit_chip(t: float, chip: Polygon2D, start_angle: float) -> void:
	if not is_instance_valid(chip):
		return
	var angle: float = start_angle + t
	var radius: float = lerpf(GRAVITY_RADIUS, 8.0, t / TAU)
	chip.position = Vector2(cos(angle), sin(angle)) * radius


func _update_gravity_wells(delta: float) -> void:
	if player_ref == null:
		return
	var to_remove: Array[Area2D] = []
	for well: Area2D in _gravity_wells:
		if not is_instance_valid(well):
			to_remove.append(well)
			continue
		var dist: float = player_ref.global_position.distance_to(well.global_position)
		var radius: float = well.get_meta("radius", GRAVITY_RADIUS)
		if dist < radius and dist > 1.0:
			var force: float = well.get_meta("force", GRAVITY_FORCE)
			var pull: Vector2 = (well.global_position - player_ref.global_position).normalized()
			player_ref.global_position += pull * force * delta
	for w: Area2D in to_remove:
		_gravity_wells.erase(w)


func _build_circle_poly(radius: float, steps: int) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	for i: int in range(steps):
		var a: float = (TAU / steps) * i
		pts.append(Vector2(cos(a) * radius, sin(a) * radius))
	return pts


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
	grunt.global_position = global_position + Vector2(-40.0, randf_range(-80.0, 80.0))


func _on_phase_change(new_phase: int) -> void:
	_radial_timer = 0.0
	_teleport_timer = 0.0
	_well_timer = 0.0
	_sweep_timer = 0.0
	_sweep_bullet_accum = 0.0
	_claw_fire_timer = 0.0
	_spawn_timer = 0.0
	_charge_state = ChargeState.IDLE
	_charge_state_timer = 0.0

	if new_phase == 3:
		# Clear gravity wells from previous phase
		for w: Area2D in _gravity_wells:
			if is_instance_valid(w):
				w.queue_free()
		_gravity_wells.clear()
