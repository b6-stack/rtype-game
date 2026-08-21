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

func _phase_attack(delta: float) -> void:
	_spin_angle += delta * 120.0
	_barrage_timer += delta

	match current_phase:
		0:
			# Spiral barrage
			if _barrage_timer >= 0.2:
				_barrage_timer = 0.0
				var dir := Vector2.LEFT.rotated(deg_to_rad(_spin_angle))
				_spawn_boss_bullet(dir * 500.0, Color.MAGENTA, 2)
		1:
			# Dual spiral + aimed lasers
			if _barrage_timer >= 0.15:
				_barrage_timer = 0.0
				_spawn_boss_bullet(Vector2.LEFT.rotated(deg_to_rad(_spin_angle)) * 550.0, Color.MAGENTA, 2)
				_spawn_boss_bullet(Vector2.LEFT.rotated(deg_to_rad(_spin_angle + 180.0)) * 550.0, Color.CYAN, 2)
			if int(_phase_time * 2.0) % 3 == 0:
				_fire_at_player(650.0, 3, Color.YELLOW)
		2:
			# Nova eruption
			if _barrage_timer >= 0.8:
				_barrage_timer = 0.0
				_fire_radial(16, 480.0, 2, Color.CORAL, _spin_angle)
				_fire_at_player(700.0, 3, Color.RED)
