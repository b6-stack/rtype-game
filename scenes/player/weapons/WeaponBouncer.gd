class_name WeaponBouncer
extends WeaponBase
## WeaponBouncer — fires ricocheting bullets that bounce off top and bottom walls.

func _do_fire(spawn_pos: Vector2) -> void:
	var angle: float = 20.0
	var b1: Bullet = _spawn_bullet(spawn_pos, Vector2.RIGHT.rotated(deg_to_rad(angle)) * bullet_speed, bullet_color, damage, 0.9)
	var b2: Bullet = _spawn_bullet(spawn_pos, Vector2.RIGHT.rotated(deg_to_rad(-angle)) * bullet_speed, bullet_color, damage, 0.9)
	if b1: _attach_bounce(b1)
	if b2: _attach_bounce(b2)

func _do_charge_fire(spawn_pos: Vector2, charge_level: float) -> void:
	var raw_dmg: float = damage * 1.5
	var bouncer_dmg: int = max(1, int(raw_dmg * get_charge_tier_multiplier(charge_level)))
	for i in 3:
		var angle: float = -30.0 + i * 30.0
		var b: Bullet = _spawn_bullet(spawn_pos, Vector2.RIGHT.rotated(deg_to_rad(angle)) * bullet_speed, bullet_color.lightened(0.2 if charge_level < 1.0 else 0.5), bouncer_dmg, 1.3)
		if b: _attach_bounce(b)

func _attach_bounce(b: Bullet) -> void:
	var timer := Timer.new()
	timer.wait_time = 0.03
	timer.autostart = true
	b.add_child(timer)
	timer.timeout.connect(func():
		if not is_instance_valid(b):
			return
		if b.global_position.y < 80.0 and b.velocity.y < 0:
			b.velocity.y = -b.velocity.y
			b.rotation = b.velocity.angle()
		elif b.global_position.y > 1000.0 and b.velocity.y > 0:
			b.velocity.y = -b.velocity.y
			b.rotation = b.velocity.angle()
	)
