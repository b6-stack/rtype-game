class_name WeaponWave
extends WeaponBase
## WeaponWave — oscillating sine-wave phase pulses.
## Super Charge: Mega Resonance Wave — 4 synchronized massive energy rings.

func _do_fire(spawn_pos: Vector2) -> void:
	var b1: Bullet = _spawn_bullet(spawn_pos, Vector2.RIGHT * bullet_speed, bullet_color, damage, 1.1, "wave")
	var b2: Bullet = _spawn_bullet(spawn_pos, Vector2.RIGHT * bullet_speed, bullet_color, damage, 1.1, "wave")
	if b1: _attach_wave(b1, 1.0, 260.0)
	if b2: _attach_wave(b2, -1.0, 260.0)

func _do_charge_fire(spawn_pos: Vector2, charge_level: float) -> void:
	var wave_count: int = 2 if charge_level < 0.6 else (3 if charge_level < 1.0 else 4)
	var raw_dmg: float = damage * lerpf(1.6, 2.7, charge_level)
	var wave_dmg: int = max(1, int(raw_dmg * get_charge_tier_multiplier(charge_level)))
	var wave_size: float = lerpf(1.3, 2.4, charge_level)
	var wave_col: Color = bullet_color.lightened(0.3 if charge_level < 1.0 else 0.75)
	var pierces: int = 1 if charge_level < 1.0 else 4

	var amplitudes: Array[float] = [180.0, 320.0, -180.0, -320.0]
	for i in wave_count:
		var amp: float = amplitudes[i % amplitudes.size()]
		var b: Bullet = _spawn_bullet(spawn_pos, Vector2.RIGHT * (bullet_speed * 1.05), wave_col, wave_dmg, wave_size, "wave", pierces)
		if b: _attach_wave(b, 1.0 if amp > 0 else -1.0, absf(amp))

func _attach_wave(b: Bullet, phase_sign: float, amplitude: float) -> void:
	var time: float = 0.0
	var timer := Timer.new()
	timer.wait_time = 0.016
	timer.autostart = true
	b.add_child(timer)
	timer.timeout.connect(func():
		if not is_instance_valid(b) or b.is_queued_for_deletion():
			return
		time += 0.016
		b.velocity.y = cos(time * 11.0) * amplitude * phase_sign
	)
