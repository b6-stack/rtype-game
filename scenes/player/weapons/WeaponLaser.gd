class_name WeaponLaser
extends WeaponBase
## WeaponLaser — concentrated piercing high-velocity beam.
## Super Charge: Hyper Mega-Beam — 5 parallel piercing laser beams across a wide column.

func _do_fire(spawn_pos: Vector2) -> void:
	_spawn_bullet(
		spawn_pos,
		Vector2.RIGHT * bullet_speed * 1.3,
		bullet_color,
		damage,
		0.85,
		"laser",
		1
	)

func _do_charge_fire(spawn_pos: Vector2, charge_level: float) -> void:
	var beam_count: int = 2 if charge_level < 0.6 else (3 if charge_level < 1.0 else 5)
	var raw_beam_dmg: float = damage * lerpf(1.6, 2.8, charge_level)
	var beam_damage: int = max(1, int(raw_beam_dmg * get_charge_tier_multiplier(charge_level)))
	var beam_size: float = lerpf(1.0, 2.2, charge_level)
	var beam_col: Color = bullet_color.lightened(0.35 if charge_level < 1.0 else 0.8)
	var pierces: int = 2 if charge_level < 1.0 else 8

	var offsets: Array[float] = [-10.0, 10.0] if beam_count == 2 else ([-18.0, 0.0, 18.0] if beam_count == 3 else [-32.0, -16.0, 0.0, 16.0, 32.0])
	for offset: float in offsets:
		var offset_pos := spawn_pos + Vector2(0.0, offset)
		_spawn_bullet(
			offset_pos,
			Vector2.RIGHT * bullet_speed * 1.4,
			beam_col,
			beam_damage,
			beam_size,
			"laser",
			pierces
		)
