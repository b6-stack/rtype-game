class_name WeaponPlasma
extends WeaponBase
## WeaponPlasma -- slow, medium plasma ball that hits hard.
## Charge: fires a condensed plasma sphere with heavy damage.

func _do_fire(spawn_pos: Vector2) -> void:
	_spawn_bullet(
		spawn_pos,
		Vector2.RIGHT * bullet_speed * 0.7,
		bullet_color,
		damage,
		1.4,
		"plasma"
	)

func _do_charge_fire(spawn_pos: Vector2, charge_level: float) -> void:
	var giant_size: float = lerpf(2.2, 3.0, charge_level)
	var giant_speed: float = bullet_speed * lerpf(0.55, 0.45, charge_level)
	var giant_damage: int = int(damage * 2.2 * charge_level + 10)
	var giant_col: Color = bullet_color.lightened(0.4)
	_spawn_bullet(
		spawn_pos,
		Vector2.RIGHT * giant_speed,
		giant_col,
		giant_damage,
		giant_size,
		"plasma"
	)
