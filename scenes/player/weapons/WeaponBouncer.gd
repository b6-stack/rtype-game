class_name WeaponBouncer
extends WeaponBase
## WeaponBouncer — ricocheting prism crystals that bounce off cavern walls.
## Super Charge: 7-way Prism Flak Cannon filling the arena.

func _do_fire(spawn_pos: Vector2) -> void:
	var angle: float = 22.0
	var b1: Bullet = _spawn_bullet(spawn_pos, Vector2.RIGHT.rotated(deg_to_rad(angle)) * bullet_speed, bullet_color, damage, 1.05, "bouncer")
	var b2: Bullet = _spawn_bullet(spawn_pos, Vector2.RIGHT.rotated(deg_to_rad(-angle)) * bullet_speed, bullet_color, damage, 1.05, "bouncer")
	if b1: _attach_bounce(b1)
	if b2: _attach_bounce(b2)

func _do_charge_fire(spawn_pos: Vector2, charge_level: float) -> void:
	var count: int = 3 if charge_level < 0.6 else (5 if charge_level < 1.0 else 7)
	var raw_dmg: float = damage * lerpf(1.4, 2.4, charge_level)
	var bouncer_dmg: int = max(1, int(raw_dmg * get_charge_tier_multiplier(charge_level)))
	var bouncer_size: float = lerpf(1.1, 1.9, charge_level)
	var bouncer_col: Color = bullet_color.lightened(0.25 if charge_level < 1.0 else 0.7)

	var angles: Array[float] = [-45.0, -30.0, -15.0, 0.0, 15.0, 30.0, 45.0]
	for i in count:
		var a: float = angles[i % angles.size()]
		var b: Bullet = _spawn_bullet(spawn_pos, Vector2.RIGHT.rotated(deg_to_rad(a)) * bullet_speed, bouncer_col, bouncer_dmg, bouncer_size, "bouncer")
		if b: _attach_bounce(b)

func _attach_bounce(b: Bullet) -> void:
	var timer := Timer.new()
	timer.wait_time = 0.025
	timer.autostart = true
	b.add_child(timer)
	timer.timeout.connect(func():
		if not is_instance_valid(b) or b.is_queued_for_deletion():
			return
		if b.global_position.y < 90.0 and b.velocity.y < 0:
			b.velocity.y = -b.velocity.y
			b.rotation = b.velocity.angle()
		elif b.global_position.y > 990.0 and b.velocity.y > 0:
			b.velocity.y = -b.velocity.y
			b.rotation = b.velocity.angle()
	)
