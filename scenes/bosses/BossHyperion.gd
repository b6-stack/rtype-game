class_name BossHyperion
extends BossBase
## BossHyperion — Level 10 Ultimate Final Boss: Titan Flagship with multi-vector apocalypse cannons and drone swarms.

var _pattern_timer: float = 0.0

func _ready() -> void:
	boss_name = "Hyperion Prime"
	max_health = 3500
	phase_count = 4
	score_value = 50000
	boss_color = Color(1.0, 0.85, 0.1)
	size_scale = 1.8
	super._ready()

func _phase_attack(delta: float) -> void:
	_pattern_timer += delta
	# Hover vertical oscillation
	velocity.y = sin(_time * 2.5) * 80.0

	match current_phase:
		0:
			if _pattern_timer >= 1.2:
				_pattern_timer = 0.0
				_fire_radial(8, 450.0, 2, Color.GOLD)
				_fire_at_player(600.0, 2, Color.ORANGE)
		1:
			if _pattern_timer >= 0.8:
				_pattern_timer = 0.0
				_fire_radial(12, 500.0, 2, Color.ORANGE, _time * 45.0)
				_fire_at_player(700.0, 3, Color.RED)
		2:
			if _pattern_timer >= 0.6:
				_pattern_timer = 0.0
				_fire_radial(16, 520.0, 2, Color.CYAN, -_time * 60.0)
				_fire_radial(8, 380.0, 2, Color.MAGENTA, _time * 30.0)
		3:
			if _pattern_timer >= 0.4:
				_pattern_timer = 0.0
				_fire_radial(20, 560.0, 3, Color.YELLOW, sin(_time * 3.0) * 90.0)
				_fire_at_player(750.0, 3, Color.WHITE)
