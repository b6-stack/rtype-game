class_name WeaponDrill
extends WeaponBase
## WeaponDrill — heavy armor-piercing projectile that punches through multiple targets.

func _do_fire(spawn_pos: Vector2) -> void:
	_spawn_bullet(spawn_pos, Vector2.RIGHT * bullet_speed * 1.05, bullet_color, damage, 1.2)

func _do_charge_fire(spawn_pos: Vector2, charge_level: float) -> void:
	var raw_dmg: float = damage * 2.2 * charge_level + 10.0
	var drill_dmg: int = max(1, int(raw_dmg * get_charge_tier_multiplier(charge_level)))
	_spawn_bullet(spawn_pos, Vector2.RIGHT * bullet_speed * 1.15, bullet_color.lightened(0.4 if charge_level < 1.0 else 0.7), drill_dmg, 2.0)
