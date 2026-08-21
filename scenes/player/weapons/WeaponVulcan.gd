class_name WeaponVulcan
extends WeaponBase
## WeaponVulcan — rapid-fire single shots forward.
## Charge: fires a focused 3-bullet spread.

func _do_fire(spawn_pos: Vector2) -> void:
	_spawn_bullet(
		spawn_pos,
		Vector2.RIGHT * bullet_speed,
		bullet_color,
		damage,
		0.9
	)

func _do_charge_fire(spawn_pos: Vector2, charge_level: float) -> void:
	var spread_angle: float = lerpf(25.0, 45.0, charge_level)
	var base_charge_damage: float = damage * lerpf(1.3, 1.8, charge_level)
	var charge_damage: int = max(1, int(base_charge_damage * get_charge_tier_multiplier(charge_level)))
	_spawn_spread(
		spawn_pos,
		Vector2.RIGHT * bullet_speed * 0.95,
		bullet_color.lightened(0.25 if charge_level < 1.0 else 0.5),
		charge_damage,
		1.1 if charge_level < 1.0 else 1.35,
		3,
		spread_angle
	)
