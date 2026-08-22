class_name BossOmega
extends BossBase

## Omega — Final Boss, 4 phases combining all previous patterns.
## Phase 0: Spinning claw attack (IronClaw-style).
## Phase 1: Laser sweep (PhotonCore-style).
## Phase 2: Charge + spawn grunts (Behemoth+SwarmQueen-style).
## Phase 3: 12-way radial + teleport + gravity well at max intensity.

# ── Shared ────────────────────────────────────────────────────────────────────
var _patrol_dir: int = 1
const PATROL_SPEED: float = 100.0
const PATROL_RANGE: float = 230.0

# ── Phase 0 – Claw ────────────────────────────────────────────────────────────
var _claw_top: Polygon2D
var _claw_bottom: Polygon2D
var _claw_angle: float = 0.0
var _claw_fire_timer: float = 0.0

# ── Phase 1 – Laser Sweep ─────────────────────────────────────────────────────
var _sweep_timer: float = 0.0
var _sweep_bullet_accum: float = 0.0
const SWEEP_DURATION: float = 1.8
const SWEEP_BULLET_INTERVAL: float = 0.03

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
	max_health = 2000
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
	if _claw_fire_timer >= 0.9:
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
		# Triple sweep
		for i: int in range(3):
			var base_deg: float = 150.0 + i * 30.0
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
			velocity.x = -1200.0
			velocity.y = 0.0
			move_and_slide()
			if _charge_state_timer >= 0.7:
				_charge_state = ChargeState.RECOVERING
				_charge_state_timer = 0.0
		ChargeState.RECOVERING:
			velocity.x = (_home_x - position.x) * 3.5
			velocity.y = 0.0
			move_and_slide()
			if _charge_state_timer >= 1.0:
				_charge_state = ChargeState.IDLE
				_charge_state_timer = 0.0

	_spawn_timer += delta
	if _spawn_timer >= 1.2:
		_spawn_timer = 0.0
		_spawn_grunt()

	# Also fire radial during charge phase
	_radial_timer += delta
	if _radial_timer >= 2.0:
		_radial_timer = 0.0
		_fire_radial(8, 500.0, 18, Color(1.0, 0.4, 0.1, 1.0), _time * 20.0)


# ── Phase 3: All-Out ──────────────────────────────────────────────────────────
func _phase3_all_out(delta: float) -> void:
	# Claw rotation (cosmetic)
	_claw_angle += 350.0 * delta
	if _claw_angle > 360.0:
		_claw_angle -= 360.0
	_claw_top.rotation_degrees = _claw_angle
	_claw_bottom.rotation_degrees = -_claw_angle

	# Rapid radial 12-shot
	_radial_timer += delta
	if _radial_timer >= 1.0:
		_radial_timer = 0.0
		_fire_radial(12, 560.0, 20, Color(1.0, 0.2, 0.2, 1.0), _time * 30.0)

	# Teleport every 3.5s
	_teleport_timer += delta
	if _teleport_timer >= 3.5:
		_teleport_timer = 0.0
		_do_teleport()

	# Gravity wells every 5s
	_well_timer += delta
	if _well_timer >= 5.0:
		_well_timer = 0.0
		_spawn_gravity_well()

	_update_gravity_wells(delta)


# ── Shared Helpers ────────────────────────────────────────────────────────────
func _patrol(delta: float) -> void:
	var center_y: float = 540.0
	if position.y > center_y + PATROL_RANGE:
		_patrol_dir = -1
	elif position.y < center_y - PATROL_RANGE:
		_patrol_dir = 1
	velocity.y = _patrol_dir * PATROL_SPEED
	velocity.x = 0.0
	move_and_slide()


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
	well.collision_layer = 0
	well.collision_mask = 0
	well.global_position = global_position + Vector2(randf_range(-250, 250), randf_range(-180, 180))

	var poly: Polygon2D = Polygon2D.new()
	poly.polygon = _build_circle_poly(35.0, 12)
	poly.color = Color(0.5, 0.0, 0.1, 0.55)
	well.add_child(poly)

	well.set_meta("force", GRAVITY_FORCE)
	well.set_meta("radius", GRAVITY_RADIUS)
	bullet_container.add_child(well)
	_gravity_wells.append(well)


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
