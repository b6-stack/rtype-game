class_name WeaponRicochet
extends WeaponBase
## WeaponRicochet — crystal shards that fragment into cluster spikes on impact.
## Super Charge: Cluster Shard Annihilator — 4 heavy shard bombs.

func _do_fire(spawn_pos: Vector2) -> void:
	var b: Bullet = _spawn_bullet(spawn_pos, Vector2.RIGHT * bullet_speed, bullet_color, damage, 1.0, "ricochet")
	if b:
		b.hit_target.connect(func(pos: Vector2):
			_spawn_spread(pos, Vector2.RIGHT * bullet_speed * 0.75, bullet_color.lightened(0.2), int(damage * 0.6), 0.75, 2, 50.0, "ricochet")
		)

func _do_charge_fire(spawn_pos: Vector2, charge_level: float) -> void:
	var bomb_count: int = 2 if charge_level < 0.6 else (3 if charge_level < 1.0 else 4)
	var raw_dmg: float = damage * lerpf(1.5, 2.5, charge_level)
	var cluster_dmg: int = max(1, int(raw_dmg * get_charge_tier_multiplier(charge_level)))
	var cluster_size: float = lerpf(1.2, 1.9, charge_level)
	var shard_count: int = 3 if charge_level < 1.0 else 4

	var angles: Array = [-24.0, 24.0, -8.0, 8.0]
	for i in bomb_count:
		var angle: float = float(angles[i % angles.size()])
		var b: Bullet = _spawn_bullet(spawn_pos, Vector2.RIGHT.rotated(deg_to_rad(angle)) * bullet_speed, bullet_color.lightened(0.3 if charge_level < 1.0 else 0.7), cluster_dmg, cluster_size, "ricochet", 0, charge_level >= 1.0)
		if b:
			b.hit_target.connect(func(pos: Vector2):
				_spawn_spread(pos, Vector2.RIGHT * bullet_speed * 0.8, bullet_color.lightened(0.4), max(1, int(damage * 0.75 * get_charge_tier_multiplier(charge_level))), 0.9, shard_count, 70.0, "ricochet")
			)
