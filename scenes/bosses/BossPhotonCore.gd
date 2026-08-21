class_name BossPhotonCore
extends BossBase

## Photon Core Boss
## Simulates giant laser sweeps by firing bullets in a rotating arc.
## Phase 0: single 180-degree sweep over 2s. Phase 1: dual sweeps. Phase 2: triple sweeps + radial.

const SWEEP_DURATION: float = 2.0
const SWEEP_DEGREES: float = 180.0
const BULLET_INTERVAL: float = 0.04  # seconds between sweep bullets

var _sweep_timer: float = 0.0
var _bullet_accum: float = 0.0
var _radial_timer: float = 0.0

# Each sweep has a start angle, a direction, and a color
var _active_sweeps: Array[Dictionary] = []

var _patrol_dir: int = 1
const PATROL_SPEED: float = 70.0
const PATROL_RANGE: float = 200.0


func _ready() -> void:
	boss_name = "Photon Core"
	max_health = 1100
	phase_count = 3
	boss_color = Color(1.0, 0.9, 0.1, 1.0)
	size_scale = 1.0
	entry_speed = 160.0
	score_value = 9000

	super._ready()
	_setup_sweeps()


func _setup_sweeps() -> void:
	_active_sweeps.clear()
	match current_phase:
		0:
			_active_sweeps.append({
				"start_deg": 150.0,
				"dir": -1.0,
				"color": Color(1.0, 0.9, 0.1, 1.0),
				"speed": 700.0,
				"dmg": 18
			})
		1:
			_active_sweeps.append({
				"start_deg": 150.0,
				"dir": -1.0,
				"color": Color(1.0, 0.9, 0.1, 1.0),
				"speed": 750.0,
				"dmg": 18
			})
			_active_sweeps.append({
				"start_deg": 210.0,
				"dir": 1.0,
				"color": Color(1.0, 0.5, 0.1, 1.0),
				"speed": 750.0,
				"dmg": 18
			})
		2:
			_active_sweeps.append({
				"start_deg": 150.0,
				"dir": -1.0,
				"color": Color(1.0, 0.9, 0.1, 1.0),
				"speed": 800.0,
				"dmg": 20
			})
			_active_sweeps.append({
				"start_deg": 210.0,
				"dir": 1.0,
				"color": Color(1.0, 0.5, 0.1, 1.0),
				"speed": 800.0,
				"dmg": 20
			})
			_active_sweeps.append({
				"start_deg": 180.0,
				"dir": -1.0,
				"color": Color(0.9, 0.2, 1.0, 1.0),
				"speed": 800.0,
				"dmg": 20
			})


func _phase_attack(delta: float) -> void:
	_patrol(delta)
	_sweep_timer += delta
	_bullet_accum += delta

	if _sweep_timer >= SWEEP_DURATION:
		_sweep_timer = 0.0

	# Fire sweep bullets based on progress
	if _bullet_accum >= BULLET_INTERVAL:
		_bullet_accum = 0.0
		_fire_sweep_bullets()

	# Phase 2: also fires radial bursts
	if current_phase == 2:
		_radial_timer += delta
		if _radial_timer >= 3.5:
			_radial_timer = 0.0
			_fire_radial(12, 500.0, 14, Color(1.0, 0.9, 0.1, 1.0), _time * 20.0)


func _fire_sweep_bullets() -> void:
	var t: float = _sweep_timer / SWEEP_DURATION  # 0..1

	for sweep: Dictionary in _active_sweeps:
		var current_deg: float = sweep["start_deg"] + sweep["dir"] * t * SWEEP_DEGREES
		var rad: float = deg_to_rad(current_deg)
		var vel: Vector2 = Vector2(cos(rad), sin(rad)) * sweep["speed"]
		_spawn_boss_bullet(vel, sweep["color"], sweep["dmg"])


func _patrol(delta: float) -> void:
	var center_y: float = 540.0
	if position.y > center_y + PATROL_RANGE:
		_patrol_dir = -1
	elif position.y < center_y - PATROL_RANGE:
		_patrol_dir = 1
	velocity.y = _patrol_dir * PATROL_SPEED
	velocity.x = 0.0
	move_and_slide()


func _on_phase_change(new_phase: int) -> void:
	_sweep_timer = 0.0
	_bullet_accum = 0.0
	_radial_timer = 0.0
	_setup_sweeps()
