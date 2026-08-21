class_name BossBehemoth
extends BossBase

## Behemoth Boss
## Large, slow boss that charges horizontally across the screen.
## Phase 0: charges at speed -600, fires radial 6-shot every 2s.
## Phase 1: charge speed -1200, fires radial 8-shot every 1.5s.

enum State { IDLE, CHARGING, RECOVERING }

const IDLE_DURATION: float = 1.5
const CHARGE_DURATION: float = 0.8
const RECOVER_DURATION: float = 1.2

var _state: State = State.IDLE
var _state_timer: float = 0.0
var _radial_timer: float = 0.0
var _home_x: float = 0.0
var _home_y: float = 540.0
var _patrol_dir: int = 1

const PATROL_SPEED: float = 60.0
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
			# Slow vertical drift
			_slow_patrol(delta)
			if _state_timer >= IDLE_DURATION:
				_begin_charge()

		State.CHARGING:
			var charge_speed: float = -600.0 if current_phase == 0 else -1200.0
			velocity.x = charge_speed
			velocity.y = 0.0
			move_and_slide()
			if _state_timer >= CHARGE_DURATION:
				_begin_recover()

		State.RECOVERING:
			# Slide back toward home x
			var diff_x: float = _home_x - position.x
			velocity.x = diff_x * 3.0
			velocity.y = 0.0
			move_and_slide()
			if _state_timer >= RECOVER_DURATION:
				_state = State.IDLE
				_state_timer = 0.0


func _slow_patrol(delta: float) -> void:
	if position.y > _home_y + PATROL_RANGE:
		_patrol_dir = -1
	elif position.y < _home_y - PATROL_RANGE:
		_patrol_dir = 1
	velocity.x = 0.0
	velocity.y = _patrol_dir * PATROL_SPEED
	move_and_slide()


func _begin_charge() -> void:
	_state = State.CHARGING
	_state_timer = 0.0
	_home_x = position.x


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
			# Reset to idle on phase transition
			_state = State.IDLE
			_state_timer = 0.0
