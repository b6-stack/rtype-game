class_name WeaponWave
extends WeaponBase
## WeaponWave — fires projectiles in a sine-wave oscillation.

func _do_fire(spawn_pos: Vector2) -> void:
	var b1: Bullet = _spawn_bullet(spawn_pos, Vector2.RIGHT * bullet_speed, bullet_color, damage, 0.9)
	var b2: Bullet = _spawn_bullet(spawn_pos, Vector2.RIGHT * bullet_speed, bullet_color, damage, 0.9)
	if b1: _attach_wave(b1, 1.0, 240.0)
	if b2: _attach_wave(b2, -1.0, 240.0)

func _do_charge_fire(spawn_pos: Vector2, charge_level: float) -> void:
	var b1: Bullet = _spawn_bullet(spawn_pos, Vector2.RIGHT * bullet_speed, bullet_color.lightened(0.3), int(damage * 1.8), 1.4)
	var b2: Bullet = _spawn_bullet(spawn_pos, Vector2.RIGHT * bullet_speed, bullet_color.lightened(0.3), int(damage * 1.8), 1.4)
	if b1: _attach_wave(b1, 1.0, 380.0)
	if b2: _attach_wave(b2, -1.0, 380.0)

func _attach_wave(b: Bullet, phase_sign: float, amplitude: float) -> void:
	var time: float = 0.0
	var timer := Timer.new()
	timer.wait_time = 0.016
	timer.autostart = true
	b.add_child(timer)
	timer.timeout.connect(func():
		if not is_instance_valid(b):
			return
		time += 0.016
		b.velocity.y = cos(time * 10.0) * amplitude * phase_sign
	)
