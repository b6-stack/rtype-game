class_name WeaponDrill
extends WeaponBase
## WeaponDrill — heavy armor-piercing rotating corkscrew drill.
## Super Charge: Titan Corkscrew Drill — gigantic piercing mega-drill.

func _do_fire(spawn_pos: Vector2) -> void:
	_spawn_bullet(
		spawn_pos,
		Vector2.RIGHT * bullet_speed * 1.1,
		bullet_color,
		damage,
		1.3,
		"drill",
		2
	)

func _do_charge_fire(spawn_pos: Vector2, charge_level: float) -> void:
	var raw_dmg: float = damage * 2.6 * charge_level + 18.0
	var drill_dmg: int = max(1, int(raw_dmg * get_charge_tier_multiplier(charge_level)))
	var drill_size: float = lerpf(1.8, 3.8, charge_level)
	var drill_col: Color = bullet_color.lightened(0.35 if charge_level < 1.0 else 0.8)
	var pierces: int = 4 if charge_level < 1.0 else 12

	_spawn_bullet(
		spawn_pos,
		Vector2.RIGHT * bullet_speed * 1.25,
		drill_col,
		drill_dmg,
		drill_size,
		"drill",
		pierces,
		charge_level >= 1.0
	)
