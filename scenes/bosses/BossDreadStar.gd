class_name BossDreadStar
extends BossBase
## BossDreadStar — Level 9 Boss: Cosmic Pulsar Dreadnought with rotating particle cannons and orbital shield mines.

var _spin_angle: float = 0.0
var _barrage_timer: float = 0.0

func _ready() -> void:
	boss_name = "Dread Star"
	max_health = 4375
	phase_count = 3
	score_value = 25000
	boss_color = Color(0.9, 0.2, 0.8)
	size_scale = 1.6
	super._ready()

## Reserves a narrow safe lane toward the player as maneuvering room —
## the player's finger IS the control and the ship sits to the right of
## that band, so a fully omnidirectional spiral/radial (the pulsar's
## identity) was flooding the exact space the player needs to dodge in.
## Bullets that would fly within this arc are simply not spawned. Kept
## narrow (45 degrees, not the original 120) so the pattern still mostly
## reads as a genuine 360-degree spiral like the other bosses — just
## missing one small wedge — rather than looking broken.
## Direct aimed shots at the player are unaffected — those are singular
## and telegraphed, not blanket clutter.
##
## The lane's center sweeps slowly around due-left instead of sitting
## fixed there, so the player can't just camp at the boss's exact height
## and tank-free-fire from a permanently safe spot — they have to track
## where the gap currently is.
const SAFE_LANE_HALF_WIDTH_RAD: float = 0.3927  # 22.5 degrees
const SAFE_LANE_SWEEP_AMPLITUDE_RAD: float = 0.6109  # 35 degrees
const SAFE_LANE_SWEEP_PERIOD: float = 5.0

func _safe_lane_center_angle() -> float:
	return PI + sin(_time * TAU / SAFE_LANE_SWEEP_PERIOD) * SAFE_LANE_SWEEP_AMPLITUDE_RAD

func _in_safe_lane(dir: Vector2) -> bool:
	var diff: float = wrapf(dir.angle() - _safe_lane_center_angle(), -PI, PI)
	return absf(diff) < SAFE_LANE_HALF_WIDTH_RAD

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
	if _in_safe_lane(dir):
		return
	_spawn_boss_bullet(dir * speed, col, dmg)

func _fire_radial_avoiding_safe_lane(count: int, speed: float, dmg: int, col: Color, angle_offset_deg: float) -> void:
	for i in count:
		var angle: float = TAU / float(count) * i + deg_to_rad(angle_offset_deg)
		var dir := Vector2.RIGHT.rotated(angle)
		if _in_safe_lane(dir):
			continue
		_spawn_boss_bullet(dir * speed, col, dmg)
