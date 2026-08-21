class_name WeaponRicochet
extends WeaponBase
## WeaponRicochet — on impact with enemies or borders, splits into cluster shrapnel.

func _do_fire(spawn_pos: Vector2) -> void:
	var b: Bullet = _spawn_bullet(spawn_pos, Vector2.RIGHT * bullet_speed, bullet_color, damage, 0.9)
	if b:
		b.hit_target.connect(func(pos: Vector2):
			_spawn_spread(pos, Vector2.RIGHT * bullet_speed * 0.7, bullet_color.lightened(0.2), int(damage * 0.5), 0.7, 2, 45.0)
		)

func _do_charge_fire(spawn_pos: Vector2, charge_level: float) -> void:
	var raw_dmg: float = damage * 1.4
	var cluster_dmg: int = max(1, int(raw_dmg * get_charge_tier_multiplier(charge_level)))
	for i in 2:
		var angle: float = -15.0 + i * 30.0
		var b: Bullet = _spawn_bullet(spawn_pos, Vector2.RIGHT.rotated(deg_to_rad(angle)) * bullet_speed, bullet_color.lightened(0.3 if charge_level < 1.0 else 0.6), cluster_dmg, 1.1)
		if b:
			b.hit_target.connect(func(pos: Vector2):
				_spawn_spread(pos, Vector2.RIGHT * bullet_speed * 0.75, bullet_color.lightened(0.3), max(1, int(damage * 0.6 * get_charge_tier_multiplier(charge_level))), 0.8, 3, 60.0)
			)
