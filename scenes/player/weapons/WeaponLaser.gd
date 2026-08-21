class_name WeaponLaser
extends WeaponBase
## WeaponLaser -- thin focused beam simulated by rapid energy pulses.
## Charge: fires dual parallel piercing beams.

const BEAM_OFFSETS: Array[float] = [-4.0, 4.0]

func _do_fire(spawn_pos: Vector2) -> void:
	_spawn_bullet(
		spawn_pos,
		Vector2.RIGHT * bullet_speed * 1.2,
		bullet_color,
		damage,
		0.7
	)

func _do_charge_fire(spawn_pos: Vector2, charge_level: float) -> void:
	var beam_speed: float = bullet_speed * lerpf(1.1, 1.3, charge_level)
	var raw_beam_dmg: float = damage * lerpf(1.4, 2.0, charge_level)
	var beam_damage: int = max(1, int(raw_beam_dmg * get_charge_tier_multiplier(charge_level)))
	var beam_size: float = lerpf(0.9, 1.25, charge_level)
	var beam_col: Color = bullet_color.lightened(0.35 if charge_level < 1.0 else 0.6)

	for offset: float in BEAM_OFFSETS:
		var offset_pos := spawn_pos + Vector2(0.0, offset * beam_size)
		_spawn_bullet(
			offset_pos,
			Vector2.RIGHT * beam_speed,
			beam_col,
			beam_damage,
			beam_size
		)
