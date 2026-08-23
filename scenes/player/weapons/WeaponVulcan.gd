class_name WeaponVulcan
extends WeaponBase
## WeaponVulcan — rapid-fire kinetic needle cannons.
## Super Charge: Massive 7-bullet wide vulcan flak storm.

func _do_fire(spawn_pos: Vector2) -> void:
	_spawn_bullet(
		spawn_pos,
		Vector2.RIGHT * bullet_speed,
		bullet_color,
		damage,
		1.0,
		"vulcan"
	)

func _do_charge_fire(spawn_pos: Vector2, charge_level: float) -> void:
	var count: int = 3 if charge_level < 0.6 else (5 if charge_level < 1.0 else 7)
	var spread_angle: float = 24.0 if charge_level < 0.6 else (38.0 if charge_level < 1.0 else 55.0)
	var base_charge_damage: float = damage * lerpf(1.5, 2.6, charge_level)
	var charge_damage: int = max(1, int(base_charge_damage * get_charge_tier_multiplier(charge_level) * get_charge_damage_scale()))
	var bullet_size: float = lerpf(1.1, 1.85, charge_level)

	_spawn_spread(
		spawn_pos,
		Vector2.RIGHT * bullet_speed * 1.05,
		bullet_color.lightened(0.3 if charge_level < 1.0 else 0.7),
		charge_damage,
		bullet_size,
		count,
		spread_angle,
		"vulcan",
		0,
		charge_level >= 1.0
	)
