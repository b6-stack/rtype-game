class_name BossAbyssGate
extends BossBase

## Abyss Gate Boss — 4 phases
## Teleports every 8 seconds. Spawns gravity wells (Area2D) that pull the player.
## Phase 0: teleport + fires at player.
## Phase 1: 2 gravity wells + 4-way shot.
## Phase 2: 4 gravity wells + rapid fire.
## Phase 3: constant teleporting + radial 12-shot.

const TELEPORT_INTERVAL_BASE: float = 8.0
const TELEPORT_INTERVAL_P3: float = 3.0
const GRAVITY_WELL_FORCE: float = 180.0
const GRAVITY_WELL_RADIUS: float = 160.0
const MAX_GRAVITY_WELLS: int = 4

var _teleport_timer: float = 0.0
var _fire_timer: float = 0.0
var _gravity_wells: Array[Area2D] = []
var _flash_color: bool = false


func _ready() -> void:
	boss_name = "Abyss Gate"
	max_health = 1300
	phase_count = 4
	boss_color = Color(0.25, 0.0, 0.45, 1.0)
	size_scale = 1.2
	entry_speed = 160.0
	score_value = 12000

	super._ready()


func _phase_attack(delta: float) -> void:
	var teleport_interval: float = TELEPORT_INTERVAL_P3 if current_phase == 3 else TELEPORT_INTERVAL_BASE
	_teleport_timer += delta
	if _teleport_timer >= teleport_interval:
		_teleport_timer = 0.0
		_do_teleport()

	_fire_timer += delta
	var fire_rate: float = _get_fire_rate()
	if _fire_timer >= fire_rate:
		_fire_timer = 0.0
		_do_attack()

	_update_gravity_wells(delta)


func _get_fire_rate() -> float:
	match current_phase:
		0: return 2.0
		1: return 2.0
		2: return 0.8
		3: return 1.2
	return 2.0


func _do_attack() -> void:
	match current_phase:
		0:
			_fire_at_player(500.0, 14, Color(0.5, 0.0, 0.9, 1.0))
		1:
			_fire_cross()
		2:
			_fire_at_player(560.0, 16, Color(0.5, 0.0, 0.9, 1.0))
		3:
			_fire_radial(12, 520.0, 16, Color(0.6, 0.1, 1.0, 1.0), _time * 25.0)


func _fire_cross() -> void:
	var dirs: Array = [
		Vector2(1, 0), Vector2(-1, 0),
		Vector2(0, 1), Vector2(0, -1)
	]
	for d in dirs:
		_spawn_boss_bullet(d * 500.0, Color(0.5, 0.0, 0.9, 1.0), 14)


func _do_teleport() -> void:
	# Flash effect by toggling color (visual only)
	_flash_color = true

	var margin: float = 150.0
	var new_x: float = randf_range(_arena_x - 100.0, _arena_x + 80.0)
	var new_y: float = randf_range(margin, 1080.0 - margin)
	global_position = Vector2(new_x, new_y)

	# Spawn gravity well on teleport for phases >= 1
	if current_phase >= 1:
		_spawn_gravity_well()


func _spawn_gravity_well() -> void:
	if bullet_container == null:
		return
	if _gravity_wells.size() >= MAX_GRAVITY_WELLS:
		# Remove oldest
		var oldest: Area2D = _gravity_wells.pop_front()
		if is_instance_valid(oldest):
			oldest.queue_free()

	var well: Area2D = Area2D.new()
	well.name = "GravityWell"
	well.collision_layer = 0
	well.collision_mask = 0
	well.global_position = global_position + Vector2(randf_range(-200, 200), randf_range(-150, 150))

	# Layered, animated visual — a flat static circle read as decoration
	# rather than an active hazard. Two counter-rotating warning rings, a
	# pulsing core, and orbiting debris chips that spiral inward sell the
	# "actively pulling you in" read at a glance.
	var ring: Polygon2D = Polygon2D.new()
	ring.polygon = _build_circle_poly(GRAVITY_WELL_RADIUS, 28)
	ring.color = Color(0.7, 0.1, 1.0, 0.16)
	well.add_child(ring)
	var ring_tween := ring.create_tween().set_loops()
	ring_tween.tween_property(ring, "rotation", TAU, 3.0).set_trans(Tween.TRANS_LINEAR)

	var swirl: Polygon2D = Polygon2D.new()
	swirl.polygon = _build_circle_poly(GRAVITY_WELL_RADIUS * 0.55, 20)
	swirl.color = Color(0.5, 0.0, 0.9, 0.22)
	well.add_child(swirl)
	var swirl_tween := swirl.create_tween().set_loops()
	swirl_tween.tween_property(swirl, "rotation", -TAU, 1.8).set_trans(Tween.TRANS_LINEAR)

	var core: Polygon2D = Polygon2D.new()
	core.polygon = _build_circle_poly(30.0, 14)
	core.color = Color(0.6, 0.1, 1.0, 0.75)
	well.add_child(core)
	var core_tween := core.create_tween().set_loops()
	core_tween.tween_property(core, "scale", Vector2(1.3, 1.3), 0.4).set_trans(Tween.TRANS_SINE)
	core_tween.tween_property(core, "scale", Vector2(0.85, 0.85), 0.4).set_trans(Tween.TRANS_SINE)

	for i in 6:
		var chip := Polygon2D.new()
		chip.polygon = _build_circle_poly(5.0, 6)
		chip.color = Color(0.85, 0.5, 1.0, 0.9)
		var start_angle: float = (TAU / 6.0) * i
		chip.position = Vector2(cos(start_angle), sin(start_angle)) * GRAVITY_WELL_RADIUS
		well.add_child(chip)
		var chip_tween := chip.create_tween().set_loops()
		chip_tween.tween_method(_orbit_chip.bind(chip, start_angle), 0.0, TAU, 1.6).set_trans(Tween.TRANS_LINEAR)

	well.set_meta("force", GRAVITY_WELL_FORCE)
	well.set_meta("radius", GRAVITY_WELL_RADIUS)

	bullet_container.add_child(well)
	_gravity_wells.append(well)


## Orbits a debris chip around the well's center while spiraling it inward
## over the loop, so it reads as being pulled in rather than just circling.
func _orbit_chip(chip: Polygon2D, start_angle: float, t: float) -> void:
	if not is_instance_valid(chip):
		return
	var angle: float = start_angle + t
	var radius: float = lerpf(GRAVITY_WELL_RADIUS, 8.0, t / TAU)
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
		var radius: float = well.get_meta("radius", GRAVITY_WELL_RADIUS)
		if dist < radius and dist > 1.0:
			var force: float = well.get_meta("force", GRAVITY_WELL_FORCE)
			var pull_dir: Vector2 = (well.global_position - player_ref.global_position).normalized()
			# Directly nudge player position (gentle pull)
			player_ref.global_position += pull_dir * force * delta

	for w: Area2D in to_remove:
		_gravity_wells.erase(w)


func _build_circle_poly(radius: float, steps: int) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	for i: int in range(steps):
		var a: float = (TAU / steps) * i
		pts.append(Vector2(cos(a) * radius, sin(a) * radius))
	return pts


func _on_phase_change(new_phase: int) -> void:
	_teleport_timer = 0.0
	_fire_timer = 0.0
	match new_phase:
		1:
			# Spawn initial wells
			_spawn_gravity_well()
			_spawn_gravity_well()
		2:
			_spawn_gravity_well()
			_spawn_gravity_well()
		3:
			# Clear old wells and start fresh
			for w: Area2D in _gravity_wells:
				if is_instance_valid(w):
					w.queue_free()
			_gravity_wells.clear()
