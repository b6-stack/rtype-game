class_name BossHyperion
extends BossBase
## BossHyperion — Level 10 Ultimate Final Boss: Titan Flagship with multi-vector apocalypse cannons and drone swarms.
## The true final gauntlet -- draws on signature moves from across the
## roster (radial storms, aimed fire, a sweeping beam, a ramming charge,
## and a teleport) so the fight reads as "everything the game has thrown
## at you, at once" without exceeding what a well-piloted player can
## survive: bullet counts/speeds are kept in line with what any single
## earlier boss uses for the same pattern, and a shifting safe lane (see
## BossDreadStar) guarantees dodge room in every phase.

var _pattern_timer: float = 0.0
var _sweep_timer: float = 0.0

enum ChargeState { IDLE, CHARGING, RECOVERING }
var _charge_state: ChargeState = ChargeState.IDLE
var _charge_timer: float = 0.0
var _home_x: float = 0.0

var _teleport_timer: float = 0.0

const SAFE_LANE_HALF_WIDTH_RAD: float = 0.3927  # 22.5 degrees
const SAFE_LANE_SWEEP_AMPLITUDE_RAD: float = 0.6109  # 35 degrees
const SAFE_LANE_SWEEP_PERIOD: float = 4.5

func _safe_lane_center_angle() -> float:
	return PI + sin(_time * TAU / SAFE_LANE_SWEEP_PERIOD) * SAFE_LANE_SWEEP_AMPLITUDE_RAD

func _in_safe_lane(dir: Vector2) -> bool:
	var diff: float = wrapf(dir.angle() - _safe_lane_center_angle(), -PI, PI)
	return absf(diff) < SAFE_LANE_HALF_WIDTH_RAD

func _ready() -> void:
	boss_name = "Hyperion Prime"
	max_health = 7000
	phase_count = 4
	score_value = 50000
	boss_color = Color(1.0, 0.85, 0.1)
	size_scale = 1.8
	super._ready()

func _phase_attack(delta: float) -> void:
	_pattern_timer += delta
	velocity.y = sin(_time * 2.5) * 80.0

	match current_phase:
		0: _phase0_radial_aimed(delta)
		1: _phase1_sweep_radial(delta)
		2: _phase2_charge_dual_radial(delta)
		3: _phase3_everything(delta)

## Phase 0 — same opening as before: a warm-up radial + aimed shot. Safe
## lane is active from the very start so the player learns to track it
## before the pattern count ramps up.
func _phase0_radial_aimed(_delta: float) -> void:
	if _pattern_timer >= 1.2:
		_pattern_timer = 0.0
		_fire_radial_avoiding_safe_lane(8, 450.0, 2, Color.GOLD, _time * 20.0)
		_fire_at_player(600.0, 2, Color.ORANGE)

## Phase 1 — adds a Photon-Core-style sweeping beam and an occasional,
## rare ramming charge (a taste of what's coming) alongside a lighter
## radial burst, so the player has three different threat shapes to
## track instead of just one radial pattern.
func _phase1_sweep_radial(delta: float) -> void:
	_sweep_timer += delta
	_handle_charge(delta, 2.6, -700.0, 0.5, 1.0)
	if _pattern_timer >= 1.4:
		_pattern_timer = 0.0
		_fire_radial_avoiding_safe_lane(8, 470.0, 2, Color.ORANGE, _time * 45.0)
	if _sweep_timer >= 0.06:
		_sweep_timer = 0.0
		var sweep_deg: float = 60.0 + sin(_time * 1.6) * 110.0
		var dir: Vector2 = Vector2.from_angle(deg_to_rad(sweep_deg))
		if not _in_safe_lane(dir):
			_spawn_boss_bullet(dir * 700.0, Color.CYAN, 2)

## Phase 2 — a full Behemoth-style ramming charge cycle (a real
## positional threat, not just more bullets) alongside the dual
## counter-rotating radial from before.
func _phase2_charge_dual_radial(delta: float) -> void:
	_handle_charge(delta, 1.6, -800.0, 0.6, 1.0)

	if _pattern_timer >= 1.1:
		_pattern_timer = 0.0
		_fire_radial_avoiding_safe_lane(10, 500.0, 2, Color.CYAN, -_time * 60.0)
		_fire_radial_avoiding_safe_lane(6, 380.0, 2, Color.MAGENTA, _time * 30.0)

## Phase 3 — everything at once: furious back-to-back ramming charges
## (matching Behemoth's own phase-1 escalation: faster cycle, harder
## charge speed), the densest radial storm, aimed fire, and a
## short-range teleport (Abyss-Gate/Dread-Star style) to keep the
## player from settling into one dodge rhythm. The safe lane is what
## keeps this survivable despite the volume -- there is always exactly
## one guaranteed gap, it just keeps moving.
func _phase3_everything(delta: float) -> void:
	_handle_charge(delta, 1.0, -1000.0, 0.6, 0.8)

	if _pattern_timer >= 0.6:
		_pattern_timer = 0.0
		_fire_radial_avoiding_safe_lane(12, 540.0, 2, Color.YELLOW, sin(_time * 3.0) * 90.0)
		_fire_at_player(720.0, 3, Color.WHITE)

	_teleport_timer += delta
	if _teleport_timer >= 5.0:
		_teleport_timer = 0.0
		_do_teleport()

## Shared Behemoth-style ramming charge state machine — idle/charge/recover
## durations and charge speed are tuned per phase so later phases feel
## more furious, the same way Behemoth itself escalates between its two
## phases.
func _handle_charge(delta: float, idle_duration: float, charge_speed: float,
		charge_duration: float, recover_duration: float) -> void:
	_charge_timer += delta
	match _charge_state:
		ChargeState.IDLE:
			if _charge_timer >= idle_duration:
				_home_x = position.x
				_charge_state = ChargeState.CHARGING
				_charge_timer = 0.0
		ChargeState.CHARGING:
			velocity.x = charge_speed
			if _charge_timer >= charge_duration or position.x <= 250.0:
				_charge_state = ChargeState.RECOVERING
				_charge_timer = 0.0
		ChargeState.RECOVERING:
			velocity.x = clamp((_home_x - position.x) * 3.0, 150.0, 900.0)
			if position.x >= _home_x - 10.0 or _charge_timer >= recover_duration:
				position.x = _home_x
				_charge_state = ChargeState.IDLE
				_charge_timer = 0.0

func _do_teleport() -> void:
	var margin: float = 120.0
	global_position = Vector2(
		randf_range(_arena_x - 100.0, _arena_x + 80.0),
		randf_range(margin, 1080.0 - margin)
	)

func _fire_radial_avoiding_safe_lane(count: int, speed: float, dmg: int, col: Color, angle_offset_deg: float) -> void:
	for i in count:
		var angle: float = TAU / float(count) * i + deg_to_rad(angle_offset_deg)
		var dir: Vector2 = Vector2.RIGHT.rotated(angle)
		if _in_safe_lane(dir):
			continue
		_spawn_boss_bullet(dir * speed, col, dmg)

func _on_phase_change(_new_phase: int) -> void:
	_pattern_timer = 0.0
	_sweep_timer = 0.0
	_charge_state = ChargeState.IDLE
	_charge_timer = 0.0
	_teleport_timer = 0.0
