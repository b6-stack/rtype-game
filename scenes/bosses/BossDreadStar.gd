class_name BossDreadStar
extends BossBase
## BossDreadStar — Level 9 Boss: Cosmic Pulsar Dreadnought with rotating particle cannons and orbital shield mines.

var _spin_angle: float = 0.0
var _barrage_timer: float = 0.0

func _ready() -> void:
	boss_name = "Dread Star"
	max_health = 2500
	phase_count = 3
	score_value = 25000
	boss_color = Color(0.9, 0.2, 0.8)
	size_scale = 1.6
	super._ready()

## Reserves the left 30-40% of the screen as maneuvering room — the
## player's finger IS the control and the ship sits to the right of that
## band, so a fully omnidirectional spiral/radial (the pulsar's identity)
## was flooding the exact space the player needs to dodge in. Bullets
## that would fly predominantly leftward are simply not spawned, leaving
## a consistent safe lane instead. Direct aimed shots at the player are
## unaffected — those are singular and telegraphed, not blanket clutter.
const SAFE_LANE_DIR_X_THRESHOLD: float = -0.5

func _phase_attack(delta: float) -> void:
	_spin_angle += delta * 120.0
	_barrage_timer += delta

	match current_phase:
		0:
			# Spiral barrage
			if _barrage_timer >= 0.2:
				_barrage_timer = 0.0
				_fire_spiral_bullet(_spin_angle, 500.0, Color.MAGENTA, 2)
		1:
			# Dual spiral + aimed lasers
			if _barrage_timer >= 0.15:
				_barrage_timer = 0.0
				_fire_spiral_bullet(_spin_angle, 550.0, Color.MAGENTA, 2)
				_fire_spiral_bullet(_spin_angle + 180.0, 550.0, Color.CYAN, 2)
			if int(_phase_time * 2.0) % 3 == 0:
				_fire_at_player(650.0, 3, Color.YELLOW)
		2:
			# Nova eruption
			if _barrage_timer >= 0.8:
				_barrage_timer = 0.0
				_fire_radial_avoiding_safe_lane(16, 480.0, 2, Color.CORAL, _spin_angle)
				_fire_at_player(700.0, 3, Color.RED)

func _fire_spiral_bullet(angle_deg: float, speed: float, col: Color, dmg: int) -> void:
	var dir := Vector2.LEFT.rotated(deg_to_rad(angle_deg))
	if dir.x < SAFE_LANE_DIR_X_THRESHOLD:
		return
	_spawn_boss_bullet(dir * speed, col, dmg)

func _fire_radial_avoiding_safe_lane(count: int, speed: float, dmg: int, col: Color, angle_offset_deg: float) -> void:
	for i in count:
		var angle: float = TAU / float(count) * i + deg_to_rad(angle_offset_deg)
		var dir := Vector2.RIGHT.rotated(angle)
		if dir.x < SAFE_LANE_DIR_X_THRESHOLD:
			continue
		_spawn_boss_bullet(dir * speed, col, dmg)
