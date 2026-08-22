class_name WeaponPlasma
extends WeaponBase
## WeaponPlasma — slow heavy energy spheres.
## Super Charge: Supernova Sphere — gigantic piercing plasma sun.

func _do_fire(spawn_pos: Vector2) -> void:
	_spawn_bullet(
		spawn_pos,
		Vector2.RIGHT * bullet_speed * 0.75,
		bullet_color,
		damage,
		1.35,
		"plasma"
	)

func _do_charge_fire(spawn_pos: Vector2, charge_level: float) -> void:
	var giant_size: float = lerpf(2.2, 4.5, charge_level)
	var giant_speed: float = bullet_speed * lerpf(0.65, 0.40, charge_level)
	var raw_giant_dmg: float = damage * 2.8 * charge_level + 15.0
	var giant_damage: int = max(1, int(raw_giant_dmg * get_charge_tier_multiplier(charge_level)))
	var giant_col: Color = bullet_color.lightened(0.4 if charge_level < 1.0 else 0.85)
	var pierces: int = 1 if charge_level < 1.0 else 6

	_spawn_bullet(
		spawn_pos,
		Vector2.RIGHT * giant_speed,
		giant_col,
		giant_damage,
		giant_size,
		"plasma",
		pierces
	)
