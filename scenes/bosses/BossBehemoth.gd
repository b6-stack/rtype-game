class_name BossBehemoth
extends BossBase

## Behemoth Boss
## Large, heavy armored ramming cruiser.
## Phase 0: charges across the screen, fires radial 6-shot every 2s.
## Phase 1: furious charges, fires radial 8-shot every 1.5s.

enum State { IDLE, CHARGING, RECOVERING }

const IDLE_DURATION: float = 1.6
const CHARGE_DURATION: float = 0.9
const RECOVER_DURATION: float = 1.4

var _state: State = State.IDLE
var _state_timer: float = 0.0
var _radial_timer: float = 0.0
var _home_x: float = 1400.0
var _home_y: float = 540.0
var _patrol_dir: int = 1

const PATROL_SPEED: float = 70.0
const PATROL_RANGE: float = 180.0

func _ready() -> void:
	boss_name = "Behemoth"
	max_health = 1500
	phase_count = 2
	boss_color = Color(0.35, 0.2, 0.1, 1.0)
	size_scale = 1.8
	entry_speed = 120.0
	score_value = 10000

	super._ready()

func _phase_attack(delta: float) -> void:
	_state_timer += delta
	_handle_state(delta)
	_handle_radial(delta)

func _handle_state(delta: float) -> void:
	match _state:
		State.IDLE:
			_slow_patrol(delta)
			if _state_timer >= IDLE_DURATION:
				_begin_charge()

		State.CHARGING:
			var charge_speed: float = -650.0 if current_phase == 0 else -1000.0
			velocity.x = charge_speed
			velocity.y = 0.0
			if _state_timer >= CHARGE_DURATION or global_position.x <= 250.0:
				_begin_recover()

		State.RECOVERING:
			var diff_x: float = _home_x - global_position.x
			velocity.x = clamp(diff_x * 3.5, 200.0, 800.0)
			velocity.y = 0.0
			if global_position.x >= _home_x - 10.0 or _state_timer >= RECOVER_DURATION:
				global_position.x = _home_x
				_state = State.IDLE
				_state_timer = 0.0

func _slow_patrol(_delta: float) -> void:
	if global_position.y > _home_y + PATROL_RANGE:
		_patrol_dir = -1
	elif global_position.y < _home_y - PATROL_RANGE:
		_patrol_dir = 1
	velocity.x = 0.0
	velocity.y = _patrol_dir * PATROL_SPEED

func _begin_charge() -> void:
	_state = State.CHARGING
	_state_timer = 0.0
	_home_x = global_position.x

func _begin_recover() -> void:
	_state = State.RECOVERING
	_state_timer = 0.0

func _handle_radial(delta: float) -> void:
	var fire_rate: float = 2.0 if current_phase == 0 else 1.5
	var shot_count: int = 6 if current_phase == 0 else 8

	_radial_timer += delta
	if _radial_timer >= fire_rate:
		_radial_timer = 0.0
		_fire_radial(shot_count, 420.0, 16, Color(0.8, 0.4, 0.1, 1.0), _time * 15.0)

func _on_phase_change(new_phase: int) -> void:
	match new_phase:
		1:
			_state = State.IDLE
			_state_timer = 0.0
